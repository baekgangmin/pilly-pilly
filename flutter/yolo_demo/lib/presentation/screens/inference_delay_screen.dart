import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'inference_result_screen.dart';
import 'dart:io';

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
  @override
  void initState() {
    super.initState();
    _startInference();
  }

  Future<void> _startInference() async {
    try {
      debugPrint('🟢 Inference 시작: cleanImagePaths = ${widget.cleanImagePaths}');
      var uri = Uri.parse("http://192.168.0.2:8000/predict_multiple");
      var request = http.MultipartRequest('POST', uri);

      for (var path in widget.cleanImagePaths) {
        debugPrint('🟢 이미지 첨부 중: $path');
        final file = File(path);
        final bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          bytes,
          filename: path.split('/').last,
        ));
      }

      var response = await request.send();
      final responseData = await http.Response.fromStream(response);
      debugPrint('🟢 응답 수신: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> resultList = json.decode(responseData.body);
        debugPrint('🟢 응답 결과: $resultList');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InferenceResultScreen(
              bboxImagePaths: widget.bboxImagePaths,
              inferenceResults: resultList,
              resultsJson: json.encode(resultList), // 필요시 문자열도 같이 전달
            ),
          ),
        );
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔴 오류 발생: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 중 오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              'AI가 이미지를 분석 중입니다...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}