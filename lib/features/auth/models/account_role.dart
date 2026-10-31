import 'package:flutter/material.dart';

enum AccountRole { buyer, rider, logistics }

extension AccountRoleX on AccountRole {
  String get apiValue => switch (this) {
    AccountRole.buyer => 'buyer',
    AccountRole.rider => 'rider',
    AccountRole.logistics => 'logistics',
  };

  String get label => switch (this) {
    AccountRole.buyer => 'Buyer',
    AccountRole.rider => 'Rider',
    AccountRole.logistics => 'Logistics',
  };

  String get subtitle => switch (this) {
    AccountRole.buyer => 'Shop products from trusted sellers',
    AccountRole.rider => 'Pick up parcels and complete deliveries',
    AccountRole.logistics => 'Manage parcels and logistics operations',
  };

  IconData get icon => switch (this) {
    AccountRole.buyer => Icons.shopping_bag_outlined,
    AccountRole.rider => Icons.delivery_dining_outlined,
    AccountRole.logistics => Icons.warehouse_outlined,
  };

  String get reviewAuthority => switch (this) {
    AccountRole.buyer => 'Bearly Administrator',
    AccountRole.rider => 'Selected Logistics / Sorting Center',
    AccountRole.logistics => 'Bearly Administrator',
  };
}
