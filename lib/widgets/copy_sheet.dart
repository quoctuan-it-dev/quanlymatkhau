import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/account.dart';
import '../data/account_store.dart';
import '../services/app_channel.dart';
import '../theme.dart';
import 'app_icon.dart';

/// Kết quả khi đóng cửa sổ sao chép.
enum CopySheetResult { edit, deleted }

/// Màn hình 3: Cửa sổ sao chép, trượt từ dưới lên.
Future<CopySheetResult?> showCopySheet(BuildContext context, Account account) {
  return showModalBottomSheet<CopySheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CopySheet(account: account),
  );
}

enum _Field { username, password, oldPassword }

class _CopySheet extends StatefulWidget {
  const _CopySheet({required this.account});

  final Account account;

  @override
  State<_CopySheet> createState() => _CopySheetState();
}

class _CopySheetState extends State<_CopySheet> {
  static const _valueStyle = TextStyle(fontSize: 22, color: AppColors.text);
  static const _darkGrey = Color(0xFF3D4A53);

  AccountSecret? _secret; // chỉ giữ trong lúc cửa sổ đang mở
  bool _installed = true;
  bool _loading = true;
  String? _error;
  bool _obscure = true;
  bool _showOld = false;
  _Field? _copied;

  Account get _account => widget.account;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _secret = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final secret = await AccountStore.instance.readSecret(_account);
      final installed = await AppChannel.isInstalled(_account.packageName);
      _secret = secret;
      _installed = installed;
    } catch (_) {
      _error = 'Không đọc được dữ liệu của tài khoản này.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _copy(_Field field, String value) async {
    try {
      await AppChannel.copySecret(value);
    } catch (_) {
      return;
    }
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _copied = field);
  }

  Future<void> _openApp() async {
    final ok = await AppChannel.launchApp(_account.packageName);
    if (!ok && mounted) setState(() => _installed = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xóa tài khoản ${_account.appName}?'),
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
    try {
      await AccountStore.instance.delete(_account);
      if (mounted) Navigator.of(context).pop(CopySheetResult.deleted);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không xóa được. Hãy thử lại.');
    }
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  /// Che bớt tên đăng nhập, chỉ để lộ 4 ký tự cuối.
  String _mask(String s) {
    if (s.length <= 4) return s;
    return '${'•' * min(6, s.length - 4)}${s.substring(s.length - 4)}';
  }

  String get _copiedName => switch (_copied) {
        _Field.username => 'tên đăng nhập',
        _Field.password => 'mật khẩu',
        _Field.oldPassword => 'mật khẩu cũ',
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.error),
              ),
            )
          else
            ..._buildBody(_secret!),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AppIcon(
          packageName: _account.packageName,
          label: _account.appName,
          size: 64,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _account.appName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Đổi mật khẩu lần cuối: ${_formatDate(_account.passwordChangedAt)}',
                style: const TextStyle(fontSize: 15, color: AppColors.textSub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBody(AccountSecret s) {
    return [
      if (s.username.isNotEmpty) ...[
        _label('Tên đăng nhập'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _valueBox(Text(
                _mask(s.username),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _valueStyle,
              )),
            ),
            const SizedBox(width: 10),
            _copyButton(_Field.username, s.username),
          ],
        ),
        const SizedBox(height: 18),
      ],
      _label('Mật khẩu'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _valueBox(Row(
              children: [
                Expanded(
                  child: Text(
                    _obscure ? '••••••••••' : s.password,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _valueStyle,
                  ),
                ),
                IconButton(
                  tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  iconSize: 26,
                  color: AppColors.textSub,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ],
            )),
          ),
          const SizedBox(width: 10),
          _copyButton(_Field.password, s.password),
        ],
      ),
      if (s.previousPassword != null) ...[
        const SizedBox(height: 8),
        if (_showOld)
          _buildOldBox(s.previousPassword!)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showOld = true),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentText,
                minimumSize: const Size(0, 44),
                padding: EdgeInsets.zero,
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
              icon: const Icon(Icons.history_rounded, size: 22),
              label: const Text('Xem mật khẩu cũ'),
            ),
          ),
      ],
      const SizedBox(height: 20),
      if (!_installed) ...[
        _buildNotInstalled(),
        const SizedBox(height: 16),
      ],
      SizedBox(
        height: 64,
        child: FilledButton(
          onPressed: _installed ? _openApp : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: _darkGrey,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _installed
                      ? 'Mở ${_account.appName}'
                      : 'Chưa cài ${_account.appName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_installed) ...[
                const SizedBox(width: 10),
                const Icon(Icons.north_east_rounded, size: 24),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (_copied != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '✓ Đã chép $_copiedName · tự xóa sau $kClipboardClearMinutes phút',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.accentText,
            ),
          ),
        ),
      if (_installed)
        const Text(
          'Sao chép xong, bấm Mở rồi giữ ngón tay vào ô và chọn Dán',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppColors.textSub, height: 1.4),
        ),
      const SizedBox(height: 12),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(CopySheetResult.edit),
            style: TextButton.styleFrom(
              foregroundColor: _darkGrey,
              minimumSize: const Size(80, 48),
              textStyle:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            child: const Text('Sửa'),
          ),
          const SizedBox(width: 24),
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              minimumSize: const Size(80, 48),
              textStyle:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ];
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.textSub,
      ),
    );
  }

  Widget _valueBox(Widget child) {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 4),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  /// Nút Sao chép; sau khi bấm đổi thành nút xanh "✓ Đã chép".
  Widget _copyButton(_Field field, String value, {bool subtle = false}) {
    final copied = _copied == field;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const textStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    return SizedBox(
      height: 56,
      child: copied
          ? FilledButton.icon(
              onPressed: () => _copy(field, value),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: shape,
                textStyle: textStyle,
                padding: padding,
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Đã chép'),
            )
          : OutlinedButton(
              onPressed: () => _copy(field, value),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: subtle ? _darkGrey : AppColors.accentText,
                side: BorderSide(
                  color: subtle ? AppColors.border : AppColors.accent,
                  width: 2,
                ),
                shape: shape,
                textStyle: textStyle,
                padding: padding,
              ),
              child: const Text('Sao chép'),
            ),
    );
  }

  /// Khung "Mật khẩu cũ" (chỉ hiện khi bấm "Xem mật khẩu cũ").
  Widget _buildOldBox(String old) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mật khẩu cũ (dùng trước ${_formatDate(_account.passwordChangedAt)})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSub,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showOld = false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentText,
                  minimumSize: const Size(48, 44),
                ),
                child: const Text('Ẩn', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _valueBox(Text(
                  old,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, color: _darkGrey),
                )),
              ),
              const SizedBox(width: 10),
              _copyButton(_Field.oldPassword, old, subtle: true),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Chỉ dùng khi vừa đổi mật khẩu mà app báo chưa đổi được.',
            style: TextStyle(fontSize: 15, color: AppColors.textSub, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Khung báo app đích đã bị gỡ.
  Widget _buildNotInstalled() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF9A4A06)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chưa cài app này trên điện thoại. '
              'Bạn vẫn sao chép được tên đăng nhập và mật khẩu.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B3304),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}