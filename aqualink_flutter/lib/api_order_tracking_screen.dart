import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_map/flutter_map.dart' as leaflet;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

import 'clarin_barangay_locations.dart';
import 'firestore_service.dart';

String trackingApiBaseUrl({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  // Lahi ang localhost address sa Android emulator ug sa ubang platforms.
  if (isWeb) return 'http://localhost:8000';
  if (platform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

class ApiOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final int? orderTotal;
  final String? orderStatus;
  final String? stationName;
  final String? barangay;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? landmark;
  final String? deliveryAddress;
  final bool isDelivery;

  const ApiOrderTrackingScreen({
    super.key,
    required this.orderId,
    this.orderTotal,
    this.orderStatus,
    this.stationName,
    this.barangay,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.landmark,
    this.deliveryAddress,
    this.isDelivery = true,
  });

  @override
  State<ApiOrderTrackingScreen> createState() => _ApiOrderTrackingScreenState();
}

class _ApiOrderTrackingScreenState extends State<ApiOrderTrackingScreen> {
  static String get apiBaseUrl {
    return trackingApiBaseUrl(isWeb: kIsWeb, platform: defaultTargetPlatform);
  }

  Timer? _refreshTimer;
  StreamSubscription<String?>? _statusSubscription;
  TrackingData? _tracking;
  String? _currentOrderStatus;
  bool _loading = false;
  bool _showAddressMap = false;

  @override
  void initState() {
    super.initState();
    _currentOrderStatus = widget.orderStatus;
    _fetchTracking();
    if (Firebase.apps.isNotEmpty) {
      // Maminaw sa real-time status sa Firestore ug i-refresh ang tracking kung mausab.
      _statusSubscription = FirestoreService.watchOrderStatus(widget.orderId)
          .listen((status) {
            if (status == null || !mounted) return;
            final previousStatus = _currentOrderStatus;
            setState(() => _currentOrderStatus = status);
            if (previousStatus?.toLowerCase() == 'pending' &&
                status.toLowerCase() == 'accepted') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order #${widget.orderId} was accepted.'),
                ),
              );
            }
            _fetchTrackingSilently();
          });
    }
  }

  Uri _trackingUri() {
    // I-apil ang order ug delivery details aron magamit kini sa tracking API.
    final query = <String, String>{};
    if (_currentOrderStatus != null) {
      query['order_status'] = _currentOrderStatus!;
    }
    if (widget.stationName != null) query['station'] = widget.stationName!;
    if (widget.barangay != null && widget.barangay!.trim().isNotEmpty) {
      query['barangay'] = widget.barangay!;
    }
    if (widget.deliveryLatitude != null) {
      query['delivery_latitude'] = '${widget.deliveryLatitude}';
    }
    if (widget.deliveryLongitude != null) {
      query['delivery_longitude'] = '${widget.deliveryLongitude}';
    }
    if (widget.landmark != null && widget.landmark!.isNotEmpty) {
      query['landmark'] = widget.landmark!;
    }
    if (widget.deliveryAddress != null && widget.deliveryAddress!.isNotEmpty) {
      query['delivery_address'] = widget.deliveryAddress!;
    }
    return Uri.parse(
      '$apiBaseUrl/orders/${widget.orderId}/tracking',
    ).replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<void> _fetchTracking() async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await http.get(
        _trackingUri(),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw Exception('Order tracking was not found.');
      }
      final data = TrackingData.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _tracking = data;
        _loading = false;
      });
      // I-refresh matag 10 segundos aron makita ang pinakabag-ong lokasyon sa rider.
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchTrackingSilently(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _tracking = null;
      });
      debugPrint('Tracking fetch failed for ${widget.orderId}: $error');
    }
  }

  Future<void> _fetchTrackingSilently() async {
    // Background refresh kini; dili usbon ang loading state samtang nagpakita ang screen.
    try {
      final response = await http.get(_trackingUri());
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _tracking = TrackingData.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8FA),
    appBar: AppBar(
      title: const Text('Order status'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: Builder(
      builder: (context) {
        final tracking =
            _tracking ??
            // Kung dili maabot ang API, gamiton ang order details isip map/status fallback.
            TrackingData.fallback(
              orderId: widget.orderId,
              stationName: widget.stationName ?? 'Water Station',
              deliveryLatitude: widget.deliveryLatitude,
              deliveryLongitude: widget.deliveryLongitude,
              landmark: widget.landmark,
              deliveryAddress: widget.deliveryAddress,
            );
        final status =
            _currentOrderStatus ?? _tracking?.status ?? 'No tracking yet';
        final address =
            (widget.isDelivery
                    ? [widget.deliveryAddress, widget.landmark, widget.barangay]
                    : [widget.stationName])
                .whereType<String>()
                .map((value) => value.trim())
                .firstWhere(
                  (value) => value.isNotEmpty,
                  orElse: () => 'Address not provided',
                );

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Text(
              'Order #${widget.orderId}',
              style: const TextStyle(
                color: Color(0xFF17212B),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.stationName != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.stationName!,
                style: const TextStyle(color: Color(0xFF71808D), fontSize: 13),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (_tracking == null) ...[
              const SizedBox(height: 12),
              Text(
                'Live tracking details are unavailable. Showing the latest saved order status.',
                style: TextStyle(color: Color(0xFF71808D), fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE3EAEE)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status timeline',
                    style: TextStyle(
                      color: Color(0xFF17212B),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StatusTimeline(
                    status: status,
                    estimatedDeliveryAt: _tracking?.estimatedDeliveryAt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE3EAEE)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF087F9D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isDelivery
                              ? 'Delivery address'
                              : 'Pickup location',
                          style: const TextStyle(
                            color: Color(0xFF71808D),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: const TextStyle(
                            color: Color(0xFF17212B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isDelivery) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showAddressMap = !_showAddressMap),
                icon: Icon(
                  _showAddressMap
                      ? Icons.map_outlined
                      : Icons.location_on_outlined,
                ),
                label: Text(
                  _showAddressMap ? 'Hide address map' : 'Show address map',
                ),
              ),
              if (_showAddressMap) ...[
                const SizedBox(height: 8),
                _RoutePreview(tracking: tracking),
              ],
            ],
            const SizedBox(height: 16),
            _TrackingSummary(amount: widget.orderTotal),
          ],
        );
      },
    ),
  );
}

class _RoutePreview extends StatefulWidget {
  final TrackingData tracking;

  const _RoutePreview({required this.tracking});

  @override
  State<_RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<_RoutePreview> {
  final leaflet.MapController _mapController = leaflet.MapController();
  late Future<List<LatLng>> _routeFuture;

  @override
  void initState() {
    super.initState();
    // Sugdan ang route lookup sa unang pagpakita sa map.
    _routeFuture = _loadDrivingRoute(widget.tracking);
  }

  @override
  void didUpdateWidget(covariant _RoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // I-recalculate ang dalan kung mausab ang station, rider, o delivery coordinates.
    if (widget.tracking.stationLocation != oldWidget.tracking.stationLocation ||
        widget.tracking.latestLocation != oldWidget.tracking.latestLocation ||
        widget.tracking.deliveryLocation !=
            oldWidget.tracking.deliveryLocation) {
      _routeFuture = _loadDrivingRoute(widget.tracking);
    }
    final latestLocation = widget.tracking.latestLocation;
    if (latestLocation != null) {
      _mapController.move(latestLocation, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateZoom(double delta) {
    _mapController.move(
      _mapController.camera.center,
      (_mapController.camera.zoom + delta).clamp(10.0, 18.0),
    );
  }

  Future<List<LatLng>> _loadDrivingRoute(TrackingData tracking) async {
    // Ang rider location mahimong waypoint aron ang route mosunod sa iyang kasamtangang posisyon.
    final waypoints = [
      tracking.stationLocation,
      if (tracking.latestLocation != null) tracking.latestLocation!,
      tracking.deliveryLocation,
    ];
    final coordinates = waypoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
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
    final routeCoordinates = geometry['coordinates'] as List<dynamic>;
    return routeCoordinates.map((coordinate) {
      final pair = coordinate as List<dynamic>;
      return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Ipakita sa mapa ang mga station, delivery point, ug rider kung naa nay location.
    final markers = [
      leaflet.Marker(
        point: widget.tracking.stationLocation,
        width: 34,
        height: 34,
        child: const Icon(
          Icons.location_on,
          color: Color(0xFF087F9D),
          size: 30,
        ),
      ),
      for (final station in widget.tracking.stations)
        if (station.name != widget.tracking.stationName)
          leaflet.Marker(
            point: station.location,
            width: 34,
            height: 34,
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF0F766E),
              size: 30,
            ),
          ),
      leaflet.Marker(
        point: widget.tracking.deliveryLocation,
        width: 34,
        height: 34,
        child: const Icon(
          Icons.location_on,
          color: Color(0xFFF59E0B),
          size: 30,
        ),
      ),
      if (widget.tracking.latestLocation != null)
        leaflet.Marker(
          point: widget.tracking.latestLocation!,
          width: 38,
          height: 38,
          child: const Icon(
            Icons.local_shipping,
            color: Color(0xFF087F9D),
            size: 30,
          ),
        ),
    ];

    return FutureBuilder<List<LatLng>>(
      future: _routeFuture,
      builder: (context, snapshot) {
        final route = snapshot.data;
        return _buildMapShell(
          leaflet.FlutterMap(
            mapController: _mapController,
            options: leaflet.MapOptions(
              initialCenter: widget.tracking.stationLocation,
              initialZoom: 15,
            ),
            children: [
              leaflet.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.aqualink',
              ),
              if (route != null && route.length > 1)
                leaflet.PolylineLayer(
                  polylines: [
                    leaflet.Polyline(
                      points: route,
                      color: const Color(0xFF27AE60),
                      strokeWidth: 7,
                    ),
                  ],
                ),
              leaflet.MarkerLayer(markers: markers),
            ],
          ),
          routeMessage: snapshot.connectionState == ConnectionState.waiting
              ? 'Finding a road route...'
              : snapshot.hasError
              ? 'Road route unavailable; showing locations only.'
              : null,
        );
      },
    );
  }

  Widget _buildMapShell(Widget map, {String? routeMessage}) => Container(
    height: 430,
    decoration: const BoxDecoration(color: Color(0xFFECEFF1)),
    child: Stack(
      children: [
        map,
        Positioned(
          top: 14,
          left: 20,
          child: Text(
            'Address map',
            style: const TextStyle(
              color: Color(0xFF5D6B72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (routeMessage != null)
          Positioned(
            top: 34,
            left: 20,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(
                  routeMessage,
                  style: const TextStyle(
                    color: Color(0xFF5D6B72),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _DeliveryInfoPanel(
            stationName: widget.tracking.stationName,
            address:
                widget.tracking.deliveryAddress ??
                widget.tracking.deliveryLandmark ??
                'Clarin, Bohol',
          ),
        ),
        Positioned(
          right: 12,
          bottom: 155,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _updateZoom(1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD8E3E8)),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Color(0xFF5D6B72),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _updateZoom(-1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD8E3E8)),
                  ),
                  child: const Icon(
                    Icons.remove,
                    size: 18,
                    color: Color(0xFF5D6B72),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DeliveryInfoPanel extends StatelessWidget {
  final String stationName;
  final String address;

  const _DeliveryInfoPanel({required this.stationName, required this.address});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InfoRow(
            icon: Icons.location_on,
            color: const Color(0xFFE74C3C),
            label: 'Station',
            value: stationName,
          ),
          const Divider(height: 12),
          _InfoRow(
            icon: Icons.flag,
            color: const Color(0xFFE74C3C),
            label: 'Address',
            value: address,
          ),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF52616B), fontSize: 12),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    ],
  );
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  final DateTime? estimatedDeliveryAt;

  const _StatusTimeline({
    required this.status,
    required this.estimatedDeliveryAt,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    // Ibulag ang cancelled/rejected ug completed orders gikan sa normal nga timeline.
    final isCancelled =
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'rejected';
    final isComplete =
        normalized.contains('completed') || normalized.contains('delivered');
    // I-convert ang status text ngadto sa index sa katapusang aktibong timeline step.
    final activeStep = isComplete
        ? 4
        : normalized.contains('delivery')
        ? 3
        : normalized.contains('prepar')
        ? 2
        : normalized.contains('accept')
        ? 1
        : normalized.contains('pending')
        ? 0
        : -1;
    if (isCancelled) {
      final label = normalized == 'rejected' ? 'Rejected' : 'Cancelled';
      return _StatusStep(
        title: label,
        detail: 'This order will not continue.',
        icon: Icons.close,
        active: true,
        last: true,
        color: const Color(0xFFD64545),
      );
    }

    const steps = [
      ('Order received', Icons.receipt_long_outlined),
      ('Accepted', Icons.check),
      ('Preparing', Icons.inventory_2_outlined),
      ('Out for Delivery', Icons.two_wheeler_outlined),
      ('Delivered', Icons.home_outlined),
    ];
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _StatusStep(
            title: steps[index].$1,
            detail: _detailForStep(index, activeStep, isComplete),
            icon: steps[index].$2,
            active: activeStep >= 0 && index <= activeStep,
            last: index == steps.length - 1,
          ),
      ],
    );
  }

  String _detailForStep(int index, int activeStep, bool isComplete) {
    if (activeStep < 0) return 'Waiting for an update';
    if (index < activeStep) return 'Complete';
    if (index == 4 && isComplete) return 'Complete';
    if (index == 4 && estimatedDeliveryAt != null) {
      return 'Estimated ${_formatDateTime(estimatedDeliveryAt!)}';
    }
    if (index > activeStep) return 'Not started';
    if (index == 4) return 'No estimate yet';
    return 'Current status';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _StatusStep extends StatelessWidget {
  final String title;
  final String detail;
  final IconData icon;
  final bool active;
  final bool last;
  final Color? color;

  const _StatusStep({
    required this.title,
    required this.detail,
    required this.icon,
    required this.active,
    required this.last,
    this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 62,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: active
                    ? (color ?? const Color(0xFF087F9D))
                    : const Color(0xFFEAF0F4),
                child: Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : const Color(0xFF9AAABD),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: active
                        ? (color ?? const Color(0xFF087F9D))
                        : const Color(0xFFDDE5EC),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? const Color(0xFF17212B)
                      : const Color(0xFF9AAABD),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 10,
                  color: active
                      ? const Color(0xFF71808D)
                      : const Color(0xFF9AAABD),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TrackingSummary extends StatelessWidget {
  final int? amount;

  const _TrackingSummary({required this.amount});

  @override
  Widget build(BuildContext context) {
    if (amount == null) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: Color(0xFF087F9D)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Order total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF71808D),
                ),
              ),
            ),
            Text(
              'P$amount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17212B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    recordedAt: DateTime.parse(json['recorded_at']).toLocal(),
  );
}

class StationLocation {
  final String name;
  final String address;
  final LatLng location;

  const StationLocation({
    required this.name,
    required this.address,
    required this.location,
  });

  factory StationLocation.fromJson(Map<String, dynamic> json) =>
      StationLocation(
        name: json['name'] as String,
        address: json['address'] as String? ?? 'Clarin, Bohol',
        location: LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
      );
}

class TrackingData {
  static final Map<String, LatLng> clarinBarangayCoordinates =
      ClarinBarangayLocations.all;

  final String orderId;
  final String trackingCode;
  final String status;
  final String? riderName;
  final String stationName;
  final LatLng stationLocation;
  final List<StationLocation> stations;
  final LatLng? latestLocation;
  final LatLng pickupLocation;
  final LatLng deliveryLocation;
  final String? deliveryLandmark;
  final String? deliveryAddress;
  final List<LocationPoint> locationHistory;
  final DateTime? estimatedDeliveryAt;

  const TrackingData({
    required this.orderId,
    required this.trackingCode,
    required this.status,
    required this.riderName,
    required this.stationName,
    required this.stationLocation,
    required this.stations,
    required this.latestLocation,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.deliveryLandmark,
    required this.deliveryAddress,
    required this.locationHistory,
    required this.estimatedDeliveryAt,
  });

  String get displayRiderName {
    final station = stationName.toLowerCase();
    if (station.contains('remoreras')) return 'Remoreras';
    if (station.contains('j&p')) return 'J&P';
    if (station.contains('cjoan')) return 'CJoan';
    final name = riderName?.trim();
    return name == null || name.isEmpty ? 'AquaLink Rider' : name;
  }

  static LatLng _resolveDeliveryLocation({
    required String? landmark,
    required double? deliveryLatitude,
    required double? deliveryLongitude,
  }) {
    // Unahon ang eksaktong GPS; kung wala, pangitaon ang barangay pinaagi sa landmark.
    if (deliveryLatitude != null && deliveryLongitude != null) {
      return LatLng(deliveryLatitude, deliveryLongitude);
    }

    final candidate = (landmark ?? '').trim();
    if (candidate.isNotEmpty) {
      final normalized = candidate.toLowerCase();
      for (final entry in clarinBarangayCoordinates.entries) {
        final key = entry.key.toLowerCase();
        if (normalized.contains(key) || key.contains(normalized)) {
          return entry.value;
        }
      }
    }

    return clarinBarangayCoordinates['Poblacion Sur'] ??
        const LatLng(9.9569363, 124.0262300);
  }

  factory TrackingData.fallback({
    required String orderId,
    required String stationName,
    required double? deliveryLatitude,
    required double? deliveryLongitude,
    required String? landmark,
    required String? deliveryAddress,
  }) {
    // Gamiton kining lokal nga coordinates aron magpabilin nga magamit ang map bisan walay API data.
    final stationPoint = stationName.toLowerCase().contains('remoreras')
        ? const LatLng(9.9547, 124.0084)
        : stationName.toLowerCase().contains('j&p')
        ? const LatLng(9.9601634, 124.0260079)
        : stationName.toLowerCase().contains('cjoan')
        ? const LatLng(9.9501, 124.0224)
        : const LatLng(9.9651186, 124.0237998);
    final delivery = _resolveDeliveryLocation(
      landmark: landmark,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );

    return TrackingData(
      orderId: orderId,
      trackingCode: 'N/A',
      status: 'No tracking yet',
      riderName: 'AquaLink Rider',
      stationName: stationName,
      stationLocation: stationPoint,
      stations: const [],
      latestLocation: null,
      pickupLocation: stationPoint,
      deliveryLocation: delivery,
      deliveryLandmark: landmark ?? 'Poblacion Sur, Clarin, Bohol',
      deliveryAddress: deliveryAddress,
      locationHistory: const [],
      estimatedDeliveryAt: null,
    );
  }

  static LatLng? _latLngFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (latitude == null || longitude == null) return null;
    return LatLng((latitude as num).toDouble(), (longitude as num).toDouble());
  }

  static LatLng _resolveStationLocation({
    required String? stationName,
    required LatLng? reportedLocation,
  }) {
    // I-prioritize ang coordinates nga na-define para sa nailhang stations.
    final normalizedName = stationName?.toLowerCase() ?? '';
    if (normalizedName.contains('remoreras')) {
      return const LatLng(9.9547, 124.0084);
    }
    if (normalizedName.contains('j&p')) {
      return const LatLng(9.9601634, 124.0260079);
    }
    if (normalizedName.contains('cjoan')) {
      return const LatLng(9.9501, 124.0224);
    }
    return reportedLocation ?? const LatLng(9.9547, 124.0084);
  }

  // I-convert ang API response ngadto sa typed tracking model nga gamiton sa screen.
  factory TrackingData.fromJson(Map<String, dynamic> json) => TrackingData(
    orderId: json['order_id'] as String,
    trackingCode: json['tracking_code'] as String,
    status: json['status'] as String,
    riderName: json['rider_name'] as String?,
    stationName: json['station_name'] as String? ?? 'Water Station',
    stationLocation: _resolveStationLocation(
      stationName: json['station_name'] as String?,
      reportedLocation:
          _latLngFromJson(json['station_location'] as Map<String, dynamic>?) ??
          _latLngFromJson(json['pickup_location'] as Map<String, dynamic>?),
    ),
    stations: (json['stations'] as List<dynamic>? ?? [])
        .map((item) => StationLocation.fromJson(item as Map<String, dynamic>))
        .toList(),
    latestLocation: _latLngFromJson(
      json['latest_location'] as Map<String, dynamic>?,
    ),
    pickupLocation:
        _latLngFromJson(json['pickup_location'] as Map<String, dynamic>?) ??
        const LatLng(9.9700, 124.0150),
    deliveryLocation:
        _latLngFromJson(json['delivery_location'] as Map<String, dynamic>?) ??
        const LatLng(9.9560, 124.0340),
    deliveryLandmark:
        (json['delivery_location'] as Map<String, dynamic>?)?['landmark']
            as String?,
    deliveryAddress:
        (json['delivery_location'] as Map<String, dynamic>?)?['address']
            as String?,
    locationHistory: (json['location_history'] as List<dynamic>? ?? [])
        .map((item) => LocationPoint.fromJson(item as Map<String, dynamic>))
        .toList(),
    estimatedDeliveryAt: _dateTimeFromJson(json['estimated_delivery_at']),
  );

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
