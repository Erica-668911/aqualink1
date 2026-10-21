import 'package:flutter/material.dart';
import 'app_state.dart';
import 'checkout_screen.dart';

class StationProductsScreen extends StatelessWidget {
  final String stationName;

  const StationProductsScreen({super.key, required this.stationName});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final details = state.detailsForStation(stationName);
    final products = state.productsForStation(stationName);

    return Scaffold(
      appBar: AppBar(
        title: Text(stationName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: state.cart.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CheckoutScreen(stationName: stationName),
                      ),
                    ),
              child: Text('Cart ${state.cartItemCount}'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StationInfoCard(
            icon: Icons.schedule_outlined,
            title: 'Operating hours',
            value: details.operatingHours,
          ),
          _StationInfoCard(
            icon: Icons.local_shipping_outlined,
            title: 'Delivery information',
            value: '${details.deliveryAreas}  •  Fee: P${details.deliveryFee}',
          ),
          _StationInfoCard(
            icon: Icons.phone_outlined,
            title: 'Contact',
            value: '${details.contact}  •  ${details.address}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Products and availability',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...products.map(
            (product) => _ProductTile(
              name: product.name,
              price: product.price,
              available: product.available,
              inCart: state.cart.any(
                (item) => item.productName == product.name,
              ),
              onAdd: product.available
                  && !state.cart.any(
                    (item) => item.productName == product.name,
                  )
                  ? () {
                      state.addToCart(
                        productName: product.name,
                        price: product.price,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} added to cart'),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final String name;
  final int price;
  final bool available;
  final bool inCart;
  final VoidCallback? onAdd;

  const _ProductTile({
    required this.name,
    required this.price,
    required this.available,
    required this.inCart,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        inCart ? Icons.check_circle : Icons.water_drop_outlined,
        color: inCart ? Colors.green : null,
      ),
      title: Text(name),
      subtitle: Text(
        'P$price per container  •  ${available ? 'Available' : 'Unavailable'}',
      ),
      trailing: ElevatedButton(
        onPressed: onAdd,
        child: Text(
          inCart
              ? 'Added to cart'
              : available
              ? 'Add to cart'
              : 'Unavailable',
        ),
      ),
    ),
  );
}

class _StationInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StationInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    ),
  );
}
