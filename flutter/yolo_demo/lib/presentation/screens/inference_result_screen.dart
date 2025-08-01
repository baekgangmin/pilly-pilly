import 'dart:convert';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../screens/final_result.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';

class InferenceResultScreen extends StatefulWidget {
  final List<String> bboxImagePaths;
  final List<String> cleanImagePaths;
  final Map<String, dynamic>? initialResult;

  const InferenceResultScreen({
    Key? key,
    required this.bboxImagePaths,
    required this.cleanImagePaths,
    required this.initialResult,
  }) : super(key: key);

  @override
  State<InferenceResultScreen> createState() => _InferenceResultScreenState();
}

class _InferenceResultScreenState extends State<InferenceResultScreen> {
  int selectedIndex = 0;
  List<Map<String, dynamic>?> results = [];
  List<Map<String, dynamic>> cartItems = [];

  @override
  void initState() {
    super.initState();

    results = List.filled(widget.cleanImagePaths.length, null);
    results[0] = widget.initialResult;

    _startSequentialInference();
  }

  Future<void> _startSequentialInference() async {
    for (int i = 1; i < widget.cleanImagePaths.length; i++) {
      final result = await _inferSingleImage(
        widget.cleanImagePaths[i],
        fallbackImagePath: widget.bboxImagePaths[i],
      );
      setState(() {
        results[i] = result;
      });
    }
  }

  Future<Map<String, dynamic>?> _inferSingleImage(String imagePath,
      {String? fallbackImagePath}) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('🔴 파일이 존재하지 않음: $imagePath, bbox로 대체 시도');
        if (fallbackImagePath != null) {
          return await _inferSingleImage(fallbackImagePath);
        }
        return null;
      }

      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/v2/image-search');
      final headers = await ApiHelper.getAuthHeaders();

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
    } on CameraException catch (e) {
      debugPrint('🔴 카메라 오류: $e');
      return null;
    } catch (e) {
      debugPrint('🔴 일반 오류: $e');
      return null;
    }
  }

  void _toggleCart(Map<String, dynamic> item) {
    final alreadyInCart = cartItems.any((e) => e['itemSeq'] == item['itemSeq']);
    setState(() {
      if (alreadyInCart) {
        cartItems.removeWhere((e) => e['itemSeq'] == item['itemSeq']);
      } else {
        cartItems.add(item);
      }
    });
  }

  Future<void> _goToFinalResult() async {
    final itemSeqList = cartItems.map((e) => e['itemSeq']).toList();

    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final uri = Uri.parse('$baseUrl/api/v2/log');
    final headers = await ApiHelper.getAuthHeaders();

    final response = await http.post(
      uri,
      headers: headers,
      body: json.encode(itemSeqList),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // 최근 검색 기록 저장
      final resultMap = data['results'] as Map<String, dynamic>;
      for (final itemSeq in resultMap.keys) {
        final item = resultMap[itemSeq];
        final itemName = item['permit']?['permitDetail']?['itemName'];
        final timestamp = DateTime.now().toIso8601String();

        if (itemName != null) {
          await DBHelper.addRecentPill(
            itemSeq: itemSeq,
            itemName: itemName,
            userId: 'guest',
            timestamp: timestamp,
          );
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FinalResultScreen(resultData: data),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 오류: ${response.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('분류 결과')),
      body: Column(
        children: [
          // 썸네일 선택
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.bboxImagePaths.length,
              itemBuilder: (context, index) {
                final bboxPath = widget.bboxImagePaths[index];
                final isAvailable = results[index] != null;

                return GestureDetector(
                  onTap: isAvailable
                      ? () => setState(() => selectedIndex = index)
                      : null,
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedIndex == index ? Colors.red : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.file(
                          File(bboxPath),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (!isAvailable)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),

          // 결과 리스트 (UI 크게 변경)
          Expanded(
            child: Builder(
              builder: (context) {
                final currentResult = results[selectedIndex];
                if (currentResult == null) {
                  return const Center(child: Text('아직 분석 중입니다...'));
                }

                final topK = (currentResult['top_k'] as List<dynamic>?) ?? [];
                final summary = (currentResult['summary'] as List<dynamic>?) ?? [];

                final merged = topK.map((item) {
                  final matched = summary.firstWhere(
                    (s) => s['itemSeq'] == item['itemSeq'],
                    orElse: () => {},
                  );
                  return {
                    'itemSeq': item['itemSeq'],
                    'finalScore': item['finalScore'],
                    'itemName': matched['itemName'] ?? '알 수 없음',
                    'imageUrl': matched['imageUrl'],
                  };
                }).toList();

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: merged.length,
                  itemBuilder: (context, index) {
                    final item = merged[index];
                    final isInCart = cartItems.any((e) => e['itemSeq'] == item['itemSeq']);

                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            item['imageUrl'] != null
                                ? Image.network(
                                    item['imageUrl'],
                                    width: 150,
                                    height: 110,
                                    fit: BoxFit.contain,
                                  )
                                : const Icon(Icons.image_not_supported, size: 150),
                            const SizedBox(height: 15),
                            AutoSizeText(
                              item['itemName'],
                              style: const TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold
                              ),
                              maxLines: 2,
                              minFontSize: 10,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '정확도: ${(item['finalScore'] * 100 as num).toStringAsFixed(2)}%',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: Icon(
                                Icons.add_shopping_cart,
                                color: isInCart ? Colors.teal : Colors.grey,
                                size: 25,
                              ),
                              onPressed: () => _toggleCart(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 장바구니
          if (cartItems.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['imageUrl'] ?? 'https://via.placeholder.com/60',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    cartItems.removeAt(index);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _goToFinalResult,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}