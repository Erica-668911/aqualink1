import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'app_state.dart';
import 'clarin_barangay_locations.dart';
import 'firestore_service.dart';
import 'models/models.dart';

class CheckoutScreen extends StatefulWidget {
  final String stationName;

  const CheckoutScreen({super.key, required this.stationName});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  FulfillmentMethod _fulfillmentMethod = FulfillmentMethod.delivery;
  bool _submitting = false;
  WaterOrder? _pendingOrder;
  String? _selectedBarangay;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  double? _gpsAccuracyMeters;
  bool _locating = false;
  bool _isExactGpsLocation = false;
  final _addressFormKey = GlobalKey<FormState>();
  final TextEditingController _purokController = TextEditingController();
  final TextEditingController _sitioController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  static final Map<String, (double, double)> _barangays =
      ClarinBarangayLocations.all.map(
        (key, value) => MapEntry(key, (value.latitude, value.longitude)),
      );

  @override
  void dispose() {
    _purokController.dispose();
    _sitioController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _useExactLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      if (!position.accuracy.isFinite ||
          position.accuracy <= 0 ||
          position.accuracy > 100) {
        throw Exception(
          'GPS accuracy is too low (${position.accuracy.toStringAsFixed(0)} m). '
          'Move outdoors and try again.',
        );
      }
      setState(() {
        _deliveryLatitude = position.latitude;
        _deliveryLongitude = position.longitude;
        _gpsAccuracyMeters = position.accuracy;
        _isExactGpsLocation = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get exact GPS: $error')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submitOrder() async {
    final state = AppScope.of(context);
    if (state.cart.isEmpty) return;
    final deliveryFee = _fulfillmentMethod == FulfillmentMethod.delivery
        ? state.stationDetails[widget.stationName]?.deliveryFee ?? 0
        : 0;
    if (_fulfillmentMethod == FulfillmentMethod.delivery &&
        !(_addressFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_fulfillmentMethod == FulfillmentMethod.delivery &&
        (_deliveryLatitude == null || _deliveryLongitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a barangay to set the delivery location.'),
        ),
      );
      return;
    }
    if (_fulfillmentMethod == FulfillmentMethod.delivery &&
        !_isExactGpsLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use your exact GPS location before submitting a delivery order.',
          ),
        ),
      );
      return;
    }
    if (_fulfillmentMethod == FulfillmentMethod.delivery) {
      final selectedCoordinates = _barangays[_selectedBarangay];
      if (selectedCoordinates == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a valid barangay.')),
        );
        return;
      }

      double distanceTo((double, double) coordinates) =>
          Geolocator.distanceBetween(
            coordinates.$1,
            coordinates.$2,
            _deliveryLatitude!,
            _deliveryLongitude!,
          );

