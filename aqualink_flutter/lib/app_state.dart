import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'models/models.dart';

final _orderIdRandom = Random.secure();

enum AccountRole { customer, stationOwner }

class OwnerDailySummary {
  final int newOrders;
  final int activeOrders;
  final int completedOrders;
  final int sales;

  const OwnerDailySummary({
    required this.newOrders,
    required this.activeOrders,
    required this.completedOrders,
    required this.sales,
  });
}

class AccountCredentials {
  static const ownerEmail = 'remoreras.owner@aqualink.com';
  static const ownerPassword = 'Remoreras#2026Owner';
  static const ownerStationName = 'Remoreras Water Refilling';
  static const jAndPOwnerEmail = 'jp.owner@aqualink.com';
  static const jAndPOwnerPassword = 'JP#2026Owner';
  static const jAndPStationName = 'J&P Water Station';
  static const cJoanOwnerEmail = 'cjoan.owner@aqualink.com';
  static const cJoanOwnerPassword = 'CJoan#2026Owner';
  static const cJoanStationName = 'CJoan Water Station';
  static const retiredAdminEmail = 'admin@aqualink.com';

  static String? stationForOwnerEmail(String email) =>
      switch (email.trim().toLowerCase()) {
        ownerEmail => ownerStationName,
        jAndPOwnerEmail => jAndPStationName,
        cJoanOwnerEmail => cJoanStationName,
        _ => null,
      };

  static String? passwordForOwnerEmail(String email) =>
      switch (email.trim().toLowerCase()) {
        ownerEmail => ownerPassword,
        jAndPOwnerEmail => jAndPOwnerPassword,
        cJoanOwnerEmail => cJoanOwnerPassword,
        _ => null,
      };

  static String? nameForOwnerEmail(String email) =>
      switch (email.trim().toLowerCase()) {
        ownerEmail => 'Remoreras Station Owner',
        jAndPOwnerEmail => 'J&P Station Owner',
        cJoanOwnerEmail => 'CJoan Station Owner',
        _ => null,
      };

  static String? mobileForOwnerEmail(String email) =>
      switch (email.trim().toLowerCase()) {
        ownerEmail => '09170000001',
        jAndPOwnerEmail => '09170000003',
        cJoanOwnerEmail => '09170000004',
        _ => null,
      };
}

class AppState extends ChangeNotifier {
  bool isLoggedIn = false;
  AccountRole accountRole = AccountRole.customer;
  String? fullName;
  String? mobile;
  String? email;
  String? stationName;
  String userName = '';
  String deliveryAddress = 'Poblacion Norte, Clarin, Bohol';
  final List<Station> stations = demoStations;
  final Map<String, StationDetails> stationDetails = {
    'Remoreras Water Refilling': const StationDetails(
      name: 'Remoreras Water Refilling',
      address: 'Lajog, Clarin, Bohol',
      contact: '0917 123 4567',
      operatingHours: '7:00 AM - 7:00 PM',
      deliveryAreas: 'Clarin and nearby barangays',
      deliveryFee: 25,
    ),
    'J&P Water Station': const StationDetails(
      name: 'J&P Water Station',
      address: 'Behind BISU, Clarin, Bohol',
      contact: '0918 765 4321',
      operatingHours: '8:00 AM - 6:00 PM',
      deliveryAreas: 'Clarin within 3 km',
      deliveryFee: 30,
    ),
    'CJoan Water Station': const StationDetails(
      name: 'CJoan Water Station',
      address: 'Candajec, Clarin, Bohol',
      contact: 'Contact not provided',
      operatingHours: '7:00 AM - 7:00 PM',
      deliveryAreas: 'Candajec and nearby barangays',
      deliveryFee: 25,
    ),
  };
  final Map<String, List<StationProduct>> stationProducts = {
    for (final station in demoStations)
      station.name: List<StationProduct>.from(station.products),
  };
  final List<CartItem> cart = [];
  final List<WaterOrder> orders = [];
  final List<WaterOrder> incomingOrders = [];
  Station? selectedStation;

  int get cartItemCount => cart.fold(0, (total, item) => total + item.quantity);

  List<WaterOrder> incomingOrdersForStation(String stationName) =>
      incomingOrders.where((order) => order.station == stationName).toList();

