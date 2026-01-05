import 'package:flutter/material.dart';
import 'produits_page.dart';

/// Products list page - displays the main products management page
class ProductsListPage extends StatelessWidget {
  const ProductsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use ProduitsPage from features/products/pages
    return const ProduitsPage();
  }
}
