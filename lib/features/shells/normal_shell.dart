import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Normal shell for employees and managers
/// Contains bottom navigation with: Home, Pointage, Temperatures, Réceptions, Nettoyage, Historique
class NormalShell extends StatefulWidget {
  final Widget child;
  final String location;

  const NormalShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  State<NormalShell> createState() => _NormalShellState();
}

class _NormalShellState extends State<NormalShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSelectedIndex();
  }

  void _updateSelectedIndex() {
    final location = widget.location;
    if (location.startsWith('/app/home') || location == '/app') {
      _currentIndex = 0;
    } else if (location.startsWith('/app/clock')) {
      _currentIndex = 1;
    } else if (location.startsWith('/app/temperatures')) {
      _currentIndex = 2;
    } else if (location.startsWith('/app/receptions')) {
      _currentIndex = 3;
    } else if (location.startsWith('/app/cleaning')) {
      _currentIndex = 4;
    } else if (location.startsWith('/app/history')) {
      _currentIndex = 5;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        context.go('/app/home');
        break;
      case 1:
        context.go('/app/clock');
        break;
      case 2:
        context.go('/app/temperatures');
        break;
      case 3:
        context.go('/app/receptions');
        break;
      case 4:
        context.go('/app/cleaning');
        break;
      case 5:
        context.go('/app/history');
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
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