  OwnerDailySummary ownerDailySummary(String stationName, {DateTime? now}) {
    final today = (now ?? DateTime.now()).toLocal();
    bool isToday(DateTime? value) {
      final date = value?.toLocal();
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }

    final stationOrders = incomingOrdersForStation(stationName);
    final newOrders = stationOrders.where((order) {
      final createdAt = order.createdAt?.toLocal();
      return createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day &&
          order.status == OrderStatus.pending;
    }).length;
    final activeOrders = stationOrders
        .where((order) => order.status == OrderStatus.accepted)
        .length;
    final completedToday = stationOrders
        .where(
          (order) =>
              (order.status == OrderStatus.delivered ||
                  order.status == OrderStatus.completed) &&
              isToday(order.completedAt ?? order.createdAt),
        )
        .toList();
    return OwnerDailySummary(
      newOrders: newOrders,
      activeOrders: activeOrders,
      completedOrders: completedToday.length,
      sales: completedToday.fold(0, (total, order) => total + order.total),
    );
  }

  void replaceIncomingOrdersForStation(
    String stationName,
    List<WaterOrder> orders,
  ) {
    incomingOrders.removeWhere((order) => order.station == stationName);
    incomingOrders.addAll(
      orders.where((order) => order.station == stationName),
    );
    incomingOrders.sort(
      (first, second) => (second.createdAt ?? DateTime(1970)).compareTo(
        first.createdAt ?? DateTime(1970),
      ),
    );
    notifyListeners();
  }

  void replaceCustomerOrders(List<WaterOrder> customerOrders) {
    orders
      ..clear()
      ..addAll(customerOrders);
    orders.sort(
      (first, second) => (second.createdAt ?? DateTime(1970)).compareTo(
        first.createdAt ?? DateTime(1970),
      ),
    );
    notifyListeners();
  }

  List<StationProduct> productsForStation(String stationName) =>
      stationProducts[stationName] ?? const [];

  StationDetails detailsForStation(String stationName) =>
      stationDetails[stationName] ??
      StationDetails(
        name: stationName,
        address: 'Address not provided',
        contact: 'Contact not provided',
        operatingHours: 'Hours not provided',
        deliveryAreas: 'Delivery areas not provided',
        deliveryFee: 0,
      );

  void updateStationDetails({
    required String stationName,
    required StationDetails details,
  }) {
    stationDetails[stationName] = details;
    if (details.name != stationName) {
      stationDetails[details.name] = details;
      final products = stationProducts.remove(stationName);
      if (products != null) stationProducts[details.name] = products;
    }
    notifyListeners();
  }

  void addProduct({
    required String stationName,
    required StationProduct product,
  }) {
    stationProducts.putIfAbsent(stationName, () => []).add(product);
    notifyListeners();
  }

  void updateProduct({
    required String stationName,
    required int index,
    required StationProduct product,
  }) {
    final products = stationProducts[stationName];
    if (products == null || index < 0 || index >= products.length) return;
    products[index] = product;
    notifyListeners();
  }

  void removeProduct({required String stationName, required int index}) {
    final products = stationProducts[stationName];
    if (products == null || index < 0 || index >= products.length) return;
    products.removeAt(index);
    notifyListeners();
  }

  void addToCart({
    required String productName,
    required int price,
    int quantity = 1,
  }) {
    final existingIndex = cart.indexWhere(
      (item) => item.productName == productName,
    );
    if (existingIndex == -1) {
      cart.add(
        CartItem(productName: productName, price: price, quantity: quantity),
      );
    } else {
      final item = cart[existingIndex];
      cart[existingIndex] = item.copyWith(quantity: item.quantity + quantity);
    }
    notifyListeners();
  }

