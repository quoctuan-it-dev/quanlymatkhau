import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/app_channel.dart';
import '../theme.dart';

/// Biểu tượng app: ảnh thật lấy từ điện thoại.
/// Nếu app đã bị gỡ thì hiện ô màu có chữ cái đầu của tên app.
class AppIcon extends StatefulWidget {
  const AppIcon({
    super.key,
    required this.packageName,
    required this.label,
    this.size = 80,
  });

  final String packageName;
  final String label;
  final double size;

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  late Future<Uint8List?> _icon;

  @override
  void initState() {
    super.initState();
    _icon = AppChannel.getAppIcon(widget.packageName);
  }

  @override
  void didUpdateWidget(covariant AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _icon = AppChannel.getAppIcon(widget.packageName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.size / 4);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Uint8List?>(
        future: _icon,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null) {
            return ClipRRect(
              borderRadius: radius,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            // Đang tải: hiện ô xám nhạt.
            return DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: radius,
              ),
            );
          }
          return _LetterTile(
            label: widget.label,
            size: widget.size,
            radius: radius,
          );
        },
      ),
    );
  }
}

/// Ô màu có chữ cái đầu (dùng khi app không còn trên máy).
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.label,
    required this.size,
    required this.radius,
  });

  final String label;
  final double size;
  final BorderRadius radius;

  // Các màu đều đủ tương phản với chữ trắng.
  static const _colors = [
    Color(0xFFB42318),
    Color(0xFF1D4ED8),
    Color(0xFF047857),
    Color(0xFFB45309),
    Color(0xFF6D28D9),
    Color(0xFF0E7490),
    Color(0xFFA21CAF),
    Color(0xFF3D4A53),
  ];

  @override
  Widget build(BuildContext context) {
    final name = label.trim();
    final letter =
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
    final colorIndex = name.codeUnits.fold<int>(0, (a, b) => a + b) % _colors.length;
    return DecoratedBox(
      decoration: BoxDecoration(color: _colors[colorIndex], borderRadius: radius),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}