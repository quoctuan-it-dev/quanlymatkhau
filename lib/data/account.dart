/// Một tài khoản đã lưu.
/// Tên đăng nhập và mật khẩu KHÔNG nằm ở đây dạng chữ thường,
/// mà nằm trong [secretBox] (đã mã hóa), chỉ giải mã khi cần dùng.
class Account {
  const Account({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.createdAt,
    required this.updatedAt,
    required this.passwordChangedAt,
    required this.secretBox,
  });

  final String id;
  final String appName; // tên hiển thị, ví dụ VNeID
  final String packageName; // để lấy biểu tượng và mở app
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime passwordChangedAt; // lần đổi mật khẩu gần nhất
  final String secretBox; // tên đăng nhập + mật khẩu đã mã hóa

  Account copyWith({
    DateTime? updatedAt,
    DateTime? passwordChangedAt,
    String? secretBox,
  }) {
    return Account(
      id: id,
      appName: appName,
      packageName: packageName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      secretBox: secretBox ?? this.secretBox,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'app': appName,
        'pkg': packageName,
        'created': createdAt.millisecondsSinceEpoch,
        'updated': updatedAt.millisecondsSinceEpoch,
        'pwChanged': passwordChangedAt.millisecondsSinceEpoch,
        'secret': secretBox,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        appName: json['app'] as String,
        packageName: json['pkg'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['created'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated'] as int),
        passwordChangedAt:
            DateTime.fromMillisecondsSinceEpoch(json['pwChanged'] as int),
        secretBox: json['secret'] as String,
      );
}

/// Phần bí mật của một tài khoản (chỉ tồn tại tạm thời sau khi giải mã).
class AccountSecret {
  const AccountSecret({
    required this.username,
    required this.password,
    this.previousPassword,
  });

  final String username;
  final String password;
  final String? previousPassword; // mật khẩu cũ gần nhất (nếu đã từng đổi)

  Map<String, dynamic> toJson() => {
        'u': username,
        'p': password,
        if (previousPassword != null) 'prev': previousPassword,
      };

  factory AccountSecret.fromJson(Map<String, dynamic> json) => AccountSecret(
        username: json['u'] as String,
        password: json['p'] as String,
        previousPassword: json['prev'] as String?,
      );
}