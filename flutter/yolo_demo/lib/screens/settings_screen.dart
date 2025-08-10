import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/painting.dart';
import '../notifiers/font_size_notifier.dart';
import '../utils/cache_utils.dart';
import '../db_helper.dart';
import '../api_services/token_service.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  void _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('캐시 삭제 확인'),
        content: Text('즐겨찾기, 최근검색이력 등 모든 캐시가 삭제됩니다.\n그래도 삭제하시겠습니까?'),
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
          SnackBar(content: Text('캐시가 삭제되었습니다.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('캐시 삭제 실패: $e')),
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
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text('캐시 삭제'),
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
              ],
            ),
          ),
        ],
      ),
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
                  max: 30,
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