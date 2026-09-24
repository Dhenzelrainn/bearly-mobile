import 'package:flutter/material.dart';

enum AccountRole { buyer, seller, rider, logistics }

extension AccountRoleX on AccountRole {
  String get label => switch (this) {
    AccountRole.buyer => 'Buyer',
    AccountRole.seller => 'Seller',
    AccountRole.rider => 'Rider',
    AccountRole.logistics => 'Logistics',
  };

  String get subtitle => switch (this) {
    AccountRole.buyer => 'Shop products from trusted sellers',
    AccountRole.seller => 'Manage products, orders, and your store',
    AccountRole.rider => 'Pick up parcels and complete deliveries',
    AccountRole.logistics => 'Sort parcels and manage rider operations',
  };

  IconData get icon => switch (this) {
    AccountRole.buyer => Icons.shopping_bag_outlined,
    AccountRole.seller => Icons.storefront_outlined,
    AccountRole.rider => Icons.delivery_dining_outlined,
    AccountRole.logistics => Icons.warehouse_outlined,
  };

  String get detailStepTitle => switch (this) {
    AccountRole.buyer => 'Buyer details',
    AccountRole.seller => 'Business details',
    AccountRole.rider => 'Vehicle details',
    AccountRole.logistics => 'Logistics details',
  };

  bool get requiresRoleDetails => this != AccountRole.buyer;
}
