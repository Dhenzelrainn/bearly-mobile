import 'dart:convert';
import 'package:flutter/services.dart';

class LandingProduct {
  const LandingProduct({required this.id, required this.name, required this.shop, required this.group, required this.cell, required this.atlas, this.source});
  final String id;
  final String name;
  final String shop;
  final String group;
  final int cell;
  final String atlas;
  final String? source;

  factory LandingProduct.fromJson(Map<String, dynamic> json) => LandingProduct(
    id: json['id'] as String,
    name: json['name'] as String,
    shop: json['shop'] as String,
    group: json['group'] as String,
    cell: json['cell'] as int,
    atlas: json['atlas'] as String,
    source: json['source'] as String?,
  );
}

class LandingCategory {
  const LandingCategory({required this.name, required this.slug, required this.icon, required this.subcategories});
  final String name;
  final String slug;
  final String icon;
  final List<String> subcategories;

  factory LandingCategory.fromJson(Map<String, dynamic> json) => LandingCategory(
    name: json['name'] as String,
    slug: json['slug'] as String,
    icon: json['icon'] as String,
    subcategories: List<String>.from(json['subcategories'] as List),
  );
}

class LandingRepository {
  const LandingRepository();

  Future<List<LandingProduct>> loadProducts() async {
    final raw = await rootBundle.loadString('assets/data/landing-products.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => LandingProduct.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<LandingCategory>> loadCategories() async {
    final raw = await rootBundle.loadString('assets/data/categories.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => LandingCategory.fromJson(item as Map<String, dynamic>)).toList();
  }
}
