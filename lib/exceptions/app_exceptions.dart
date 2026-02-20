/// Base exception for app errors
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Network-related exceptions
class NetworkException extends AppException {
  NetworkException(super.message) : super(code: 'NETWORK_ERROR');
}

/// Authentication exceptions
class AuthException extends AppException {
  AuthException(super.message) : super(code: 'AUTH_ERROR');
}

/// Supabase operation exceptions
class SupabaseException extends AppException {
  SupabaseException(super.message, {String? code})
    : super(code: code ?? 'SUPABASE_ERROR');
}

/// Validation exceptions
class ValidationException extends AppException {
  ValidationException(super.message) : super(code: 'VALIDATION_ERROR');
}
