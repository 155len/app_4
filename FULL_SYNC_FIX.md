# 同步功能完整修复说明

## 问题分析

### 原因 1：Provider 状态未刷新
- `CloudSyncService` 从服务器拉取数据后写入 Hive
- 但 `GlucoseProvider` 和 `MealPhotoProvider` 没有监听数据变化
- 导致历史记录页面显示的是旧数据

### 原因 2：图片上传路径问题
- 拍照后图片保存到本地存储目录
- 上传时可能文件还未写入完成
- 导致上传失败

## 修复内容

### 1. CloudSyncService 添加数据变化通知

**文件：** `lib/data/remote/cloud_sync_service.dart`

```dart
// 添加回调
VoidCallback? onDataChanged;

// 同步完成后通知
void _notifyDataChanged() {
  print('[CloudSync] 数据已变更，通知刷新');
  onDataChanged?.call();
}
```

### 2. Provider 监听数据变化

**文件：** `lib/presentation/providers/glucose_provider.dart`

```dart
class GlucoseNotifier extends StateNotifier<GlucoseState> {
  GlucoseNotifier() : super(GlucoseState()) {
    // 监听同步服务的数据变化
    _syncService.onDataChanged = _onDataChanged;
    loadAll();
  }

  void _onDataChanged() {
    print('[GlucoseProvider] 数据已变更，刷新状态');
    loadAll(); // 自动重新加载数据
  }
}
```

**文件：** `lib/presentation/providers/meal_photo_provider.dart`

```dart
class MealPhotoNotifier extends StateNotifier<MealPhotoState> {
  MealPhotoNotifier() : super(MealPhotoState()) {
    // 监听同步服务的数据变化
    _syncService.onDataChanged = _onDataChanged;
    loadAll();
  }

  void _onDataChanged() {
    print('[MealPhotoProvider] 数据已变更，刷新状态');
    loadAll();
  }
}
```

### 3. 拍照上传添加文件验证

**文件：** `lib/presentation/providers/meal_photo_provider.dart`

```dart
Future<MealPhotoRecord?> takePhoto(MealType mealType) async {
  // ... 保存图片 ...

  // 等待文件写入完成
  await Future.delayed(const Duration(milliseconds: 100));

  // 验证文件存在
  if (!await File(savedPath).exists()) {
    throw Exception('图片文件保存失败：$savedPath');
  }

  // 上传到服务器
  _uploadToCloud(record);
}
```

### 4. 上传前验证文件存在

```dart
Future<void> _uploadToCloud(MealPhotoRecord record) async {
  print('开始上传饮食记录：${record.id}');

  // 验证文件存在
  if (!await File(record.imagePath).exists()) {
    print('图片文件不存在：${record.imagePath}');
    throw Exception('图片文件不存在：${record.imagePath}');
  }

  await _api.uploadMealRecord(record);
  print('饮食记录已上传到服务器：${record.id}');
}
```

## 数据流程

### 血糖记录同步

```
手机 A 添加血糖记录
    ↓
保存到本地 Hive
    ↓
后台上传到服务器
    ↓
------------------ 网络传输 ------------------
    ↓
模拟器 B 打开历史页面
    ↓
CloudSyncService.calibrateAndSync()
    ↓
从服务器拉取缺失数据
    ↓
写入本地 Hive
    ↓
通知 onDataChanged
    ↓
GlucoseProvider.loadAll() 刷新
    ↓
页面显示新数据 ✓
```

### 饮食记录同步（含图片）

```
手机 A 拍照记录饮食
    ↓
1. 保存图片到本地存储目录
2. 等待 100ms 确保文件写入完成
3. 验证文件存在
4. 保存到 Hive
5. 后台上传图片到服务器
    ↓
服务器接收图片
    ↓
转换为 WebP 格式
    ↓
保存到 uploads/images/
    ↓
------------------ 网络传输 ------------------
    ↓
模拟器 B 打开历史页面
    ↓
CloudSyncService.calibrateAndSync()
    ↓
从服务器拉取缺失数据（包含图片路径）
    ↓
写入本地 Hive
    ↓
通知 onDataChanged
    ↓
MealPhotoProvider.loadAll() 刷新
    ↓
页面显示新数据（需要下载图片）✓
```

