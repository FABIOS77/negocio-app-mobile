import 'package:dio/dio.dart';
import '../auth/token_storage.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  final String _baseUrl;
  final Function()? _onSessionExpired;

  bool _isRefreshing = false;
  Future<bool>? _refreshFuture;

  AuthInterceptor({
    required TokenStorage tokenStorage,
    required String baseUrl,
    Function()? onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _baseUrl = baseUrl,
        _onSessionExpired = onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final isAuthEndpoint = err.requestOptions.path.contains('/auth/login') ||
          err.requestOptions.path.contains('/auth/refresh');

      if (!isAuthEndpoint) {
        final refreshed = await _getOrStartRefresh();
        if (refreshed) {
          try {
            final newAccessToken = await _tokenStorage.getAccessToken();
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccessToken';

            final cloneReq = await Dio().fetch(opts);
            return handler.resolve(cloneReq);
          } catch (e) {
            return handler.next(err);
          }
        } else {
          await _tokenStorage.clearAll();
          _onSessionExpired?.call();
        }
      }
    }
    handler.next(err);
  }

  Future<bool> _getOrStartRefresh() {
    if (_isRefreshing && _refreshFuture != null) {
      return _refreshFuture!;
    }
    _isRefreshing = true;
    _refreshFuture = _refreshToken().whenComplete(() {
      _isRefreshing = false;
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final dio = Dio();
      final response = await dio.post(
        '$_baseUrl/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        final newAccessToken = data['accessToken'] as String?;
        if (newAccessToken != null) {
          await _tokenStorage.saveAccessToken(newAccessToken);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
