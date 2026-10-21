import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_state.dart';
import 'models/models.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? validateRegistration({
    required String fullName,
    required String mobile,
    required String password,
  }) {
    final nameParts = fullName.trim().split(RegExp(r'\s+'));
    final validName = RegExp(r"^[A-Za-z]+(?:[ '-][A-Za-z]+)*$");
    if (nameParts.length < 2 ||
        nameParts.any((part) => part.length < 2 || !validName.hasMatch(part))) {
      return 'Enter your complete first and last name.';
    }
    if (!RegExp(r'^09\d{9}$').hasMatch(mobile.trim())) {
      return 'Mobile number must be exactly 11 digits and start with 09.';
    }
    if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$').hasMatch(password)) {
      return 'Password must be 8+ characters with uppercase, lowercase, and a number.';
    }
    return null;
  }

  static Future<UserCredential> registerAccount({
    required String fullName,
    required String mobile,
    required String email,
    required String password,
  }) async {
    final normalizedMobile = mobile.trim();
    final validationError = validateRegistration(
      fullName: fullName,
      mobile: normalizedMobile,
      password: password,
    );
    if (validationError != null) {
      throw FirebaseAuthException(
        code: 'invalid-registration-data',
        message: validationError,
      );
    }
    final mobileRef = _db.collection('user_phones').doc(normalizedMobile);

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user!.updateDisplayName(fullName.trim());
      final uid = credential.user!.uid;
      await _db.runTransaction((transaction) async {
        final mobileSnapshot = await transaction.get(mobileRef);
        if (mobileSnapshot.exists) {
          throw FirebaseAuthException(
            code: 'mobile-already-in-use',
            message: 'This mobile number is already registered.',
          );
        }
        transaction.set(mobileRef, {
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      await saveUser(
        uid: uid,
        fullName: fullName,
        mobile: normalizedMobile,
        email: email,
        role: 'customer',
      );
      return credential;
    } catch (error) {
      await _auth.currentUser?.delete();
      rethrow;
    }
  }

  static Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) => _auth.signInWithEmailAndPassword(
    email: email.trim().toLowerCase(),
    password: password,
  );

  static Future<UserCredential> loginWithMobileOrEmail({
    required String mobileOrEmail,
    required String password,
  }) async {
    final normalizedLoginId = mobileOrEmail.trim();
    if (normalizedLoginId.contains('@')) {
      return loginWithEmail(email: normalizedLoginId, password: password);
    }

    if (!RegExp(r'^09\d{9}$').hasMatch(normalizedLoginId)) {
      return loginWithEmail(email: normalizedLoginId, password: password);
    }

    final mobileDoc = await _db
        .collection('user_phones')
        .doc(normalizedLoginId)
        .get();
    final uid = mobileDoc.data()?['uid'] as String?;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account was found for that mobile number.',
      );
    }

    final profile = await loadUserProfile(uid);
    final email = (profile?['email'] as String?)?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account was found for that mobile number.',
      );
    }

    return loginWithEmail(email: email, password: password);
  }

  static Future<Map<String, dynamic>?> loadUserProfile(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    return snapshot.data();
  }

  static Future<Map<String, dynamic>?> loadOwnerProfile(String uid) async {
    final snapshot = await _db.collection('owners').doc(uid).get();
    return snapshot.data();
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> sendPasswordReset({required String email}) =>
      _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());

  static Future<void> initializeBuiltInAccountsAndData() async {
    final builtInAccounts = [
      (
        email: AccountCredentials.ownerEmail,
        password: AccountCredentials.ownerPassword,
        fullName: 'Remoreras Station Owner',
        mobile: '09170000001',
        role: 'stationOwner',
        stationName: AccountCredentials.ownerStationName,
      ),
      (
        email: AccountCredentials.jAndPOwnerEmail,
        password: AccountCredentials.jAndPOwnerPassword,
        fullName: 'J&P Station Owner',
        mobile: '09170000003',
        role: 'stationOwner',
        stationName: AccountCredentials.jAndPStationName,
      ),
      (
        email: AccountCredentials.cJoanOwnerEmail,
        password: AccountCredentials.cJoanOwnerPassword,
        fullName: 'CJoan Station Owner',
        mobile: '09170000004',
        role: 'stationOwner',
        stationName: AccountCredentials.cJoanStationName,
      ),
    ];

    for (final account in builtInAccounts) {
      UserCredential credential;
      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: account.email,
          password: account.password,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        credential = await _auth.signInWithEmailAndPassword(
          email: account.email,
          password: account.password,
        );
      }
      await saveUser(
        uid: credential.user!.uid,
        fullName: account.fullName,
        mobile: account.mobile,
        email: account.email,
        role: account.role,
      );
      await _db.collection('owners').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'fullName': account.fullName,
        'mobile': account.mobile,
        'email': account.email,
        'role': account.role,
        'stationName': account.stationName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final station = demoStations.firstWhere(
        (station) => station.name == account.stationName,
      );
      await saveStation(station: station);
    }
    await _auth.signOut();
  }

  static Future<void> saveUser({
    String? uid,
    required String fullName,
    required String mobile,
    required String email,
    required String role,
  }) async {
    final userRef = uid == null
        ? _db.collection('users').doc()
        : _db.collection('users').doc(uid);
    await userRef.set({
      'fullName': fullName.trim(),
      'mobile': mobile.trim(),
      'email': email.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateUserLogin({
    required String uid,
    required String role,
    required String mobileOrEmail,
  }) async {
    await _db.collection('users').doc(uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'role': role,
      'mobileOrEmail': mobileOrEmail.trim(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateCurrentUserName(String fullName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to update your profile name.');
    }

    final normalizedName = fullName.trim();
    await _db.collection('users').doc(user.uid).set({
      'fullName': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updateDisplayName(normalizedName);
  }

  static Future<void> saveStation({required Station station}) async {
    final stationRef = _db.collection('stations').doc(station.name);
    final batch = _db.batch();
    batch.set(stationRef, {
      'name': station.name,
      'isOpen': station.isOpen,
      'rating': station.rating,
      'reviewCount': station.reviewCount,
      'distanceKm': station.distanceKm,
      'priceLabel': station.priceLabel,
      'operatingHours': station.operatingHours,
      'deliveryInformation': station.deliveryInformation,
      'icon': station.icon.codePoint,
      'iconColor': station.iconColor.toARGB32(),
      'iconBg': station.iconBg.toARGB32(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (final product in station.products) {
      batch.set(
        _db.collection('products').doc('${station.name}_${product.name}'),
        {
          'stationName': station.name,
          'name': product.name,
          'price': product.price,
          'available': product.available,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static Future<void> saveStationDetails({
    required String stationId,
    required StationDetails details,
  }) async {
    await _requireStationOwner(stationId);
    await _db.collection('station_details').doc(stationId).set({
      'stationName': details.name,
      'address': details.address,
      'contact': details.contact,
      'operatingHours': details.operatingHours,
      'deliveryAreas': details.deliveryAreas,
      'deliveryFee': details.deliveryFee,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveProduct({
    required String stationName,
    required StationProduct product,
  }) async {
    await _requireStationOwner(stationName);
    await _db.collection('products').doc('${stationName}_${product.name}').set({
      'stationName': stationName,
      'name': product.name,
      'price': product.price,
      'available': product.available,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _requireStationOwner(String stationName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in before editing station data.');
    final owner = await _db.collection('owners').doc(uid).get();
    if (owner.data()?['stationName'] != stationName) {
      throw StateError('This account cannot edit another station.');
    }
  }

  static Future<Map<String, StationDetails>> loadSavedStationDetails() async {
    final snapshot = await _db.collection('station_details').get();
    final detailsByStation = <String, StationDetails>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      final name = data['stationName'];
      final address = data['address'];
      final contact = data['contact'];
      final operatingHours = data['operatingHours'];
      final deliveryAreas = data['deliveryAreas'];
      final deliveryFee = data['deliveryFee'];
      if (name is! String ||
          address is! String ||
          contact is! String ||
          operatingHours is! String ||
          deliveryAreas is! String ||
          deliveryFee is! num) {
        continue;
      }
      detailsByStation[document.id] = StationDetails(
        name: name,
        address: address,
        contact: contact,
        operatingHours: operatingHours,
        deliveryAreas: deliveryAreas,
        deliveryFee: deliveryFee.toInt(),
      );
    }
    return detailsByStation;
  }

  static Future<void> saveOrder({required WaterOrder order}) async {
    final customerUid = _auth.currentUser?.uid;
    if (customerUid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Sign in before submitting an order.',
      );
    }

    final batch = _db.batch();
    batch.set(_db.collection('orders').doc(order.number), {
      'number': order.number,
      'station': order.station,
      'customerUid': customerUid,
      'customer': order.customer,
      'total': order.total,
      'deliveryFee': order.deliveryFee,
      'fulfillmentMethod': order.fulfillmentMethod.name,
      'status': order.status.name,
      'deliveryAddress': order.deliveryAddress ?? '',
      'barangay': order.barangay ?? '',
      'landmark': order.landmark ?? '',
      'deliveryLatitude': order.deliveryLatitude,
      'deliveryLongitude': order.deliveryLongitude,
      'reason': order.reason ?? '',
      'items': order.items
          .map(
            (item) => {
              'productName': item.productName,
              'price': item.price,
              'quantity': item.quantity,
            },
          )
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    for (var index = 0; index < order.items.length; index++) {
      final item = order.items[index];
      batch.set(
        _db.collection('order_items').doc('${order.number}_$index'),
        {
          'orderNumber': order.number,
          'station': order.station,
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    if (order.fulfillmentMethod == FulfillmentMethod.delivery) {
      batch.set(_db.collection('deliveries').doc(order.number), {
        'orderNumber': order.number,
        'customer': order.customer,
        'station': order.station,
        'address': order.deliveryAddress ?? '',
        'barangay': order.barangay ?? '',
        'landmark': order.landmark ?? '',
        'latitude': order.deliveryLatitude,
        'longitude': order.deliveryLongitude,
        'status': order.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  static Stream<List<WaterOrder>> watchOrdersForStation(String stationName) =>
      _db
          .collection('orders')
          .where('station', isEqualTo: stationName)
          .snapshots()
          .map((snapshot) {
            final orders = snapshot.docs
                .map((document) => _orderFromData(document.id, document.data()))
                .whereType<WaterOrder>()
                .toList();
            orders.sort(
              (first, second) => (second.createdAt ?? DateTime(1970)).compareTo(
                first.createdAt ?? DateTime(1970),
              ),
            );
            return orders;
          });

  static Stream<List<WaterOrder>> watchOrdersForCustomer() {
    final customerUid = _auth.currentUser?.uid;
    if (customerUid == null) return const Stream.empty();
    return _db
        .collection('orders')
        .where('customerUid', isEqualTo: customerUid)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((document) => _orderFromData(document.id, document.data()))
              .whereType<WaterOrder>()
              .toList();
          orders.sort(
            (first, second) => (second.createdAt ?? DateTime(1970)).compareTo(
              first.createdAt ?? DateTime(1970),
            ),
          );
          return orders;
        });
  }

  static Stream<String?> watchOrderStatus(String number) => _db
      .collection('orders')
      .doc(number)
      .snapshots()
      .map((snapshot) => snapshot.data()?['status'] as String?);

  static WaterOrder? _orderFromData(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final station = data['station'];
    if (station is! String) return null;
    final fulfillmentName = data['fulfillmentMethod'];
    final statusName = data['status'];
    final createdAt = data['createdAt'];
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .map((rawItem) {
                if (rawItem is! Map) return null;
                final name = rawItem['productName'];
                final price = rawItem['price'];
                final quantity = rawItem['quantity'];
                if (name is! String || price is! num || quantity is! num) {
                  return null;
                }
                return CartItem(
                  productName: name,
                  price: price.toInt(),
                  quantity: quantity.toInt(),
                );
              })
              .whereType<CartItem>()
              .toList()
        : <CartItem>[];

    return WaterOrder(
      number: data['number'] as String? ?? documentId,
      station: station,
      customer: data['customer'] as String? ?? 'Customer',
      items: items,
      total: (data['total'] as num?)?.toInt() ?? 0,
      deliveryFee: (data['deliveryFee'] as num?)?.toInt() ?? 0,
      fulfillmentMethod: FulfillmentMethod.values.firstWhere(
        (method) => method.name == fulfillmentName,
        orElse: () => FulfillmentMethod.pickup,
      ),
      status: OrderStatus.values.firstWhere(
        (orderStatus) => orderStatus.name == statusName,
        orElse: () => OrderStatus.pending,
      ),
      deliveryAddress: _optionalString(data['deliveryAddress']),
      barangay: _optionalString(data['barangay']),
      landmark: _optionalString(data['landmark']),
      deliveryLatitude: (data['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (data['deliveryLongitude'] as num?)?.toDouble(),
      reason: _optionalString(data['reason']),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt is DateTime
          ? createdAt
          : null,
      completedAt: data['completedAt'] is Timestamp
          ? (data['completedAt'] as Timestamp).toDate()
          : data['completedAt'] is DateTime
          ? data['completedAt'] as DateTime
          : null,
    );
  }

  static String? _optionalString(dynamic value) =>
      value is String && value.isNotEmpty ? value : null;

  static Future<void> updateOrderStatus({
    required String number,
    required OrderStatus status,
    String? reason,
  }) => _db.collection('orders').doc(number).update({
    'status': status.name,
    'reason': reason?.trim() ?? '',
    if (status == OrderStatus.completed || status == OrderStatus.delivered)
      'completedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
