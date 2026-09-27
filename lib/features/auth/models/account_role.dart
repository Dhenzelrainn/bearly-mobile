import 'package:flutter/material.dart';

enum AccountRole { buyer, rider }

extension AccountRoleX on AccountRole {
  String get label => switch (this) {
        AccountRole.buyer => 'Buyer',
        AccountRole.rider => 'Rider',
      };

  String get subtitle => switch (this) {
        AccountRole.buyer => 'Shop products from trusted sellers',
        AccountRole.rider => 'Pick up parcels and complete deliveries',
      };

  IconData get icon => switch (this) {
        AccountRole.buyer => Icons.shopping_bag_outlined,
        AccountRole.rider => Icons.delivery_dining_outlined,
      };

  String get reviewAuthority => switch (this) {
        AccountRole.buyer => 'Bearly Administrator',
        AccountRole.rider => 'Selected Logistics / Sorting Center',
      };
}
