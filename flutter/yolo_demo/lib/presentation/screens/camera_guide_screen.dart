// camera_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 풀스크린 촬영 가이드
/// - 사용자가 "다음부터 보지 않기"를 체크하면 이후부터 건너뜀
/// - 체크리스트 + 예시 이미지
class CameraGuideScreen extends StatefulWidget {
  const CameraGuideScreen({super.key});

  @override
  State<CameraGuideScreen> createState() => _CameraGuideScreenState();
}

class _CameraGuideScreenState extends State<CameraGuideScreen> {
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPref();
  }

  Future<void> _loadInitialPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final show = prefs.getBool('show_camera_guide') ?? true;
      if (!mounted) return;
      setState(() {
        // If currently "show guide" is false, checkbox should be checked (skip next time)
        _dontShowAgain = !show;
      });
    } catch (_) {
      // ignore read failures; leave default
    }
  }

  Future<void> _persistShowPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_camera_guide', !_dontShowAgain);
    debugPrint('📌 CameraGuide: set show_camera_guide=${!_dontShowAgain}');
  }

  Future<void> _onConfirm() async {
    await _persistShowPref();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/camera_inference');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: PopScope(
        canPop: true,
        onPopInvoked: (didPop) async {
          if (didPop) {
            await _persistShowPref();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
            // 본문
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 상단 타이틀
                  Text(
                    '정확도를 높이려면\n이렇게 찍어주세요',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 예시 이미지 카드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.25)),
                    ),
                    child: Column(
                      children: [
                        // 예시 이미지 (자유롭게 교체 가능)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/hi_logo.png',
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            // 예시 이미지가 없을 때 graceful fallback
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.photo_camera_back_outlined,
                              size: 120,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '예시: 단색 배경 위에 알약 한 개를 중앙에 두고 정면에서 촬영',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 체크리스트
                  _GuideBullet(
                    icon: Icons.filter_center_focus,
                    label: '알약 한 개만 프레임 중앙에 놓기',
                  ),
                  _GuideBullet(
                    icon: Icons.wb_sunny_outlined,
                    label: '정면으로, 그림자/반사 최소화',
                  ),
                  _GuideBullet(
                    icon: Icons.block,
                    label: '반으로 갈라진 약은 인식 불가',
                  ),
                  _GuideBullet(
                    icon: Icons.layers_outlined,
                    label: '배경은 단색 권장 (하얀 종이 위 추천)',
                  ),
                  const SizedBox(height: 12),

                  // "다시 보지 않기" 토글
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _dontShowAgain,
                        onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
                      ),
                      const SizedBox(width: 4),
                      const Text('다음부터는 이 가이드를 건너뛰기'),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 시작 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onConfirm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('촬영 시작하기'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 보조 안내
                  Text(
                    '설정 > 촬영 가이드에서 “다시 보기”를 켤 수 있어요.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // 상단 닫기
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await _persistShowPref();
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}

/// 체크리스트 한 줄 위젯
class _GuideBullet extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GuideBullet({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 전역 헬퍼: 촬영 진입 전에 호출해서, 설정에 따라 가이드 표시/생략
Future<void> showCameraGuideIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final show = prefs.getBool('show_camera_guide') ?? true; // 기본은 보여주기
  if (show) {
    await Navigator.pushNamed(context, '/camera_guide');
  } else {
    debugPrint('📌 CameraGuide: show_camera_guide=false, skipping guide');
    await Navigator.pushReplacementNamed(context, '/camera_inference');
  }
}
