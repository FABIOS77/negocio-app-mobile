import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, prod }

class EnvConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;

  const EnvConfig._({
    required this.environment,
    required this.apiBaseUrl,
  });

  /// Factory para resolver el entorno mediante la constante de compilación `--dart-define=APP_ENV=dev` o `prod`.
  /// Por defecto apunta obligatoriamente a PRODUCCIÓN (https://katering-grecia-app.onrender.com/api/v1).
  factory EnvConfig.fromEnvironment() {
    const envString = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
    if (envString.toLowerCase() == 'dev') {
      return EnvConfig.dev();
    }
    return EnvConfig.prod();
  }

  /// Configuración para Entorno de Desarrollo (DEV)
  /// - Android Emulator: http://10.0.2.2:3000/api/v1
  /// - iOS Simulator / Web / Desktop: http://localhost:3000/api/v1
  factory EnvConfig.dev({bool? isAndroidEmulator}) {
    final useAndroid = isAndroidEmulator ?? (defaultTargetPlatform == TargetPlatform.android && !kIsWeb);
    final host = useAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
    return EnvConfig._(
      environment: AppEnvironment.dev,
      apiBaseUrl: '$host/api/v1',
    );
  }

  /// Configuración para Entorno de Producción (PROD) - Servidor Render
  factory EnvConfig.prod() {
    return const EnvConfig._(
      environment: AppEnvironment.prod,
      apiBaseUrl: 'https://katering-grecia-app.onrender.com/api/v1',
    );
  }

  bool get isDev => environment == AppEnvironment.dev;
  bool get isProd => environment == AppEnvironment.prod;

  @override
  String toString() => 'EnvConfig(environment: $environment, apiBaseUrl: $apiBaseUrl)';
}
