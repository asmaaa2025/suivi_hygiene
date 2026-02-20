import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/section_card.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Switch Employee Button (Prominent)
          SectionCard(
            onTap: () => context.go('/employee-selection'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Changer d\'employé',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sélectionner un autre compte employé',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Section Saisie Rapide
          _buildSectionHeader(
            context,
            'Saisie rapide',
            Icons.add_circle_outline,
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () {
              final isAdminRoute = GoRouterState.of(
                context,
              ).matchedLocation.startsWith('/admin');
              context.push(isAdminRoute ? '/admin/entry' : '/app/entry');
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_circle,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nouvelle saisie',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Température, réception, nettoyage, changement d\'huile',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Consultations
          _buildSectionHeader(context, 'Consultations', Icons.folder_outlined),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/temperatures'),
            child: _buildMenuItem(
              context,
              Icons.thermostat,
              'Températures',
              'Consulter l\'historique des températures',
              AppTheme.statusInfo,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/receptions'),
            child: _buildMenuItem(
              context,
              Icons.inventory_2,
              'Réceptions',
              'Consulter l\'historique des réceptions',
              AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/cleaning'),
            child: _buildMenuItem(
              context,
              Icons.cleaning_services,
              'Nettoyages',
              'Gérer les tâches et l\'historique de nettoyage',
              AppTheme.statusOk,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/oil-changes'),
            child: _buildMenuItem(
              context,
              Icons.oil_barrel,
              'Changements d\'huile',
              'Consulter l\'historique des changements d\'huile',
              AppTheme.statusWarn,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/products'),
            child: _buildMenuItem(
              context,
              Icons.category,
              'Produits',
              'Gérer les produits et leurs DLC',
              Colors.purple,
            ),
          ),
          const SizedBox(height: 24),

          // Section Outils
          _buildSectionHeader(context, 'Outils', Icons.build),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/history'),
            child: _buildMenuItem(
              context,
              Icons.history,
              'Historique unifié',
              'Voir toutes les activités en un seul endroit',
              Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/suppliers'),
            child: _buildMenuItem(
              context,
              Icons.local_shipping,
              'Fournisseurs',
              'Gérer les fournisseurs et leurs produits',
              AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            onTap: () => context.push('/labels'),
            child: _buildMenuItem(
              context,
              Icons.label,
              'Étiquettes',
              'Gérer et imprimer les étiquettes',
              Colors.orange,
            ),
          ),
          // Pointage pour tous les utilisateurs
          const SizedBox(height: 8),
          SectionCard(
            onTap: () {
              if (_isAdmin) {
                context.go('/admin/clock');
              } else {
                context.go('/app/clock');
              }
            },
            child: _buildMenuItem(
              context,
              Icons.access_time,
              'Pointage',
              'Pointer l\'entrée et la sortie',
              Colors.orange,
            ),
          ),
          // Admin-only tools
          if (_isAdmin) ...[
            const SizedBox(height: 8),
            SectionCard(
              onTap: () => context.go('/admin/employees'),
              child: _buildMenuItem(
                context,
                Icons.people_outline,
                'Employés',
                'Gérer les employés et leurs rôles',
                AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            SectionCard(
              onTap: () => context.go('/admin/rh'),
              child: _buildMenuItem(
                context,
                Icons.people,
                'RH',
                'Gérer le registre du personnel',
                AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            SectionCard(
              onTap: () => context.go('/admin/clock-history'),
              child: _buildMenuItem(
                context,
                Icons.history_outlined,
                'Historique de pointage',
                'Consulter l\'historique des pointages',
                Colors.purple,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      ],
    );
  }
}
