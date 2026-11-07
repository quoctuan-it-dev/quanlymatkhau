import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security/vault.dart';
import 'account.dart';
import 'account_store.dart';

/// Lỗi: sai mật khẩu sao lưu (hoặc file đã bị sửa).
class BackupWrongPassword implements Exception {}

/// Lỗi: không phải file sao lưu của app này, hoặc file bị hỏng.
class BackupInvalidFile implements Exception {}

/// Nội dung file sao lưu sau khi mở thành công.
class OpenedBackup {
  const OpenedBackup({required this.createdAt, required this.entries});

  final DateTime createdAt;
  final List<PlainAccount> entries;
}

/// Mật khẩu sao lưu tối thiểu bao nhiêu ký tự.
const int kMinBackupPasswordLength = 10;

/// Argon2id cho file sao lưu: nặng hơn lúc mở khóa (46 MiB, 2 vòng),
/// vì file nằm ngoài máy nên kẻ gian có thể thử đoán không giới hạn.
const KdfParams kBackupKdf =
    KdfParams(memoryKiB: 47104, iterations: 2, parallelism: 1);

const _format = 'quanlymatkhau-backup';
const _version = 1;
const _nonceLength = 12;
const _macLength = 16;
final List<int> _aad = utf8.encode('$_format-v$_version');

/// Định dạng file (dạng chữ JSON, phần quan trọng đã mã hóa):
/// {
///   "format": "quanlymatkhau-backup", "v": 1,
///   "kdf": {"alg": "argon2id", "m": ..., "t": ..., "p": ...},
///   "salt": "<base64>",
///   "data": "<base64 của nonce + dữ liệu mã hóa AES-256-GCM + tag>"
/// }
class BackupService {
  static final AesGcm _aes = AesGcm.with256bits();

  /// Tạo nội dung file sao lưu (đã mã hóa) từ toàn bộ tài khoản.
  static Future<Uint8List> createBackup(String password) async {
    final entries = await AccountStore.instance.exportPlain();
    final payload = utf8.encode(jsonEncode({
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'items': entries.map((e) => e.toJson()).toList(),
    }));

    final salt = _randomBytes(16);
    final key = await _deriveKey(password, salt, kBackupKdf);
    final box = await _aes.encrypt(payload, secretKey: key, aad: _aad);

    final file = {
      'format': _format,
      'v': _version,
      'kdf': kBackupKdf.toJson(),
      'salt': base64Encode(salt),
      'data': base64Encode(box.concatenation()),
    };
    return Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(file)));
  }

  /// Mở file sao lưu bằng mật khẩu.
  /// Ném [BackupWrongPassword] nếu sai mật khẩu, [BackupInvalidFile] nếu file hỏng.
  static Future<OpenedBackup> openBackup(
      Uint8List bytes, String password) async {
    final header = _parseHeader(bytes);
    final key = await _deriveKey(password, header.salt, header.kdf);
    try {
      final box = SecretBox.fromConcatenation(
        header.sealed,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      final clear = await _aes.decrypt(box, secretKey: key, aad: _aad);
      return _parsePayload(clear);
    } on SecretBoxAuthenticationError {
      throw BackupWrongPassword();
    } on BackupInvalidFile {
      rethrow;
    } catch (_) {
      throw BackupInvalidFile();
    }
  }

  static ({KdfParams kdf, List<int> salt, List<int> sealed}) _parseHeader(
      Uint8List bytes) {
    try {
      final file = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (file['format'] != _format || file['v'] != _version) {
        throw BackupInvalidFile();
      }
      final kdf = KdfParams.fromJson(file['kdf'] as Map<String, dynamic>);
      // Chặn file bị sửa thông số để làm treo máy (bộ nhớ quá lớn).
      if (kdf.memoryKiB < 8192 ||
          kdf.memoryKiB > 262144 ||
          kdf.iterations < 1 ||
          kdf.iterations > 10 ||
          kdf.parallelism < 1 ||
          kdf.parallelism > 4) {
        throw BackupInvalidFile();
      }
      return (
        kdf: kdf,
        salt: base64Decode(file['salt'] as String),
        sealed: base64Decode(file['data'] as String),
      );
    } catch (_) {
      throw BackupInvalidFile();
    }
  }

  static OpenedBackup _parsePayload(List<int> clear) {
    try {
      final payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      return OpenedBackup(
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(payload['createdAt'] as int),
        entries: (payload['items'] as List)
            .map((e) => PlainAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      throw BackupInvalidFile();
    }
  }
}

Future<SecretKey> _deriveKey(
    String password, List<int> salt, KdfParams kdf) async {
  // Chạy ở luồng riêng để giao diện không bị đứng.
  final bytes = await Isolate.run(() => _argon2id(password, salt, kdf));
  return SecretKey(bytes);
}

Future<List<int>> _argon2id(
    String password, List<int> salt, KdfParams kdf) async {
  final algorithm = Argon2id(
    memory: kdf.memoryKiB,
    iterations: kdf.iterations,
    parallelism: kdf.parallelism,
    hashLength: 32,
  );
  final key = await algorithm.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );
  return key.extractBytes();
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}