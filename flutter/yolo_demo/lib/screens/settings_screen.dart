import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifiers/font_size_notifier.dart';
import '../utils/cache_utils.dart';
import '../db_helper.dart';
import '../api_services/token_service.dart';

const String kShowCameraGuideKey = 'show_camera_guide';
const String kShowGalleryGuideKey = 'show_gallery_guide';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCameraGuide = true;
  bool _showGalleryGuide = true;
  bool _loadingGuidePref = true;

  @override
  void initState() {
    super.initState();
    _loadGuidePref();
  }

  Future<void> _loadGuidePref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showCameraGuide = prefs.getBool(kShowCameraGuideKey) ?? true;
        _showGalleryGuide = prefs.getBool(kShowGalleryGuideKey) ?? true;
        _loadingGuidePref = false;
      });
    } catch (_) {
      setState(() {
        _showCameraGuide = true;
        _loadingGuidePref = false;
      });
    }
  }

  Future<void> _setShowGuide(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kShowCameraGuideKey, value);
    if (mounted) {
      debugPrint('📌 Settings: set $kShowCameraGuideKey=$value');
      setState(() => _showCameraGuide = value);
    }
  }

  Future<void> _setShowGalleryGuide(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kShowGalleryGuideKey, value);
    if (mounted) {
      debugPrint('📌 Settings: set $kShowGalleryGuideKey=$value');
      setState(() => _showGalleryGuide = value);
    }
  }

  void _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('캐시 삭제 확인'),
        content: Text('즐겨찾기, 최근검색이력 등 모든 기록이 삭제됩니다.\n그래도 삭제하시겠습니까?'),
        actions: [
          TextButton(
            child: Text('아니오'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('예'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await clearCache(); // 캐시 삭제 함수 호출
        final authService = AuthService();
        await authService.fetchToken();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('쌓인 기록이 삭제되었습니다.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('쌓인 기록 삭제 실패: $e')),
        );
      }
    }
  }

  void _openFeedbackForm() async {
    const url = 'https://docs.google.com/forms/d/e/1FAIpQLSdDx9mAPyTwF9_nYtBtGt91DrTTQCfJ-4pJsXtiJTVJ7EE37g/viewform?usp=header';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('환경설정'),
      ),
      body: _loadingGuidePref
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text('쌓인 기록 지우기'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => _clearCache(context),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text('글씨 크기 조정'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => FontSizeSettingsScreen(),
                    ));
                  },
                ),
                ListTile(
                  title: Text('앱 버전 정보'),
                  subtitle: Text('v1.0.0'),
                ),
                ListTile(
                  title: Text('문의하기 / 피드백'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _openFeedbackForm,
                ),
                SwitchListTile.adaptive(
                  title: const Text('촬영 가이드 보기'),
                  subtitle: const Text('카메라 촬영 진입 시 안내 팝업 표시'),
                  value: _showCameraGuide,
                  onChanged: (v) => _setShowGuide(v),
                ),
                SwitchListTile.adaptive(
                  title: const Text('갤러리 가이드 보기'),
                  subtitle: const Text('앨범 선택 진입 시 안내 팝업 표시'),
                  value: _showGalleryGuide,
                  onChanged: (v) => _setShowGalleryGuide(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideDialog(BuildContext context) {
    bool dontShowAgain = false;
    return StatefulBuilder(
      builder: (context, setStateSB) {
        return AlertDialog(
          title: const Text('촬영 가이드'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('정확도를 높이려면 이렇게 찍어주세요:'),
                SizedBox(height: 8),
                Text('• 알약 한 개만 프레임 중앙에 놓기'),
                Text('• 정면으로, 그림자/반사 최소화'),
                Text('• 반으로 갈라진 약은 인식 불가'),
                Text('• 배경은 단색 권장(하얀 종이 위 추천)'),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Checkbox(
                  value: dontShowAgain,
                  onChanged: (v) {
                    setStateSB(() => dontShowAgain = v ?? false);
                  },
                ),
                const Expanded(child: Text('다시 보지 않기')),
                TextButton(
                  onPressed: () async {
                    if (dontShowAgain) {
                      await _setShowGuide(false);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

}

class FontSizeSettingsScreen extends StatefulWidget {
  @override
  _FontSizeSettingsScreenState createState() => _FontSizeSettingsScreenState();
}

class _FontSizeSettingsScreenState extends State<FontSizeSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final fontSizeNotifier = Provider.of<FontSizeNotifier>(context);
    double currentFontSize = fontSizeNotifier.fontSize;

    return Scaffold(
      appBar: AppBar(title: Text('글씨 크기 조정')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('작게'),
              Expanded(
                child: Slider.adaptive(
                  min: 12,
                  max: 26,
                  divisions: 9,
                  value: currentFontSize,
                  onChanged: (value) {
                    fontSizeNotifier.setFontSize(value);
                  },
                ),
              ),
              Text('크게'),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                '미리보기 텍스트',
                style: TextStyle(fontSize: currentFontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCameraGuideIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final show = prefs.getBool(kShowCameraGuideKey) ?? true;
  debugPrint('📌 CameraGuide: $kShowCameraGuideKey=$show');
  if (!show) return;

  bool dontShowAgain = false;
  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: const Text('촬영 가이드'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('정확도를 높이려면 이렇게 찍어주세요:'),
                  SizedBox(height: 8),
                  Text('• 알약 한 개만 프레임 중앙에 놓기'),
                  Text('• 정면으로, 그림자/반사 최소화'),
                  Text('• 반으로 갈라진 약은 인식 불가'),
                  Text('• 배경은 단색 권장(하얀 종이 위 추천)'),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Checkbox(
                    value: dontShowAgain,
                    onChanged: (v) {
                      setStateSB(() => dontShowAgain = v ?? false);
                    },
                  ),
                  const Expanded(child: Text('다시 보지 않기')),
                  TextButton(
                    onPressed: () async {
                      if (dontShowAgain) {
                        await prefs.setBool(kShowCameraGuideKey, false);
                        debugPrint('📌 CameraGuide: set $kShowCameraGuideKey=false');
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('확인'),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}