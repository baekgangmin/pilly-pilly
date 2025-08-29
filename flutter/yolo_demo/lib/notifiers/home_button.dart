import 'package:flutter/material.dart';
import 'package:yolo_demo/screens/main_screen.dart'; // ← 홈화면 경로 맞게 수정

/// 네비게이션 스택 비우고 홈으로
void goHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => MainScreen()),
    (route) => false,
  );
}

/// 오른쪽 하단의 동그라미 홈 버튼 (FAB)
class HomeFab extends StatelessWidget {
  final Color? bg;   // 배경색 커스터마이즈용
  final Color? fg;   // 아이콘색 커스터마이즈용
  const HomeFab({super.key, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    // 앱 팔레트: F9CB99(포인트1), 689B8A(포인트2), 280A3E(글씨)
    final defaultBg = bg ?? const Color(0xFFF9CB99);
    final defaultFg = fg ?? const Color(0xFF280A3E);

    return FloatingActionButton(
      onPressed: () => goHome(context),
      backgroundColor: defaultBg,
      foregroundColor: defaultFg,
      child: const Icon(Icons.home_rounded),
      tooltip: '홈으로',
      elevation: 4,
      shape: const CircleBorder(),
    );
  }
}