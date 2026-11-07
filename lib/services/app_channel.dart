import 'package:flutter/services.dart';

/// Một app đã cài trên điện thoại.
class InstalledApp {
  const InstalledApp({required this.packageName, required this.label});

  final String packageName; // mã định danh, ví dụ com.vnid
  final String label; // tên hiển thị, ví dụ VNeID
}

/// Gọi sang code Kotlin (MainActivity.kt) qua kênh "apps".
class AppChannel {
  static const _channel = MethodChannel('com.giadinh.quanlymatkhau/apps');

  // Lưu tạm biểu tượng đã lấy để không phải hỏi Android nhiều lần.
  static final Map<String, Uint8List?> _iconCache = {};

  /// Danh sách app có thể mở được, sắp xếp theo tên.
  static Future<List<InstalledApp>> getLaunchableApps() async {
    final raw = await _channel.invokeListMethod<Map>('getLaunchableApps') ?? [];
    final apps = raw
        .map((m) => InstalledApp(
              packageName: m['packageName'] as String,
              label: m['label'] as String,
            ))
        .toList();
    apps.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return apps;
  }

  /// Biểu tượng thật của app (ảnh PNG), hoặc null nếu app đã bị gỡ.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    if (_iconCache.containsKey(packageName)) return _iconCache[packageName];
    final bytes = await _channel.invokeMethod<Uint8List>(
      'getAppIcon',
      {'packageName': packageName, 'size': 144},
    );
    _iconCache[packageName] = bytes;
    return bytes;
  }

  /// App còn cài trên máy không.
  static Future<bool> isInstalled(String packageName) async {
    return await _channel.invokeMethod<bool>(
            'isInstalled', {'packageName': packageName}) ??
        false;
  }

  /// Mở app đích. Trả về false nếu app chưa cài.
  static Future<bool> launchApp(String packageName) async {
    return await _channel.invokeMethod<bool>(
            'launchApp', {'packageName': packageName}) ??
        false;
  }
}