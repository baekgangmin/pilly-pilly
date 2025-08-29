import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'notifiers/font_size_notifier.dart';
import 'notifiers/cart_notifier.dart';
import 'screens/splash_screen.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'presentation/screens/camera_guide_screen.dart';
import 'presentation/screens/camera_inference_screen.dart';
import 'presentation/screens/inference_delay_screen.dart';
import 'presentation/screens/gallery_guide_screen.dart';
import 'presentation/screens/gallery_edit_screen.dart';
import 'screens/main_screen.dart';
import 'screens/recent_all_screen.dart';
import 'screens/settings_screen.dart';
import 'web/admin_dashboard.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_services/token_service.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// RouteObserver 전역 선언
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides(); // HTTP 인증서 오류 무시 (배포할땐 삭제 예정)


  await dotenv.load(fileName: ".env");
  await CompareTray.instance.init(); // 비교함 초기화

  // ✅ Web 환경이 아닐 때만 DB 관련 코드 실행
  if (!kIsWeb) {
    await printDBPath();
  }

  await _initToken();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FontSizeNotifier()),
        ChangeNotifierProvider(create: (_) => CartNotifier()),
      ],
      child: const PillyApp(),
    ),
  );
}

/// 디바이스 기반 user_id 생성 후 토큰 발급
Future<void> _initToken() async {
  final auth = AuthService();

  // 1) 이미 저장된 토큰이 있으면 먼저 유효성 체크 → 만료면 refresh 시도
  final valid = await auth.getValidToken();
  if (valid != null) {
    final userId = await auth.getUserId();
    print("🔐 유효 토큰 확보: user_id=$userId");
    return;
  }

  // 2) 저장된 refresh도 없어서 회복 불가한 경우에만 최초 발급
  final refresh = await auth.getRefreshToken();
  if (refresh == null) {
    final ok = await auth.fetchToken(); // ✅ 앱 최초 1회만
    if (ok) {
      final userId = await auth.getUserId();
      print("🔑 최초 발급 완료: user_id=$userId");
    } else {
      print("❌ 최초 발급 실패");
    }
  } else {
    // refresh는 있는데 refresh 호출이 실패한 케이스라면 서버 상태 이슈일 수 있음
    print("⚠️ refresh 존재하나 access 회복 실패. 서버 로그 확인 필요");
  }
}


Future<void> printDBPath() async {
  final path = await getDatabasesPath();
  print("🔍 SQLite DB 경로: $path");
}

class MyHttpOverrides extends HttpOverrides {  // HTTP 인증서 오류 무시 (개발용, 배포 시 삭제 예정)
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 30);
    client.maxConnectionsPerHost = 5;
    return client;
  }
}


class PillyApp extends StatelessWidget {
  const PillyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FontSizeNotifier>(
      builder: (context, fontSizeNotifier, child) {
          final scheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF689B8A), // 세이지 그린 기반 하모니 생성
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFF689B8A),      // 세이지 그린
            secondary: const Color(0xFFF9CB99),    // 코랄 오렌지
            background: const Color(0xFFF2EDD1),   // 연베이지
            surface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: const Color(0xFF280A3E),
            onBackground: const Color(0xFF280A3E),
            onSurface: const Color(0xFF280A3E),
            error: const Color(0xFFB00020),
            onError: Colors.white,
          );
        return MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: fontSizeNotifier.fontSizeFactor,
              ),
              child: child!,
            );
          },
          title: 'Pillypilly',
          debugShowCheckedModeBanner: false,
          navigatorObservers: [routeObserver],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko'),
            Locale('en'),
          ],
          locale: const Locale('ko'), // 기기 언어 무시하고 한글 고정하려면 주석 해제
          theme: ThemeData(
            useMaterial3: true,
            // 배경 기본색
            scaffoldBackgroundColor: scheme.background, // 연베이지
            // 컬러 스킴 정의
            colorScheme: scheme,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF9CB99), // 코랄 오렌지
              foregroundColor: Color(0xFF280A3E), // 딥 퍼플 텍스트/아이콘
              elevation: 0,
              centerTitle: true,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              shadowColor: Colors.black.withOpacity(0.05),
              elevation: 2,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF689B8A), // 세이지 그린
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.primary.withOpacity(0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            textTheme: const TextTheme(
              titleLarge: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF280A3E), // 딥 퍼플
              ),
              bodyMedium: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF280A3E),
              ),
            ),
          ),
          home: kIsWeb ? AdminDashboard() : SplashScreen(),
          routes: {
            '/camera_guide': (context) => const CameraGuideScreen(),
            '/camera_inference': (context) => const CameraInferenceScreen(),
            '/gallery_guide': (context) => const GalleryGuideScreen(),
            '/gallery_edit': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              final List<String> paths = (args?['paths'] as List<dynamic>? ?? const [])
                  .map((e) => e.toString())
                  .toList();
              return GalleryEditScreen(initialPaths: paths);
            },
            '/admin': (context) => AdminDashboard(),
            '/settings': (context) => const SettingsScreen(),
            '/recent': (_) => const RecentAllScreen(),
          },
        );
      },
    );
  }
}

/// 캐시 디렉토리 삭제 함수
Future<void> clearCache() async {
  final cacheDir = await getTemporaryDirectory();
  if (cacheDir.existsSync()) {
    cacheDir.deleteSync(recursive: true);
    print("🧹 캐시 삭제 완료");
  } else {
    print("⚠️ 캐시 디렉토리가 존재하지 않음");
  }
}