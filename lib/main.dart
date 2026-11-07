import 'package:flutter/material.dart';

import 'screens/passcode_screen.dart';
import 'security/vault.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuanLyMatKhauApp());
}

class QuanLyMatKhauApp extends StatelessWidget {
  const QuanLyMatKhauApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý mật khẩu',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const StartScreen(),
    );
  }
}

/// Kiểm tra đã có passcode chưa rồi mở màn hình "Tạo" hoặc "Nhập" passcode.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late final Future<bool> _hasPasscode = Vault.instance.hasPasscode();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasPasscode,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không đọc được dữ liệu của app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return PasscodeScreen(isCreating: !snapshot.data!);
      },
    );
  }
}