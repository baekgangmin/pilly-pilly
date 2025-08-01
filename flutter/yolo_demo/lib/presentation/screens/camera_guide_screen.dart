// camera_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraGuideScreen extends StatelessWidget {
  const CameraGuideScreen({super.key});

  Future<void> _setSeenGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_camera_guide', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.zoom_in, size: 100, color: Colors.grey),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  '정확한 검출을 위해\n3배 줌을 눌러\n촬영해주세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await _setSeenGuide();
                  Navigator.pushReplacementNamed(context, '/camera_inference');
                },
                child: const Text('확인했어요'),
              )
            ],
          ),
        ),
      ),
    ),
    );
  }
}