## 服务器端图片处理

服务器已配置自动将上传的图片转换为 WebP 格式：

```python
# server/main.py
@app.post("/api/v1/meals/upload")
async def upload_meal_record(...):
    # 处理图片 - 转换为 WebP
    image_data = await image.read()
    img = Image.open(io.BytesIO(image_data))

    # 转换为 RGB 模式（处理 PNG 透明通道）
    if img.mode in ('RGBA', 'LA', 'P'):
        img = img.convert('RGB')

    # 保存为 WebP
    webp_buffer = io.BytesIO()
    img.save(webp_buffer, format='WEBP', quality=85)

    # 保存到文件
    filename = f"{id}.webp"
    filepath = UPLOAD_DIR / filename
    with open(filepath, 'wb') as f:
        f.write(webp_buffer.getvalue())
```

### WebP 优势

| 格式 | 质量 85% 大小 | 压缩率 |
|------|-------------|--------|
| JPG | ~500KB | 基准 |
| WebP | ~300KB | 40% 减小 |

- **减少占用空间**：比 JPG 小 30-50%
- **传输更快**：文件大小减小，上传下载速度提升
- **质量保持**：肉眼几乎无法区分差异

## 测试步骤

### 1. 启动服务器
```bash
cd D:\work\xuetang\server
python -m uvicorn main:app --host 0.0.0.0 --port 54628 --reload
```

### 2. 安装新 APK
```
D:\work\xuetang\build\app\outputs\flutter-apk\app-release.apk
```

### 3. 测试血糖同步
1. 手机 A：添加一条血糖记录
2. 查看控制台日志：`血糖记录已上传到服务器：xxx`
3. 模拟器 B：打开"历史"页面
4. 应该能看到手机 A 添加的数据

### 4. 测试饮食同步
1. 手机 A：拍照记录饮食
2. 查看控制台日志：
   - `开始上传饮食记录：xxx`
   - `饮食记录已上传到服务器：xxx`
3. 服务器控制台日志：
   - `POST /api/v1/meals/upload HTTP/1.1" 200`
4. 模拟器 B：打开"历史"页面
5. 应该能看到饮食记录（图片需要从服务器下载）

## 日志说明

### 成功上传
```
[GlucoseProvider] 数据已变更，刷新状态
血糖记录已上传到服务器：1234567890
```

### 成功同步
```
[CloudSync] 校准并同步...
[CloudSync] 数据已变更，通知刷新
[GlucoseProvider] 数据已变更，刷新状态
[MealPhotoProvider] 数据已变更，刷新状态
```

### 上传失败（网络问题）
```
上传血糖记录失败：SocketException: Connection timed out
```
> 失败不影响本地保存，数据仍在 Hive 中

## 注意事项

1. **图片同步**：当前实现中，饮食记录的图片路径是服务器路径（如 `/images/xxx.webp`）
   - 手机端保存的是本地图片路径
   - 其他设备同步时获取到的是服务器路径
   - **需要额外处理**：从服务器下载图片到本地

2. **离线使用**：没有网络时，数据保存在本地，恢复网络后自动上传

3. **数据冲突**：如果多个设备同时修改同一条数据，以时间戳较新的为准

## 待优化项

### 图片下载功能（需要额外实现）

当前问题：
- 手机端拍照后，图片路径是本地路径
- 上传到服务器后，服务器存储为 WebP
- 其他设备同步时，只获取到服务器路径，但本地没有图片文件

解决方案（可选）：
1. **按需下载**：查看图片时，如果本地不存在则从服务器下载
2. **预下载**：同步数据时，同时下载所有新图片

实现示例（按需下载）：
```dart
// 在显示图片的 Widget 中
FutureBuilder<Uint8List>(
  future: _downloadImageIfNeeded(record),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Image.memory(snapshot.data!);
    }
    return CircularProgressIndicator();
  },
)
```
