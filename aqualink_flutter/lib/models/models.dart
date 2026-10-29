import 'package:flutter/material.dart';

class Station {
  final String name;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool isOpen;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final String priceLabel;
  final String operatingHours;
  final String deliveryInformation;
  final List<StationProduct> products;

  const Station({
    required this.name,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.isOpen,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.priceLabel,
    this.operatingHours = '7:00 AM - 7:00 PM',
    this.deliveryInformation = 'Delivery available within 5 km',
    this.products = const [],
  });
}

class StationProduct {
  final String name;
  final int price;
  final bool available;

  const StationProduct({
    required this.name,
    required this.price,
    required this.available,
  });

  StationProduct copyWith({String? name, int? price, bool? available}) =>
      StationProduct(
        name: name ?? this.name,
        price: price ?? this.price,
        available: available ?? this.available,
      );
}

class StationDetails {
  final String name;
  final String address;
  final String contact;
  final String operatingHours;
  final String deliveryAreas;
  final int deliveryFee;

  const StationDetails({
    required this.name,
    required this.address,
    required this.contact,
    required this.operatingHours,
    required this.deliveryAreas,
    required this.deliveryFee,
  });

  StationDetails copyWith({
    String? name,
    String? address,
    String? contact,
    String? operatingHours,
    String? deliveryAreas,
    int? deliveryFee,
  }) => StationDetails(
    name: name ?? this.name,
    address: address ?? this.address,
    contact: contact ?? this.contact,
    operatingHours: operatingHours ?? this.operatingHours,
    deliveryAreas: deliveryAreas ?? this.deliveryAreas,
    deliveryFee: deliveryFee ?? this.deliveryFee,
  );
}

enum FulfillmentMethod { delivery, pickup }

enum OrderStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  delivered,
  completed,
}

enum OrderItemStatus { pending, accepted, rejected }

class WaterOrder {
  final String number;
  final String station;
  final String customer;
  final List<CartItem> items;
  final int total;
  final int deliveryFee;
  final FulfillmentMethod fulfillmentMethod;
  final String? deliveryAddress;
  final String? barangay;
  final String? landmark;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final OrderStatus status;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const WaterOrder({
    required this.number,
    required this.station,
    required this.customer,
    required this.items,
    required this.total,
    this.deliveryFee = 0,
    required this.fulfillmentMethod,
    required this.status,
    this.deliveryAddress,
    this.barangay,
    this.landmark,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.reason,
    this.createdAt,
    this.completedAt,
  });

  bool get hasPendingItems =>
      items.any((item) => item.decisionStatus == OrderItemStatus.pending);
  bool get hasAcceptedItems =>
      items.any((item) => item.decisionStatus == OrderItemStatus.accepted);
  bool get hasRejectedItems =>
      items.any((item) => item.decisionStatus == OrderItemStatus.rejected);
  bool get isPartiallyAccepted =>
      status == OrderStatus.accepted && hasAcceptedItems && hasRejectedItems;

  WaterOrder copyWith({
    OrderStatus? status,
    List<CartItem>? items,
    int? total,
    String? reason,
    DateTime? completedAt,
  }) => WaterOrder(
    number: number,
    station: station,
    customer: customer,
    items: items ?? this.items,
    total: total ?? this.total,
    deliveryFee: deliveryFee,
    fulfillmentMethod: fulfillmentMethod,
    deliveryAddress: deliveryAddress,
    barangay: barangay,
    landmark: landmark,
    deliveryLatitude: deliveryLatitude,
    deliveryLongitude: deliveryLongitude,
    status: status ?? this.status,
    reason: reason ?? this.reason,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
  );
}

class CartItem {
  final String productName;
  final int price;
  final int quantity;
  final OrderItemStatus decisionStatus;
  final String? decisionReason;

  const CartItem({
    required this.productName,
    required this.price,
    required this.quantity,
    this.decisionStatus = OrderItemStatus.pending,
    this.decisionReason,
  });

  CartItem copyWith({
    int? quantity,
    OrderItemStatus? decisionStatus,
    String? decisionReason,
  }) => CartItem(
    productName: productName,
    price: price,
    quantity: quantity ?? this.quantity,
    decisionStatus: decisionStatus ?? this.decisionStatus,
    decisionReason: decisionReason ?? this.decisionReason,
  );
}

const demoStations = <Station>[
  Station(
    name: 'Remoreras Water Refilling',
    icon: Icons.water_drop,
    iconBg: Color(0xFFE6F7FB),
    iconColor: Color(0xFF087F9D),
    isOpen: true,
    rating: 4.8,
    reviewCount: 124,
    distanceKm: 0.8,
    priceLabel: 'From P15 per container',
    operatingHours: '7:00 AM - 7:00 PM',
    deliveryInformation: 'Delivery available within 5 km',
    products: [
      StationProduct(
        name: 'Mineral Water (2.5 Gal)',
        price: 15,
        available: true,
      ),
      StationProduct(name: 'Mineral Water (5 Gal)', price: 25, available: true),
    ],
  ),
  Station(
    name: 'J&P Water Station',
    icon: Icons.local_drink,
    iconBg: Color(0xFFEEF2FF),
    iconColor: Color(0xFF4F46E5),
    isOpen: true,
    rating: 4.6,
    reviewCount: 89,
    distanceKm: 1.4,
    priceLabel: 'From P20 per container',
    operatingHours: '8:00 AM - 6:00 PM',
    deliveryInformation: 'Pickup available; delivery within 3 km',
    products: [
      StationProduct(name: 'Mineral Water (3 Gal)', price: 20, available: true),
      StationProduct(name: 'Mineral Water (5 Gal)', price: 25, available: true),
    ],
  ),
  Station(
    name: 'CJoan Water Station',
    icon: Icons.water_drop,
    iconBg: Color(0xFFE6F7FB),
    iconColor: Color(0xFF087F9D),
    isOpen: true,
    rating: 0,
    reviewCount: 0,
    distanceKm: 0,
    priceLabel: 'From P25 per container',
    operatingHours: '7:00 AM - 7:00 PM',
    deliveryInformation: 'Delivery available in Candajec and nearby barangays',
    products: [
      StationProduct(
        name: 'Purified Water (5 Gal)',
        price: 25,
        available: true,
      ),
      StationProduct(name: 'Mineral Water (5 Gal)', price: 25, available: true),
    ],
  ),
];
