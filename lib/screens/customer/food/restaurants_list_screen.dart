import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/firebase_service.dart';
import '../../../theme/app_theme.dart';
import 'restaurant_menu_screen.dart';

class RestaurantsListScreen extends StatefulWidget {
  final AppUser user;
  const RestaurantsListScreen({super.key, required this.user});

  @override
  State<RestaurantsListScreen> createState() => _RestaurantsListScreenState();
}

class _RestaurantsListScreenState extends State<RestaurantsListScreen> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مطاعم المنوفية')),
      body: StreamBuilder<List<Restaurant>>(
        stream: FirebaseService.instance.restaurantsStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final restaurants = snap.data!
              .where((r) => r.name.toLowerCase().contains(search.toLowerCase()) ||
                  r.category.toLowerCase().contains(search.toLowerCase()))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن مطعم أو نوع أكل...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: restaurants.isEmpty
                    ? const Center(
                        child: Text('لا يوجد مطاعم متاحة حاليًا', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: restaurants.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _RestaurantTile(
                          restaurant: restaurants[i],
                          user: widget.user,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final AppUser user;
  const _RestaurantTile({required this.restaurant, required this.user});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: !restaurant.isOpen
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('المطعم مغلق حاليًا، جرب مطعم تاني')))
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RestaurantMenuScreen(restaurant: restaurant, user: user)),
                ),
        child: Opacity(
          opacity: restaurant.isOpen ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.restaurant, color: AppColors.primary, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(restaurant.name,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          ),
                          if (!restaurant.isOpen) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: const Text('مغلق الآن',
                                  style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(restaurant.category,
                          style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                      if (restaurant.promoText != null) ...[
                        const SizedBox(height: 4),
                        Text(restaurant.promoText!,
                            style: const TextStyle(color: Colors.amber, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
