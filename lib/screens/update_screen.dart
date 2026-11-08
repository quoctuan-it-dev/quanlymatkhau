import 'package:flutter/material.dart';

import '../services/app_channel.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/form_parts.dart';
import 'backup_screen.dart';

enum _Stage { idle, checking, upToDate, available, downloading, error }

/// Màn hình Cập nhật app: kiểm tra GitHub → tải → kiểm tra → cài đè.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  ({String name, int code})? _current;
  _Stage _stage = _Stage.idle;
  UpdateInfo? _info;
  double? _progress;
  int _lastPercent = -1;
  String? _error;

  bool get _busy =>
      _stage == _Stage.checking || _stage == _Stage.downloading;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await AppChannel.getAppVersion();
      if (mounted) setState(() => _current = v);
    } catch (_) {}
  }

  /// Chỉ lúc này app mới kết nối Internet.
  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });
    try {
      final info = await UpdateService.fetchLatest();
      final currentCode = _current?.code ?? 0;
      if (!mounted) return;
      setState(() {
        _info = info;
        _stage = info.versionCode > currentCode
            ? _Stage.available
            : _Stage.upToDate;
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    }
  }

  Future<void> _downloadAndInstall() async {
    final info = _info;
    if (info == null) return;

    // Lần đầu: phải cho phép app này mở trình cài đặt.
    if (!await AppChannel.canInstallPackages()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cần cho phép cài bản cập nhật'),
          content: const Text(
            'Ở màn hình tiếp theo, hãy bật "Cho phép từ nguồn này", '
            'rồi quay lại đây và bấm "Tải về và cài đặt" lần nữa.\n\n'
            'Chỉ cần làm một lần.',
            style: TextStyle(fontSize: 17, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Để sau', style: TextStyle(fontSize: 18)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Mở cài đặt', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
      if (ok == true) await AppChannel.openInstallPermissionSettings();
      return;
    }

    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
      _lastPercent = -1;
      _error = null;
    });
    try {
      final path = await UpdateService.download(info, (p) {
        final percent = (p * 100).floor();
        if (percent != _lastPercent && mounted) {
          _lastPercent = percent;
          setState(() => _progress = p);
        }
      });
      if (!mounted) return;
      // Quay về trạng thái "có bản mới" để lỡ bấm hủy thì cài lại được.
      setState(() => _stage = _Stage.available);
      await AppChannel.installApk(path);
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    }
  }

  Future<void> _openBackup() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BackupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                'Cập nhật app',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Phiên bản đang dùng: ${_current?.name ?? '...'}',
                style: const TextStyle(fontSize: 18, color: AppColors.textSub),
              ),
              const SizedBox(height: 24),
              const WarningBox(
                  'Nên sao lưu trước khi cập nhật, phòng khi có sự cố.'),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _openBackup,
                  style: secondaryButtonStyle(),
                  icon: const Icon(Icons.save_alt_rounded, size: 24),
                  label: const Text('Sao lưu trước'),
                ),
              ),
              const SizedBox(height: 28),
              ..._buildStage(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStage() {
    switch (_stage) {
      case _Stage.idle:
        return [
          _primaryButton('Kiểm tra bản mới', _check),
          const SizedBox(height: 8),
          const Text(
            'Chỉ lúc bấm nút này app mới kết nối Internet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSub),
          ),
        ];
      case _Stage.checking:
        return [_primaryButton(null, null, busyText: 'Đang kiểm tra...')];
      case _Stage.upToDate:
        return [
          _statusBox(Icons.check_circle_rounded, AppColors.accent,
              'Bạn đang dùng bản mới nhất.'),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: _check,
              style: secondaryButtonStyle(),
              child: const Text('Kiểm tra lại'),
            ),
          ),
        ];
      case _Stage.available:
        final info = _info!;
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Có bản mới ${info.versionName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentText,
                  ),
                ),
                if (info.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    info.notes,
                    style: const TextStyle(
                        fontSize: 17, color: AppColors.text, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton('Tải về và cài đặt', _downloadAndInstall),
          const SizedBox(height: 10),
          const Text(
            'Tải xong, Android sẽ hỏi "Cập nhật ứng dụng này?" → bấm Cập nhật. '
            'Mật khẩu đã lưu vẫn giữ nguyên.',
            style: TextStyle(
                fontSize: 15, color: AppColors.textSub, height: 1.4),
          ),
        ];
      case _Stage.downloading:
        final percent = _progress == null ? null : (_progress! * 100).round();
        return [
          Text(
            'Đang tải bản ${_info?.versionName ?? ''}...',
            style: const TextStyle(fontSize: 18, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: _progress, minHeight: 12),
          ),
          const SizedBox(height: 8),
          Text(
            percent == null ? '' : '$percent%',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: AppColors.textSub),
          ),
        ];
      case _Stage.error:
        return [
          _statusBox(Icons.error_outline_rounded, AppColors.error,
              _error ?? 'Có lỗi xảy ra.'),
          const SizedBox(height: 16),
          _primaryButton('Thử lại', _check),
        ];
    }
  }

  Widget _primaryButton(String? text, VoidCallback? onPressed,
      {String? busyText}) {
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: onPressed,
        style: primaryButtonStyle(),
        child: busyText != null ? busyLabel(busyText) : Text(text ?? ''),
      ),
    );
  }

  Widget _statusBox(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 18, color: AppColors.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}