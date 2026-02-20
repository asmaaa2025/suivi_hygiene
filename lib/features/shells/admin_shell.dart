import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Admin shell - Same as normal shell but with additional admin menu
/// Contains bottom navigation with: Home, Pointage, Temperatures, Réceptions, Nettoyage, Historique
/// Plus a dropdown menu with: RH, Historique Pointage
class AdminShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AdminShell({super.key, required this.child, required this.location});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final location = widget.location;
    // Normal shell routes
    if (location.startsWith('/app/home') ||
        location == '/app' ||
        location.startsWith('/admin/home') ||
        location == '/admin') {
      _currentIndex = 0;
    } else if (location.startsWith('/app/clock') ||
        location.startsWith('/admin/clock')) {
      _currentIndex = 1;
    } else if (location.startsWith('/app/temperatures') ||
        location.startsWith('/admin/temperatures')) {
      _currentIndex = 2;
    } else if (location.startsWith('/app/receptions') ||
        location.startsWith('/admin/receptions')) {
      _currentIndex = 3;
    } else if (location.startsWith('/app/cleaning') ||
        location.startsWith('/admin/cleaning')) {
      _currentIndex = 4;
    } else if (location.startsWith('/app/history') ||
        location.startsWith('/admin/history')) {
      _currentIndex = 5;
    }
    // Admin-specific routes (not in bottom nav, accessed via menu)
    // RH and Clock History are in the dropdown menu
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/admin/home');
        break;
      case 1:
        context.go('/admin/clock');
        break;
      case 2:
        context.go('/admin/temperatures');
        break;
      case 3:
        context.go('/admin/receptions');
        break;
      case 4:
        context.go('/admin/cleaning');
        break;
      case 5:
        context.go('/admin/history');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          // Normal shell items
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Pointage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat),
            label: 'Températures',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Réceptions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cleaning_services),
            label: 'Nettoyage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
