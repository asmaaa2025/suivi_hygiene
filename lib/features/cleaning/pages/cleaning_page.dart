import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/utils/navigation_helpers.dart';
import 'cleaning_todo_page.dart';
import 'cleaning_history_page.dart';
import 'taches_management_page.dart';

/// Main cleaning page with tabs for Todo and History
class CleaningPage extends StatefulWidget {
  const CleaningPage({super.key});

  @override
  State<CleaningPage> createState() => _CleaningPageState();
}

class _CleaningPageState extends State<CleaningPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdminRoute = GoRouterState.of(
      context,
    ).matchedLocation.startsWith('/admin');
    final routePrefix = isAdminRoute ? '/admin' : '/app';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nettoyage'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => NavigationHelpers.goHaccpHub(context),
          tooltip: 'Retour',
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Aujourd\'hui'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
            Tab(icon: Icon(Icons.settings), text: 'Tâches'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('$routePrefix/cleaning/taches/new'),
            tooltip: 'Créer une tâche',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CleaningTodoPage(),
          const CleaningHistoryPage(),
          const TachesManagementPage(),
        ],
      ),
    );
  }
}
