import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/vault.dart';
import 'account.dart';

/// Lưu, đọc, sửa, xóa tài khoản. Mọi thứ đều mã hóa bằng chìa khóa dữ liệu
/// (chỉ có sau khi nhập đúng passcode).
///
/// - Lớp ngoài: cả danh sách mã hóa AES-256-GCM thành một khối.
/// - Lớp trong: tên đăng nhập + mật khẩu của từng tài khoản mã hóa riêng,
///   gắn với id của tài khoản đó (không tráo khối này sang tài khoản khác được).
class AccountStore {
  AccountStore._();
  static final AccountStore instance = AccountStore._();

  static const _kAccounts = 'v1_accounts';
  static const _nonceLength = 12;
  static const _macLength = 16;
  static final List<int> _outerAad = utf8.encode('accounts-v1');

  final FlutterSecureStorage _storage = FlutterSecureStorage();
  final AesGcm _aes = AesGcm.with256bits();

  List<Account> _items = [];

  /// Danh sách tài khoản (chỉ đọc).
  List<Account> get items => List.unmodifiable(_items);

  SecretKey get _key {
    final key = Vault.instance.dataKey;
    if (key == null) throw StateError('App chưa được mở khóa');
    return key;
  }

  /// Đọc danh sách từ máy (gọi sau khi mở khóa).
  Future<void> load() async {
    final stored = await _storage.read(key: _kAccounts);
    if (stored == null) {
      _items = [];
      return;
    }
    final clear = await _decrypt(base64Decode(stored), _outerAad);
    final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    _items = (json['items'] as List)
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Giải mã tên đăng nhập + mật khẩu của một tài khoản.
  Future<AccountSecret> readSecret(Account account) async {
    final clear = await _decrypt(
        base64Decode(account.secretBox), utf8.encode(account.id));
    return AccountSecret.fromJson(
        jsonDecode(utf8.decode(clear)) as Map<String, dynamic>);
  }

  Future<void> add({
    required String appName,
    required String packageName,
    required String username,
    required String password,
  }) async {
    final id = _newId();
    final now = DateTime.now();
    final secretBox = await _sealSecret(
        id, AccountSecret(username: username, password: password));
    final account = Account(
      id: id,
      appName: appName,
      packageName: packageName,
      createdAt: now,
      updatedAt: now,
      passwordChangedAt: now,
      secretBox: secretBox,
    );
    await _save([..._items, account]);
  }

  /// Sửa tài khoản. Nếu mật khẩu đổi thì giữ lại mật khẩu cũ gần nhất.
  Future<void> update(
    Account account, {
    required String username,
    required String password,
  }) async {
    final old = await readSecret(account);
    final changed = old.password != password;
    final secret = AccountSecret(
      username: username,
      password: password,
      previousPassword: changed ? old.password : old.previousPassword,
    );
    final now = DateTime.now();
    final updated = account.copyWith(
      updatedAt: now,
      passwordChangedAt: changed ? now : null,
      secretBox: await _sealSecret(account.id, secret),
    );
    await _save([for (final a in _items) a.id == account.id ? updated : a]);
  }

  Future<void> delete(Account account) async {
    await _save(_items.where((a) => a.id != account.id).toList());
  }

  /// Giải mã toàn bộ tài khoản (chỉ dùng để tạo file sao lưu).
  Future<List<PlainAccount>> exportPlain() async {
    final result = <PlainAccount>[];
    for (final a in _items) {
      result.add(PlainAccount(
        appName: a.appName,
        packageName: a.packageName,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        passwordChangedAt: a.passwordChangedAt,
        secret: await readSecret(a),
      ));
    }
    return result;
  }

  /// Thay TOÀN BỘ dữ liệu bằng danh sách từ file sao lưu.
  /// Mỗi tài khoản được mã hóa lại bằng chìa khóa của máy này.
  Future<void> replaceAll(List<PlainAccount> entries) async {
    final next = <Account>[];
    for (final e in entries) {
      final id = _newId();
      next.add(Account(
        id: id,
        appName: e.appName,
        packageName: e.packageName,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        passwordChangedAt: e.passwordChangedAt,
        secretBox: await _sealSecret(id, e.secret),
      ));
    }
    await _save(next);
  }
  // ---- phần nội bộ ----

  /// Ghi xuống máy trước, thành công rồi mới cập nhật danh sách đang hiện.
  Future<void> _save(List<Account> next) async {
    final json = jsonEncode({
      'v': 1,
      'items': next.map((a) => a.toJson()).toList(),
    });
    final sealed = await _encrypt(utf8.encode(json), _outerAad);
    await _storage.write(key: _kAccounts, value: base64Encode(sealed));
    _items = next;
  }

  Future<String> _sealSecret(String id, AccountSecret secret) async {
    final sealed = await _encrypt(
        utf8.encode(jsonEncode(secret.toJson())), utf8.encode(id));
    return base64Encode(sealed);
  }

  Future<List<int>> _encrypt(List<int> data, List<int> aad) async {
    final box = await _aes.encrypt(data, secretKey: _key, aad: aad);
    return box.concatenation();
  }

  Future<List<int>> _decrypt(List<int> sealed, List<int> aad) async {
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    return _aes.decrypt(box, secretKey: _key, aad: aad);
  }

  String _newId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}