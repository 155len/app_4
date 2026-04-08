/// API 配置
class ApiConfig {
  // 服务器地址
  static const String baseUrl = 'http://160.202.231.11:23300';

  // API 版本
  static const String apiVersion = '/api/v1';

  // 超时时间（秒）
  static const int timeoutSeconds = 30;

  // 同步间隔（分钟）
  static const int syncIntervalMinutes = 5;

  // API 端点
  static String get glucoseEndpoint => '$baseUrl$apiVersion/glucose';
  static String get mealEndpoint => '$baseUrl$apiVersion/meals';
  static String get medicationEndpoint => '$baseUrl$apiVersion/medications';
  static String get syncEndpoint => '$baseUrl$apiVersion/sync';
  static String get healthEndpoint => '$baseUrl/health';
  static String get syncStatusEndpoint => '$baseUrl$apiVersion/sync/status';

  // 认证（如果需要）
  static const String? authToken = null; // 后续可添加 token 认证

  // 图片基础路径
  static String get imageBaseUrl => '$baseUrl$apiVersion/meals';
}
