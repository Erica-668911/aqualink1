import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'login_screen.dart';
import 'models/models.dart';
import 'api_order_tracking_screen.dart';
import 'station_products_screen.dart';
import 'firestore_service.dart';

const _blue = Color(0xFF0878D1);
const _ink = Color(0xFF17212B);
const _muted = Color(0xFF71808D);
const _paper = Color(0xFFF5F8FA);
const _line = Color(0xFFE3EAEE);

Future<void> _useCurrentLocation(BuildContext context) async {
  final state = AppScope.of(context);
  try {
    final error = await state.useCurrentLocation();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Delivery location updated.')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to read your current location.')),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, AppState state) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('Are you sure you want to log out of AquaLink?'),
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

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tab = 0;
  StreamSubscription<List<WaterOrder>>? _ordersSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ordersSubscription != null || Firebase.apps.isEmpty) return;
    final state = AppScope.of(context);
    _ordersSubscription = FirestoreService.watchOrdersForCustomer().listen((
      orders,
    ) {
      state.replaceCustomerOrders(orders);
    });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final pages = [
      _CustomerDashboard(
        state: state,
        onNavigate: (index) => setState(() => _tab = index),
      ),
      const _CustomerOrders(),
      _CustomerProfile(state: state),
    ];
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE5F1FF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _CustomerDashboard extends StatelessWidget {
  final AppState state;
  final ValueChanged<int> onNavigate;

  const _CustomerDashboard({required this.state, required this.onNavigate});

  void _showNotifications(BuildContext context) {
    final orders = state.orders;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order notifications'),
        content: orders.isEmpty
            ? const Text('You have no order updates yet.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: orders.map((order) {
                    final status = order.isPartiallyAccepted
                        ? 'Partially accepted'
                        : order.status.name[0].toUpperCase() +
                              order.status.name.substring(1);
                    final canTrack =
                        order.status != OrderStatus.cancelled &&
                        order.status != OrderStatus.rejected;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        canTrack
                            ? Icons.local_shipping_outlined
                            : Icons.info_outline,
                        color: _blue,
                      ),
                      title: Text('#${order.number}'),
                      subtitle: Text('$status  •  P${order.total}'),
                      trailing: canTrack
                          ? IconButton(
                              tooltip: 'View order status',
                              icon: const Icon(Icons.location_searching),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ApiOrderTrackingScreen(
                                      orderId: order.number,
                                      orderTotal: order.total,
                                      orderItems: order.items,
                                      stationName: order.station,
                                      isDelivery:
                                          order.fulfillmentMethod ==
                                          FulfillmentMethod.delivery,
                                      orderStatus: order.status.name,
                                      barangay: order.barangay,
                                      deliveryLatitude: order.deliveryLatitude,
                                      deliveryLongitude:
                                          order.deliveryLongitude,
                                      deliveryAddress: order.deliveryAddress,
                                      landmark: order.landmark,
                                    ),
                                  ),
                                );
                              },
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onNavigate(1);
            },
            child: const Text('View all orders'),
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
  Widget build(BuildContext context) => _CustomerScaffold(
    title: 'AquaLink',
    action: IconButton(
      tooltip: 'Order notifications',
      onPressed: () => _showNotifications(context),
      icon: const Icon(Icons.notifications_none, color: _muted),
    ),
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 8),
        Text(
          'Hello, ${state.userName.trim().split(RegExp(r'\s+')).first}',
          style: const TextStyle(
            fontSize: 20,
            color: _ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => _useCurrentLocation(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F1FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: _blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DELIVER TO',
                        style: TextStyle(
                          fontSize: 9,
                          color: _blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.deliveryAddress,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.my_location_outlined, color: _blue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(
          'Water stations in Clarin, Bohol',
          trailing: 'View all',
        ),
        const SizedBox(height: 10),
        _StationCard(
          name: 'Remoreras Water Refilling',
          location: 'Lajog, Clarin, Bohol',
          distance: '1.2 km',
          price: 'From P25 per container',
          color: _blue,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StationProductsScreen(
                stationName: 'Remoreras Water Refilling',
              ),
            ),
          ),
        ),
        _StationCard(
          name: 'J&P Water Station',
          location: 'Behind BISU, Clarin, Bohol',
          distance: '1.6 km',
          price: 'From P25 per container',
          color: Colors.teal,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const StationProductsScreen(stationName: 'J&P Water Station'),
            ),
          ),
        ),
        _StationCard(
          name: 'CJoan Water Station',
          location: 'Candajec, Clarin, Bohol',
          distance: '—',
          price: 'From P25 per container',
          color: Colors.teal,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StationProductsScreen(
                stationName: 'CJoan Water Station',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CustomerScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _CustomerScaffold({
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.water_drop_outlined, color: _blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle(this.title, {this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
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
            color: _blue,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _StationCard extends StatelessWidget {
  final String name, location, distance, price;
  final Color color;
  final VoidCallback onTap;
  const _StationCard({
    required this.name,
    required this.location,
    required this.distance,
    required this.price,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.water_drop_outlined, color: color, size: 23),
          ),
          const SizedBox(width: 11),
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
                  '★ 4.8   •   $distance',
                  style: const TextStyle(
                    fontSize: 9,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const _OpenBadge(),
        ],
      ),
    ),
  );
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE5F8F1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'Open',
      style: TextStyle(
        fontSize: 9,
        color: Color(0xFF009B70),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _CustomerOrders extends StatefulWidget {
  const _CustomerOrders();

  @override
  State<_CustomerOrders> createState() => _CustomerOrdersState();
}

class _CustomerOrdersState extends State<_CustomerOrders> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final orders = state.orders.map(_OrderData.fromOrder).toList();
    final filteredOrders = orders
        .where(
          (order) => switch (_selectedFilter) {
            'Active' =>
              order.orderStatus == OrderStatus.pending ||
                  order.orderStatus == OrderStatus.accepted,
            'Completed' =>
              order.orderStatus == OrderStatus.completed ||
                  order.orderStatus == OrderStatus.delivered,
            'Cancelled' =>
              order.orderStatus == OrderStatus.cancelled ||
                  order.orderStatus == OrderStatus.rejected,
            _ => true,
          },
        )
        .toList();
    return _CustomerScaffold(
      title: 'My Orders',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _OrderTabs(
            selectedFilter: _selectedFilter,
            onFilterSelected: (filter) =>
                setState(() => _selectedFilter = filter),
          ),
          const SizedBox(height: 15),
          if (filteredOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  _selectedFilter == 'All'
                      ? 'No orders yet.'
                      : 'No ${_selectedFilter.toLowerCase()} orders yet.',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
            )
          else
            ...filteredOrders.map((order) => _OrderCard(order: order)),
        ],
      ),
    );
  }
}

class _OrderTabs extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  const _OrderTabs({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _TabPill(
        'All',
        selected: selectedFilter == 'All',
        onTap: () => onFilterSelected('All'),
      ),
      const SizedBox(width: 7),
      _TabPill(
        'Active',
        selected: selectedFilter == 'Active',
        onTap: () => onFilterSelected('Active'),
      ),
      const SizedBox(width: 7),
      _TabPill(
        'Completed',
        selected: selectedFilter == 'Completed',
        onTap: () => onFilterSelected('Completed'),
      ),
      const SizedBox(width: 7),
      _TabPill(
        'Cancelled',
        selected: selectedFilter == 'Cancelled',
        onTap: () => onFilterSelected('Cancelled'),
      ),
    ],
  );
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill(this.label, {required this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _blue : Colors.white,
        border: Border.all(color: selected ? _blue : _line),
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
    ),
  );
}

