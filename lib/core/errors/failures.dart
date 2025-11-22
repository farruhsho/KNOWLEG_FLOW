import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure(String message, {String? code}) : super(message, code: code);
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message, {String? code}) : super(message, code: code);
}

class CacheFailure extends Failure {
  const CacheFailure(String message, {String? code}) : super(message, code: code);
}

// Auth failures
class AuthFailure extends Failure {
  const AuthFailure(String message, {String? code}) : super(message, code: code);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure(String message, {String? code}) : super(message, code: code);
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure(String message, {String? code}) : super(message, code: code);
}

// Payment failures
class PaymentFailure extends Failure {
  const PaymentFailure(String message, {String? code}) : super(message, code: code);
}

class InsufficientFundsFailure extends PaymentFailure {
  const InsufficientFundsFailure(String message, {String? code}) : super(message, code: code);
}

// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(String message, {String? code}) : super(message, code: code);
}

// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure(String message, {String? code}) : super(message, code: code);
}
