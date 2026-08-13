import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/database/app_database.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final Dio _dio;
  final TokenStorage _tokenStorage;
  final AppDatabase _db;

  AuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
    required AppDatabase db,
  })  : _dio = dio,
        _tokenStorage = tokenStorage,
        _db = db;

  Future<UserModel> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );

    final data = response.data['data'] ?? response.data;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final userJson = data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);

    // Guardar tokens y usuario en almacenamiento seguro y SQLite local
    await _tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await _tokenStorage.saveUserData(user.toJson());

    await _db.into(_db.usersSessionTable).insertOnConflictUpdate(
          UsersSessionTableCompanion.insert(
            id: user.id,
            name: user.name,
            email: user.email,
            active: Value(user.active),
            version: Value(user.version),
            createdAt: user.createdAt ?? DateTime.now().toUtc(),
          ),
        );

    return user;
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      } catch (_) {
        // Ignorar errores de red en logout offline
      }
    }

    await _tokenStorage.clearAll();
    await _db.delete(_db.usersSessionTable).go();
  }

  Future<UserModel?> getCachedUser() async {
    final session = await (_db.select(_db.usersSessionTable)..limit(1)).getSingleOrNull();
    if (session != null) {
      return UserModel(
        id: session.id,
        name: session.name,
        email: session.email,
        active: session.active,
        version: session.version,
        createdAt: session.createdAt,
      );
    }

    final json = await _tokenStorage.getUserData();
    if (json != null) {
      return UserModel.fromJson(json);
    }
    return null;
  }
}
