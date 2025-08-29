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
    } else if (response.statusCode == 422) {
      // 🚀 422 Unprocessable Entity: 이미지 추론 실패 (bbox 인식 실패)
      debugPrint('🖼️ [InferenceDelay] 422 - 이미지 추론 실패 (bbox 인식 실패)');
      
      // 🚀 사용자에게 이미지 추론 실패 안내
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.orange),
                SizedBox(width: 8),
                Text('이미지 인식 실패'),
              ],
            ),
            content: const Text(
              '약물 이미지를 인식할 수 없습니다.\n\n'
              '다음 사항을 확인해주세요:\n'
              '• 약물이 이미지 중앙에 명확하게 보이는지\n'
              '• 이미지가 너무 흐리거나 어둡지 않은지\n'
              '• 약물이 다른 물체에 가려지지 않았는지\n\n'
              '다시 촬영해 주세요.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 다이얼로그 닫기
                  Navigator.pop(context); // 이전 화면으로 돌아가기
                },
                child: const Text('다시 촬영'),
              ),
            ],
          ),
        );
      }
      
      throw Exception('이미지 추론 실패: 약물을 인식할 수 없습니다');
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