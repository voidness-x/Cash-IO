import 'package:flutter/foundation.dart';

/// Sealed Result pattern representing either a [Success] with value [S]
/// or a [Failure] with an [AppError] of type [E].
@immutable
sealed class Result<S, E extends AppError> {
  const Result();

  bool get isSuccess => this is Success<S, E>;
  bool get isFailure => this is Failure<S, E>;

  S? get dataOrNull => switch (this) {
        Success<S, E>(data: final d) => d,
        Failure<S, E>() => null,
      };

  E? get errorOrNull => switch (this) {
        Success<S, E>() => null,
        Failure<S, E>(error: final e) => e,
      };

  R when<R>({
    required R Function(S data) success,
    required R Function(E error) failure,
  }) =>
      switch (this) {
        Success<S, E>(data: final d) => success(d),
        Failure<S, E>(error: final e) => failure(e),
      };

  Result<T, E> map<T>(T Function(S data) transform) => switch (this) {
        Success<S, E>(data: final d) => Success(transform(d)),
        Failure<S, E>(error: final e) => Failure(e),
      };

  Result<S, T> mapError<T extends AppError>(T Function(E error) transform) =>
      switch (this) {
        Success<S, E>(data: final d) => Success(d),
        Failure<S, E>(error: final e) => Failure(transform(e)),
      };
}

final class Success<S, E extends AppError> extends Result<S, E> {
  final S data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<S, E> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

final class Failure<S, E extends AppError> extends Result<S, E> {
  final E error;
  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<S, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Base class for all domain and system errors in Cash-IO
@immutable
sealed class AppError {
  final String message;
  final String? code;
  final Object? cause;

  const AppError(this.message, {this.code, this.cause});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => Object.hash(runtimeType, message, code);

  @override
  String toString() => '${runtimeType.toString()}: $message (code: $code)';
}

/// Invariant violation in double-entry bookkeeping (e.g., postings sum != 0)
final class InvariantViolationError extends AppError {
  final int balanceDifferenceCents;
  const InvariantViolationError(
    super.message, {
    this.balanceDifferenceCents = 0,
    super.code = 'ERR_INVARIANT_VIOLATION',
    super.cause,
  });
}

/// Validation error (e.g., empty description, non-positive amount)
final class ValidationError extends AppError {
  final String field;
  const ValidationError(
    super.message, {
    required this.field,
    super.code = 'ERR_VALIDATION',
    super.cause,
  });
}

/// Storage/database errors
final class StorageError extends AppError {
  const StorageError(
    super.message, {
    super.code = 'ERR_STORAGE',
    super.cause,
  });
}

/// Cryptographic or security errors
final class CryptographicError extends AppError {
  const CryptographicError(
    super.message, {
    super.code = 'ERR_CRYPTO',
    super.cause,
  });
}

/// Entity not found errors
final class NotFoundError extends AppError {
  final String entityType;
  final String entityId;
  const NotFoundError(
    super.message, {
    required this.entityType,
    required this.entityId,
    super.code = 'ERR_NOT_FOUND',
    super.cause,
  });
}

/// CRDT synchronization and conflict errors
final class SyncError extends AppError {
  const SyncError(
    super.message, {
    super.code = 'ERR_SYNC',
    super.cause,
  });
}
