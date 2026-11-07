import 'package:flutter/material.dart';

import '../theme.dart';

/// Màn hình 2: Tài khoản. Tạm thời chỉ báo đã mở khóa; giai đoạn 3 sẽ làm lưới app.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài khoản',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Đã mở khóa thành công.\nLưới các app sẽ làm ở giai đoạn 3.',
                style: TextStyle(fontSize: 18, color: AppColors.textSub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}