// gallery_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// 갤러리 가이드 화면 (카메라 가이드와 UI 톤/구성 일치)
/// - 체크박스: "다음부터 이 가이드를 건너뛰기"
/// - 하단 버튼: [닫기], [사진 선택하기]
/// - 이 화면에서 바로 이미지 선택(파일 피커)까지 수행
class GalleryGuideScreen extends StatefulWidget {
  const GalleryGuideScreen({Key? key}) : super(key: key);

  @override
  State<GalleryGuideScreen> createState() => _GalleryGuideScreenState();
}

class _GalleryGuideScreenState extends State<GalleryGuideScreen> {
  bool _skipNext = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPref();
  }

  Future<void> _loadInitialPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final show = prefs.getBool('show_gallery_guide') ?? true; // 기본은 보여주기
      if (!mounted) return;
      setState(() {
        // show=true(보여줌) -> 체크박스 false, show=false(건너뜀) -> 체크박스 true
        _skipNext = !show;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _persistSkipFlag(bool skip) async {
    final prefs = await SharedPreferences.getInstance();
    // skip=true -> 다음부터 건너뛰기 => show_gallery_guide=false
    await prefs.setBool('show_gallery_guide', !skip);
  }

  Future<void> _startPick() async {
    // 체크 상태 저장
    await _persistSkipFlag(_skipNext);

    try {
      final files = await pickNonLiveImages(context, maxAssets: 1);
      if (!mounted) return;

      if (files.isEmpty) {
        // 선택 취소 또는 라이브 사진만 선택된 경우
        return;
      }

      final paths = files.map((f) => f.path).toList();

      Navigator.pushReplacementNamed(
        context,
        '/gallery_edit',
        arguments: {'paths': paths},
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('선택 오류'),
          content: Text('이미지 선택 중 문제가 발생했어요.\n$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 상단 타이틀 (카메라 가이드와 톤/서체 맞춤)
                  Text(
                    '정확도를 높이려면\n이렇게 선택해 주세요',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 예시 이미지 카드 (카메라 가이드와 동일 스타일)
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/hi_logo.png',
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.photo_library_outlined,
                              size: 120,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '예시: 단색 배경 위에 알약 한 개를 중앙에 두고 선명한 사진 선택',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 체크리스트 (카메라 가이드 구성과 유사)
                  const _GuideRow(icon: Icons.filter_center_focus, text: '알약 한 개만 프레임 중앙에 선명하게 보이는 사진'),
                  const _GuideRow(icon: Icons.center_focus_strong, text: '흐릿/손떨림 없는 사진 권장'),
                  const _GuideRow(icon: Icons.block, text: 'Live/동영상/움직이는 포맷은 불가 — 정지 이미지만'),
                  const _GuideRow(icon: Icons.layers_outlined, text: '배경은 단색 권장 (하얀 종이 위 추천)'),
                  const SizedBox(height: 12),

                  // "다시 보지 않기" 토글
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _skipNext,
                        onChanged: (v) => setState(() => _skipNext = v ?? false),
                      ),
                      const SizedBox(width: 4),
                      const Text('다음부터는 이 가이드를 건너뛰기'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 사진 선택 버튼 (녹색 계열 톤)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startPick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6BA88E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('사진 선택하기'),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    '설정 > 앨범 가이드에서 "다시 보기"를 켤 수 있어요.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // 상단 닫기 버튼 (카메라 가이드와 동일 위치/동작)
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuideRow({Key? key, required this.icon, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// 라이브 사진을 그리드에서 숨기고, 혹시라도 선택에 섞여 들어오면 즉시 안내 다이얼로그를 띄운 뒤 제외합니다.
Future<List<File>> pickNonLiveImages(BuildContext context, {int maxAssets = 1}) async {
  // 1) 그리드 단계에서 라이브 사진 제외
  final filter = FilterOptionGroup(
    containsLivePhotos: false, // iOS Live Photo 사전 제외
    orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  final assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: AssetPickerConfig(
      requestType: RequestType.image,
      maxAssets: maxAssets,
      filterOptions: filter, // iOS Live Photo 제외
    ),
  );

  if (assets == null || assets.isEmpty) {
    return [];
  }

  final out = <File>[];
  bool blockedLiveFound = false;

  for (final a in assets) {
    try {
      // 방어적: 드물게 isLivePhoto가 true로 들어오는 경우 차단
      if (a.isLivePhoto == true) {
        blockedLiveFound = true;
        continue;
      }
      final f = await a.file;
      if (f != null) out.add(f);
    } catch (_) {}
  }

  if (blockedLiveFound) {
    // 작은 다이얼로그로 즉시 안내 (갤러리 화면을 벗어나지 않음)
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('라이브 사진은 지원하지 않아요'),
        content: const Text('갤러리에서 라이브 아이콘을 해제하고 다시 선택해 주세요.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  return out;
}

/// 전역 헬퍼: 앨범 진입 전에 호출해서, 설정에 따라 가이드 표시/생략
Future<void> showGalleryGuideIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final show = prefs.getBool('show_gallery_guide') ?? true; // 기본은 보여주기
  if (show) {
    await Navigator.pushNamed(context, '/gallery_guide');
    return;
  }
  // 가이드를 건너뛰는 경우: 즉시 사진 선택 -> 에디트 화면으로
  try {
    final files = await pickNonLiveImages(context, maxAssets: 1);
    if (files.isEmpty) {
      // 사용자가 취소하거나 라이브만 골라서 필터링된 경우: 그냥 복귀
      return;
    }
    final paths = files.map((f) => f.path).toList();
    if (context.mounted) {
      await Navigator.pushNamed(
        context,
        '/gallery_edit',
        arguments: {'paths': paths},
      );
    }
  } catch (e) {
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('선택 오류'),
          content: Text('이미지 선택 중 문제가 발생했어요.\n$e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
        ),
      );
    }
  }
}