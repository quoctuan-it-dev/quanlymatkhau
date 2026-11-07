import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/backup_service.dart';
import '../services/app_channel.dart';
import '../theme.dart';
import '../widgets/form_parts.dart';

/// Màn hình Khôi phục: chọn file → nhập mật khẩu sao lưu → xem trước → khôi phục.
/// Đóng với kết quả true nếu đã khôi phục.
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _password = TextEditingController();
  Uint8List? _file;
  OpenedBackup? _opened; // nội dung đã giải mã, chỉ giữ trong lúc màn hình mở
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _opened = null;
    _file = null;
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final bytes = await AppChannel.openFile();
      if (bytes == null || !mounted) return; // bấm hủy
      setState(() {
        _file = bytes;
        _opened = null;
        _password.clear();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Không đọc được file này.');
    }
  }

  Future<void> _openFile() async {
    FocusScope.of(context).unfocus();
    final file = _file;
    if (file == null) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Hãy nhập mật khẩu sao lưu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opened = await BackupService.openBackup(file, _password.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _opened = opened;
        _password.clear();
      });
    } on BackupWrongPassword {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Sai mật khẩu sao lưu.';
      });
    } on BackupInvalidFile {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _file = null;
        _error = 'File này không phải file sao lưu của app, hoặc đã bị hỏng.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Có lỗi khi mở file. Hãy thử lại.';
      });
    }
  }

  Future<void> _restore() async {
    final opened = _opened;
    if (opened == null) return;
    final current = AccountStore.instance.items.length;
    if (current > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Thay thế dữ liệu hiện có?'),
          content: Text(
            'Toàn bộ $current tài khoản đang có trong máy sẽ bị thay bằng '
            '${opened.entries.length} tài khoản trong file. Không thể hoàn tác.',
            style: const TextStyle(fontSize: 17, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy', style: TextStyle(fontSize: 18)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Thay thế', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await AccountStore.instance.replaceAll(opened.entries);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã khôi phục ${opened.entries.length} tài khoản.',
              style: const TextStyle(fontSize: 17)),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Không khôi phục được. Hãy thử lại.';
      });
    }
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
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
                'Khôi phục',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lấy lại tài khoản từ file sao lưu đã tạo trước đó.',
                style: TextStyle(
                    fontSize: 18, color: AppColors.textSub, height: 1.4),
              ),
              const SizedBox(height: 28),
              if (opened != null)
                ..._buildPreview(opened)
              else if (_file != null)
                ..._buildPassword()
              else
                ..._buildPick(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bước 1: chọn file.
  List<Widget> _buildPick() {
    return [
      SizedBox(
        height: 64,
        child: FilledButton.icon(
          onPressed: _pickFile,
          style: primaryButtonStyle(),
          icon: const Icon(Icons.folder_open_rounded, size: 26),
          label: const Text('Chọn file sao lưu'),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'File có đuôi .qlmk, ví dụ quanlymatkhau-20261107.qlmk',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: AppColors.textSub),
      ),
    ];
  }

  /// Bước 2: nhập mật khẩu sao lưu.
  List<Widget> _buildPassword() {
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.accent),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Đã chọn file sao lưu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _pickFile,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentText,
                minimumSize: const Size(0, 48),
              ),
              child: const Text('Chọn file khác',
                  style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const FieldLabel('Mật khẩu sao lưu'),
      const SizedBox(height: 10),
      TextField(
        controller: _password,
        obscureText: _obscure,
        enabled: !_busy,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        style: const TextStyle(fontSize: 22, color: AppColors.text),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _openFile(),
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
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 64,
        child: FilledButton(
          onPressed: _busy ? null : _openFile,
          style: primaryButtonStyle(),
          child: _busy ? busyLabel('Đang giải mã...') : const Text('Mở file'),
        ),
      ),
    ];
  }

  /// Bước 3: xem trước và khôi phục.
  List<Widget> _buildPreview(OpenedBackup opened) {
    final count = opened.entries.length;
    final current = AccountStore.instance.items.length;
    final names = opened.entries.map((e) => e.appName).join(', ');
    return [
      Text(
        'File sao lưu ngày ${_formatDate(opened.createdAt)} có $count tài khoản:',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Text(
          names.isEmpty ? 'Không có tài khoản nào.' : names,
          style: const TextStyle(
              fontSize: 18, color: AppColors.text, height: 1.5),
        ),
      ),
      const SizedBox(height: 20),
      if (current > 0) ...[
        WarningBox(
            'Khôi phục sẽ THAY THẾ toàn bộ $current tài khoản đang có trong máy.'),
        const SizedBox(height: 20),
      ],
      SizedBox(
        height: 64,
        child: FilledButton(
          onPressed: _busy || count == 0 ? null : _restore,
          style: primaryButtonStyle(),
          child: _busy
              ? busyLabel('Đang khôi phục...')
              : Text('Khôi phục $count tài khoản'),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF3D4A53),
          minimumSize: const Size(0, 52),
        ),
        child: const Text('Hủy', style: TextStyle(fontSize: 18)),
      ),
    ];
  }
}