  void updateCartQuantity(String productName, int quantity) {
    final index = cart.indexWhere((item) => item.productName == productName);
    if (index == -1) return;
    if (quantity <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = cart[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  WaterOrder submitOrder({
    required String station,
    required FulfillmentMethod fulfillmentMethod,
    int deliveryFee = 0,
    String? deliveryAddress,
    String? barangay,
    String? landmark,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) {
    final order = prepareOrder(
      station: station,
      fulfillmentMethod: fulfillmentMethod,
      deliveryFee: deliveryFee,
      deliveryAddress: deliveryAddress,
      barangay: barangay,
      landmark: landmark,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );
    recordSubmittedOrder(order);
    return order;
  }

  WaterOrder prepareOrder({
    required String station,
    required FulfillmentMethod fulfillmentMethod,
    int deliveryFee = 0,
    String? deliveryAddress,
    String? barangay,
    String? landmark,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) {
    if (cart.isEmpty) {
      throw StateError('Add at least one product before submitting an order.');
    }
    final items = List<CartItem>.unmodifiable(cart);
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final randomSuffix = _orderIdRandom
        .nextInt(0x7fffffff)
        .toRadixString(36)
        .padLeft(7, '0');
    final order = WaterOrder(
      number: 'WG-${timestamp.toUpperCase()}-${randomSuffix.toUpperCase()}',
      station: station,
      customer: userName.isNotEmpty ? userName : (fullName ?? 'Customer'),
      items: items,
      total:
          items.fold(0, (sum, item) => sum + item.price * item.quantity) +
          (fulfillmentMethod == FulfillmentMethod.delivery ? deliveryFee : 0),
      deliveryFee: fulfillmentMethod == FulfillmentMethod.delivery
          ? deliveryFee
          : 0,
      fulfillmentMethod: fulfillmentMethod,
      deliveryAddress: fulfillmentMethod == FulfillmentMethod.delivery
          ? deliveryAddress
          : null,
      barangay: fulfillmentMethod == FulfillmentMethod.delivery
          ? barangay
          : null,
      landmark: fulfillmentMethod == FulfillmentMethod.delivery
          ? landmark
          : null,
      deliveryLatitude: fulfillmentMethod == FulfillmentMethod.delivery
          ? deliveryLatitude
          : null,
      deliveryLongitude: fulfillmentMethod == FulfillmentMethod.delivery
          ? deliveryLongitude
          : null,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
    return order;
  }

  void recordSubmittedOrder(WaterOrder order) {
    orders.removeWhere((existing) => existing.number == order.number);
    incomingOrders.removeWhere((existing) => existing.number == order.number);
    orders.insert(0, order);
    incomingOrders.insert(0, order);
    cart.clear();
    notifyListeners();
  }

  bool updateOrderStatus({
    required String number,
    required OrderStatus status,
    String? reason,
  }) {
    if ((status == OrderStatus.rejected || status == OrderStatus.cancelled) &&
        (reason == null || reason.trim().isEmpty)) {
      return false;
    }
    final orderIndex = orders.indexWhere((order) => order.number == number);
    final incomingIndex = incomingOrders.indexWhere(
      (order) => order.number == number,
    );
    if (orderIndex == -1 && incomingIndex == -1) return false;
    final currentOrder = orderIndex != -1
        ? orders[orderIndex]
        : incomingOrders[incomingIndex];
    if ((status == OrderStatus.accepted || status == OrderStatus.rejected) &&
        currentOrder.status != OrderStatus.pending) {
      return false;
    }
    final updatedOrder = currentOrder.copyWith(
      status: status,
      reason: reason?.trim(),
      completedAt:
          status == OrderStatus.completed || status == OrderStatus.delivered
          ? DateTime.now()
          : currentOrder.completedAt,
    );
    if (orderIndex != -1) orders[orderIndex] = updatedOrder;
    if (incomingIndex != -1) incomingOrders[incomingIndex] = updatedOrder;
    notifyListeners();
    return true;
  }

  void register({
    required String fullName,
    required String mobile,
    required String email,
    String? stationName,
    AccountRole role = AccountRole.customer,
  }) {
    isLoggedIn = true;
    accountRole = role;
    this.fullName = fullName;
    this.mobile = mobile;
    this.email = email;
    this.stationName = stationName;
    userName = fullName;
    notifyListeners();
  }

  void updateFullName(String fullName) {
    final normalizedName = fullName.trim();
    this.fullName = normalizedName;
    userName = normalizedName;
    notifyListeners();
  }

  void login({
    required String mobileOrEmail,
    AccountRole role = AccountRole.customer,
    String? stationName,
    String? fullName,
    String? mobile,
  }) {
    isLoggedIn = true;
    accountRole = role;
    this.stationName = stationName;

    final resolvedFullName = (fullName ?? this.fullName ?? '').trim();
    final fallbackName = switch (role) {
      AccountRole.stationOwner => 'Remoreras Station Owner',
      AccountRole.customer => 'Customer',
    };

    this.fullName = resolvedFullName.isNotEmpty
        ? resolvedFullName
        : fallbackName;
    this.mobile = mobile ?? this.mobile;
    userName = this.fullName ?? fallbackName;

    if (mobileOrEmail.contains('@')) {
      email = mobileOrEmail;
    } else {
      this.mobile = mobileOrEmail;
    }
    notifyListeners();
  }

  void selectStation(Station station) {
    selectedStation = station;
    notifyListeners();
  }

  Future<String?> useCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return 'Location services are disabled.';

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission was denied.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission is permanently denied.';
    }

    final position = await Geolocator.getCurrentPosition();
    deliveryAddress =
        'Current location (${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)})';
    notifyListeners();
    return null;
  }

  void logout() {
    isLoggedIn = false;
    accountRole = AccountRole.customer;
    fullName = null;
    mobile = null;
    email = null;
    stationName = null;
    userName = '';
    deliveryAddress = 'Poblacion Norte, Clarin, Bohol';
    selectedStation = null;
    cart.clear();
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
