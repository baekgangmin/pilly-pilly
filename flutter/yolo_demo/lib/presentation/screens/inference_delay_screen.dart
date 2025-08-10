import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'inference_result_screen.dart';

class InferenceDelayScreen extends StatefulWidget {
  final List<String> bboxImagePaths;
  final List<String> cleanImagePaths;

  const InferenceDelayScreen({
    super.key,
    required this.bboxImagePaths,
    required this.cleanImagePaths,
  });

  @override
  State<InferenceDelayScreen> createState() => _InferenceDelayScreenState();
}

class _InferenceDelayScreenState extends State<InferenceDelayScreen> {
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    print("🚀 InferenceDelayScreen 진입");
    print("bboxImagePaths: ${widget.bboxImagePaths}");
    print("cleanImagePaths: ${widget.cleanImagePaths}");
    
    _startFirstInference();
  }

  /// 첫 번째 이미지 추론 후 결과 화면으로 이동
  Future<void> _startFirstInference() async {
    try {
      final firstImage = widget.cleanImagePaths.first;
      final firstResult = await _inferSingleImage(firstImage);

      if (!mounted) return;

      // YOLOView가 남아있지 않도록 이전 화면 상태 해제
      _forceDisposeYoloView();

      // 결과 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InferenceResultScreen(
            bboxImagePaths: widget.bboxImagePaths,
            cleanImagePaths: widget.cleanImagePaths,
            initialResult: firstResult,
          ),
        ),
      );
    } catch (e) {
      debugPrint('🔴 첫 추론 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 중 오류: $e')),
      );
    }
  }

  /// API 호출
  Future<Map<String, dynamic>?> _inferSingleImage(String imagePath) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final uri = Uri.parse('$baseUrl/api/v2/image-search');
    final headers = await ApiHelper.getAuthHeaders();

    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imagePath.split('/').last,
      ));

    final response = await request.send();
    final responseData = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      return json.decode(responseData.body);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  }

  /// YOLOView 강제 해제
  void _forceDisposeYoloView() {
    if (_disposed) return;
    _disposed = true;

    // 이전 CameraInferenceScreen의 YOLOView 상태 초기화
    debugPrint('🟠 InferenceDelayScreen: YOLOView 강제 해제 요청');
    Navigator.popUntil(context, (route) {
      return true; // 단순 pop 처리로 YOLOView 완전 dispose
    });
  }

  @override
  void dispose() {
    _forceDisposeYoloView();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('AI가 이미지를 분석하고 있어요 ...'),
          ],
        ),
      ),
    );
  }
}