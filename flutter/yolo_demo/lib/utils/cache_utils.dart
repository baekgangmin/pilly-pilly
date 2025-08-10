import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../db_helper.dart';

Future<void> clearCache() async {
  final cacheDir = await getTemporaryDirectory();
  if (cacheDir.existsSync()) {
    final files = cacheDir.listSync();
    for (var file in files) {
      try {
        if (file is File) {
          file.deleteSync();
        } else if (file is Directory) {
          file.deleteSync(recursive: true);
        }
      } catch (e) {
        print("❌ 캐시 파일 삭제 실패: $e");
      }
    }
    print("🧹 이미지 캐시 삭제 완료");
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  print("🧹 SharedPreferences 삭제 완료");

  await DBHelper.deleteRecentPills();
  await DBHelper.deleteFavoriteFolders();
  print("✅ 전체 캐시 삭제 완료");
}