import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_module_tile.dart';
import '../../../../services/employee_session_service.dart';
import '../../../../services/auth_service.dart';

/// Dashboard page - Main entry point after login
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _sessionService = EmployeeSessionService();
  final _authService = AuthService();
  String? _greeting;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadGreeting();
    _checkAdminStatus();
  }

  void _loadGreeting() {
    _sessionService.initialize().then((_) {
      if (mounted) {
        setState(() {
          final employee = _sessionService.currentEmployee;
          _greeting = employee != null
              ? 'Bonjour, ${employee.firstName}'
              : 'Bonjour';
        });
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    try {
      final userRole = await _authService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _isAdmin = userRole.isAdmin;
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] Error checking admin status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_greeting != null)
              Text(
                _greeting!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text('Suivi HACCP'),
            if (_greeting != null)
              const Text(
                'Suivi HACCP',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: _isAdmin ? _buildAdminBody(context) : _buildEmployeeBody(context),
    );
  }

  Widget _buildAdminBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            AppModuleTile(
              icon: Icons.fact_check_outlined,
              title: 'HACCP',
              subtitle: 'Suivi hygiène',
              color: AppTheme.primaryBlue,
              onTap: () => context.go('/admin/haccp'),
            ),
            AppModuleTile(
              icon: Icons.people_alt_outlined,
              title: 'RH',
              subtitle: 'Gestion du personnel',
              color: Colors.teal,
              onTap: () => context.go('/admin/rh-hub'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Compact "Changer d'employé" banner
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => context.go('/employee-selection'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Changer d\'employé',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Module tiles
          Expanded(
            child: Center(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AppModuleTile(
                    icon: Icons.fact_check_outlined,
                    title: 'HACCP',
                    subtitle: 'Suivi hygiène',
                    color: AppTheme.primaryBlue,
                    onTap: () => context.go('/app/haccp'),
                  ),
                  AppModuleTile(
                    icon: Icons.access_time,
                    title: 'Pointage',
                    subtitle: 'Entrée / Sortie',
                    color: Colors.orange,
                    onTap: () => context.go('/app/clock'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
