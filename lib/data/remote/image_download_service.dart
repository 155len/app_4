import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../local/hive_service.dart';

/// 图片下载服务
class ImageDownloadService {
  /// 下载进度回调
  static Function(int progress)? onProgress;

  /// 下载图片到本地存储
  /// [recordId] 饮食记录 ID
  /// [serverPath] 服务器图片路径（如 /images/xxx.webp）
  /// [onProgress] 进度回调 (0-100)
  /// 返回本地文件路径
  static Future<String> downloadImage(
    String recordId,
    String serverPath, {
    Function(int progress)? onProgress,
  }) async {
    try {
      // 构建完整的 URL
      final imageUrl = '${ApiConfig.baseUrl}${serverPath}';

      // 使用 Client 进行流式下载以支持进度
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(imageUrl));
        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode != 200) {
          throw Exception('下载图片失败：${streamedResponse.statusCode}');
        }

        final totalBytes = streamedResponse.contentLength ?? 0;
        int downloadedBytes = 0;

        // 获取本地存储目录
        final storageDir = await HiveService.getImageStorageDir();

        // 保存为 webp 格式
        final fileName = '$recordId.webp';
        final localPath = '$storageDir/$fileName';

        // 创建文件
        final file = File(localPath);
        final sink = file.openWrite();

        // 监听数据流
        await streamedResponse.stream.listen(
          (List<int> chunk) {
            sink.add(chunk);
            downloadedBytes += chunk.length;
            if (totalBytes > 0) {
              final progress = ((downloadedBytes / totalBytes) * 100).toInt();
              onProgress?.call(progress);
              ImageDownloadService.onProgress?.call(progress);
            }
          },
          onDone: () async {
            await sink.close();
            if (totalBytes == 0) {
              onProgress?.call(100);
              ImageDownloadService.onProgress?.call(100);
            }
          },
          onError: (e) {
            sink.close();
            print('下载出错：$e');
          },
          cancelOnError: true,
        ).asFuture<void>();

        print('图片已下载到：$localPath');
        return localPath;
      } finally {
        client.close();
      }
    } catch (e) {
      print('下载图片失败：$e');
      rethrow;
    }
  }

  /// 批量下载图片
  static Future<Map<String, String>> downloadImages(
    List<(String recordId, String serverPath)> images,
  ) async {
    final result = <String, String>{};

    for (final item in images) {
      try {
        final localPath = await downloadImage(item.$1, item.$2);
        result[item.$1] = localPath;
      } catch (e) {
        print('下载图片 ${item.$1} 失败：$e');
        result[item.$1] = ''; // 失败时返回空路径
      }
    }

    return result;
  }

  /// 检查图片是否存在于本地
  static Future<bool> isImageCached(String recordId) async {
    final storageDir = await HiveService.getImageStorageDir();
    final webpPath = '$storageDir/${recordId}.webp';
    final jpgPath = '$storageDir/${recordId}.jpg';

    return await File(webpPath).exists() || await File(jpgPath).exists();
  }

  /// 获取本地图片路径
  static Future<String?> getLocalImagePath(String recordId) async {
    final storageDir = await HiveService.getImageStorageDir();
    final webpFile = File('$storageDir/${recordId}.webp');
    final jpgFile = File('$storageDir/${recordId}.jpg');

    if (await webpFile.exists()) return webpFile.path;
    if (await jpgFile.exists()) return jpgFile.path;

    return null;
  }
}
