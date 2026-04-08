# Android 连接服务器配置指南

## 1. 网络权限（已添加）

已在 `android/app/src/main/AndroidManifest.xml` 中添加：
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## 2. 配置服务器地址

编辑 `lib/config/api_config.dart`：

### 场景 1：本地开发（Android 模拟器）

Android 模拟器使用 `10.0.2.2` 访问本机：

```dart
static const String baseUrl = 'http://10.0.2.2:54628';
```

### 场景 2：局域网测试（真机连接）

确保手机和电脑在同一 Wi-Fi 网络，使用电脑的局域网 IP：

```dart
// 查看电脑 IP：Windows 运行 ipconfig
static const String baseUrl = 'http://192.168.x.x:54628';
```

### 场景 3：公网访问（已配置）

你已经有公网 IP，当前配置：

```dart
static const String baseUrl = 'http://160.202.231.11:54628';
```

## 3. 服务器端配置

### 启动服务器
```bash
cd D:\work\xuetang\server
python -m uvicorn main:app --host 0.0.0.0 --port 54628 --reload
```

### 检查防火墙

**Windows 防火墙设置：**
1. 打开"Windows Defender 防火墙"
2. 点击"高级设置"
3. 点击"入站规则" → "新建规则"
4. 选择"端口" → 下一步
5. 选择"TCP"，端口输入 `54628` → 下一步
6. 选择"允许连接" → 下一步
7. 全选（域、专用、公用） → 下一步
8. 名称输入 `Flutter API Server` → 完成

**或使用命令行（管理员权限）：**
```powershell
netsh advfirewall firewall add rule name="Flutter API" dir=in action=allow protocol=TCP localport=54628
```

## 4. 验证连接

### 方法 1：浏览器测试
在手机浏览器访问：`http://160.202.231.11:54628/health`

应该看到：
```json
{"status":"ok","server_time":"...","version":"1.0.0"}
```

### 方法 2：命令行测试
```bash
curl http://160.202.231.11:54628/health
```

### 方法 3：Flutter App 测试
运行 App 后，打开历史记录或统计页面，观察控制台日志：
- 如果看到 `[CloudSync] 校准并同步...` 表示连接成功
- 如果看到错误信息，检查网络和防火墙

## 5. 常见问题

### 问题 1：连接超时
```
SocketException: Connection timed out
```

**解决方案：**
1. 检查服务器是否启动
2. 检查防火墙是否开放端口 54628
3. 检查 IP 地址是否正确

### 问题 2：无法访问公网 IP
```
SocketException: Failed host lookup
```

**解决方案：**
1. 确认公网 IP 是否正确（`160.202.231.11`）
2. 检查路由器端口转发是否配置
3. 确认服务器监听了 `0.0.0.0` 而不是 `127.0.0.1`

### 问题 3：模拟器无法连接
**解决方案：**
- Android 模拟器不能用 `localhost` 或 `127.0.0.1`
- 使用 `10.0.2.2` 访问本机
- 使用 `ipconfig` 获取的 IP 地址访问局域网

### 问题 4：真机无法连接
**解决方案：**
1. 确保手机和电脑在同一 Wi-Fi
2. 使用电脑的局域网 IP（不是 `127.0.0.1`）
3. 检查防火墙是否允许局域网访问

## 6. 快速切换配置

创建不同环境的配置文件：

```dart
// lib/config/api_config_dev.dart (本地开发)
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:54628';
  // ... 其他配置
}

// lib/config/api_config_prod.dart (生产环境)
class ApiConfig {
  static const String baseUrl = 'http://160.202.231.11:54628';
  // ... 其他配置
}
```

或者添加环境判断：

```dart
static String get baseUrl {
  // 开发环境使用模拟器
  return _isDebug ? 'http://10.0.2.2:54628' : 'http://160.202.231.11:54628';
}
```

## 7. 当前配置状态

你的当前配置 (`lib/config/api_config.dart`)：
```dart
static const String baseUrl = 'http://160.202.231.11:54628';
```

**需要确认：**
1. 服务器是否在运行？
2. 端口 54628 是否在防火墙开放？
3. 公网 IP `160.202.231.11` 是否正确且可访问？

如果服务器在本地运行，建议先使用局域网 IP 测试，确认正常后再配置公网访问。
