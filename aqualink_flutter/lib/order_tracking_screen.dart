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
        return 1;
      case 'Preparing':
        return 2;
      case 'Out for Delivery':
        return 3;
      case 'Delivered':
      case 'Completed':
        return 4;
      default:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = fulfillmentMethod == FulfillmentMethod.delivery;
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text('Order status'),
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
          const SizedBox(height: 18),
          const Text(
            'Status timeline',
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
              detail: 'This order will not continue',
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
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.brand600,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDelivery ? 'Delivering to' : 'Pickup from',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDelivery
                            ? (deliveryAddress ?? 'Your delivery address')
                            : station,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _statusRows => [
    _StatusRow(
      icon: Icons.receipt_long_outlined,
      title: 'Order received',
      detail: activeStep == 0
          ? 'Current status'
          : activeStep > 0
          ? 'Complete'
          : 'Waiting for an update',
      active: activeStep >= 0,
    ),
    _StatusRow(
      icon: Icons.check,
      title: 'Accepted',
      detail: activeStep == 1
          ? 'Current status'
          : activeStep > 1
          ? 'Complete'
          : 'Not started',
      active: activeStep >= 1,
    ),
    _StatusRow(
      icon: Icons.inventory_2_outlined,
      title: 'Preparing',
      detail: activeStep == 2
          ? 'Current status'
          : activeStep > 2
          ? 'Complete'
          : 'Not started',
      active: activeStep >= 2,
    ),
    _StatusRow(
      icon: Icons.two_wheeler_outlined,
      title: 'Out for Delivery',
      detail: activeStep == 3
          ? 'Current status'
          : activeStep > 3
          ? 'Complete'
          : 'Not started',
      active: activeStep >= 3,
    ),
    _StatusRow(
      icon: Icons.home_outlined,
      title: 'Delivered',
      detail: activeStep == 4 ? 'Complete' : 'Not started',
      active: activeStep >= 4,
      last: true,
    ),
  ];
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final bool active;
  final bool last;
  final Color? color;

  const _StatusRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.active,
    this.last = false,
    this.color,
  });

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
              CircleAvatar(
                radius: 13,
                backgroundColor: active
                    ? (color ?? AppColors.brand600)
                    : AppColors.slate100,
                child: Icon(
                  icon,
                  size: 14,
                  color: active ? Colors.white : AppColors.slate400,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: active ? AppColors.brand600 : AppColors.slate200,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.slate800 : AppColors.slate400,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? AppColors.slate500 : AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
