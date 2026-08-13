import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/sync/sync_engine.dart';

import '../data/auth_repository.dart';
import '../domain/user_model.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(UserModel user) => AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.error(String message) => AuthState(status: AuthStatus.error, errorMessage: message);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final db = ref.watch(databaseProvider);
  return AuthRepository(dio: dio, tokenStorage: tokenStorage, db: db);
});

final authStateNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    try {
      final user = await _repository.getCachedUser();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _repository.login(email, password);
      state = AuthState.authenticated(user);
    } catch (e) {
      String msg = 'Error de autenticación';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          final errorMap = data['error'];
          if (errorMap is Map && errorMap['message'] != null) {
            msg = errorMap['message'].toString();
          } else if (data['message'] != null) {
            msg = data['message'].toString();
          } else {
            msg = e.message ?? e.toString();
          }
        } else if (e.message != null && e.message!.isNotEmpty) {
          msg = e.message!;
        } else {
          msg = 'HTTP ${e.response?.statusCode ?? 500}: ${e.toString()}';
        }
      } else {
        msg = e.toString();
      }
      state = AuthState.error(msg);
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    await _repository.logout();
    state = AuthState.unauthenticated();
  }
}
