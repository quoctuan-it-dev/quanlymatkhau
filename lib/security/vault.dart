import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kết quả khi thử mở khóa bằng passcode.
sealed class UnlockResult {}

class UnlockSuccess extends UnlockResult {}

class UnlockWrong extends UnlockResult {
  UnlockWrong(this.attemptsLeft);
  final int attemptsLeft; // còn bao nhiêu lần thử trước khi bị khóa tạm
}

class UnlockLocked extends UnlockResult {
  UnlockLocked(this.remaining);
  final Duration remaining; // còn bao lâu mới được thử lại
}

/// Thông số của Argon2id (hàm tạo khóa từ passcode, cố ý chạy chậm để chống dò).
/// Được lưu kèm dữ liệu, nên sau này tăng thông số vẫn mở được dữ liệu cũ.
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, dynamic> toJson() => {
        'alg': 'argon2id',
        'm': memoryKiB,
        't': iterations,
        'p': parallelism,
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
        memoryKiB: json['m'] as int,
        iterations: json['t'] as int,
        parallelism: json['p'] as int,
      );
}

/// Mức tối thiểu OWASP khuyến nghị cho Argon2id: 19 MiB bộ nhớ, 2 vòng, 1 luồng.
const KdfParams kDefaultKdf =
    KdfParams(memoryKiB: 19456, iterations: 2, parallelism: 1);

/// Nhập sai bao nhiêu lần thì bắt đầu khóa tạm.
const int kMaxFreeAttempts = 5;

/// Thời gian khóa tăng dần sau mỗi lần sai tiếp theo.
const List<Duration> kLockSteps = [
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(hours: 1),
];

// Tên các mục trong kho lưu trữ an toàn (v1 = phiên bản định dạng).
const _kSalt = 'v1_salt';
const _kKdf = 'v1_kdf';
const _kWrappedKey = 'v1_wrapped_key';
const _kFailCount = 'v1_fail_count';
const _kLockUntil = 'v1_lock_until';

const _nonceLength = 12; // AES-GCM nonce 96 bit
const _macLength = 16; // AES-GCM tag 128 bit

/// Quản lý passcode và "chìa khóa dữ liệu".
///
/// Cách hoạt động:
/// - Chìa khóa dữ liệu: 256 bit ngẫu nhiên, dùng để mã hóa tài khoản (giai đoạn 3).
/// - Lớp khóa 1: chìa khóa dữ liệu được mã hóa AES-256-GCM bằng một khóa
///   tạo từ passcode qua Argon2id (có salt ngẫu nhiên).
/// - Lớp khóa 2: kết quả được cất trong flutter_secure_storage, vốn mã hóa
///   bằng khóa nằm trong Android Keystore của chính điện thoại này.
/// - Sai passcode thì giải mã AES-GCM thất bại, nên không cần lưu passcode.
class Vault {
  Vault._();
  static final Vault instance = Vault._();

  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final AesGcm _aes = AesGcm.with256bits();

  SecretKey? _dataKey;

  /// Chìa khóa dữ liệu, chỉ có sau khi mở khóa thành công (chỉ nằm trong RAM).
  SecretKey? get dataKey => _dataKey;
  bool get isUnlocked => _dataKey != null;

  /// Đã tạo passcode chưa (để biết hiện màn hình "Tạo" hay "Nhập").
  Future<bool> hasPasscode() async {
    return (await _storage.read(key: _kWrappedKey)) != null;
  }

  /// Tạo passcode lần đầu: sinh chìa khóa dữ liệu mới và khóa nó lại.
  Future<void> createPasscode(String passcode) async {
    final salt = _randomBytes(16);
    final dataKey = await _aes.newSecretKey();
    final dataKeyBytes = await dataKey.extractBytes();

    final passKey = await _deriveKey(passcode, salt, kDefaultKdf);
    final box = await _aes.encrypt(dataKeyBytes, secretKey: passKey);

    await _storage.write(key: _kKdf, value: jsonEncode(kDefaultKdf.toJson()));
    await _storage.write(key: _kSalt, value: base64Encode(salt));
    await _resetFails();
    // Ghi mục này sau cùng: chỉ khi có nó thì app mới coi là đã có passcode.
    await _storage.write(
        key: _kWrappedKey, value: base64Encode(box.concatenation()));

    _dataKey = dataKey;
  }

