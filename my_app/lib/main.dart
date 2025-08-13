import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// 웹 전용 관리자 대시보드
import 'web/admin/admin_dashboard.dart';

// ❌ 웹에서 문제되는 패키지와 없는 화면 import는 일단 주석/삭제
// import 'screens/splash_screen.dart';
// import 'presentation/screens/camera_guide_screen.dart';
// import 'presentation/screens/camera_inference_screen.dart';
// import 'screens/main_screen.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'api_services/token_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PillyApp());
}

class PillyApp extends StatelessWidget {
  const PillyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pillypilly (Web)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.amber,
        useMaterial3: true,
      ),
      home: kIsWeb ? const AdminDashboard() : const _MobilePlaceholder(),
    );
  }
}

class _MobilePlaceholder extends StatelessWidget {
  const _MobilePlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mobile entry is not implemented yet.')),
    );
  }
}
