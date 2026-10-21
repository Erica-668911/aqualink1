import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models/models.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderNumber;
  final String station;
  final String status;
  final String amount;
  final String? deliveryAddress;
  final FulfillmentMethod fulfillmentMethod;

  const OrderTrackingScreen({
    super.key,
    required this.orderNumber,
    required this.station,
    required this.status,
    required this.amount,
    required this.fulfillmentMethod,
    this.deliveryAddress,
  });

  bool get isCancelled => status == 'Cancelled' || status == 'Rejected';

  int get activeStep {
    if (isCancelled) return -1;
    switch (status) {
      case 'Pending':
        return 0;
      case 'Accepted':
        return 2;
      case 'Delivered':
      case 'Completed':
        return 4;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = fulfillmentMethod == FulfillmentMethod.delivery;
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Track order'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          Text(
            'Order #$orderNumber',
            style: const TextStyle(
              color: AppColors.brand600,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDelivery ? 'Expected delivery: Today, 2:00 PM - 4:00 PM' : 'Ready for pickup today',
            style: const TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _DriverBanner(
            title: isDelivery ? 'Driver is nearby' : 'Your order is being prepared',
            detail: isDelivery ? 'John is 15 mins away (2.2 miles)' : station,
          ),
          const SizedBox(height: 10),
          _RouteMap(isDelivery: isDelivery, station: station),
          const SizedBox(height: 22),
          const Text(
            'Delivery Status',
            style: TextStyle(
              color: AppColors.slate800,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (isCancelled)
            _StatusRow(
              icon: Icons.close,
              title: status,
              detail: 'This order is no longer active',
              active: true,
              color: Colors.red,
            )
          else
            ..._statusRows,
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.slate200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AppColors.brand600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isDelivery ? 'Delivering to' : 'Pickup from', style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
                      const SizedBox(height: 3),
                      Text(
                        isDelivery ? (deliveryAddress ?? 'Your delivery address') : station,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.slate800),
                      ),
                    ],
                  ),
                ),
                Text(amount, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.slate800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _statusRows => [
        _StatusRow(icon: Icons.check, title: 'Pending', detail: '9:00 AM', active: activeStep >= 0),
        _StatusRow(icon: Icons.check, title: 'Accepted', detail: '9:15 AM', active: activeStep >= 1),
        _StatusRow(icon: Icons.inventory_2_outlined, title: 'Preparing', detail: '10:30 AM', active: activeStep >= 2),
        _StatusRow(icon: Icons.two_wheeler_outlined, title: 'Out for Delivery', detail: 'On the way', active: activeStep >= 3),
        _StatusRow(icon: Icons.home_outlined, title: 'Delivered', detail: 'Estimated 2:00 PM - 4:00 PM', active: activeStep >= 4, last: true),
      ];
}

class _DriverBanner extends StatelessWidget {
  final String title;
  final String detail;

  const _DriverBanner({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: AppColors.brand600, child: Icon(Icons.local_shipping_outlined, color: Colors.white, size: 19)),
            const SizedBox(width: 11),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate800)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
            ]),
          ],
        ),
      );
}

class _RouteMap extends StatelessWidget {
  final bool isDelivery;
  final String station;

  const _RouteMap({required this.isDelivery, required this.station});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _MapPainter())),
              const Positioned(
                top: 10,
                left: 12,
                child: Text(
                  'Clarin, Bohol',
                  style: TextStyle(
                    color: AppColors.slate600,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(top: 42, left: 20, child: _MapPin(label: station, color: AppColors.brand600)),
              Positioned(bottom: 22, right: 22, child: _MapPin(label: isDelivery ? 'You' : 'Pickup', color: Colors.orange)),
              if (isDelivery) const Positioned(top: 90, left: 125, child: Icon(Icons.local_shipping, color: AppColors.brand600, size: 25)),
            ],
          ),
        ),
      );
}

class _MapPin extends StatelessWidget {
  final String label;
  final Color color;

  const _MapPin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
          ),
          Icon(Icons.location_on, color: color, size: 25),
        ],
      );
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFEAF2F3), BlendMode.src);
    final minor = Paint()..color = const Color(0xFFD8E4E5)..strokeWidth = 2;
    final major = Paint()..color = Colors.white..strokeWidth = 7;
    for (var x = -size.height; x < size.width + size.height; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), minor);
    }
    for (var y = 15.0; y < size.height; y += 39) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 25), major);
    }
    final route = Paint()..color = AppColors.brand600..strokeWidth = 4..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * .16, size.height * .76)
      ..lineTo(size.width * .42, size.height * .76)
      ..lineTo(size.width * .45, size.height * .43)
      ..lineTo(size.width * .66, size.height * .43)
      ..lineTo(size.width * .84, size.height * .2);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool active;
  final bool last;
  final Color? color;

  const _StatusRow({required this.icon, required this.title, required this.detail, required this.active, this.last = false, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 57,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  CircleAvatar(radius: 13, backgroundColor: active ? (color ?? AppColors.brand600) : AppColors.slate100, child: Icon(icon, size: 14, color: active ? Colors.white : AppColors.slate400)),
                  if (!last) Expanded(child: Container(width: 2, color: active ? AppColors.brand600 : AppColors.slate200)),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? AppColors.slate800 : AppColors.slate400)),
                const SizedBox(height: 3),
                Text(detail, style: TextStyle(fontSize: 10, color: active ? AppColors.slate500 : AppColors.slate400)),
              ]),
            ),
          ],
        ),
      );
}