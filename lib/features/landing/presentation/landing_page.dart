import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/bearly_logo.dart';
import '../data/landing_models.dart';
import '../widgets/sprite_atlas_image.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _savedKey = 'bearly-landing-saved-v2';
  static const _groups = <String>[
    'All',
    'Fashion',
    'Tech',
    'Beauty',
    'Home',
    'Books',
    'Accessories',
    'Sports',
    'Pets',
  ];

  final _repository = const LandingRepository();
  final _heroController = PageController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<LandingProduct> _products = const [];
  List<LandingCategory> _categories = const [];
  final Set<String> _saved = <String>{};
  Timer? _heroTimer;
  int _heroIndex = 0;
  String _activeGroup = 'All';
  String _search = '';
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
    _heroTimer = Timer.periodic(const Duration(milliseconds: 6500), (_) {
      if (!_heroController.hasClients) return;
      final next = (_heroIndex + 1) % 3;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repository.loadProducts(),
        _repository.loadCategories(),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_savedKey) ?? const <String>[];
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<LandingProduct>;
        _categories = results[1] as List<LandingCategory>;
        _saved
          ..clear()
          ..addAll(saved.where((id) => _products.any((p) => p.id == id)));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Unable to load the Bearly sample catalogue.';
      });
    }
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<LandingProduct> get _filteredProducts {
    final query = _search.trim().toLowerCase();
    return _products.where((product) {
      final groupMatches = _activeGroup == 'All' || product.group == _activeGroup;
      final searchMatches = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.shop.toLowerCase().contains(query) ||
          product.group.toLowerCase().contains(query);
      return groupMatches && searchMatches;
    }).toList();
  }

  Future<void> _toggleSaved(LandingProduct product) async {
    setState(() {
      if (!_saved.add(product.id)) _saved.remove(product.id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedKey, _saved.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _saved.contains(product.id)
              ? 'Saved on this device.'
              : 'Removed from saved products.',
        ),
      ),
    );
  }

  void _selectGroup(String group) {
    setState(() => _activeGroup = group);
  }


  String _categoryImage(String categoryName) {
    switch (categoryName.toLowerCase().trim()) {
      case 'pet supplies':
        return 'assets/images/landing/categories/01_pet_supplies.png';
      case 'electronics and gadgets':
      case 'electronics':
        return 'assets/images/landing/categories/02_electronics_and_gadgets.png';
      case "women's apparel":
        return 'assets/images/landing/categories/03_womens_apparel.png';
      case "men's apparel":
        return 'assets/images/landing/categories/04_mens_apparel.png';
      case 'kids and baby':
        return 'assets/images/landing/categories/05_kids_and_baby.png';
      case 'home and garden':
        return 'assets/images/landing/categories/06_home_and_garden.png';
      case 'sports and outdoors':
        return 'assets/images/landing/categories/07_sports_and_outdoors.png';
      case 'health and beauty':
        return 'assets/images/landing/categories/08_health_and_beauty.png';
      case 'books and media':
        return 'assets/images/landing/categories/09_books_and_media.png';
      case 'food and gourmet':
        return 'assets/images/landing/categories/10_food_and_gourmet.png';
      case 'furniture and office equipment':
        return 'assets/images/landing/categories/11_furniture_and_office_equipment.png';
      case 'jewelry and watches':
        return 'assets/images/landing/categories/12_jewelry_and_watches.png';
      default:
        return 'assets/images/catalog-placeholders.png';
    }
  }


  Future<void> _showNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: BearlyColors.cream50,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: BearlyColors.cream200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: BearlyColors.brown700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No notifications yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Updates about your Bearly activity will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBottomNavigation(int index) {
    switch (index) {
      case 0:
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
        break;
      case 1:
        _showCategories();
        break;
      case 2:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Cart will be available when the Buyer module is connected.',
              ),
            ),
          );
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.login);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _mobileHeader()),
            SliverToBoxAdapter(child: _searchBar()),
            SliverToBoxAdapter(child: _hero()),
            const SliverToBoxAdapter(child: _BrandStrip()),
            SliverToBoxAdapter(child: _categoriesSection()),
            SliverToBoxAdapter(child: _campaignSection()),
            SliverToBoxAdapter(child: _featuredHeading()),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 72),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_loadError != null)
              SliverToBoxAdapter(child: _errorState())
            else
              _productGrid(),
            SliverToBoxAdapter(child: _storySection()),
            SliverToBoxAdapter(child: _supportSection()),
            SliverToBoxAdapter(child: _signupSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: _landingBottomNavigation(),
    );
  }

  Widget _mobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 8),
      child: Row(
        children: [
          const BearlyLogo(width: 126),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _showNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _landingBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: BearlyColors.lineSoft),
        ),
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: _handleBottomNavigation,
        backgroundColor: Colors.white,
        indicatorColor: BearlyColors.cream300,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _search = value),
        decoration: InputDecoration(
          hintText: 'Search products and stores',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          fillColor: BearlyColors.cream200.withValues(alpha: .65),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    const slides = [
      _HeroData(
        image: 'assets/images/landing/hero.webp',
        eyebrow: 'BEARLY',
        title: 'Shopping made\nBearly a hassle.',
        description: 'Discover unique finds from big stores and independent sellers, all in one place.',
        button: 'Shop now',
        group: 'All',
      ),
      _HeroData(
        image: 'assets/images/landing/tech.webp',
        eyebrow: 'YOUR DAILY SETUP',
        title: 'Find more.\nLive better.',
        description: 'A little upgrade for work, play, and everything in between.',
        button: 'Explore tech',
        group: 'Tech',
      ),
      _HeroData(
        image: 'assets/images/landing/fashion.webp',
        eyebrow: 'EVERYDAY STYLE',
        title: 'Shopping should\nbe easy.',
        description: 'Bearly stressful. Find something that feels like you.',
        button: 'Explore fashion',
        group: 'Fashion',
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            controller: _heroController,
            itemCount: slides.length,
            onPageChanged: (index) => setState(() => _heroIndex = index),
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        slide.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: BearlyColors.cream300,
                          child: Center(child: Icon(Icons.image_outlined, size: 48)),
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB82C1A14)],
                            stops: [.25, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 22,
                        right: 22,
                        bottom: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide.eyebrow,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 1.7,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slide.title,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 38,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              slide.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: .9),
                                  ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: BearlyColors.cream50,
                                foregroundColor: BearlyColors.brown950,
                              ),
                              onPressed: () => _selectGroup(slide.group),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.north_east_rounded, size: 18),
                              label: Text(slide.button),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: index == _heroIndex ? 24 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: index == _heroIndex ? BearlyColors.gold : BearlyColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _categoriesSection() {
    final quick = _categories.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 30, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Shop by Categories',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton(
                  onPressed: _showCategories,
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 154,
            child: quick.isEmpty && _loading
                ? const Center(child: LinearProgressIndicator())
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 18),
                    itemCount: quick.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final category = quick[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          final group = _groupForCategory(category.name);
                          _selectGroup(group);
                        },
                        child: Container(
                          width: 132,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: BearlyColors.lineSoft),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ColoredBox(
                                    color: Colors.white,
                                    child: Image.asset(
                                      _categoryImage(category.name),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Icon(
                                          _iconForCategory(category.name),
                                          color: BearlyColors.brown700,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _shortCategory(category.name),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _campaignSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
      child: Column(
        children: [
          _CampaignCard(
            image: 'assets/images/landing/tech.webp',
            eyebrow: 'TECH ESSENTIALS',
            title: 'For your everyday',
            subtitle: 'Your next daily upgrade.',
            onTap: () => _selectGroup('Tech'),
          ),
          const SizedBox(height: 14),
          _CampaignCard(
            image: 'assets/images/landing/fashion.webp',
            eyebrow: 'FRESH LOOKS',
            title: 'A fresh little upgrade',
            subtitle: 'Everyday style, your way.',
            onTap: () => _selectGroup('Fashion'),
          ),
        ],
      ),
    );
  }

  Widget _featuredHeading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Featured Products', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('A little of everything, all in one place.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _groups.map((group) {
                final active = _activeGroup == group;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: active,
                    label: Text(group),
                    onSelected: (_) => _selectGroup(group),
                    showCheckmark: false,
                    selectedColor: BearlyColors.brown900,
                    labelStyle: TextStyle(
                      color: active ? Colors.white : BearlyColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    side: const BorderSide(color: BearlyColors.lineSoft),
                    backgroundColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sample catalogue · Illustrative photos · Prices to be confirmed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  SliverPadding _productGrid() {
    final products = _filteredProducts;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 36),
      sliver: products.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 44),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 42, color: BearlyColors.muted),
                    const SizedBox(height: 12),
                    Text('No matching products found.', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            )
          : SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  return _ProductCard(
                    product: product,
                    saved: _saved.contains(product.id),
                    onSave: () => _toggleSaved(product),
                    onOpen: () => _showProduct(product),
                  );
                },
                childCount: products.length,
              ),
            ),
    );
  }

  Widget _storySection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: BearlyColors.cream200,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('ABOUT BEARLY'),
          const SizedBox(height: 8),
          Text('Shopping should feel more human.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Bearly brings independent stores and thoughtful shoppers together in one easy-to-use marketplace.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _supportSection() {
    const items = [
      (Icons.inventory_2_outlined, 'Shopping & Orders'),
      (Icons.storefront_outlined, 'Seller Support'),
      (Icons.person_outline_rounded, 'Account & Registration'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow('CONTACT BEARLY'),
          const SizedBox(height: 8),
          Text('We’re here to help.', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BearlyColors.lineSoft),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(item.$1, color: BearlyColors.brown700),
                title: Text(item.$2, style: Theme.of(context).textTheme.titleMedium),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signupSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BearlyColors.brown900,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: BearlyColors.cream200, size: 34),
          const SizedBox(height: 14),
          Text(
            'Make shopping Bearly a hassle.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an account and start discovering.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: BearlyColors.cream50,
              foregroundColor: BearlyColors.brown950,
            ),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Create an account'),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 32, 18, 52),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 44, color: BearlyColors.error),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  Future<void> _showSaved() async {
    final savedProducts = _products.where((product) => _saved.contains(product.id)).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BearlyColors.cream50,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved products', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              if (savedProducts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Center(child: Text('No saved products yet. Tap a heart to keep one here.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: savedProducts.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final product = savedProducts[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name),
                        subtitle: Text(product.shop),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          onPressed: () async {
                            await _toggleSaved(product);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.favorite_rounded, color: BearlyColors.brown700),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _showProduct(product);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showProduct(LandingProduct product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BearlyColors.cream50,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: SpriteAtlasImage(
                  assetPath: product.atlas == 'mixed'
                      ? 'assets/images/landing/mixed-products.webp'
                      : 'assets/images/catalog-placeholders.png',
                  cell: product.cell,
                  rows: product.atlas == 'mixed' ? 3 : 4,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 18),
              Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('${product.shop} · ${product.group}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                'Sample catalogue preview. Price, stock, and final specifications have not been confirmed yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _toggleSaved(product),
                  icon: Icon(_saved.contains(product.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                  label: Text(_saved.contains(product.id) ? 'Remove from saved' : 'Save this product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategories() async {
  var query = '';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BearlyColors.cream50,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        final matches = _categories.where((category) {
          final q = query.trim().toLowerCase();

          return q.isEmpty ||
              category.name.toLowerCase().contains(q) ||
              category.subcategories.any(
                (item) => item.toLowerCase().contains(q),
              );
        }).toList();

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .84,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Eyebrow('BEARLY MARKETPLACE'),
                      const SizedBox(height: 6),

                      Text(
                        'Shop by category',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        autofocus: true,
                        onChanged: (value) {
                          setSheetState(() {
                            query = value;
                          });
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search categories and subcategories',
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: matches.isEmpty
                      ? const Center(
                          child: Text('No matching categories.'),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          itemCount: matches.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 24),
                          itemBuilder: (_, index) {
                            final category = matches[index];

                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding:
                                  const EdgeInsets.only(bottom: 8),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 46,
                                  height: 46,
                                  child: ColoredBox(
                                    color: Colors.white,
                                    child: Image.asset(
                                      _categoryImage(category.name),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        _iconForCategory(category.name),
                                        color: BearlyColors.brown700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                category.name,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              children: category.subcategories
                                  .map(
                                    (sub) => ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.only(left: 48),
                                      title: Text(sub),
                                      onTap: () {
                                        Navigator.pop(sheetContext);

                                        setState(() {
                                          _searchController.text = sub;
                                          _search = sub;
                                          _activeGroup = 'All';
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                              onExpansionChanged: (open) {
                                if (open) {
                                  _selectGroup(
                                    _groupForCategory(category.name),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  static String _groupForCategory(String category) {
    if (category.contains('Electronics')) return 'Tech';
    if (category.contains('Apparel') || category.contains('Kids')) return 'Fashion';
    if (category.contains('Beauty')) return 'Beauty';
    if (category.contains('Home') || category.contains('Furniture') || category.contains('Food')) return 'Home';
    if (category.contains('Books')) return 'Books';
    if (category.contains('Jewelry')) return 'Accessories';
    if (category.contains('Sports')) return 'Sports';
    if (category.contains('Pet')) return 'Pets';
    return 'All';
  }

  static String _shortCategory(String value) {
    return value
        .replaceAll(' and Gadgets', '')
        .replaceAll(' and Garden', '')
        .replaceAll(' and Beauty', '')
        .replaceAll(' and Media', '')
        .replaceAll(' and Watches', '');
  }

  static IconData _iconForCategory(String name) {
    if (name.contains('Pet')) return Icons.pets_outlined;
    if (name.contains('Electronics')) return Icons.devices_outlined;
    if (name.contains('Apparel')) return Icons.checkroom_outlined;
    if (name.contains('Kids')) return Icons.child_care_outlined;
    if (name.contains('Home')) return Icons.home_outlined;
    if (name.contains('Sports')) return Icons.sports_basketball_outlined;
    if (name.contains('Beauty')) return Icons.spa_outlined;
    if (name.contains('Books')) return Icons.menu_book_outlined;
    if (name.contains('Food')) return Icons.local_grocery_store_outlined;
    if (name.contains('Furniture')) return Icons.chair_outlined;
    if (name.contains('Jewelry')) return Icons.watch_outlined;
    return Icons.category_outlined;
  }
}

class _HeroData {
  const _HeroData({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.button,
    required this.group,
  });

  final String image;
  final String eyebrow;
  final String title;
  final String description;
  final String button;
  final String group;
}

class _BrandStrip extends StatelessWidget {
  const _BrandStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      color: BearlyColors.brown950,
      child: Text(
        'Find more. Live better.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, letterSpacing: .4),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String image;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: BearlyColors.cream300),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB32C1A14)],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Text('Shop collection ↗', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final LandingProduct product;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: BearlyColors.lineSoft),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SpriteAtlasImage(
                      assetPath: product.atlas == 'mixed'
                          ? 'assets/images/landing/mixed-products.webp'
                          : 'assets/images/catalog-placeholders.png',
                      cell: product.cell,
                      rows: product.atlas == 'mixed' ? 3 : 4,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: saved ? 'Remove from saved' : 'Save product',
                        onPressed: onSave,
                        icon: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.shop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: BearlyColors.gold,
            letterSpacing: 1.35,
          ),
    );
  }
}
