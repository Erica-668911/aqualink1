import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/api_order_tracking_screen.dart';
import 'package:flutter_application_1/app_state.dart';
import 'package:flutter_application_1/customer_home_screen.dart';
import 'package:flutter_application_1/home_screen.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/models.dart';

void main() {
  test('owner login provisions the station account', () {
    final state = AppState();

    state.login(
      mobileOrEmail: AccountCredentials.ownerEmail,
      role: AccountRole.stationOwner,
      stationName: AccountCredentials.ownerStationName,
    );

    expect(state.accountRole, AccountRole.stationOwner);
    expect(state.stationName, AccountCredentials.ownerStationName);
    expect(state.userName, 'Remoreras Station Owner');
  });

  test('built-in station owners use separate credentials and assignments', () {
    expect(
      AccountCredentials.stationForOwnerEmail(AccountCredentials.ownerEmail),
      AccountCredentials.ownerStationName,
    );
    expect(
      AccountCredentials.stationForOwnerEmail(
        AccountCredentials.jAndPOwnerEmail,
      ),
      AccountCredentials.jAndPStationName,
    );
    expect(
      AccountCredentials.ownerPassword,
      isNot(AccountCredentials.jAndPOwnerPassword),
    );
    expect(
      AccountCredentials.stationForOwnerEmail(
        AccountCredentials.cJoanOwnerEmail,
      ),
      AccountCredentials.cJoanStationName,
    );
    expect(
      AccountCredentials.mobileForOwnerEmail(AccountCredentials.ownerEmail),
      '09170000001',
    );
    expect(
      AccountCredentials.mobileForOwnerEmail(
        AccountCredentials.jAndPOwnerEmail,
      ),
      '09170000003',
    );
    expect(
      AccountCredentials.mobileForOwnerEmail(
        AccountCredentials.cJoanOwnerEmail,
      ),
      '09170000004',
    );
    expect(
      AccountCredentials.ownerPassword,
      isNot(AccountCredentials.cJoanOwnerPassword),
    );
  });

  test('station directory contains the updated names and locations', () {
    final state = AppState();
    final stationNames = state.stations.map((station) => station.name);

    expect(stationNames, contains(AccountCredentials.ownerStationName));
    expect(stationNames, contains(AccountCredentials.jAndPStationName));
    expect(stationNames, contains(AccountCredentials.cJoanStationName));
    expect(
      state.detailsForStation(AccountCredentials.ownerStationName).address,
      'Lajog, Clarin, Bohol',
    );
    expect(
      state.detailsForStation(AccountCredentials.jAndPStationName).address,
      'Behind BISU, Clarin, Bohol',
    );
    expect(
      state.detailsForStation(AccountCredentials.cJoanStationName).address,
      'Candajec, Clarin, Bohol',
    );
    expect(
      state.productsForStation(AccountCredentials.cJoanStationName),
      isNotEmpty,
    );
    expect(
      state.productsForStation(AccountCredentials.ownerStationName),
      contains(
        const StationProduct(
          name: 'Mineral Water (2.5 Gal)',
          price: 15,
          available: true,
        ),
      ),
    );
    expect(
      state.productsForStation(AccountCredentials.jAndPStationName),
      contains(
        const StationProduct(
          name: 'Mineral Water (3 Gal)',
          price: 20,
          available: true,
        ),
      ),
    );
    expect(
      state
          .productsForStation(AccountCredentials.ownerStationName)
          .map((product) => product.name),
      isNot(contains('Purified Water (5 Gal)')),
    );
    expect(
      state
          .productsForStation(AccountCredentials.jAndPStationName)
          .map((product) => product.name),
      isNot(contains('Purified Water (5 Gal)')),
    );
    for (final stationName in [
      AccountCredentials.ownerStationName,
      AccountCredentials.jAndPStationName,
      AccountCredentials.cJoanStationName,
    ]) {
      final mineralProducts = state
          .productsForStation(stationName)
          .where((product) => product.name.startsWith('Mineral Water'));
      expect(mineralProducts, isNotEmpty);
      for (final product in mineralProducts) {
        expect(product.price, switch (product.name) {
          'Mineral Water (2.5 Gal)' => 15,
          'Mineral Water (3 Gal)' => 20,
          _ => 25,
        });
      }
    }
  });

  test('registration keeps a customer signed in', () {
    final state = AppState();

    state.register(
      fullName: 'Test Customer',
      mobile: '09123456789',
      email: 'customer@example.com',
    );

    expect(state.isLoggedIn, isTrue);
    expect(state.accountRole, AccountRole.customer);
    expect(state.email, 'customer@example.com');
    expect(state.userName, 'Test Customer');
  });

  test('incoming owner orders are scoped to their station', () {
    final state = AppState();
    state.addToCart(productName: 'Purified Water', price: 25);
    state.submitOrder(
      station: AccountCredentials.ownerStationName,
      fulfillmentMethod: FulfillmentMethod.pickup,
    );
    state.addToCart(productName: 'Mineral Water', price: 30);
    state.submitOrder(
      station: AccountCredentials.jAndPStationName,
      fulfillmentMethod: FulfillmentMethod.pickup,
    );

    expect(
      state
          .incomingOrdersForStation(AccountCredentials.ownerStationName)
          .map((order) => order.station),
      everyElement(AccountCredentials.ownerStationName),
    );
    expect(
      state
          .incomingOrdersForStation(AccountCredentials.jAndPStationName)
          .map((order) => order.station),
      everyElement(AccountCredentials.jAndPStationName),
    );
  });

  test('submitting an order stores quantities and fulfillment method', () {
    final state = AppState()..userName = 'Customer';
    state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);
    state.updateCartQuantity('Purified Water (5 Gal)', 3);

    final order = state.submitOrder(
      station: 'Remoreras Water Refilling',
      fulfillmentMethod: FulfillmentMethod.pickup,
    );

    expect(order.items.single.quantity, 3);
    expect(order.fulfillmentMethod, FulfillmentMethod.pickup);
    expect(state.cart, isEmpty);
  });

  test(
    'delivery order total includes the product subtotal and delivery fee',
    () {
      final state = AppState();
      state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);
      state.updateCartQuantity('Purified Water (5 Gal)', 3);

      final order = state.prepareOrder(
        station: 'J&P Water Station',
        fulfillmentMethod: FulfillmentMethod.delivery,
        deliveryFee: 30,
      );

      expect(order.deliveryFee, 30);
      expect(order.total, 105);
    },
  );

  test('prepared orders keep the cart until recorded and do not duplicate', () {
    final state = AppState();
    state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);

    final order = state.prepareOrder(
      station: 'Remoreras Water Refilling',
      fulfillmentMethod: FulfillmentMethod.pickup,
    );

    expect(state.cart, hasLength(1));
    expect(state.orders, isEmpty);
    expect(order.number, matches(RegExp(r'^WG-[A-Z0-9]+-[A-Z0-9]{7}$')));

    state.recordSubmittedOrder(order);
    state.replaceCustomerOrders([order]);
    state.recordSubmittedOrder(order);

    expect(state.cart, isEmpty);
    expect(state.orders, hasLength(1));
    expect(state.incomingOrders, hasLength(1));
  });

  test('rejected and cancelled orders require a reason', () {
    final state = AppState();
    state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);
    final order = state.submitOrder(
      station: 'Remoreras Water Refilling',
      fulfillmentMethod: FulfillmentMethod.delivery,
      deliveryAddress: 'Current location',
    );

    expect(
      state.updateOrderStatus(
        number: order.number,
        status: OrderStatus.rejected,
      ),
      isFalse,
    );
    expect(
      state.updateOrderStatus(
        number: order.number,
        status: OrderStatus.cancelled,
        reason: 'Customer changed their plans',
      ),
      isTrue,
    );
    expect(state.orders.single.reason, 'Customer changed their plans');
  });

  test('owner can accept or reject only pending orders', () {
    final state = AppState();
    state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);
    final order = state.submitOrder(
      station: 'Remoreras Water Refilling',
      fulfillmentMethod: FulfillmentMethod.pickup,
    );

    expect(
      state.updateOrderStatus(
        number: order.number,
        status: OrderStatus.accepted,
      ),
      isTrue,
    );
    expect(
      state.updateOrderStatus(
        number: order.number,
        status: OrderStatus.rejected,
        reason: 'Station capacity reached',
      ),
      isFalse,
    );
    expect(
      state.updateOrderStatus(
        number: order.number,
        status: OrderStatus.completed,
      ),
      isTrue,
    );
    expect(state.orders.single.status, OrderStatus.completed);
    expect(state.orders.single.completedAt, isNotNull);
  });

  test('station can reject one product without rejecting the whole order', () {
    final state = AppState();
    state.addToCart(productName: 'Mineral Water (2.5 Gal)', price: 15);
    state.updateCartQuantity('Mineral Water (2.5 Gal)', 2);
    state.addToCart(productName: 'Mineral Water (5 Gal)', price: 25);
    final order = state.submitOrder(
      station: AccountCredentials.ownerStationName,
      fulfillmentMethod: FulfillmentMethod.delivery,
      deliveryFee: 30,
    );

    expect(
      state.updateOrderItemStatus(
        number: order.number,
        itemIndex: 0,
        status: OrderItemStatus.rejected,
      ),
      isFalse,
    );
    expect(
      state.updateOrderItemStatus(
        number: order.number,
        itemIndex: 0,
        status: OrderItemStatus.rejected,
        reason: 'Out of stock',
      ),
      isTrue,
    );

    final partiallyDecidedOrder = state.orders.single;
    expect(partiallyDecidedOrder.status, OrderStatus.pending);
    expect(
      partiallyDecidedOrder.items[0].decisionStatus,
      OrderItemStatus.rejected,
    );
    expect(partiallyDecidedOrder.items[0].decisionReason, 'Out of stock');
    expect(
      partiallyDecidedOrder.items[1].decisionStatus,
      OrderItemStatus.pending,
    );
    expect(partiallyDecidedOrder.total, 55);

    expect(
      state.updateOrderItemStatus(
        number: order.number,
        itemIndex: 1,
        status: OrderItemStatus.accepted,
      ),
      isTrue,
    );
    final finalOrder = state.orders.single;
    expect(finalOrder.status, OrderStatus.accepted);
    expect(finalOrder.isPartiallyAccepted, isTrue);
    expect(finalOrder.total, 55);
    expect(finalOrder.items[0].decisionStatus, OrderItemStatus.rejected);
    expect(finalOrder.items[1].decisionStatus, OrderItemStatus.accepted);
  });

  test('incoming orders stay empty until a real customer submits one', () {
    final state = AppState();

    expect(state.incomingOrders, isEmpty);
  });

  test("owner daily summary counts only today's station orders", () {
    final state = AppState();
    final now = DateTime(2026, 10, 1, 12);

    WaterOrder order({
      required String number,
      required String station,
      required OrderStatus status,
      required int daysAgo,
      required int total,
      int? completedDaysAgo,
    }) => WaterOrder(
      number: number,
      station: station,
      customer: 'Customer',
      items: const [],
      total: total,
      fulfillmentMethod: FulfillmentMethod.pickup,
      status: status,
      createdAt: now.subtract(Duration(days: daysAgo)),
      completedAt: completedDaysAgo == null
          ? null
          : now.subtract(Duration(days: completedDaysAgo)),
    );

    state.incomingOrders.addAll([
      order(
        number: 'new',
        station: AccountCredentials.ownerStationName,
        status: OrderStatus.pending,
        daysAgo: 0,
        total: 120,
      ),
      order(
        number: 'active',
        station: AccountCredentials.ownerStationName,
        status: OrderStatus.accepted,
        daysAgo: 0,
        total: 90,
      ),
      order(
        number: 'done',
        station: AccountCredentials.ownerStationName,
        status: OrderStatus.completed,
        daysAgo: 0,
        total: 250,
        completedDaysAgo: 0,
      ),
      order(
        number: 'finished-today',
        station: AccountCredentials.ownerStationName,
        status: OrderStatus.completed,
        daysAgo: 1,
        total: 75,
        completedDaysAgo: 0,
      ),
      order(
        number: 'other-station',
        station: AccountCredentials.jAndPStationName,
        status: OrderStatus.completed,
        daysAgo: 0,
        total: 500,
        completedDaysAgo: 0,
      ),
      order(
        number: 'yesterday',
        station: AccountCredentials.ownerStationName,
        status: OrderStatus.completed,
        daysAgo: 1,
        total: 800,
        completedDaysAgo: 1,
      ),
    ]);

    final summary = state.ownerDailySummary(
      AccountCredentials.ownerStationName,
      now: now,
    );

    expect(summary.newOrders, 1);
    expect(summary.activeOrders, 1);
    expect(summary.completedOrders, 2);
    expect(summary.sales, 325);
  });

  test('login without a profile name still keeps a valid display name', () {
    final state = AppState();

    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: null,
    );

    expect(state.userName, isNotEmpty);
    expect(state.accountRole, AccountRole.customer);
  });

  test('owner product catalog supports add, edit, and remove', () {
    final state = AppState();
    const station = 'Remoreras Water Refilling';
    final initialCount = state.productsForStation(station).length;

    state.addProduct(
      stationName: station,
      product: const StationProduct(
        name: 'Spring Water',
        price: 40,
        available: true,
      ),
    );
    expect(state.productsForStation(station).length, initialCount + 1);

    final addedIndex = state.productsForStation(station).length - 1;
    state.updateProduct(
      stationName: station,
      index: addedIndex,
      product: const StationProduct(
        name: 'Spring Water Large',
        price: 45,
        available: false,
      ),
    );
    expect(state.productsForStation(station)[addedIndex].price, 45);
    expect(state.productsForStation(station)[addedIndex].available, isFalse);

    state.removeProduct(stationName: station, index: addedIndex);
    expect(state.productsForStation(station).length, initialCount);
  });

  test('owner station details can be updated', () {
    final state = AppState();
    state.updateStationDetails(
      stationName: 'Remoreras Water Refilling',
      details: const StationDetails(
        name: 'Remoreras Express',
        address: 'New address',
        contact: '0999 000 0000',
        operatingHours: '6:00 AM - 8:00 PM',
        deliveryAreas: 'Clarin only',
        deliveryFee: 15,
      ),
    );

    final details = state.detailsForStation('Remoreras Express');
    expect(details.address, 'New address');
    expect(details.deliveryFee, 15);
    expect(state.productsForStation('Remoreras Express'), isNotEmpty);
  });

  test(
    'tracking API uses localhost on web and the Android emulator host on Android',
    () {
      expect(
        trackingApiBaseUrl(isWeb: true, platform: TargetPlatform.android),
        'http://localhost:8000',
      );
      expect(
        trackingApiBaseUrl(isWeb: false, platform: TargetPlatform.android),
        'http://10.0.2.2:8000',
      );
    },
  );

  testWidgets('order status screen shows the products and quantities ordered', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ApiOrderTrackingScreen(
          orderId: 'WG-TEST-ORDER',
          orderTotal: 55,
          stationName: 'Remoreras Water Refilling',
          orderStatus: 'accepted',
          isDelivery: false,
          orderItems: [
            CartItem(
              productName: 'Mineral Water (2.5 Gal)',
              price: 15,
              quantity: 2,
              decisionStatus: OrderItemStatus.rejected,
              decisionReason: 'Out of stock',
            ),
            CartItem(
              productName: 'Mineral Water (5 Gal)',
              price: 25,
              quantity: 1,
              decisionStatus: OrderItemStatus.accepted,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Items ordered'), findsOneWidget);
    expect(find.text('2 x Mineral Water (2.5 Gal)'), findsOneWidget);
    expect(find.text('1 x Mineral Water (5 Gal)'), findsOneWidget);
    expect(find.text('Reason: Out of stock'), findsOneWidget);
    expect(find.text('P30'), findsOneWidget);
    expect(find.text('P25'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Order total'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('P55'), findsOneWidget);
  });

  test('tracking rider label matches its station brand', () {
    final aquaPureTracking = TrackingData.fallback(
      orderId: 'AP-1',
      stationName: 'Remoreras Water Refilling',
      deliveryLatitude: null,
      deliveryLongitude: null,
      landmark: null,
      deliveryAddress: null,
    );
    final jAndPTracking = TrackingData.fallback(
      orderId: 'JP-1',
      stationName: 'J&P Water Station',
      deliveryLatitude: null,
      deliveryLongitude: null,
      landmark: null,
      deliveryAddress: null,
    );

    expect(aquaPureTracking.displayRiderName, 'Remoreras');
    expect(jAndPTracking.displayRiderName, 'J&P');
    expect(aquaPureTracking.stationLocation.latitude, 9.9547);
    expect(aquaPureTracking.stationLocation.longitude, 124.0084);
  });

  test('tracking API uses the registered Remoreras station location', () {
    final tracking = TrackingData.fromJson({
      'order_id': 'AP-2',
      'tracking_code': 'TRK-AP-2',
      'status': 'Pending',
      'station_name': 'Remoreras Water Refilling',
      'station_location': {'latitude': 9.9598185, 'longitude': 124.0229362},
      'pickup_location': {'latitude': 9.9598185, 'longitude': 124.0229362},
      'delivery_location': {'latitude': 9.956, 'longitude': 124.034},
    });

    expect(tracking.stationLocation.latitude, 9.9547);
    expect(tracking.stationLocation.longitude, 124.0084);
  });

  testWidgets('shows the login screen', (tester) async {
    await tester.pumpWidget(const AquaLinkApp());
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets(
    'login navigates to the owner dashboard with built-in credentials',
    (tester) async {
      await tester.pumpWidget(const AquaLinkApp());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), AccountCredentials.ownerEmail);
      await tester.enterText(fields.at(1), AccountCredentials.ownerPassword);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Owner Dashboard'), findsOneWidget);
    },
  );

  testWidgets('J&P owner login opens only the J&P station', (tester) async {
    await tester.pumpWidget(const AquaLinkApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), AccountCredentials.jAndPOwnerEmail);
    await tester.enterText(fields.at(1), AccountCredentials.jAndPOwnerPassword);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('J&P Water Station'), findsOneWidget);
    expect(find.text('Remoreras Water Refilling'), findsNothing);
  });

  testWidgets('station owner can log in without registration', (tester) async {
    await tester.pumpWidget(const AquaLinkApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), AccountCredentials.ownerEmail);
    await tester.enterText(fields.at(1), AccountCredentials.ownerPassword);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Owner Dashboard'), findsOneWidget);
    expect(find.text('Remoreras Water Refilling'), findsOneWidget);
  });

  test('customer can log out from the profile screen', () {
    final state = AppState();
    state.login(
      mobileOrEmail: 'demo-customer',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );

    state.logout();

    expect(state.isLoggedIn, isFalse);
    expect(state.accountRole, AccountRole.customer);
    expect(state.userName, isEmpty);
    expect(state.deliveryAddress, 'Poblacion Norte, Clarin, Bohol');
  });

  testWidgets('customer can add a product to the cart', (tester) async {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    expect(find.text('Hello, Customer'), findsOneWidget);
    await tester.tap(find.text('Remoreras Water Refilling'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to cart').first);
    await tester.pump();

    expect(find.text('Cart 1'), findsOneWidget);
    expect(find.text('Mineral Water (2.5 Gal) added to cart'), findsOneWidget);
  });

  testWidgets('customer can view station details and availability', (
    tester,
  ) async {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    await tester.tap(find.text('Remoreras Water Refilling'));
    await tester.pumpAndSettle();

    expect(find.text('Operating hours'), findsOneWidget);
    expect(find.text('7:00 AM - 7:00 PM'), findsOneWidget);
    expect(find.text('Delivery information'), findsOneWidget);
    expect(find.text('Mineral Water (2.5 Gal)'), findsOneWidget);
    expect(find.textContaining('P15 per container'), findsOneWidget);
    expect(find.textContaining('P25 per container'), findsOneWidget);
  });

  testWidgets('customer sees an empty orders state by default', (tester) async {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.textContaining('WG-'), findsNothing);
    expect(find.text('No orders yet.'), findsOneWidget);
  });

  testWidgets('customer order tabs show every matching order status', (
    tester,
  ) async {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );

    WaterOrder addOrder(String productName) {
      state.addToCart(productName: productName, price: 25);
      return state.submitOrder(
        station: AccountCredentials.ownerStationName,
        fulfillmentMethod: FulfillmentMethod.pickup,
      );
    }

    final pending = addOrder('Pending order');
    final accepted = addOrder('Accepted order');
    state.updateOrderStatus(
      number: accepted.number,
      status: OrderStatus.accepted,
    );
    final completed = addOrder('Completed order');
    state.updateOrderStatus(
      number: completed.number,
      status: OrderStatus.accepted,
    );
    state.updateOrderStatus(
      number: completed.number,
      status: OrderStatus.completed,
    );
    final delivered = addOrder('Delivered order');
    state.updateOrderStatus(
      number: delivered.number,
      status: OrderStatus.delivered,
    );
    final cancelled = addOrder('Cancelled order');
    state.updateOrderStatus(
      number: cancelled.number,
      status: OrderStatus.cancelled,
      reason: 'Customer changed their mind',
    );
    final rejected = addOrder('Rejected order');
    state.updateOrderStatus(
      number: rejected.number,
      status: OrderStatus.rejected,
      reason: 'Product unavailable',
    );

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text(pending.number), findsOneWidget);
    expect(find.text(accepted.number), findsOneWidget);
    expect(find.text(completed.number), findsNothing);
    expect(find.text(delivered.number), findsNothing);
    expect(find.text(cancelled.number), findsNothing);
    expect(find.text(rejected.number), findsNothing);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text(completed.number), findsOneWidget);
    expect(find.text(delivered.number), findsOneWidget);
    expect(find.text(pending.number), findsNothing);

    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text(cancelled.number), findsOneWidget);
    expect(find.text(rejected.number), findsOneWidget);
    expect(find.text(completed.number), findsNothing);
  });

  testWidgets('customer opens the orders tab without any tracking actions', (
    tester,
  ) async {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('My Orders'), findsOneWidget);
    expect(find.text('Track order'), findsNothing);
    expect(find.text('Delivery Status'), findsNothing);
  });

  testWidgets('station owner navigation opens the management pages', (
    tester,
  ) async {
    await tester.pumpWidget(const AquaLinkApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), AccountCredentials.ownerEmail);
    await tester.enterText(fields.at(1), AccountCredentials.ownerPassword);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.text('Manage inventory and pricing'), findsOneWidget);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('Manage customer orders'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('QUICK ACTIONS'), findsNothing);
    expect(find.textContaining('hours today'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Manage your station details'), findsOneWidget);
  });

  testWidgets('owner dashboard lists rejected products for its station', (
    tester,
  ) async {
    final state = AppState();
    state.login(
      mobileOrEmail: AccountCredentials.ownerEmail,
      role: AccountRole.stationOwner,
      stationName: AccountCredentials.ownerStationName,
    );
    state.addToCart(productName: 'Mineral Water (2.5 Gal)', price: 15);
    state.updateCartQuantity('Mineral Water (2.5 Gal)', 2);
    final rejectedOrder = state.submitOrder(
      station: AccountCredentials.ownerStationName,
      fulfillmentMethod: FulfillmentMethod.pickup,
    );
    state.updateOrderItemStatus(
      number: rejectedOrder.number,
      itemIndex: 0,
      status: OrderItemStatus.rejected,
      reason: 'Out of stock',
    );

    state.addToCart(productName: 'Mineral Water (5 Gal)', price: 25);
    final otherStationOrder = state.submitOrder(
      station: AccountCredentials.jAndPStationName,
      fulfillmentMethod: FulfillmentMethod.pickup,
    );
    state.updateOrderItemStatus(
      number: otherStationOrder.number,
      itemIndex: 0,
      status: OrderItemStatus.rejected,
      reason: 'Other station product',
    );

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('REJECTED PRODUCTS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('REJECTED PRODUCTS'), findsOneWidget);
    expect(find.text('1 product'), findsOneWidget);
    expect(find.text('2 x Mineral Water (2.5 Gal)'), findsOneWidget);
    expect(find.textContaining('Reason: Out of stock'), findsOneWidget);
    expect(find.textContaining('Other station product'), findsNothing);
  });

  testWidgets('station owner rejects only the unavailable product', (
    tester,
  ) async {
    final state = AppState();
    state.login(
      mobileOrEmail: AccountCredentials.ownerEmail,
      role: AccountRole.stationOwner,
      stationName: AccountCredentials.ownerStationName,
    );
    state.addToCart(productName: 'Mineral Water (2.5 Gal)', price: 15);
    state.addToCart(productName: 'Mineral Water (5 Gal)', price: 25);
    final order = state.submitOrder(
      station: AccountCredentials.ownerStationName,
      fulfillmentMethod: FulfillmentMethod.pickup,
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    expect(find.text('Accept product'), findsNWidgets(2));
    expect(find.text('Reject product'), findsNWidgets(2));
    expect(
      find.widgetWithText(FilledButton, 'Accept product'),
      findsNWidgets(2),
    );
    expect(
      find.widgetWithText(FilledButton, 'Reject product'),
      findsNWidgets(2),
    );

    await tester.tap(find.text('Reject product').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Out of stock');
    await tester.tap(find.text('Reject product').last);
    await tester.pumpAndSettle();

    final updatedOrder = state.incomingOrders.single;
    expect(updatedOrder.number, order.number);
    expect(updatedOrder.status, OrderStatus.pending);
    expect(updatedOrder.items[0].decisionStatus, OrderItemStatus.rejected);
    expect(updatedOrder.items[1].decisionStatus, OrderItemStatus.pending);
    expect(find.text('2 x Mineral Water (2.5 Gal)'), findsNothing);
    expect(find.text('1 x Mineral Water (5 Gal)'), findsOneWidget);
    expect(find.textContaining('Reason: Out of stock'), findsNothing);
    expect(find.text('Reject product'), findsOneWidget);
  });

  testWidgets('station owner can open the add product form', (tester) async {
    await tester.pumpWidget(const AquaLinkApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), AccountCredentials.ownerEmail);
    await tester.enterText(fields.at(1), AccountCredentials.ownerPassword);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add product'), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    await tester.tap(find.text('Add Product').last);
    await tester.pumpAndSettle();

    expect(find.text('Add product'), findsOneWidget);
    expect(find.text('Product name'), findsOneWidget);
    expect(find.text('Price (P)'), findsOneWidget);
  });

  test('owner can accept a real incoming order', () {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000001',
      role: AccountRole.customer,
      fullName: 'Maria Dela Cruz',
    );
    state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);
    final order = state.submitOrder(
      station: 'Remoreras Water Refilling',
      fulfillmentMethod: FulfillmentMethod.delivery,
      deliveryAddress: 'Current location',
    );

    expect(order.customer, 'Maria Dela Cruz');
    expect(
      state.updateOrderStatus(
        number: order.number,
        status: OrderStatus.accepted,
      ),
      isTrue,
    );
    expect(
      state.incomingOrders.any(
        (item) =>
            item.number == order.number && item.status == OrderStatus.accepted,
      ),
      isTrue,
    );
  });

  test('owner notifications only include real customer orders', () {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000002',
      role: AccountRole.customer,
      fullName: 'Pedro Reyes',
    );
    state.addToCart(productName: 'Purified Water (5 Gal)', price: 25);
    state.submitOrder(
      station: 'Remoreras Water Refilling',
      fulfillmentMethod: FulfillmentMethod.pickup,
    );

    expect(
      state.incomingOrders.any(
        (order) =>
            order.customer == 'Pedro Reyes' &&
            order.status == OrderStatus.pending,
      ),
      isTrue,
    );
  });

  testWidgets('customer notifications open the orders view', (tester) async {
    final state = AppState();
    state.login(
      mobileOrEmail: '09170000003',
      role: AccountRole.customer,
      fullName: 'Customer User',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    await tester.tap(find.byTooltip('Order notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Order notifications'), findsOneWidget);
    expect(find.text('You have no order updates yet.'), findsOneWidget);
    await tester.tap(find.text('View all orders'));
    await tester.pumpAndSettle();

    expect(find.text('My Orders'), findsOneWidget);
  });

  test(
    'logout clears the active session without fabricating customer orders',
    () {
      final state = AppState();

      state.login(
        mobileOrEmail: '09170000009',
        role: AccountRole.customer,
        fullName: 'Real Customer',
      );
      state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(state.userName, isEmpty);
      expect(state.incomingOrders, isEmpty);
    },
  );

  testWidgets('retired administrator account is no longer available', (
    tester,
  ) async {
    await tester.pumpWidget(const AquaLinkApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin@aqualink.com');
    await tester.enterText(fields.at(1), 'admin123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('This account is no longer available.'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('incorrect station owner credentials are rejected', (
    tester,
  ) async {
    await tester.pumpWidget(const AquaLinkApp());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), AccountCredentials.ownerEmail);
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });
}
