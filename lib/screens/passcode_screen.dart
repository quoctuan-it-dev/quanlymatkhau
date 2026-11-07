import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/vault.dart';
import '../theme.dart';
import 'home_screen.dart';

/// Màn hình 1: Tạo passcode (lần đầu) hoặc Nhập passcode (các lần sau).
class PasscodeScreen extends StatefulWidget {
  const PasscodeScreen({super.key, required this.isCreating});

  final bool isCreating;

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  static const _length = 6;

  String _input = '';
  String? _firstEntry; // lần nhập đầu khi tạo passcode
  String? _message; // thông báo lỗi
  bool _busy = false;
  Duration _lockLeft = Duration.zero;
  Timer? _lockTimer;

  bool get _confirming => widget.isCreating && _firstEntry != null;
  bool get _locked => _lockLeft > Duration.zero;
  bool get _keypadEnabled => !_busy && !_locked;

  @override
  void initState() {
    super.initState();
    if (!widget.isCreating) _checkLock();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLock() async {
    final left = await Vault.instance.lockRemaining();
    if (mounted) _startCountdown(left);
  }

  void _startCountdown(Duration left) {
    _lockTimer?.cancel();
    setState(() => _lockLeft = left);
    if (left <= Duration.zero) return;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _lockLeft - const Duration(seconds: 1);
      setState(() {
        _lockLeft = next > Duration.zero ? next : Duration.zero;
        if (!_locked) _message = null;
      });
      if (!_locked) timer.cancel();
    });
  }

  void _onDigit(String digit) {
    if (!_keypadEnabled || _input.length >= _length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _input += digit;
      _message = null;
    });
    if (_input.length == _length) _submit(_input);
  }

  void _onDelete() {
    if (!_keypadEnabled || _input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  Future<void> _submit(String code) async {
    if (widget.isCreating) {
      await _handleCreate(code);
    } else {
      await _handleUnlock(code);
    }
  }

  Future<void> _handleCreate(String code) async {
    if (_firstEntry == null) {
      if (isWeakPasscode(code)) {
        _showError('Passcode quá dễ đoán. Hãy chọn 6 số khác.');
        return;
      }
      setState(() {
        _firstEntry = code;
        _input = '';
      });
      return;
    }
    if (code != _firstEntry) {
      _firstEntry = null;
      _showError('Hai lần nhập không khớp. Hãy tạo lại từ đầu.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Vault.instance.createPasscode(code);
      if (mounted) _goHome();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _firstEntry = null;
      });
      _showError('Không lưu được. Hãy thử lại.');
    }
  }

  Future<void> _handleUnlock(String code) async {
    setState(() => _busy = true);
    final result = await Vault.instance.unlock(code);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case UnlockSuccess():
        _goHome();
      case UnlockWrong(:final attemptsLeft):
        _showError('Sai passcode. Còn $attemptsLeft lần thử.');
      case UnlockLocked(:final remaining):
        _showError('Nhập sai nhiều lần, app tạm khóa.');
        _startCountdown(remaining);
    }
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _input = '';
      _message = message;
    });
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return minutes > 0 ? '$minutes phút $seconds giây' : '$seconds giây';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCreating
        ? (_confirming ? 'Nhập lại passcode' : 'Tạo passcode')
        : 'Nhập passcode';
    final subtitle = widget.isCreating
        ? (_confirming ? 'Nhập lại 6 số vừa tạo' : 'Chọn 6 số bạn dễ nhớ')
        : 'Nhập 6 số để mở app';
    final bottomNote = widget.isCreating
        ? 'Lưu ý: quên passcode sẽ không lấy lại được.\nĐừng dùng ngày sinh.'
        : 'Nhập sai 5 lần sẽ bị khóa tạm 30 giây';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: AppColors.textSub),
              ),
              const SizedBox(height: 28),
              _Dots(filled: _input.length, length: _length),
              SizedBox(height: 56, child: Center(child: _buildStatus())),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _Keypad(
                      enabled: _keypadEnabled,
                      onDigit: _onDigit,
                      onDelete: _onDelete,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                bottomNote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    if (_busy) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 12),
          Text('Đang kiểm tra...',
              style: TextStyle(fontSize: 18, color: AppColors.textSub)),
        ],
      );
    }
    final text = _locked
        ? 'Thử lại sau ${_formatDuration(_lockLeft)}'
        : _message;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
      ),
    );
  }
}

/// 6 chấm tròn: chấm đặc là đã nhập, chấm viền là chưa.
class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.length});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đã nhập $filled trên $length số',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(length, (i) {
          final isFilled = i < filled;
          return Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? AppColors.accent : null,
              border: isFilled
                  ? null
                  : Border.all(color: AppColors.dotEmpty, width: 2),
            ),
          );
        }),
      ),
    );
  }
}

/// Bàn phím số do app tự vẽ: 1–9, hàng cuối gồm ô trống, 0, nút xóa.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
  });

  final bool enabled;
  final void Function(String digit) onDigit;
  final VoidCallback onDelete;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];
  static const double _size = 84;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _buildKey(key),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKey(String key) {
    if (key.isEmpty) return const SizedBox(width: _size, height: _size);

    if (key == 'del') {
      return SizedBox(
        width: _size,
        height: _size,
        child: IconButton(
          tooltip: 'Xóa số vừa nhập',
          onPressed: enabled ? onDelete : null,
          icon: const Icon(Icons.backspace_outlined, size: 34),
          color: AppColors.text,
        ),
      );
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => onDigit(key) : null,
          child: Center(
            child: Text(
              key,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w500,
                color: enabled ? AppColors.text : AppColors.dotEmpty,
              ),
            ),
          ),
        ),
      ),
    );
  }
}