import 'package:flutter/material.dart';
import '../../../../screens/produits_page.dart';

/// Products list page - redirects to existing ProduitsPage
class ProductsListPage extends StatelessWidget {
  const ProductsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the existing ProduitsPage from screens
    return const ProduitsPage();
  }
}
