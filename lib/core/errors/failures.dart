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
  const ServerFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.code});
}

// Auth failures
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure(super.message, {super.code});
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure(super.message, {super.code});
}

// Payment failures
class PaymentFailure extends Failure {
  const PaymentFailure(super.message, {super.code});
}

class InsufficientFundsFailure extends PaymentFailure {
  const InsufficientFundsFailure(super.message, {super.code});
}

// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}
