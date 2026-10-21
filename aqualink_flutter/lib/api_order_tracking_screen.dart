import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentOrderStatus = widget.orderStatus;
    _fetchTracking();
    if (Firebase.apps.isNotEmpty) {
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

  void _handleSearchSubmission(String value) {
    final query = value.trim();
    if (!mounted) return;
    setState(() {
      _searchQuery = query;
    });
  }

  Uri _trackingUri() {
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEBF0F3),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF3F6F7),
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2A33)),
      ),
      title: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDE5E8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: Color(0xFF6B7A86)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onSubmitted: _handleSearchSubmission,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Color(0xFF1D2A33), fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search location',
                  hintStyle: TextStyle(color: Color(0xFF6B7A86), fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.menu, size: 22, color: Color(0xFF1D2A33)),
        ),
      ],
    ),
    body: _tracking == null
        ? ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            children: [
              const SizedBox(height: 6),
              _loading
                  ? const SizedBox(
                      height: 430,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _RoutePreview(
                      tracking: TrackingData.fallback(
                        orderId: widget.orderId,
                        stationName: widget.stationName ?? 'Water Station',
                        deliveryLatitude: widget.deliveryLatitude,
                        deliveryLongitude: widget.deliveryLongitude,
                        landmark: widget.landmark,
                        deliveryAddress: widget.deliveryAddress,
                      ),
                      searchQuery: _searchQuery,
                    ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Status',
                      style: TextStyle(
                        color: Color(0xFF17212B),
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusTimeline(
                      status:
                          _currentOrderStatus ??
                          (_loading ? 'Pending' : 'No tracking yet'),
                      estimatedDeliveryAt: null,
                    ),
                    const SizedBox(height: 18),
                    _TrackingSummary(amount: widget.orderTotal),
                  ],
                ),
              ),
            ],
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            children: [
              const SizedBox(height: 6),
              _RoutePreview(tracking: _tracking!, searchQuery: _searchQuery),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Status',
                      style: TextStyle(
                        color: Color(0xFF17212B),
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StatusTimeline(
                      status: _currentOrderStatus ?? _tracking!.status,
                      estimatedDeliveryAt: _tracking!.estimatedDeliveryAt,
                    ),
                    const SizedBox(height: 18),
                    _TrackingSummary(amount: widget.orderTotal),
                  ],
                ),
              ),
            ],
          ),
  );
}

class _RoutePreview extends StatefulWidget {
  final TrackingData tracking;
  final String searchQuery;

  const _RoutePreview({required this.tracking, required this.searchQuery});

  @override
  State<_RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<_RoutePreview> {
  final leaflet.MapController _mapController = leaflet.MapController();
  late Future<List<LatLng>> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _loadDrivingRoute(widget.tracking);
  }

