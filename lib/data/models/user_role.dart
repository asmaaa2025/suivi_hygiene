/// User role enum for RBAC (Role-Based Access Control)
enum UserRole {
  /// Regular employee - can clock in/out and perform HACCP operations
  employee,
  
  /// Manager - same as employee + can manage employees (future)
  manager,
  
  /// Admin - access to admin shell with HR, clock history, and correlation
  admin;

  /// Get role from string
  static UserRole? fromString(String? role) {
    if (role == null) return null;
    switch (role.toLowerCase()) {
      case 'employee':
      case 'employé':
        return UserRole.employee;
      case 'manager':
      case 'gestionnaire':
        return UserRole.manager;
      case 'admin':
      case 'administrateur':
        return UserRole.admin;
      default:
        return null;
    }
  }

  /// Convert role to string
  String toValue() {
    switch (this) {
      case UserRole.employee:
        return 'employee';
      case UserRole.manager:
        return 'manager';
      case UserRole.admin:
        return 'admin';
    }
  }

  /// Check if role has admin access
  bool get isAdmin => this == UserRole.admin;

  /// Check if role can access normal shell
  bool get canAccessNormalShell => true; // All roles can access normal shell

  /// Check if role can access admin shell
  bool get canAccessAdminShell => this == UserRole.admin;
}

