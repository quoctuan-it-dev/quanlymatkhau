import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/backup_service.dart';
import '../services/app_channel.dart';
import '../theme.dart';
import '../widgets/form_parts.dart';
import 'restore_screen.dart';

/// Màn hình Sao lưu: tạo file sao lưu mã hóa; có lối vào Khôi phục.
/// Đóng với kết quả true nếu đã khôi phục (danh sách tài khoản thay đổi).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _confirm.clear();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _fileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'quanlymatkhau-${now.year}${two(now.month)}${two(now.day)}.qlmk';
  }

  Future<void> _createBackup() async {
    FocusScope.of(context).unfocus();
    final password = _password.text;
    final count = AccountStore.instance.items.length;

    String? error;
    if (count == 0) {
      error = 'Chưa có tài khoản nào để sao lưu.';
    } else if (password.length < kMinBackupPasswordLength) {
      error = 'Mật khẩu sao lưu cần ít nhất $kMinBackupPasswordLength ký tự.';
    } else if (password != _confirm.text) {
      error = 'Hai lần nhập không khớp.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await BackupService.createBackup(password);
      final saved = await AppChannel.saveFile(_fileName(), bytes);
      if (!mounted) return;
      setState(() => _busy = false);
      if (saved) {
        _password.clear();
        _confirm.clear();
        await _showSavedDialog(count);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy, chưa lưu file sao lưu.',
                style: TextStyle(fontSize: 17)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Không tạo được file sao lưu. Hãy thử lại.';
      });
    }
  }

  Future<void> _showSavedDialog(int count) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: AppColors.accent, size: 48),
        title: const Text('Đã sao lưu'),
        content: Text(
          'Đã lưu $count tài khoản vào file.\n\n'
          'Nhớ cất mật khẩu sao lưu ở nơi an toàn. '
          'Quên mật khẩu thì không mở được file.',
          style: const TextStyle(fontSize: 17, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Future<void> _openRestore() async {
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RestoreScreen()),
    );
    if (restored == true && mounted) Navigator.of(context).pop(true);
  }

  Widget _passwordField(TextEditingController controller, bool isLast) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      enabled: !_busy,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      style: const TextStyle(fontSize: 22, color: AppColors.text),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: isLast ? (_) => _createBackup() : null,
      decoration: appInputDecoration(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = AccountStore.instance.items.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sao lưu',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Xuất toàn bộ $count tài khoản ra một file đã mã hóa. '
                'Bạn tự chọn nơi lưu, ví dụ Google Drive.',
                style: const TextStyle(
                    fontSize: 18, color: AppColors.textSub, height: 1.4),
              ),
              const SizedBox(height: 28),
              const FieldLabel('Mật khẩu sao lưu'),
              const SizedBox(height: 10),
              _passwordField(_password, false),
              const SizedBox(height: 8),
              const Text(
                'Ít nhất 10 ký tự. Nên dùng một câu dài dễ nhớ. '
                'Không dùng passcode 6 số.',
                style: TextStyle(
                    fontSize: 16, color: AppColors.textSub, height: 1.4),
              ),
              const SizedBox(height: 20),
              const FieldLabel('Nhập lại mật khẩu sao lưu'),
              const SizedBox(height: 10),
              _passwordField(_confirm, true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const WarningBox(
                'Quên mật khẩu sao lưu thì KHÔNG mở được file. '
                'Hãy ghi lại và cất ở nơi an toàn, tách riêng khỏi điện thoại.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: _busy ? null : _createBackup,
                  style: primaryButtonStyle(),
                  child: _busy
                      ? busyLabel('Đang mã hóa...')
                      : const Text('Tạo file sao lưu'),
                ),
              ),
              const SizedBox(height: 40),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 24),
              const Text(
                'Khôi phục',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Đổi máy mới hoặc cài lại app? Lấy lại tài khoản từ file sao lưu.',
                style: TextStyle(
                    fontSize: 18, color: AppColors.textSub, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _openRestore,
                  style: secondaryButtonStyle(),
                  icon: const Icon(Icons.restore_rounded, size: 24),
                  label: const Text('Khôi phục từ file'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}