  @override
  void didUpdateWidget(covariant _RoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tracking.stationLocation != oldWidget.tracking.stationLocation ||
        widget.tracking.latestLocation != oldWidget.tracking.latestLocation ||
        widget.tracking.deliveryLocation !=
            oldWidget.tracking.deliveryLocation) {
      _routeFuture = _loadDrivingRoute(widget.tracking);
    }
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery.isNotEmpty) {
      _searchLocation(widget.searchQuery);
    }

    final latestLocation = widget.tracking.latestLocation;
    if (latestLocation != null) {
      _mapController.move(latestLocation, _mapController.camera.zoom);
    }
  }

  Future<void> _searchLocation(String query) async {
    final normalizedQuery = query.toLowerCase();
    StationLocation? station;
    for (final candidate in widget.tracking.stations) {
      if (candidate.name.toLowerCase().contains(normalizedQuery)) {
        station = candidate;
        break;
      }
    }

    LatLng? barangayLocation;
    if (station == null) {
      for (final entry in TrackingData.clarinBarangayCoordinates.entries) {
        final key = entry.key.toLowerCase();
        if (normalizedQuery.contains(key) || key.contains(normalizedQuery)) {
          barangayLocation = entry.value;
          break;
        }
      }
    }

    if (!mounted) return;
    if (station != null) {
      _mapController.move(station.location, 16);
      return;
    }
    if (barangayLocation != null) {
      _mapController.move(barangayLocation, 16);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search only includes water stations and barangays.'),
      ),
    );
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
    final distanceKm = widget.tracking.latestLocation == null
        ? null
        : _distanceInKilometers(
            widget.tracking.latestLocation!,
            widget.tracking.deliveryLocation,
          );

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
          distanceKm: distanceKm,
          routeMessage: snapshot.connectionState == ConnectionState.waiting
              ? 'Finding a road route...'
              : snapshot.hasError
              ? 'Road route unavailable; showing locations only.'
              : null,
        );
      },
    );
  }

  double _distanceInKilometers(LatLng first, LatLng second) {
    const earthRadiusKm = 6371.0;
    final latitudeDelta = (second.latitude - first.latitude) * math.pi / 180;
    final longitudeDelta = (second.longitude - first.longitude) * math.pi / 180;
    final firstLatitude = first.latitude * math.pi / 180;
    final secondLatitude = second.latitude * math.pi / 180;
    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(firstLatitude) *
            math.cos(secondLatitude) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusKm *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  Widget _buildMapShell(
    Widget map, {
    double? distanceKm,
    String? routeMessage,
  }) => Container(
    height: 430,
    decoration: const BoxDecoration(color: Color(0xFFECEFF1)),
    child: Stack(
      children: [
        map,
        Positioned(
          top: 14,
          left: 20,
          child: Text(
            widget.searchQuery.isEmpty ? 'Water stations' : widget.searchQuery,
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
            riderName: widget.tracking.displayRiderName,
            stationName: widget.tracking.stationName,
            landmark:
                widget.tracking.deliveryAddress ??
                widget.tracking.deliveryLandmark ??
                'Clarin, Bohol',
            distanceKm: distanceKm,
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
  final String riderName;
  final String stationName;
  final String landmark;
  final double? distanceKm;

  const _DeliveryInfoPanel({
    required this.riderName,
    required this.stationName,
    required this.landmark,
    required this.distanceKm,
  });

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
            icon: Icons.local_shipping,
            color: const Color(0xFF27AE60),
            label: 'Delivery rider',
            value: riderName,
          ),
          const Divider(height: 12),
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
            label: 'Delivery location',
            value: landmark,
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
    final isComplete =
        normalized.contains('completed') || normalized.contains('delivered');
    final activeStep = isComplete
        ? 4
        : normalized.contains('delivery')
        ? 3
        : normalized.contains('prepar')
        ? 2
        : normalized.contains('accept')
        ? 1
        : 0;
    const steps = [
      ('Pending', Icons.check),
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
            active: index <= activeStep,
            last: index == steps.length - 1,
          ),
      ],
    );
  }

  String _detailForStep(int index, int activeStep, bool isComplete) {
    if (index < activeStep) return 'Completed';
    if (index > activeStep) return 'Pending';
    if (index == 4 && isComplete) return 'Delivered';
    if (index == 4 && estimatedDeliveryAt != null) {
      return 'Delivered ${_formatDateTime(estimatedDeliveryAt!)}';
    }
    if (index == 4) return 'Not scheduled yet';
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

  const _StatusStep({
    required this.title,
    required this.detail,
    required this.icon,
    required this.active,
    required this.last,
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
                    ? const Color(0xFF087F9D)
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
                        ? const Color(0xFF087F9D)
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
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: EdgeInsets.all(13),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: Color(0xFF087F9D)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering to',
                  style: TextStyle(fontSize: 10, color: Color(0xFF71808D)),
                ),
                SizedBox(height: 3),
                Text(
                  'Your delivery address',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17212B),
                  ),
                ),
              ],
            ),
          ),
          if (amount != null)
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
