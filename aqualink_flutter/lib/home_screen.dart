import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as leaflet;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
import 'app_state.dart';
import 'firestore_service.dart';
import 'login_screen.dart';
import 'models/models.dart';

const _green = Color(0xFF009B70);
const _ink = Color(0xFF17212B);
const _muted = Color(0xFF71808D);
const _paper = Color(0xFFF5F8FA);
const _line = Color(0xFFE3EAEE);

Future<void> _confirmOwnerLogout(BuildContext context, AppState state) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'Are you sure you want to log out of the owner account?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (shouldLogout != true) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
  state.logout();
  await FirestoreService.signOut();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String? _subscribedStation;
  StreamSubscription<List<WaterOrder>>? _ordersSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final station = state.stationName;
    if (_subscribedStation == station) return;
    _subscribedStation = station;
    _ordersSubscription?.cancel();
    if (station == null || Firebase.apps.isEmpty) return;
    _ordersSubscription = FirestoreService.watchOrdersForStation(station)
        .listen(
          (orders) => state.replaceIncomingOrdersForStation(station, orders),
          onError: (Object error) =>
              debugPrint('Station orders loading failed: $error'),
        );
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final station = state.stationName ?? 'Remoreras Water Refilling';
    final owner = state.userName.split(' ').first;
    final pages = [
      _DashboardPage(
        owner: owner,
        station: station,
        onNavigate: (index) => setState(() => _tab = index),
      ),
      const _OrdersPage(),
      const _ProductsPage(),
      _ProfilePage(owner: state.userName, station: station),
    ];

    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: _OwnerNavigation(
        selectedIndex: _tab,
        onSelected: (index) => setState(() => _tab = index),
      ),
    );
  }
}

class _OwnerNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _OwnerNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.dashboard_outlined, 'Dashboard'),
      (Icons.receipt_long_outlined, 'Orders'),
      (Icons.inventory_2_outlined, 'Products'),
      (Icons.person_outline, 'Profile'),
    ];
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE5F8F1),
      height: 68,
      destinations: [
        for (final item in items)
          NavigationDestination(icon: Icon(item.$1), label: item.$2),
      ],
    );
  }
}

class _DashboardPage extends StatefulWidget {
  final String owner;
  final String station;
  final ValueChanged<int> onNavigate;

  const _DashboardPage({
    required this.owner,
    required this.station,
    required this.onNavigate,
  });

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showNotifications(BuildContext context) {
    final pendingOrders = AppScope.of(context)
        .incomingOrdersForStation(widget.station)
        .where((order) => order.status == OrderStatus.pending)
        .toList();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notifications'),
        content: pendingOrders.isEmpty
            ? const Text('No pending order notifications.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: pendingOrders
                      .map(
                        (order) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.receipt_long_outlined,
                            color: _green,
                          ),
                          title: Text('#${order.number}'),
                          subtitle: Text(
                            '${order.customer}  •  P${order.total}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onNavigate(1);
            },
            child: const Text('Review orders'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final summary = state.ownerDailySummary(widget.station);
    final pendingOrders = state
        .incomingOrdersForStation(widget.station)
        .where((order) => order.status == OrderStatus.pending)
        .toList();
    return _PageScaffold(
      title: 'Owner Dashboard',
      subtitle: 'Water Station Management',
      action: IconButton(
        tooltip: 'Notifications',
        onPressed: () => _showNotifications(context),
        icon: const Icon(Icons.notifications_none, color: _muted),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Hello, ${widget.owner}!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Here is what is happening at your station today.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 18),
          _StationHeader(station: widget.station),
          const SizedBox(height: 18),
          const _SectionTitle('OVERVIEW', trailing: 'Today'),
          const SizedBox(height: 9),
          Row(
            children: [
              _StatCard(
                value: '${summary.newOrders}',
                label: 'New Orders',
                icon: Icons.add_circle_outline,
                onTap: _showOrders,
              ),
              SizedBox(width: 10),
              _StatCard(
                value: '${summary.activeOrders}',
                label: 'Active Orders',
                icon: Icons.timelapse,
                onTap: _showOrders,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCard(
                value: '${summary.completedOrders}',
                label: 'Completed Orders',
                icon: Icons.check_circle_outline,
                onTap: _showOrders,
              ),
              SizedBox(width: 10),
              _StatCard(
                value: 'P${summary.sales}',
                label: "Today's Sales",
                icon: Icons.payments_outlined,
                highlighted: true,
                onTap: () => _showSales(summary.sales),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            'PENDING ATTENTION',
            trailing: '${pendingOrders.length} orders',
          ),
          const SizedBox(height: 9),
          if (pendingOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No pending orders for this station.',
                style: TextStyle(fontSize: 11, color: _muted),
              ),
            )
          else
            ...pendingOrders.map(
              (order) => _AttentionRow(
                name: '#${order.number}',
                detail: '${order.customer} has an order waiting for acceptance',
                status: 'Review',
                color: _green,
                onTap: () => widget.onNavigate(1),
              ),
            ),
        ],
      ),
    );
  }

  void _showOrders() => widget.onNavigate(1);

  void _showSales(int sales) {
    _showMessage("Today's completed sales: P$sales");
  }
}

class _PageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F8F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.water_drop_outlined, color: _green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            action ?? const Icon(Icons.more_horiz, color: _muted),
          ],
        ),
      ),
      Expanded(child: child),
    ],
  );
}

