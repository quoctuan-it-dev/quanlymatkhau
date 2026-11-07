import 'package:flutter/material.dart';

import '../services/app_channel.dart';
import '../theme.dart';
import '../widgets/app_icon.dart';

/// Màn hình 4: Chọn app để thêm (các app đang có trên điện thoại).
/// Bấm "Chọn ..." thì trả app đã chọn về màn hình trước.
class PickAppScreen extends StatefulWidget {
  const PickAppScreen({super.key});

  @override
  State<PickAppScreen> createState() => _PickAppScreenState();
}

class _PickAppScreenState extends State<PickAppScreen> {
  late final Future<List<InstalledApp>> _apps = AppChannel.getLaunchableApps();
  InstalledApp? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Chọn app',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Các app đang có trên điện thoại',
                  style: TextStyle(fontSize: 18, color: AppColors.textSub),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildGrid()),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 60,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.border, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: FilledButton(
                        onPressed: selected == null
                            ? null
                            : () => Navigator.of(context).pop(selected),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w700),
                        ),
                        child: Text(
                          selected == null
                              ? 'Chọn một app'
                              : 'Chọn ${selected.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

  Widget _buildGrid() {
    return FutureBuilder<List<InstalledApp>>(
      future: _apps,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Không lấy được danh sách app.',
              style: TextStyle(fontSize: 18, color: AppColors.error),
            ),
          );
        }
        final apps = snapshot.data ?? [];
        if (apps.isEmpty) {
          return const Center(
            child: Text(
              'Không tìm thấy app nào.',
              style: TextStyle(fontSize: 18, color: AppColors.textSub),
            ),
          );
        }
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
            mainAxisExtent: 150,
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return _AppChoice(
              app: app,
              selected: app.packageName == _selected?.packageName,
              onTap: () => setState(() => _selected = app),
            );
          },
        );
      },
    );
  }
}

/// Một ô app trong lưới; app đang chọn có vòng viền màu xanh.
class _AppChoice extends StatelessWidget {
  const _AppChoice({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  final InstalledApp app;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 3,
                ),
              ),
              child: AppIcon(
                packageName: app.packageName,
                label: app.label,
                size: 72,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              app.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.accentText : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}