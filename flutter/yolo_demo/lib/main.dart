import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'presentation/screens/camera_guide_screen.dart';
import 'presentation/screens/camera_inference_screen.dart';
import 'screens/main_screen.dart';
import 'web/admin_dashboard.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_services/token_service.dart';
import 'dart:io';

// RouteObserver 전역 선언
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // ✅ Web 환경이 아닐 때만 DB 관련 코드 실행
  if (!kIsWeb) {
    await printDBPath();
  }

  await _initToken();

  runApp(const PillyApp());
}

/// 디바이스 기반 user_id 생성 후 토큰 발급
Future<void> _initToken() async {

  final authService = AuthService();
  final success = await authService.fetchToken();

  if (success) {
    print("🔑 토큰 저장 완료. API 호출 준비됨");
  } else {
    print("❌ 토큰 발급 실패 - API 호출 시 인증 오류 발생 가능");
  }
}

Future<void> printDBPath() async {
  final path = await getDatabasesPath();
  print("🔍 SQLite DB 경로: $path");
}

class PillyApp extends StatelessWidget {
  const PillyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pillypilly',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        primarySwatch: Colors.grey,
        scaffoldBackgroundColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD600),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          ),
        ),
      ),
      // 웹과 모바일 환경 분리
      home: kIsWeb ? AdminDashboard() : SplashScreen(),
      routes: {
        '/camera_guide': (context) => const CameraGuideScreen(),
        '/camera_inference': (context) => const CameraInferenceScreen(),
        '/admin': (context) => AdminDashboard(),
      },
    );
  }
}