      final nearestBarangay = _barangays.entries.reduce(
        (nearest, candidate) =>
            distanceTo(candidate.value) < distanceTo(nearest.value)
            ? candidate
            : nearest,
      );
      if (nearestBarangay.key != _selectedBarangay ||
          distanceTo(selectedCoordinates) > 3000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your GPS location does not match the selected barangay. '
              'Check your barangay and get your GPS location again.',
            ),
          ),
        );
        return;
      }
    }

    if (_fulfillmentMethod == FulfillmentMethod.delivery) {
      final address = [
        'Purok ${_purokController.text.trim()}',
        _sitioController.text.trim(),
        'Near ${_landmarkController.text.trim()}',
        _selectedBarangay!,
        'Clarin, Bohol',
      ].join(', ');
      final location = _isExactGpsLocation
          ? 'Exact GPS: ${_deliveryLatitude!.toStringAsFixed(6)}, '
                '${_deliveryLongitude!.toStringAsFixed(6)} '
                '(accuracy ±${_gpsAccuracyMeters!.toStringAsFixed(0)} m)'
          : 'Barangay center: $_selectedBarangay';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm delivery address'),
          content: Text(
            '$address\n\n$location\n\nPlease check that these details are correct.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Edit address'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Address is correct'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      final purok = _purokController.text.trim();
      final sitio = _sitioController.text.trim();
      final landmark = _landmarkController.text.trim();
      final locality = '${_selectedBarangay!}, Clarin, Bohol';
      final address = 'Purok $purok, $sitio, Near $landmark, $locality';
      final pendingOrder = _pendingOrder;
      final canRetryPendingOrder =
          pendingOrder != null &&
          pendingOrder.station == widget.stationName &&
          pendingOrder.fulfillmentMethod == _fulfillmentMethod &&
          pendingOrder.deliveryFee == deliveryFee &&
          pendingOrder.deliveryAddress ==
              (_fulfillmentMethod == FulfillmentMethod.delivery
                  ? address
                  : null) &&
          pendingOrder.barangay ==
              (_fulfillmentMethod == FulfillmentMethod.delivery
                  ? _selectedBarangay
                  : null) &&
          pendingOrder.landmark ==
              (_fulfillmentMethod == FulfillmentMethod.delivery
                  ? landmark
                  : null) &&
          pendingOrder.deliveryLatitude ==
              (_fulfillmentMethod == FulfillmentMethod.delivery
                  ? _deliveryLatitude
                  : null) &&
          pendingOrder.deliveryLongitude ==
              (_fulfillmentMethod == FulfillmentMethod.delivery
                  ? _deliveryLongitude
                  : null) &&
          pendingOrder.items.length == state.cart.length &&
          List.generate(state.cart.length, (index) {
            final pendingItem = pendingOrder.items[index];
            final cartItem = state.cart[index];
            return pendingItem.productName == cartItem.productName &&
                pendingItem.price == cartItem.price &&
                pendingItem.quantity == cartItem.quantity;
          }).every((matches) => matches);
      final order = canRetryPendingOrder
          ? pendingOrder
          : state.prepareOrder(
              station: widget.stationName,
              fulfillmentMethod: _fulfillmentMethod,
              deliveryFee: deliveryFee,
              deliveryAddress: address,
              barangay: _selectedBarangay,
              landmark: landmark,
              deliveryLatitude: _deliveryLatitude,
              deliveryLongitude: _deliveryLongitude,
            );
      _pendingOrder = order;

      if (Firebase.apps.isNotEmpty) {
        await FirestoreService.saveOrder(
          order: order,
        ).timeout(const Duration(seconds: 20));
      }
      if (!mounted) return;
      state.recordSubmittedOrder(order);
      _pendingOrder = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${order.number} submitted.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Order submission failed: $error');
      if (!mounted) return;
      final message = switch (error) {
        TimeoutException() =>
          'Saving the order timed out. Check your connection and retry.',
        FirebaseException(code: 'unauthenticated') =>
          'Please sign in again before submitting your order.',
        FirebaseException(code: 'permission-denied') =>
          'Firebase denied this order. Check Firestore permissions.',
        FirebaseException(code: 'unavailable') =>
          'Firebase is unavailable. Check your connection and retry.',
        FirebaseException(:final code) =>
          'Firebase error ($code). Please retry or contact support.',
        _ => 'Could not prepare the order. Please try again.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final subtotal = state.cart.fold(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );
    final deliveryFee = _fulfillmentMethod == FulfillmentMethod.delivery
        ? state.stationDetails[widget.stationName]?.deliveryFee ?? 0
        : 0;
    final total = subtotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: state.cart.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : IgnorePointer(
              ignoring: _submitting,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.stationName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  ...state.cart.map(
                    (item) => _CartItemRow(
                      item: item,
                      onQuantityChanged: (quantity) =>
                          state.updateCartQuantity(item.productName, quantity),
                    ),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(child: Text('Water subtotal')),
                      Text('P$subtotal'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Text('Delivery fee')),
                      Text(
                        _fulfillmentMethod == FulfillmentMethod.delivery
                            ? 'P$deliveryFee'
                            : 'P0',
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  if (_fulfillmentMethod == FulfillmentMethod.delivery) ...[
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _addressFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Address',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedBarangay,
                                decoration: const InputDecoration(
                                  labelText: 'Barangay',
                                  helperText: 'Clarin, Bohol',
                                  border: UnderlineInputBorder(),
                                ),
                                validator: (value) => value == null
                                    ? 'Select your barangay'
                                    : null,
                                items: _barangays.keys
                                    .map(
                                      (barangay) => DropdownMenuItem(
                                        value: barangay,
                                        child: Text(barangay),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setState(() {
                                  _selectedBarangay = value;
                                  final coordinates = _barangays[value];
                                  _deliveryLatitude = coordinates?.$1;
                                  _deliveryLongitude = coordinates?.$2;
                                  _gpsAccuracyMeters = null;
                                  _isExactGpsLocation = false;
                                }),
                              ),
                              if (_selectedBarangay != null &&
                                  _deliveryLatitude != null &&
                                  _deliveryLongitude != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _isExactGpsLocation
                                                ? Icons.gps_fixed
                                                : Icons.location_on_outlined,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isExactGpsLocation
                                                ? 'Exact GPS location'
                                                : 'Barangay location',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('$_selectedBarangay, Clarin, Bohol'),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _CoordinateValue(
                                              label: 'Latitude',
                                              value: _deliveryLatitude!
                                                  .toStringAsFixed(6),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _CoordinateValue(
                                              label: 'Longitude',
                                              value: _deliveryLongitude!
                                                  .toStringAsFixed(6),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!_isExactGpsLocation) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Using the barangay center. Use GPS for your exact position.',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              TextFormField(
                                controller: _purokController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Purok Number',
                                  hintText: 'e.g. 1',
                                  border: UnderlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your Purok number';
                                  }
                                  if (!RegExp(
                                    r'^\d+$',
                                  ).hasMatch(value.trim())) {
                                    return 'Enter the Purok number using digits';
                                  }
                                  return null;
                                },
                              ),
                              TextFormField(
                                controller: _sitioController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Sitio Name',
                                  hintText: 'Enter your sitio',
                                  border: UnderlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your sitio name';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Enter a complete sitio name';
                                  }
                                  return null;
                                },
                              ),
                              TextFormField(
                                controller: _landmarkController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Landmark',
                                  hintText: 'Enter a nearby landmark',
                                  border: UnderlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter a nearby landmark';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Enter a complete landmark';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _locating ? null : _useExactLocation,
                                icon: _locating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location),
                                label: const Text('Use exact GPS location'),
                              ),
                              if (_isExactGpsLocation &&
                                  _selectedBarangay != null)
                                TextButton.icon(
                                  onPressed: () {
                                    final coordinates =
                                        _barangays[_selectedBarangay];
                                    setState(() {
                                      _deliveryLatitude = coordinates?.$1;
                                      _deliveryLongitude = coordinates?.$2;
                                      _gpsAccuracyMeters = null;
                                      _isExactGpsLocation = false;
                                    });
                                  },
                                  icon: const Icon(Icons.location_on_outlined),
                                  label: const Text(
                                    'Use barangay center instead',
                                  ),
                                ),
                              if (_selectedBarangay == null &&
                                  _deliveryLatitude != null &&
                                  _deliveryLongitude != null)
                                Text(
                                  'GPS: ${_deliveryLatitude!.toStringAsFixed(6)}, '
                                  '${_deliveryLongitude!.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Text(
                    'Fulfillment method',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  RadioGroup<FulfillmentMethod>(
                    groupValue: _fulfillmentMethod,
                    onChanged: (value) => setState(() {
                      _fulfillmentMethod = value!;
                    }),
                    child: Column(
                      children: [
                        RadioListTile<FulfillmentMethod>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Delivery'),
                          subtitle: Text(state.deliveryAddress),
                          value: FulfillmentMethod.delivery,
                        ),
                        RadioListTile<FulfillmentMethod>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pickup'),
                          subtitle: const Text(
                            'Collect from the water station',
                          ),
                          value: FulfillmentMethod.pickup,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        'P$total',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitOrder,
                      child: _submitting
                          ? const CircularProgressIndicator()
                          : const Text('Submit water order'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;

  const _CartItemRow({required this.item, required this.onQuantityChanged});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(item.productName),
      subtitle: Text('P${item.price} each'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: () => onQuantityChanged(item.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${item.quantity}'),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: () => onQuantityChanged(item.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    ),
  );
}

class _CoordinateValue extends StatelessWidget {
  final String label;
  final String value;

  const _CoordinateValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}