  /// Thử mở khóa bằng passcode.
  Future<UnlockResult> unlock(String passcode) async {
    final locked = await lockRemaining();
    if (locked > Duration.zero) return UnlockLocked(locked);

    // Tăng bộ đếm TRƯỚC khi kiểm tra: nếu app bị tắt ngang lúc đang kiểm tra,
    // lần thử đó vẫn bị tính, không lách được giới hạn.
    final fails = await _readFails() + 1;
    await _storage.write(key: _kFailCount, value: '$fails');

    final salt = base64Decode((await _storage.read(key: _kSalt))!);
    final kdf = KdfParams.fromJson(
        jsonDecode((await _storage.read(key: _kKdf))!) as Map<String, dynamic>);
    final wrapped = base64Decode((await _storage.read(key: _kWrappedKey))!);

    final passKey = await _deriveKey(passcode, salt, kdf);
    try {
      final box = SecretBox.fromConcatenation(
        wrapped,
        nonceLength: _nonceLength,
        macLength: _macLength,
      );
      final keyBytes = await _aes.decrypt(box, secretKey: passKey);
      _dataKey = SecretKey(keyBytes);
      await _resetFails();
      return UnlockSuccess();
    } on SecretBoxAuthenticationError {
      if (fails >= kMaxFreeAttempts) {
        final step = min(fails - kMaxFreeAttempts, kLockSteps.length - 1);
        final duration = kLockSteps[step];
        final until = DateTime.now().add(duration).millisecondsSinceEpoch;
        await _storage.write(key: _kLockUntil, value: '$until');
        return UnlockLocked(duration);
      }
      return UnlockWrong(kMaxFreeAttempts - fails);
    }
  }

  /// Còn bị khóa tạm bao lâu (0 nếu không bị khóa).
  Future<Duration> lockRemaining() async {
    final until = int.tryParse(await _storage.read(key: _kLockUntil) ?? '') ?? 0;
    final diff = until - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? Duration(milliseconds: diff) : Duration.zero;
  }

  Future<int> _readFails() async {
    return int.tryParse(await _storage.read(key: _kFailCount) ?? '') ?? 0;
  }

  Future<void> _resetFails() async {
    await _storage.write(key: _kFailCount, value: '0');
    await _storage.write(key: _kLockUntil, value: '0');
  }

  static Future<SecretKey> _deriveKey(
      String passcode, List<int> salt, KdfParams kdf) async {
    // Chạy Argon2id ở luồng riêng để giao diện không bị đứng.
    final bytes = await Isolate.run(() => _argon2id(passcode, salt, kdf));
    return SecretKey(bytes);
  }
}

/// Hàm đứng riêng (không nằm trong class) để chạy được trong Isolate.
Future<List<int>> _argon2id(
    String passcode, List<int> salt, KdfParams kdf) async {
  final algorithm = Argon2id(
    memory: kdf.memoryKiB,
    iterations: kdf.iterations,
    parallelism: kdf.parallelism,
    hashLength: 32,
  );
  final key = await algorithm.deriveKeyFromPassword(
    password: passcode,
    nonce: salt,
  );
  return key.extractBytes();
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

/// Passcode quá dễ đoán: 6 số giống nhau, dãy tăng/giảm, lặp lại (123123, 121212).
bool isWeakPasscode(String code) {
  final d = code.codeUnits.map((c) => c - 48).toList();
  bool stepsBy(int s) {
    for (var i = 1; i < d.length; i++) {
      if (d[i] - d[i - 1] != s) return false;
    }
    return true;
  }

  if (stepsBy(0) || stepsBy(1) || stepsBy(-1)) return true;
  if (code.substring(0, 3) == code.substring(3)) return true;
  if (code.substring(0, 2) == code.substring(2, 4) &&
      code.substring(2, 4) == code.substring(4)) {
    return true;
  }
  return false;
}