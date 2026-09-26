import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';
import 'food_checkout_screen.dart';

class RestaurantMenuScreen extends StatefulWidget {
  final Restaurant restaurant;
  final AppUser user;
  const RestaurantMenuScreen({super.key, required this.restaurant, required this.user});

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final Map<String, int> quantities = {};

  double get total {
    double sum = 0;
    for (final item in widget.restaurant.menu) {
      final qty = quantities[item.id] ?? 0;
      sum += item.price * qty;
    }
    return sum;
  }

  int get itemCount => quantities.values.fold(0, (a, b) => a + b);

  void _add(String id) => setState(() => quantities[id] = (quantities[id] ?? 0) + 1);
  void _remove(String id) => setState(() {
        final current = quantities[id] ?? 0;
        if (current <= 1) {
          quantities.remove(id);
        } else {
          quantities[id] = current - 1;
        }
      });

  void _goToCheckout() {
    final cart = widget.restaurant.menu
        .where((item) => (quantities[item.id] ?? 0) > 0)
        .map((item) => CartItem(
              id: item.id,
              name: item.name,
              price: item.price,
              quantity: quantities[item.id]!,
            ))
        .toList();
    if (cart.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodCheckoutScreen(
          restaurant: widget.restaurant,
          cart: cart,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.restaurant.name)),
      body: widget.restaurant.menu.isEmpty
          ? const Center(child: Text('المنيو لسه فاضي', style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.restaurant.menu.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = widget.restaurant.menu[i];
                final qty = quantities[item.id] ?? 0;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration:
                      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text('${item.price.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                    color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (qty == 0)
                        ElevatedButton(
                          onPressed: () => _add(item.id),
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
                          child: const Text('إضافة'),
                        )
                      else
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => _remove(item.id),
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('$qty',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            IconButton.filled(
                              onPressed: () => _add(item.id),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: itemCount == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _goToCheckout,
                  child: Text('متابعة الطلب ($itemCount) — ${total.toStringAsFixed(0)} ج.م'),
                ),
              ),
            ),
    );
  }
}
