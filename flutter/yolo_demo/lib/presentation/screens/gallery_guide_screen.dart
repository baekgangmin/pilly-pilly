// gallery_guide_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yolo_demo/presentation/screens/gallery_edit_screen.dart';

class GalleryGuideScreen extends StatelessWidget {
  const GalleryGuideScreen({super.key});

  Future<void> _setSeenGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_gallery_guide', true);
  }

  /// 갤러리에서 이미지 한 개 선택 후 편집 화면으로 이동
  Future<void> _pickImages(BuildContext context) async {
    print("📂 앨범에서 선택 클릭됨");

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final selectedFile = File(result.files.single.path!);

      print("➡️ GalleryEditScreen으로 이동: $selectedFile");

      // 가이드 봤음 저장
      await _setSeenGuide();

      // 편집 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GalleryEditScreen(selectedImage: selectedFile),
        ),
      );
    } else {
      print("⚠️ 이미지 선택 취소됨");
    }
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
                const Icon(Icons.photo_library, size: 100, color: Colors.grey),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    '갤러리에서 이미지를 선택해 주세요!\n알약이 1개만 포함된 사진만 선택해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _pickImages(context),
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