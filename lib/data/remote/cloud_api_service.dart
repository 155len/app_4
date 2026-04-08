import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../models/blood_glucose.dart';
import '../models/meal_photo.dart';

/// 云端 API 服务
/// 负责与服务器进行 HTTP 通信
class CloudApiService {
  static final CloudApiService _instance = CloudApiService._internal();
  factory CloudApiService() => _instance;
  CloudApiService._internal();

  final http.Client _client = http.Client();
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  /// 服务器时间（用于时间校准）
  DateTime? _serverTime;
  /// 本地与服务器时间差
  Duration? _timeOffset;

  DateTime? get serverTime => _serverTime;
  Duration? get timeOffset => _timeOffset;

  /// 添加认证头
  void setAuthToken(String token) {
    _headers['Authorization'] = 'Bearer $token';
  }

  // ==================== 血糖数据 API ====================

  /// 上传血糖记录
  Future<Map<String, dynamic>> uploadGlucoseRecord(BloodGlucoseRecord record) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.glucoseEndpoint),
        headers: _headers,
        body: jsonEncode(record.toJson()),
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      return _handleResponse(response);
    } catch (e) {
      throw CloudApiException('上传血糖记录失败：$e');
    }
  }

  /// 获取血糖记录（支持增量同步）
  /// [since] - 获取此时间之后的数据，为 null 时获取全部数据
  Future<List<BloodGlucoseRecord>> getGlucoseRecords({DateTime? since}) async {
    try {
      String url = ApiConfig.glucoseEndpoint;
      if (since != null) {
        url += '?since=${since.toIso8601String()}';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      final data = _handleResponse(response);
      final List<dynamic> records = data['records'] ?? data;
      return records.map((r) => BloodGlucoseRecord.fromJson(Map<String, dynamic>.from(r))).toList();
    } catch (e) {
      throw CloudApiException('获取血糖记录失败：$e');
    }
  }

  /// 删除血糖记录
  Future<void> deleteGlucoseRecord(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('${ApiConfig.glucoseEndpoint}/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      _handleResponse(response);
    } catch (e) {
      throw CloudApiException('删除血糖记录失败：$e');
    }
  }

  // ==================== 饮食记录 API ====================

  /// 上传饮食记录
  Future<Map<String, dynamic>> uploadMealRecord(MealPhotoRecord record) async {
    try {
      // 检查图片文件是否存在
      if (!await File(record.imagePath).exists()) {
        throw CloudApiException('图片文件不存在：${record.imagePath}');
      }

      // 上传图片使用 multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.mealEndpoint}/upload'),
      );

      // 添加记录信息
      request.fields['id'] = record.id;
      request.fields['timestamp'] = record.timestamp.toIso8601String();
      request.fields['mealTypeIndex'] = record.mealTypeIndex.toString();
      request.fields['medicineTaken'] = record.medicineTaken.toString();
      request.fields['medicineReminded'] = record.medicineReminded.toString();
      if (record.medicineRemindTime != null) {
        request.fields['medicineRemindTime'] = record.medicineRemindTime!.toIso8601String();
      }

      // 添加图片文件
      final imageFile = await File(record.imagePath).readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageFile,
        filename: '${record.id}.jpg',
      ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: ApiConfig.timeoutSeconds),
      );
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      throw CloudApiException('上传饮食记录失败：$e');
    }
  }

  /// 获取饮食记录（支持增量同步）
  /// [since] - 获取此时间之后的数据，为 null 时获取全部数据
  Future<List<MealPhotoRecord>> getMealRecords({DateTime? since}) async {
    try {
      String url = ApiConfig.mealEndpoint;
      if (since != null) {
        url += '?since=${since.toIso8601String()}';
      }

      final response = await _client.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      final data = _handleResponse(response);
      final List<dynamic> records = data['records'] ?? data;
      return records.map((r) => MealPhotoRecord.fromJson(Map<String, dynamic>.from(r))).toList();
    } catch (e) {
      throw CloudApiException('获取饮食记录失败：$e');
    }
  }

  /// 获取饮食记录图片
  Future<Uint8List> getMealImage(String recordId) async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.mealEndpoint}/$recordId/image'),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      if (response.statusCode != 200) {
        throw CloudApiException('获取图片失败：${response.statusCode}');
      }

      return response.bodyBytes;
    } catch (e) {
      throw CloudApiException('获取图片失败：$e');
    }
  }

  /// 删除饮食记录
  Future<void> deleteMealRecord(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('${ApiConfig.mealEndpoint}/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      _handleResponse(response);
    } catch (e) {
      throw CloudApiException('删除饮食记录失败：$e');
    }
  }

  // ==================== 同步 API ====================

  /// 增量同步
  /// [lastSyncTime] - 上次同步时间，null 表示首次同步
  /// [deviceIds] - 本地已有数据 ID 列表
  Future<SyncResult> incrementalSync({
    DateTime? lastSyncTime,
    List<String>? deviceIds,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        if (lastSyncTime != null) 'lastSyncTime': lastSyncTime.toIso8601String(),
        if (deviceIds != null) 'deviceIds': deviceIds,
      };

      final response = await _client.post(
        Uri.parse(ApiConfig.syncEndpoint),
        headers: _headers,
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      final data = _handleResponse(response);

      // 解析响应
      final List<dynamic> glucoseList = data['glucoseRecords'] ?? [];
      final List<dynamic> mealList = data['mealRecords'] ?? [];

      final glucoseRecords = glucoseList
          .map((r) => BloodGlucoseRecord.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      final mealRecords = mealList
          .map((r) => MealPhotoRecord.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      // 获取服务器时间
      final serverTimeStr = data['serverTime'] as String?;
      DateTime? serverTime;
      if (serverTimeStr != null) {
        serverTime = DateTime.parse(serverTimeStr);
        _serverTime = serverTime;
        // 计算时间偏移（本地时间与服务器时间的差）
        _timeOffset = serverTime.difference(DateTime.now());
      }

      return SyncResult(
        glucoseRecords: glucoseRecords,
        mealRecords: mealRecords,
        serverTime: serverTime,
        newGlucoseCount: data['newGlucoseCount'] ?? 0,
        newMealCount: data['newMealCount'] ?? 0,
      );
    } catch (e) {
      throw CloudApiException('增量同步失败：$e');
    }
  }

  /// 获取同步状态
  Future<SyncStatus> getSyncStatus() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConfig.syncStatusEndpoint),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      final data = _handleResponse(response);
      return SyncStatus(
        serverTime: DateTime.parse(data['serverTime'] as String),
        glucoseRecordCount: data['glucoseRecordCount'] ?? 0,
        mealRecordCount: data['mealRecordCount'] ?? 0,
      );
    } catch (e) {
      throw CloudApiException('获取同步状态失败：$e');
    }
  }

  /// 获取服务器时间（用于时间校准）
  Future<DateTime> getServerTime() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConfig.healthEndpoint),
        headers: _headers,
      ).timeout(const Duration(seconds: ApiConfig.timeoutSeconds));

      final data = _handleResponse(response);
      final serverTime = DateTime.parse(data['server_time'] as String);
      _serverTime = serverTime;
      _timeOffset = serverTime.difference(DateTime.now());
      return serverTime;
    } catch (e) {
      throw CloudApiException('获取服务器时间失败：$e');
    }
  }

  /// 检查服务器连接
  Future<bool> checkConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== 工具方法 ====================

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw CloudApiException('服务器响应错误：${response.statusCode}');
    }
  }

  void dispose() {
    _client.close();
  }
}

/// 云同步异常
class CloudApiException implements Exception {
  final String message;
  CloudApiException(this.message);

  @override
  String toString() => message;
}

/// 同步结果
class SyncResult {
  final List<BloodGlucoseRecord> glucoseRecords;
  final List<MealPhotoRecord> mealRecords;
  final DateTime? serverTime;
  final int newGlucoseCount;
  final int newMealCount;

  SyncResult({
    required this.glucoseRecords,
    required this.mealRecords,
    this.serverTime,
    this.newGlucoseCount = 0,
    this.newMealCount = 0,
  });
}

/// 同步状态
class SyncStatus {
  final DateTime serverTime;
  final int glucoseRecordCount;
  final int mealRecordCount;

  SyncStatus({
    required this.serverTime,
    required this.glucoseRecordCount,
    required this.mealRecordCount,
  });
}
