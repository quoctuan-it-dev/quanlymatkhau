import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'app_channel.dart';

/// File thông tin bản mới nhất. Đường dẫn "latest" luôn trỏ tới
/// bản phát hành mới nhất trên GitHub.
const String kUpdateManifestUrl =
    'https://github.com/quoctuan-it-dev/quanlymatkhau/releases/latest/download/version.json';

/// Chỉ chấp nhận tải APK từ đúng mục phát hành của repo này.
const String kAllowedApkPrefix =
    'https://github.com/quoctuan-it-dev/quanlymatkhau/releases/download/';

const int _maxManifestBytes = 64 * 1024; // 64 KB
const int _maxApkBytes = 150 * 1024 * 1024; // 150 MB

/// Thông tin một bản phát hành (đọc từ version.json).
class UpdateInfo {
  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final String notes;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        versionCode: (json['versionCode'] as num).toInt(),
        versionName: json['versionName'] as String,
        apkUrl: json['apkUrl'] as String,
        sha256: (json['sha256'] as String).trim().toLowerCase(),
        notes: (json['notes'] as String?) ?? '',
      );
}

/// Lỗi khi cập nhật, kèm câu thông báo dễ hiểu cho người dùng.
class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  /// Hỏi GitHub bản mới nhất là bản nào.
  static Future<UpdateInfo> fetchLatest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(kUpdateManifestUrl));
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        throw const UpdateException('Chưa có bản phát hành nào trên GitHub.');
      }
      if (response.statusCode != 200) {
        throw UpdateException('Máy chủ báo lỗi ${response.statusCode}.');
      }
      final body = await _readLimited(response, _maxManifestBytes);
      final info = UpdateInfo.fromJson(
          jsonDecode(utf8.decode(body)) as Map<String, dynamic>);
      if (!info.apkUrl.startsWith(kAllowedApkPrefix)) {
        throw const UpdateException('Địa chỉ tải bản cập nhật không hợp lệ.');
      }
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(info.sha256)) {
        throw const UpdateException('Thông tin bản cập nhật không hợp lệ.');
      }
      return info;
    } on UpdateException {
      rethrow;
    } on SocketException {
      throw const UpdateException(
          'Không có mạng. Hãy bật Wi-Fi hoặc 4G rồi thử lại.');
    } on TimeoutException {
      throw const UpdateException('Mạng quá chậm. Hãy thử lại sau.');
    } catch (_) {
      throw const UpdateException('Không đọc được thông tin bản cập nhật.');
    } finally {
      client.close(force: true);
    }
  }

  /// Tải APK, kiểm tra SHA-256 và kiểm tra đúng là app này.
  /// Trả về đường dẫn file APK đã kiểm tra xong.
  static Future<String> download(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) async {
    final dir = await AppChannel.getUpdateDir();
    final file = File('$dir/update.apk');
    if (await file.exists()) await file.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(info.apkUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw UpdateException(
            'Không tải được bản cập nhật (lỗi ${response.statusCode}).');
      }
      final total = response.contentLength; // -1 nếu không biết trước
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          received += chunk.length;
          if (received > _maxApkBytes) {
            throw const UpdateException('File cập nhật quá lớn.');
          }
          sink.add(chunk);
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }
    } on UpdateException {
      rethrow;
    } on SocketException {
      throw const UpdateException(
          'Mất mạng khi đang tải. Hãy kiểm tra mạng rồi thử lại.');
    } catch (_) {
      throw const UpdateException('Tải bản cập nhật bị gián đoạn. Hãy thử lại.');
    } finally {
      client.close(force: true);
    }

    // Lớp kiểm tra 1: mã SHA-256 phải khớp với version.json.
    final path = file.path;
    final digest = await Isolate.run(() async {
      final hash = await Sha256().hash(await File(path).readAsBytes());
      return hash.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    });
    if (digest != info.sha256) {
      await file.delete();
      throw const UpdateException(
          'File tải về không khớp mã kiểm tra. Đã hủy để an toàn.');
    }

    // Lớp kiểm tra 2: đúng là app này, đúng số phiên bản.
    final check = await AppChannel.checkApk(path);
    if (!check.valid || check.code != info.versionCode) {
      await file.delete();
      throw const UpdateException(
          'File tải về không phải bản cập nhật hợp lệ của app.');
    }
    return path;
  }

  static Future<List<int>> _readLimited(Stream<List<int>> stream, int max) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
      if (builder.length > max) {
        throw const UpdateException('Dữ liệu quá lớn.');
      }
    }
    return builder.takeBytes();
  }
}