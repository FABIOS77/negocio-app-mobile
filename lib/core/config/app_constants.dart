class AppConstants {
  static const String appName = 'Katering Grecia App';
  
  // Zona horaria oficial del negocio
  static const String businessTimezone = 'America/La_Paz';
  
  // Claves de almacenamiento seguro
  static const String keyAccessToken = 'auth_access_token';
  static const String keyRefreshToken = 'auth_refresh_token';
  static const String keyUserData = 'auth_user_data';

  // Configuración de sincronización
  static const int syncBatchSize = 100;
  static const int syncMaxRetries = 3;

  // Claves para SyncMetadata
  static const String syncKeyLastCursor = 'last_cursor';
  static const String syncKeyLastSyncTime = 'last_sync_time';
}
