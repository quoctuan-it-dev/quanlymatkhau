import 'package:flutter/services.dart';

/// Thời gian tự xóa bộ nhớ tạm, tính bằng phút.
/// Phải giống AUTO_CLEAR_MINUTES trong ClipboardGuard.kt.
const int kClipboardClearMinutes = 15;

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

  /// Sao chép vào bộ nhớ tạm, đánh dấu nhạy cảm và hẹn giờ tự xóa.
  static Future<void> copySecret(String text) async {
    await _channel.invokeMethod<void>('copySecret', {'text': text});
  }

  /// Mở hộp "Lưu vào..." của Android.
  /// Trả về true nếu đã lưu, false nếu người dùng bấm hủy.
  static Future<bool> saveFile(String fileName, Uint8List bytes) async {
    final saved = await _channel.invokeMethod<bool>(
      'saveFile',
      {'fileName': fileName, 'bytes': bytes},
    );
    return saved ?? false;
  }

  /// Mở hộp chọn file. Trả về nội dung file, hoặc null nếu người dùng bấm hủy.
  static Future<Uint8List?> openFile() async {
    return _channel.invokeMethod<Uint8List>('openFile');
  }

  /// Phiên bản app đang cài, ví dụ name = "1.0.0", code = 1.
  static Future<({String name, int code})> getAppVersion() async {
    final m =
        await _channel.invokeMapMethod<String, dynamic>('getAppVersion') ?? {};
    return (
      name: m['versionName'] as String? ?? '',
      code: (m['versionCode'] as num?)?.toInt() ?? 0,
    );
  }

  /// Thư mục tạm để chứa file APK tải về.
  static Future<String> getUpdateDir() async {
    return (await _channel.invokeMethod<String>('getUpdateDir'))!;
  }

  /// Người dùng đã cho phép app này mở trình cài đặt chưa.
  static Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  /// Mở trang "Cho phép cài ứng dụng từ nguồn này".
  static Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  /// Kiểm tra file APK: có đúng là app này không, và số phiên bản bao nhiêu.
  static Future<({bool valid, int code})> checkApk(String path) async {
    final m = await _channel
            .invokeMapMethod<String, dynamic>('checkApk', {'path': path}) ??
        {};
    return (
      valid: m['valid'] == true,
      code: (m['versionCode'] as num?)?.toInt() ?? 0,
    );
  }

  /// Mở màn hình cài đặt của Android cho file APK.
  static Future<bool> installApk(String path) async {
    return await _channel.invokeMethod<bool>('installApk', {'path': path}) ??
        false;
  }
}