import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/employee_session_service.dart';
import '../../../services/cache_service.dart';
import '../../../data/repositories/clock_repository.dart';
import '../../../data/models/clock_session.dart';
import '../../../data/repositories/organization_repository.dart';
import 'package:intl/intl.dart';

/// Persistent top bar showing organization, current employee, clock status, and switch button
class AppTopBar extends StatefulWidget implements PreferredSizeWidget {
  final String? organizationName;
  final bool showClockStatus;

  const AppTopBar({
    super.key,
    this.organizationName,
    this.showClockStatus = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  final _sessionService = EmployeeSessionService();
  final _clockRepo = ClockRepository();
  final _orgRepo = OrganizationRepository();
  final _client = Supabase.instance.client;
  ClockSession? _currentSession;
  bool _isLoading = true;
  String? _organizationName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _sessionService.initialize();
    await _loadOrganizationName();
    if (widget.showClockStatus) {
      await _loadClockStatus();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrganizationName() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Get organization by user.id (organization.id = user.id)
      final response = await _client
          .from('organizations')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _organizationName = response['name'] as String?;
        });
      }
    } catch (e) {
      debugPrint('[AppTopBar] Error loading organization name: $e');
    }
  }

  Future<void> _loadClockStatus() async {
    try {
      final employee = _sessionService.currentEmployee;
      if (employee != null) {
        final session = await _clockRepo.getOpenSession(employee.id);
        if (mounted) {
          setState(() {
            _currentSession = session;
          });
        }
      }
    } catch (e) {
      debugPrint('[AppTopBar] Error loading clock status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = _sessionService.currentEmployee;
    final employeeName = employee != null
        ? '${employee.firstName} ${employee.lastName}'
        : 'Non sélectionné';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Organization name (small)
              Flexible(
                flex: 2,
                child: Text(
                  widget.organizationName ??
                      _organizationName ??
                      'Organisation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.left,
                ),
              ),
              // Center: Current employee + clock status (absolutely centered)
              Expanded(
                flex: 4,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              employeeName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      if (widget.showClockStatus && !_isLoading) ...[
                        const SizedBox(height: 2),
                        _buildClockStatusChip(),
                      ],
                    ],
                  ),
                ),
              ),
              // Right: Switch employee button + Logout button
              Flexible(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.go('/employee-selection'),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text(
                        'Changer',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 18),
                      color: Colors.red,
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Déconnexion',
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      // Clear cache
      await CacheService().clear();

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Redirect to login page immediately
      if (mounted) {
        context.go('/login');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Déconnexion réussie')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
        );
      }
    }
  }

  Widget _buildClockStatusChip() {
    if (_currentSession == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 12, color: Colors.orange),
            const SizedBox(width: 3),
            Text(
              'Non pointé',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
          ],
        ),
      );
    }

    final startTime = DateFormat('HH:mm').format(_currentSession!.startAt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.statusOk.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.statusOk, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 12, color: AppTheme.statusOk),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'Pointé $startTime',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.statusOk,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
