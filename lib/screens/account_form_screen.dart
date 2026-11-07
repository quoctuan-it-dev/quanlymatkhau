import 'package:flutter/material.dart';

import '../data/account.dart';
import '../data/account_store.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';

/// Màn hình 5: Nhập tài khoản (thêm mới) hoặc Sửa tài khoản.
/// Đóng màn hình với kết quả true nếu đã lưu hoặc xóa.
class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({
    super.key,
    required this.appName,
    required this.packageName,
    this.account,
  });

  final String appName;
  final String packageName;
  final Account? account; // có giá trị = đang sửa

  bool get isEditing => account != null;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _saving = false;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loading = true;
      _loadSecret();
    }
  }

  @override
  void dispose() {
    _username.clear();
    _password.clear();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadSecret() async {
    try {
      final secret = await AccountStore.instance.readSecret(widget.account!);
      _username.text = secret.username;
      _password.text = secret.password;
    } catch (_) {
      _showSnack('Không đọc được dữ liệu của tài khoản này.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Hãy nhập mật khẩu');
      return;
    }
    final username = _username.text.trim();
    setState(() => _saving = true);
    try {
      final store = AccountStore.instance;
      if (widget.isEditing) {
        await store.update(widget.account!,
            username: username, password: password);
      } else {
        await store.add(
          appName: widget.appName,
          packageName: widget.packageName,
          username: username,
          password: password,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Không lưu được. Hãy thử lại.');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xóa tài khoản ${widget.appName}?'),
        content: const Text(
          'Tên đăng nhập và mật khẩu đã lưu sẽ bị xóa khỏi máy. '
          'Không thể hoàn tác.',
          style: TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await AccountStore.instance.delete(widget.account!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Không xóa được. Hãy thử lại.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 17))),
    );
  }

  InputDecoration _decoration({String? hint, Widget? suffix, String? error}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 2),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSub, fontSize: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error),
      suffixIcon: suffix,
      errorText: error,
      errorStyle: const TextStyle(fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: AppIcon(
                        packageName: widget.packageName,
                        label: widget.appName,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.isEditing
                          ? 'Sửa tài khoản cho'
                          : 'Thêm tài khoản cho',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 17, color: AppColors.textSub),
                    ),
                    Text(
                      widget.appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._buildFields(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.text,
                          side: const BorderSide(
                              color: AppColors.border, width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        child: const Text('Hủy'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: FilledButton(
                        onPressed: _saving || _loading ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w700),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 3, color: Colors.white),
                              )
                            : const Text('Lưu'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    return [
      const Text(
        'Tên đăng nhập',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _username,
        style: const TextStyle(fontSize: 22, color: AppColors.text),
        decoration: _decoration(hint: 'Ví dụ: số điện thoại, email'),
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
      ),
      const SizedBox(height: 28),
      const Text(
        'Mật khẩu',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _password,
        obscureText: _obscure,
        style: const TextStyle(fontSize: 22, color: AppColors.text),
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        onChanged: (_) {
          if (_passwordError != null) setState(() => _passwordError = null);
        },
        onSubmitted: (_) => _save(),
        decoration: _decoration(
          error: _passwordError,
          suffix: IconButton(
            tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            iconSize: 26,
            color: AppColors.textSub,
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined),
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Có app chỉ cần mật khẩu, tên đăng nhập có thể để trống.',
        style: TextStyle(fontSize: 16, color: AppColors.textSub, height: 1.4),
      ),
      if (widget.isEditing) ...[
        const SizedBox(height: 32),
        Center(
          child: TextButton.icon(
            onPressed: _saving ? null : _delete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size(0, 52),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Xóa tài khoản này'),
          ),
        ),
      ],
    ];
  }
}