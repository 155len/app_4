# 数据同步功能说明

## 问题原因

之前的版本中，手机填写数据后**只保存到本地 Hive**，没有自动上传到服务器，导致模拟器中查看不到数据。

## 已修复内容

### 1. 血糖记录自动上传
- 文件：`lib/presentation/providers/glucose_provider.dart`
- 修改：`addRecord()` 方法保存数据后，自动调用 `_uploadToCloud()` 上传到服务器

### 2. 饮食记录自动上传
- 文件：`lib/presentation/providers/meal_photo_provider.dart`
- 修改：`takePhoto()` 和 `pickFromGallery()` 方法保存数据后，自动调用 `_uploadToCloud()` 上传到服务器

### 3. 历史/统计页面自动校准
- 文件：`lib/presentation/screens/history_screen.dart`
- 文件：`lib/presentation/screens/stats_screen.dart`
- 修改：`initState()` 中调用 `CloudSyncService().calibrateAndSync()` 自动同步

## 数据流向

```
用户添加数据
    ↓
保存到本地 Hive（立即）
    ↓
后台上传到服务器（异步）
    ↓
其他设备打开历史/统计页面
    ↓
自动从服务器拉取缺失数据
    ↓
数据显示完成
```

## 使用步骤

### 1. 确保服务器运行
```bash
cd D:\work\xuetang\server
python -m uvicorn main:app --host 0.0.0.0 --port 54628 --reload
```

### 2. 配置服务器地址
运行 `config_api.bat` 选择正确的服务器地址：
- **公网访问**：`http://160.202.231.11:54628`
- **局域网测试**：`http://192.168.x.x:54628`
- **模拟器**：`http://10.0.2.2:54628`

### 3. 安装新版本 APK
```
D:\work\xuetang\build\app\outputs\flutter-apk\app-release.apk
```

### 4. 测试数据同步

**步骤 1：** 手机 A 添加血糖记录
- 打开 App → 记录血糖 → 输入数据 → 保存

**步骤 2：** 模拟器 B 查看数据
- 打开 App → 点击"历史"标签
- 等待自动同步完成
- 应该能看到手机 A 添加的数据

## 同步机制

### 自动上传
- 每次添加数据时，先保存到本地，然后后台上传到服务器
- 上传失败不影响本地保存（离线可用）

### 自动校准
- 打开"历史记录"或"数据统计"页面时自动触发
- 只拉取本地缺少的数据，不会重复下载

### 手动同步
- 在历史/统计页面点击刷新按钮
- 强制重新同步一次

## 日志查看

如果同步失败，查看控制台日志：
- **成功上传**：`血糖记录已上传到服务器：xxx`
- **上传失败**：`上传血糖记录失败：xxx`
- **自动校准**：`[CloudSync] 校准并同步...`

## 常见问题

### Q: 手机添加了数据，但其他设备看不到？

**检查清单：**
1. 服务器是否正在运行？
2. 服务器地址配置是否正确？
3. 手机和服务器网络是否通畅？
4. 打开历史页面时是否看到同步日志？

### Q: 上传失败怎么办？

上传失败时数据仍保存在本地，不影响使用。可能的原因：
- 网络连接问题
- 服务器未启动
- 服务器地址配置错误

### Q: 如何确认数据已上传到服务器？

**方法 1：** 查看服务器日志
```bash
# 服务器控制台会显示 POST 请求
INFO:     192.168.x.x:xxxx - "POST /api/v1/glucose HTTP/1.1" 200
```

**方法 2：** 访问 API 查看数据
```
http://160.202.231.11:54628/api/v1/glucose
```

**方法 3：** 直接查看数据库
```bash
cd D:\work\xuetang\server
sqlite3 glucose_tracker.db "SELECT * FROM blood_glucose;"
```

## 注意事项

1. **首次安装**：新设备安装后，打开历史页面会自动同步所有数据
2. **离线使用**：没有网络时数据保存在本地，恢复网络后自动上传
3. **数据冲突**：如果多个设备同时修改同一条数据，以时间戳较新的为准
