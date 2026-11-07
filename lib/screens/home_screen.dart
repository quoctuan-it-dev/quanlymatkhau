import 'dart:math';

import 'package:flutter/material.dart';

import '../data/account.dart';
import '../data/account_store.dart';
import '../services/app_channel.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';
import 'account_form_screen.dart';
import 'pick_app_screen.dart';

/// Màn hình 2: Tài khoản (màn hình chính) — lưới biểu tượng 3 cột.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await AccountStore.instance.load();
    } catch (_) {
      _error = 'Không đọc được dữ liệu đã lưu.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Thêm app: chọn app → nhập tài khoản → lưu.
  Future<void> _addAccount() async {
    final app = await Navigator.of(context).push<InstalledApp>(
      MaterialPageRoute(builder: (_) => const PickAppScreen()),
    );
    if (app == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(
          appName: app.label,
          packageName: app.packageName,
        ),
      ),
    );
    if (saved == true && mounted) setState(() {});
  }

  /// Bấm vào một app. Giai đoạn 4 sẽ đổi thành cửa sổ sao chép.
  Future<void> _openAccount(Account account) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(
          appName: account.appName,
          packageName: account.packageName,
          account: account,
        ),
      ),
    );
    if (changed == true && mounted) setState(() {});
  }

  void _comingSoon(String feature, int stage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature sẽ có ở giai đoạn $stage.',
            style: const TextStyle(fontSize: 17)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Tài khoản',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Bấm vào app để lấy mật khẩu',
                  style: TextStyle(fontSize: 18, color: AppColors.textSub),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(child: _buildBody()),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _BottomButton(
                      icon: Icons.save_alt_rounded,
                      label: 'Sao lưu',
                      onPressed: () => _comingSoon('Sao lưu', 5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BottomButton(
                      icon: Icons.system_update_alt_rounded,
                      label: 'Cập nhật app',
                      onPressed: () => _comingSoon('Cập nhật app', 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: AppColors.error),
        ),
      );
    }
    final items = AccountStore.instance.items;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 8,
        mainAxisExtent: 156,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) return _AddTile(onTap: _addAccount);
        final account = items[index];
        return _AccountTile(
          account: account,
          onTap: () => _openAccount(account),
        );
      },
    );
  }
}

/// Một ô app đã lưu: biểu tượng thật + tên app.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.onTap});

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          AppIcon(
            packageName: account.packageName,
            label: account.appName,
            size: 80,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              account.appName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Ô "Thêm app": ô vuông viền nét đứt màu xanh, có dấu +.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        children: [
          CustomPaint(
            painter: _DashedBorderPainter(),
            child: const SizedBox(
              width: 80,
              height: 80,
              child: Icon(Icons.add_rounded, size: 40, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thêm app',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.accentText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    ).deflate(1.5);
    canvas.drawRRect(rrect, Paint()..color = Colors.white);

    final stroke = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = min(distance + 8, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nút dưới cùng: "Sao lưu" và "Cập nhật app".
class _BottomButton extends StatelessWidget {
  const _BottomButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.accentText,
          side: const BorderSide(color: AppColors.border, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 24),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}