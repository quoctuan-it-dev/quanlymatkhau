import 'package:flutter/material.dart';

/// Bảng màu "xanh công nghệ" theo mẫu giao diện đã duyệt.
class AppColors {
  static const accent = Color(0xFF2563EB); // nút chính, ổ khóa, chấm passcode
  static const accentText = Color(0xFF1D4ED8); // chữ màu nhấn trên nền sáng
  static const background = Color(0xFFF3F5F7); // nền màn hình
  static const text = Color(0xFF14232E); // chữ chính
  static const textSub = Color(0xFF5B6B76); // chữ phụ
  static const border = Color(0xFFD9E0E5); // viền
  static const error = Color(0xFFB42318); // báo lỗi
  static const dotEmpty = Color(0xFF8A99A3); // chấm passcode chưa nhập
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
}