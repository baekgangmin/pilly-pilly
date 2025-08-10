import 'package:flutter/material.dart';
import 'package:yolo_demo/api_services/feature_search_service.dart';
import 'package:yolo_demo/screens/feature_search_result.dart';
import 'fail_inference_feature_result.dart';

class LoadingScreen extends StatefulWidget {
  final String itemSeq;
  final String userTypedText;

  const LoadingScreen({
    Key? key,
    required this.itemSeq,
    required this.userTypedText,
  }) : super(key: key);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  final FeatureSearchService _featureSearchService = FeatureSearchService();

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    final result1 = await _featureSearchService.fetchShapeAndColorByItemSeq(widget.itemSeq);

    if (result1 != null) {
      final shape = result1['drug_shape'];
      final color = result1['color_class1'];

      final result2 = await _featureSearchService.fetchPillInfo(
        printFront: widget.userTypedText,
        shape: shape,
        colorClass1: color,
      );

      if (result2 != null && mounted) {
        //Navigator.pushReplacement(
          //context
          //MaterialPageRoute(
            //builder: (context) => FailInferenceFeatureResultScreen(
              //results: [resultMap],
            //),
          //),
        //);
      } else {
        if (!mounted) return;
        showErrorAndGoBack('유사한 알약 검색에 실패했습니다.');
      }
    } else {
      if (!mounted) return;
      showErrorAndGoBack('알약 정보 조회에 실패했습니다.');
    }
  }

  void showErrorAndGoBack(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('에러'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              '로딩 중입니다...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}