class _StationHeader extends StatelessWidget {
  final String station;
  const _StationHeader({required this.station});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F8F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_outlined, color: _green, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppScope.of(context).detailsForStation(station).address,
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ),
        const _StatusBadge('Open'),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: highlighted ? _green : Colors.white,
          border: Border.all(color: highlighted ? _green : _line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: highlighted ? Colors.white : _green),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: highlighted ? Colors.white : _ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: highlighted ? Colors.white : _muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final String? trailing;
  const _SectionTitle(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: .7,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(
            fontSize: 10,
            color: _green,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _AttentionRow extends StatelessWidget {
  final String name;
  final String detail;
  final String status;
  final Color color;
  final VoidCallback? onTap;
  const _AttentionRow({
    required this.name,
    required this.detail,
    required this.status,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProductsPage extends StatefulWidget {
  const _ProductsPage();

  @override
  State<_ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<_ProductsPage> {
  String get _stationName =>
      AppScope.of(context).stationName ?? 'Remoreras Water Refilling';

  Future<void> _editProduct({int? index}) async {
    final state = AppScope.of(context);
    final products = state.productsForStation(_stationName);
    final existing = index == null ? null : products[index];
    final nameController = TextEditingController(text: existing?.name ?? '');
    final priceController = TextEditingController(
      text: existing?.price.toString() ?? '',
    );
    var available = existing?.available ?? true;
    final product = await showDialog<StationProduct>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? 'Add product' : 'Edit product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (P)'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available'),
                value: available,
                onChanged: (value) => setDialogState(() => available = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price = int.tryParse(priceController.text.trim());
                if (name.isNotEmpty && price != null && price > 0) {
                  Navigator.pop(
                    context,
                    StationProduct(
                      name: name,
                      price: price,
                      available: available,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    priceController.dispose();
    if (!mounted || product == null) return;
    if (index == null) {
      try {
        await FirestoreService.saveProduct(
          stationName: _stationName,
          product: product,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save product to Firebase.')),
        );
        return;
      }
      state.addProduct(stationName: _stationName, product: product);
    } else {
      state.updateProduct(
        stationName: _stationName,
        index: index,
        product: product,
      );
    }
  }

  Future<void> _removeProduct(int index) async {
    final state = AppScope.of(context);
    final product = state.productsForStation(_stationName)[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove product?'),
        content: Text('Remove ${product.name} from the station catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      state.removeProduct(stationName: _stationName, index: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = AppScope.of(context).productsForStation(_stationName);
    return _PageScaffold(
      title: 'Products',
      subtitle: 'Manage inventory and pricing',
      action: IconButton(
        tooltip: 'Add product',
        onPressed: () => _editProduct(),
        icon: const Icon(Icons.add_circle_outline, color: _green),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ...products.asMap().entries.map(
            (entry) => _ProductTile(
              name: entry.value.name,
              price: 'P${entry.value.price}',
              stock: entry.value.available ? 'Available' : 'Unavailable',
              icon: Icons.water_drop_outlined,
              color: entry.value.available ? _green : _muted,
              unavailable: !entry.value.available,
              onEdit: () => _editProduct(index: entry.key),
              onRemove: () => _removeProduct(entry.key),
            ),
          ),
          const SizedBox(height: 10),
          _PrimaryButton('Add Product', onTap: () => _editProduct()),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final String name, price, stock;
  final IconData icon;
  final Color color;
  final bool unavailable;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _ProductTile({
    required this.name,
    required this.price,
    required this.stock,
    required this.icon,
    required this.color,
    required this.onEdit,
    required this.onRemove,
    this.unavailable = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$price / container',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                unavailable
                    ? 'Unavailable  •  Stock: $stock'
                    : 'Available  •  Stock: $stock',
                style: TextStyle(
                  fontSize: 9,
                  color: unavailable ? Colors.red : _green,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit product',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18, color: _muted),
        ),
        IconButton(
          tooltip: 'Remove product',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        ),
        _Toggle(on: !unavailable),
      ],
    ),
  );
}

class _Toggle extends StatelessWidget {
  final bool on;
  const _Toggle({required this.on});
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 20,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: on ? _green : _line,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Align(
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _OrdersPage extends StatelessWidget {
  const _OrdersPage();
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final stationName = state.stationName ?? '';
    final submittedOrders = state.incomingOrdersForStation(stationName);
    return _PageScaffold(
      title: 'Orders',
      subtitle: 'Manage customer orders',
      action: const Icon(Icons.search, color: _muted),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const _FilterChip(label: 'New', selected: true),
          const SizedBox(height: 16),
          ...submittedOrders.map(
            (order) => _OwnerOrder.fromOrder(order: order),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  const _FilterChip({required this.label, this.selected = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? _green : Colors.white,
      border: Border.all(color: selected ? _green : _line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        color: selected ? Colors.white : _muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _OwnerOrder extends StatelessWidget {
  final String number, customer, total, status;
  final String fulfillment;
  final WaterOrder? order;
  const _OwnerOrder({
    required this.number,
    required this.customer,
    required this.total,
    required this.status,
    this.fulfillment = '',
    this.order,
  });

  factory _OwnerOrder.fromOrder({required WaterOrder order}) => _OwnerOrder(
    number: order.number,
    customer: order.customer,
    total: 'P${order.total}',
    status: _orderStatusLabel(order.status),
    fulfillment: order.fulfillmentMethod == FulfillmentMethod.delivery
        ? 'Delivery'
        : 'Pickup',
    order: order,
  );

  static String _orderStatusLabel(OrderStatus status) =>
      status.name[0].toUpperCase() + status.name.substring(1);

  Future<void> _saveStatus(
    BuildContext context,
    OrderStatus status, {
    String? reason,
  }) async {
    final currentOrder = order;
    if (currentOrder == null) return;
    if (Firebase.apps.isNotEmpty) {
      try {
        await FirestoreService.updateOrderStatus(
          number: currentOrder.number,
          status: status,
          reason: reason,
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $error')),
        );
        return;
      }
    }
    if (!context.mounted) return;
    AppScope.of(context).updateOrderStatus(
      number: currentOrder.number,
      status: status,
      reason: reason,
    );
  }

  LatLng? _stationLocation(String stationName) => switch (stationName) {
    'Remoreras Water Refilling' => const LatLng(9.9547, 124.0084),
    'J&P Water Station' => const LatLng(9.9601634, 124.0260079),
    'CJoan Water Station' => const LatLng(9.9501, 124.0224),
    _ => null,
  };

  Future<List<LatLng>> _loadDrivingRoute(
    LatLng station,
    LatLng customer,
  ) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${station.longitude},${station.latitude};'
          '${customer.longitude},${customer.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Road route service returned ${response.statusCode}.');
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = result['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw StateError('No road route was found for this delivery.');
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    return coordinates.map((coordinate) {
      final pair = coordinate as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
  }

  void _showCustomerLocation(BuildContext context) {
    final currentOrder = order;
    if (currentOrder == null) return;
    final latitude = currentOrder.deliveryLatitude;
    final longitude = currentOrder.deliveryLongitude;
    final location = latitude != null && longitude != null
        ? LatLng(latitude, longitude)
        : null;
    final station = _stationLocation(currentOrder.station);
    final routeFuture = location != null && station != null
        ? _loadDrivingRoute(station, location)
        : null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Customer location #${currentOrder.number}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentOrder.customer,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(currentOrder.deliveryAddress ?? 'Address not provided'),
                const SizedBox(height: 12),
                if (location == null)
                  Container(
                    height: 100,
                    alignment: Alignment.center,
                    color: _paper,
                    child: const Text(
                      'GPS location was not shared. Use the delivery address above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: _muted),
                    ),
                  )
                else ...[
                  FutureBuilder<List<LatLng>>(
                    future: routeFuture,
                    builder: (context, snapshot) {
                      final route = snapshot.data ?? const <LatLng>[];
                      final stationMarker = station == null
                          ? null
                          : leaflet.Marker(
                              point: station,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.storefront,
                                color: _green,
                                size: 30,
                              ),
                            );
                      final routeBounds = [?station, location, ...route];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 230,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: leaflet.FlutterMap(
                                options: leaflet.MapOptions(
                                  initialCenter: station ?? location,
                                  initialZoom: 14,
                                  initialCameraFit: routeBounds.length > 1
                                      ? leaflet.CameraFit.bounds(
                                          bounds:
                                              leaflet.LatLngBounds.fromPoints(
                                                routeBounds,
                                              ),
                                          padding: const EdgeInsets.all(24),
                                        )
                                      : null,
                                ),
                                children: [
                                  leaflet.TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.aqualink',
                                  ),
                                  if (route.length > 1)
                                    leaflet.PolylineLayer(
                                      polylines: [
                                        leaflet.Polyline(
                                          points: route,
                                          color: _green,
                                          strokeWidth: 5,
                                        ),
                                      ],
                                    ),
                                  leaflet.MarkerLayer(
                                    markers: [
                                      ?stationMarker,
                                      leaflet.Marker(
                                        point: location,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 36,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Finding a road route for delivery...',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                            )
                          else if (snapshot.hasError || route.length < 2)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Road route unavailable. The station and customer locations are marked.',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'GPS: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject order'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain why this order is being rejected',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) Navigator.pop(context, reason);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (!context.mounted || reason == null || order == null) return;
    await _saveStatus(context, OrderStatus.rejected, reason: reason);
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '#$number',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(width: 7),
            _StatusBadge(status),
            const Spacer(),
            const Text(
              'Just now',
              style: TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order == null
                        ? '2 x Purified Water (5 Gal)\n1 x Mineral Water (5 Gal)'
                        : order!.items
                              .map(
                                (item) =>
                                    '${item.quantity} x ${item.productName}',
                              )
                              .join('\n'),
                    style: TextStyle(fontSize: 9, color: _muted, height: 1.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order == null
                        ? 'Poblacion Norte, Clarin, Bohol'
                        : order!.fulfillmentMethod == FulfillmentMethod.delivery
                        ? order!.deliveryAddress ?? 'Delivery address pending'
                        : 'Pickup at station',
                    style: TextStyle(fontSize: 9, color: _muted),
                  ),
                  if (fulfillment.isNotEmpty)
                    Text(
                      fulfillment,
                      style: const TextStyle(fontSize: 9, color: _muted),
                    ),
                  if (order?.fulfillmentMethod == FulfillmentMethod.delivery)
                    TextButton.icon(
                      onPressed: order == null
                          ? null
                          : () => _showCustomerLocation(context),
                      icon: const Icon(Icons.location_on_outlined, size: 16),
                      label: const Text('View customer location'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                    ),
                  if (order?.reason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${order!.reason}',
                      style: const TextStyle(fontSize: 9, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              total,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (order == null || order!.status == OrderStatus.pending)
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  'Reject',
                  onTap: order == null ? null : () => _reject(context),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PrimaryButton(
                  'Accept',
                  onTap: order == null
                      ? null
                      : () => _saveStatus(context, OrderStatus.accepted),
                ),
              ),
            ],
          ),
        if (order?.status == OrderStatus.accepted)
          _PrimaryButton(
            'Mark Complete',
            onTap: () => _saveStatus(context, OrderStatus.completed),
          ),
      ],
    ),
  );
}

class _ProfilePage extends StatefulWidget {
  final String owner, station;
  const _ProfilePage({required this.owner, required this.station});

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  Future<void> _editProfile() async {
    final state = AppScope.of(context);
    final current = state.detailsForStation(widget.station);
    final name = TextEditingController(text: current.name);
    final address = TextEditingController(text: current.address);
    final contact = TextEditingController(text: current.contact);
    final hours = TextEditingController(text: current.operatingHours);
    final areas = TextEditingController(text: current.deliveryAreas);
    final fee = TextEditingController(text: current.deliveryFee.toString());
    final details = await showDialog<StationDetails>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit station profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Station name'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: contact,
                decoration: const InputDecoration(
                  labelText: 'Contact information',
                ),
              ),
              TextField(
                controller: hours,
                decoration: const InputDecoration(labelText: 'Operating hours'),
              ),
              TextField(
                controller: areas,
                decoration: const InputDecoration(labelText: 'Delivery areas'),
              ),
              TextField(
                controller: fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Delivery fee (P)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsedFee = int.tryParse(fee.text.trim());
              if (name.text.trim().isEmpty ||
                  address.text.trim().isEmpty ||
                  contact.text.trim().isEmpty ||
                  hours.text.trim().isEmpty ||
                  areas.text.trim().isEmpty ||
                  parsedFee == null ||
                  parsedFee < 0) {
                return;
              }
              Navigator.pop(
                context,
                StationDetails(
                  name: name.text.trim(),
                  address: address.text.trim(),
                  contact: contact.text.trim(),
                  operatingHours: hours.text.trim(),
                  deliveryAreas: areas.text.trim(),
                  deliveryFee: parsedFee,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    contact.dispose();
    hours.dispose();
    areas.dispose();
    fee.dispose();
    if (!mounted || details == null) return;
    try {
      await FirestoreService.saveStationDetails(
        stationId: widget.station,
        details: details,
      );
      if (!mounted) return;
      state.updateStationDetails(stationName: widget.station, details: details);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Station profile saved.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save station profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final details = state.detailsForStation(widget.station);
    return _PageScaffold(
      title: 'Station Profile',
      subtitle: 'Manage your station details',
      action: const Icon(Icons.more_horiz, color: _muted),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 8),
          const CircleAvatar(
            radius: 38,
            backgroundColor: Color(0xFFE5F8F1),
            child: Icon(Icons.person, size: 36, color: _green),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.owner,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Station owner',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          ),
          const SizedBox(height: 22),
          _ProfileCard(details: details),
          const SizedBox(height: 14),
          _ProfileOption(
            icon: Icons.location_on_outlined,
            label: details.address,
          ),
          _ProfileOption(
            icon: Icons.schedule_outlined,
            label: details.operatingHours,
          ),
          _ProfileOption(
            icon: Icons.local_shipping_outlined,
            label: '${details.deliveryAreas}  •  P${details.deliveryFee}',
          ),
          _ProfileOption(icon: Icons.phone_outlined, label: details.contact),
          const SizedBox(height: 14),
          _PrimaryButton('Edit Profile', onTap: _editProfile),
          const SizedBox(height: 10),
          _OutlineButton(
            'Log out',
            onTap: () => _confirmOwnerLogout(context, state),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final StationDetails details;
  const _ProfileCard({required this.details});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F8F1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.storefront_outlined, color: _green),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details.address,
                style: TextStyle(fontSize: 9, color: _muted),
              ),
            ],
          ),
        ),
        const _StatusBadge('Verified'),
      ],
    ),
  );
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProfileOption({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        Icon(icon, color: _green, size: 19),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, color: _muted, size: 18),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE5F8F1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 8,
        color: _green,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton(this.label, {this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _OutlineButton(this.label, {this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Color(0xFFFFCACA)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
