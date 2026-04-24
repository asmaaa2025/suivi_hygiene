import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/navigation_helpers.dart';
import 'etiquette_page.dart';
import 'label_history_page.dart';

/// Page Étiquettes avec sous-onglets Impression et Historique.
class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tabParam = GoRouterState.of(context).uri.queryParameters['tab'];
    final initialIndex = tabParam == 'history' ? 1 : 0;

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationHelpers.goHaccpHub(context),
          ),
          title: const Text('Étiquettes'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.print), text: 'Impression'),
              Tab(icon: Icon(Icons.history), text: 'Historique'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EtiquettePage(showAppBar: false),
            LabelHistoryPage(showAppBar: false),
          ],
        ),
      ),
    );
  }
}
