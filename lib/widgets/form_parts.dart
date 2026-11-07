import 'package:flutter/material.dart';

import '../theme.dart';

/// Kiểu ô nhập chữ lớn, viền bo tròn (dùng chung cho các màn hình).
InputDecoration appInputDecoration({String? hint, Widget? suffix}) {
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
    disabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.accent),
    suffixIcon: suffix,
  );
}

/// Kiểu nút chính (nền xanh).
ButtonStyle primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.accent,
    disabledBackgroundColor: const Color(0xFF93B4F5),
    disabledForegroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
  );
}

/// Kiểu nút phụ (nền trắng, viền xám).
ButtonStyle secondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.accentText,
    side: const BorderSide(color: AppColors.border, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
  );
}

/// Chữ "Đang ..." kèm vòng xoay, đặt trong nút khi đang xử lý.
Widget busyLabel(String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Text(text),
    ],
  );
}

/// Nhãn đậm phía trên ô nhập.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }
}

/// Khung cảnh báo màu cam.
class WarningBox extends StatelessWidget {
  const WarningBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A4A06)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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