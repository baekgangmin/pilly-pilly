import 'package:flutter/material.dart';
import 'package:yolo_demo/api_services/feature_search_service.dart';
import 'fail_inference_feature_result.dart';

class LoadingScreen extends StatefulWidget {
  final String itemSeq;
  final String? printFront;
  final String? printBack;

  final String? overrideShape;
  final String? overrideColor;

  const LoadingScreen({
    Key? key,
    required this.itemSeq,
    this.printFront,
    this.printBack,

    this.overrideShape,
    this.overrideColor,
  });

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
    // 1) 1차: itemSeq로 shape/color 조회
    final result1 = await _featureSearchService.fetchShapeAndColorByItemSeq(widget.itemSeq);
    if (result1 == null) {
      if (!mounted) return;
      showErrorAndGoBack('알약 정보 조회에 실패했습니다.');
      return;
    }

    // 결과 구조가 다양할 수 있으므로 방어적으로 추출
    Map<String, dynamic> firstObj = {};
    if (result1 is Map) {
      final r = result1['results'];
      if (r is List && r.isNotEmpty && r.first is Map) {
        firstObj = Map<String, dynamic>.from(r.first as Map);
      } else if (result1 is Map<String, dynamic>) {
        firstObj = result1;
      }
    }
    if (firstObj.isEmpty) {
      if (!mounted) return;
      showErrorAndGoBack('알약 정보 형식이 올바르지 않습니다.');
      return;
    }

    final String shape = (firstObj['drug_shape'] ?? firstObj['DRUG_SHAPE'] ?? '').toString().trim();
    final String color = (firstObj['color_class1'] ?? firstObj['COLOR_CLASS1'] ?? '').toString().trim();

    // ✅ 우선순위: override > 1차 조회값
    final String finalShape = (widget.overrideShape?.trim().isNotEmpty ?? false)
        ? widget.overrideShape!.trim()
        : shape;
    final String finalColor = (widget.overrideColor?.trim().isNotEmpty ?? false)
        ? widget.overrideColor!.trim()
        : color;

    debugPrint('🔎 2차 검색 파라미터 -> shape:$finalShape, color:$finalColor, '
               'front:${widget.printFront}, back:${widget.printBack}');

    // 2) 2차: shape/color(+선택 텍스트)로 유사 약 검색
    final result2 = await _featureSearchService.fetchPillInfo(
      printFront: (widget.printFront ?? '').trim().isNotEmpty ? widget.printFront!.trim() : null,
      printBack: (widget.printBack ?? '').trim().isNotEmpty ? widget.printBack!.trim() : null,
      shape:      finalShape.isNotEmpty ? finalShape : null,
      colorClass1:finalColor.isNotEmpty ? finalColor : null,
    );

    if (result2 == null) {
      if (!mounted) return;
      showErrorAndGoBack('유사한 알약 검색에 실패했습니다.');
      return;
    }
    debugPrint('⚙️ result2 type: ${result2.runtimeType}');
    if (result2 is Map) {
      debugPrint('⚙️ result2["results"] type: ${result2['results']?.runtimeType}');
      if (result2['results'] is Map) {
        debugPrint('⚙️ keys: ${(result2['results'] as Map).keys.take(3).toList()}');
      }
    }
    // 3) 결과 리스트만 추출하여 결과 화면으로 이동
    List<Map<String, dynamic>> resultsList = [];

    if (result2 is Map && result2['results'] is List) {
      final list = result2['results'] as List;
      resultsList = list
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

    } else if (result2 is Map && result2['results'] is Map) {
      // 예: {"results": { "12345": {...}, "67890": {...} }}
      final m = result2['results'] as Map;
      resultsList = m.values
          .where((v) => v is Map)
          .map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v as Map))
          .toList();

      // 예: {"results": {"items": [ ... ]}}
      if (resultsList.isEmpty) {
        final inner = m['items'];
        if (inner is List) {
          resultsList = inner
              .where((e) => e is Map)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

    } else if (result2 is List) {
      final List<dynamic> list = result2 as List<dynamic>;
      resultsList = list
          .where((e) => e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (!mounted) return;
    if (resultsList.isEmpty) {
      showErrorAndGoBack('검색 결과가 없습니다.');
      return;
    }

    // ✅ 결과 정규화: 어떤 응답 구조든 아래 4개 키를 String으로 맞춰줌
    final normalizedResults = resultsList.map<Map<String, String>>((e) {
      final map = Map<String, dynamic>.from(e);

      // 중첩 안전 접근
      Map<String, dynamic>? permit = map['permit'] is Map ? Map<String, dynamic>.from(map['permit']) : null;
      Map<String, dynamic>? permitDetail = permit?['permitDetail'] is Map
          ? Map<String, dynamic>.from(permit!['permitDetail'])
          : null;

      final itemSeq = (map['itemSeq'] ?? map['ITEM_SEQ'] ?? permitDetail?['itemSeq'] ?? '').toString();
      final itemName = (map['itemName'] ?? map['ITEM_NAME'] ?? permitDetail?['itemName'] ?? '').toString();
      final entpName = (map['entpName'] ?? map['ENTP_NAME'] ?? permitDetail?['entpName'] ?? '').toString();
      final imageUrl = (map['imageUrl'] ?? map['ITEM_IMAGE'] ?? permitDetail?['itemImage'] ?? '').toString();

      return {
        'itemSeq': itemSeq,
        'itemName': itemName,
        'entpName': entpName,
        'imageUrl': imageUrl,
      };
    }).toList();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FailInferenceFeatureResultScreen(results: normalizedResults),
      ),
    );
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