class _OrderData {
  final String number, station, status, amount;
  final OrderStatus orderStatus;
  final String? reason;
  final String fulfillment;
  final WaterOrder? sourceOrder;

  const _OrderData({
    required this.number,
    required this.station,
    required this.status,
    required this.orderStatus,
    required this.amount,
    this.reason,
    this.fulfillment = 'Delivery',
    this.sourceOrder,
  });

  factory _OrderData.fromOrder(WaterOrder order) => _OrderData(
    number: order.number,
    station: order.station,
    orderStatus: order.status,
    status: order.isPartiallyAccepted
        ? 'Partially accepted'
        : order.status.name[0].toUpperCase() + order.status.name.substring(1),
    amount: 'P${order.total}',
    reason: order.reason,
    fulfillment: order.fulfillmentMethod == FulfillmentMethod.delivery
        ? 'Delivery'
        : 'Pickup',
    sourceOrder: order,
  );
}

class _OrderCard extends StatelessWidget {
  final _OrderData order;
  const _OrderCard({required this.order});

  void _track(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApiOrderTrackingScreen(
          orderId: order.number,
          orderTotal: order.sourceOrder?.total,
          orderItems: order.sourceOrder?.items ?? const [],
          stationName: order.station,
          isDelivery:
              order.sourceOrder?.fulfillmentMethod ==
              FulfillmentMethod.delivery,
          orderStatus:
              order.sourceOrder?.status.name ?? order.status.toLowerCase(),
          barangay: order.sourceOrder?.barangay,
          deliveryLatitude: order.sourceOrder?.deliveryLatitude,
          deliveryLongitude: order.sourceOrder?.deliveryLongitude,
          deliveryAddress: order.sourceOrder?.deliveryAddress,
          landmark: order.sourceOrder?.landmark,
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Explain why you are cancelling this order',
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
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    final sourceOrder = order.sourceOrder;
    if (!context.mounted || reason == null || sourceOrder == null) return;
    AppScope.of(context).updateOrderStatus(
      number: sourceOrder.number,
      status: OrderStatus.cancelled,
      reason: reason,
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 11),
    padding: const EdgeInsets.all(13),
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
              order.number,
              style: const TextStyle(
                fontSize: 10,
                color: _blue,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              order.status,
              style: TextStyle(
                fontSize: 9,
                color: order.status == 'Cancelled' || order.status == 'Rejected'
                    ? Colors.red
                    : order.status == 'Partially accepted'
                    ? Colors.orange.shade800
                    : const Color(0xFF009B70),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          order.station,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${order.fulfillment} order',
          style: const TextStyle(fontSize: 9, color: _muted, height: 1.5),
        ),
        if (order.sourceOrder case final sourceOrder?
            when sourceOrder.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...sourceOrder.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.quantity} x ${item.productName}  •  '
                    '${item.decisionStatus.name[0].toUpperCase()}'
                    '${item.decisionStatus.name.substring(1)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: item.decisionStatus == OrderItemStatus.rejected
                          ? Colors.red
                          : item.decisionStatus == OrderItemStatus.accepted
                          ? const Color(0xFF009B70)
                          : _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.decisionReason != null)
                    Text(
                      'Reason: ${item.decisionReason}',
                      style: const TextStyle(fontSize: 9, color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            order.amount,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        if (order.reason != null) ...[
          const SizedBox(height: 6),
          Text(
            'Reason: ${order.reason}',
            style: const TextStyle(fontSize: 9, color: Colors.red),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _track(context),
            icon: const Icon(Icons.location_searching, size: 16),
            label: const Text('View status'),
          ),
        ),
        if (order.sourceOrder?.status == OrderStatus.pending) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () => _cancel(context),
              child: const Text('Cancel order'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _CustomerProfile extends StatelessWidget {
  final AppState state;
  const _CustomerProfile({required this.state});

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(
      text: state.userName == 'Customer' ? '' : state.userName,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full name',
            hintText: 'Enter your first and last name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || name == null) return;

    try {
      await FirestoreService.updateCurrentUserName(name);
      if (!context.mounted) return;
      state.updateFullName(name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your name has been updated.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update your name: $error')),
      );
    }
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddress(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('My Addresses'),
        content: Text(state.deliveryAddress),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _useCurrentLocation(context);
            },
            child: const Text('Use current location'),
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
  Widget build(BuildContext context) => _CustomerScaffold(
    title: 'Profile',
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 12),
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFE5F1FF),
          child: Icon(Icons.person, size: 38, color: _blue),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.userName,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            IconButton(
              tooltip: state.userName == 'Customer'
                  ? 'Add your name'
                  : 'Edit name',
              onPressed: () => _editName(context),
              icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
            ),
          ],
        ),
        if (state.userName == 'Customer')
          const Center(
            child: Text(
              'Tap the pencil to add your name',
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            state.mobile ?? state.email ?? '',
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _ProfileOption(
          Icons.location_on_outlined,
          'My Addresses',
          onTap: () => _showAddress(context),
        ),
        _ProfileOption(
          Icons.credit_card_outlined,
          'Payment Methods',
          onTap: () => _showInfo(
            context,
            'Payment Methods',
            'Cash on delivery and cash on pickup are currently available.',
          ),
        ),
        _ProfileOption(
          Icons.notifications_none,
          'Notifications',
          onTap: () => _showInfo(
            context,
            'Notifications',
            state.orders.isEmpty
                ? 'You have no order notifications.'
                : 'You have ${state.orders.length} order notification${state.orders.length == 1 ? '' : 's'}.',
          ),
        ),
        _ProfileOption(
          Icons.help_outline,
          'Help & Support',
          onTap: () => _showInfo(
            context,
            'Help & Support',
            'For an order update, open Orders and select View status. You can also contact your water station directly from its details.',
          ),
        ),
        _ProfileOption(
          Icons.info_outline,
          'About AquaLink',
          onTap: () => _showInfo(
            context,
            'About AquaLink',
            'AquaLink helps you find nearby water stations, place orders, and track deliveries.',
          ),
        ),
        const SizedBox(height: 12),
        _CustomerOutlineButton(
          'Logout',
          onPressed: () => _confirmLogout(context, state),
        ),
      ],
    ),
  );
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ProfileOption(this.icon, this.label, {this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(11),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(icon, color: _blue, size: 19),
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
            const Icon(Icons.chevron_right, color: _muted),
          ],
        ),
      ),
    ),
  );
}

class _CustomerOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _CustomerOutlineButton(this.label, {this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Color(0xFFFFCACA)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
