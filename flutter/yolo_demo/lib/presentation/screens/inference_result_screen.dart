import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:http/http.dart' as http;
import '../../screens/final_result.dart';
import 'no_inference_screen.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:yolo_demo/screens/cart_screen.dart';
import 'package:yolo_demo/models/pill_data.dart';
import 'package:yolo_demo/utils/image_utils.dart';

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
  bool _posting = false;
  bool _cartBump = false;
  
  // 🚀 크롤링 상태 관리
  final Map<String, String> _crawledImageCache = {}; // itemSeq -> crawledImageUrl
  // 중복 호출 방지용
  final Set<String> _crawlInFlight = {};

  // 중복 크롤링 시도 방지용 (실패 포함)
  final Set<String> _crawlAttempted = {};


  void _bumpCart() {
    if (!mounted) return;
    setState(() => _cartBump = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _cartBump = false);
    });
  }

  /// 단일 품목 상세 바로 열기 (이미지 탭 시)
  Future<void> _openFinalForItem(String itemSeq, {String? fallbackImageUrl}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/v2/log');
      final headers = await ApiHelper.getAuthHeaders();
      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode([itemSeq]),
      );

      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 최근검색 DB 저장(기존 로직 그대로)
        final resultMap = data['results'] as Map<String, dynamic>?;
        if (resultMap != null) {
          for (final k in resultMap.keys) {
            final it = resultMap[k];
            final itemName = it['permit']?['permitDetail']?['itemName'];
            final ts = DateTime.now().toIso8601String();

            // Try multiple paths for image url + final fallback to the tapped card's image
            final dynamic extracted =
                it['permit']?['permitDetail']?['itemImage'] ??
                it['permit']?['permitDetail']?['images']?['main'] ??
                it['permit']?['permitList']?['imageUrl'] ?? // ✅ 추가: permitList.imageUrl
                it['images']?['main'] ??
                it['imageUrl'] ??
                it['ITEM_IMAGE'];
            String? imageUrlForDb =
                (extracted is String && extracted.startsWith('http')) ? extracted : null;

            // 마지막 보루: 카드에서 넘어온 이미지가 http면 사용
            if (imageUrlForDb == null &&
                fallbackImageUrl != null &&
                fallbackImageUrl.startsWith('http')) {
              imageUrlForDb = fallbackImageUrl;
            }

            debugPrint('🖼️ [inference->_openFinalForItem] save imageUrl: ' + (imageUrlForDb ?? 'null'));

            if (itemName != null) {
              // 크롤링된 이미지 URL 가져오기 (중복방지/캐시 연동)
              final crawledImageUrl = await _getImageWithCrawlingAndSave({'itemSeq': k, 'imageUrl': imageUrlForDb});
              final finalImageUrl = (() {
                if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
                  return crawledImageUrl; // ✅ 우선 사용
                }
                return imageUrlForDb; // 없으면 원본
              })();
              
              await DBHelper.addRecentPill(
                itemSeq: k,
                itemName: itemName,
                userId: 'guest',
                timestamp: ts,
                imageUrl: finalImageUrl,
              );
            }
          }
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FinalResultScreen(resultData: data)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  /// 크롤링된 이미지 URL을 현재 선택된 인덱스의 결과에 저장
  void _saveCrawledImageToCurrentResult(String crawledImageUrl) {
    // 🚀 현재 선택된 인덱스의 결과에 크롤링된 이미지 URL 저장
    if (selectedIndex >= 0 && selectedIndex < results.length) {
      final result = results[selectedIndex];
      if (result != null) {
        result['crawledImageUrl'] = crawledImageUrl;
        debugPrint('✅ [InferenceResult] 현재 선택된 결과[${selectedIndex}]에 크롤링된 이미지 URL 저장: $crawledImageUrl');
        setState(() {}); // UI 업데이트
      }
    }
  }

  /// image-scrape(인증 필요) 전용 렌더러
  Widget _authedNetworkImage(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return FutureBuilder<Map<String, String>>(
      future: ApiHelper.getAuthHeaders(),
      builder: (context, headersSnap) {
        if (headersSnap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final headers = headersSnap.data;
        return Image.network(
          url,
          headers: headers,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/no_image.png',
            width: width,
            height: height,
            fit: fit,
          ),
        );
      },
    );
  }

  /// 결과 리스트의 이미지 위젯 생성 (무한 루프 방지)
  Widget _buildResultImage(Map<String, dynamic> item) {
    final itemSeq = item['itemSeq']?.toString();
    final originalImageUrl = item['imageUrl']?.toString();

    // 필요시 1회 크롤링 트리거 (그리드 카드 전용)
    if ((originalImageUrl == null || ImageUtils.isPlaceholder(originalImageUrl)) &&
        itemSeq != null && itemSeq.isNotEmpty) {
      // 중복 시도 방지: 이미 시도했거나(성공/실패) 크롤링 중이거나, 캐시에 있으면 트리거하지 않음
      if (!_crawlAttempted.contains(itemSeq) &&
          !_crawledImageCache.containsKey(itemSeq) &&
          !_crawlInFlight.contains(itemSeq)) {
        _crawlAttempted.add(itemSeq); // 시도 여부 기록(실패 포함)
        _crawlInFlight.add(itemSeq);
        ImageUtils.getImageWithCrawling({'itemSeq': itemSeq}).then((url) {
          if (url != null && !ImageUtils.isPlaceholder(url)) {
            _crawledImageCache[itemSeq] = url;
            // 현재 결과에도 저장해서 상세/저장에 이어지도록
            _updateResultWithCrawledImage(itemSeq, url);
            if (mounted) setState(() {});
          }
        }).catchError((_) {
          // 무시: 실패 시에도 _crawlAttempted에 기록되어 재시도 안 함
        }).whenComplete(() {
          _crawlInFlight.remove(itemSeq);
        });
      }
    }

    // 1) 캐시에 있으면 우선 사용 (image-scrape면 인증헤더 포함 렌더)
    if (itemSeq != null && _crawledImageCache.containsKey(itemSeq)) {
      final cached = _crawledImageCache[itemSeq]!;
      debugPrint('🖼️ [InferenceResult] 캐시된 이미지 표시: $itemSeq');
      if (cached.contains('image-scrape')) {
        return _authedNetworkImage(
          cached,
          width: double.infinity,
          height: 110,
          fit: BoxFit.contain,
        );
      }
      return Image.network(
        cached,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 48),
      );
    }

    // 2) 원본이 유효하면 그대로
    if (originalImageUrl != null && !ImageUtils.isPlaceholder(originalImageUrl)) {
      return Image.network(
        originalImageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 48),
      );
    }

    // 3) 크롤링이 필요하면 기본 아이콘 표시
    return const Icon(Icons.image_not_supported, size: 48);
  }

  /// 이미지 크롤링을 포함한 이미지 URL 가져오기 (저장/상세 등 실제 크롤링 1회만 수행, 중복방지)
  Future<String?> _getImageWithCrawlingAndSave(Map<String, dynamic> item) async {
    final originalImage = item['imageUrl'];
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      return originalImage;
    }
    final itemSeq = item['itemSeq']?.toString();
    if (itemSeq == null || itemSeq.isEmpty) {
      return originalImage;
    }

    // 캐시 우선
    if (_crawledImageCache.containsKey(itemSeq)) {
      debugPrint('🔄 [InferenceResult] 캐시된 크롤링 이미지 사용: $itemSeq');
      return _crawledImageCache[itemSeq];
    }

    // 중복 호출 방지: 이미 진행 중이면 완료까지 대기하지 않고 원본 반환
    if (_crawlInFlight.contains(itemSeq)) {
      debugPrint('⏳ [InferenceResult] 크롤링 진행 중: $itemSeq');
      return originalImage;
    }

    try {
      _crawlInFlight.add(itemSeq);
      final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq});
      if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
        _crawledImageCache[itemSeq] = crawledImageUrl;
        _updateResultWithCrawledImage(itemSeq, crawledImageUrl);
        debugPrint('✅ [InferenceResult] 크롤링 성공 & 저장: $itemSeq -> $crawledImageUrl');
        return crawledImageUrl;
      }
    } catch (e) {
      debugPrint('❌ [InferenceResult] 크롤링 실패(저장용): $itemSeq - $e');
    } finally {
      _crawlInFlight.remove(itemSeq);
    }
    return originalImage;
  }

  /// 크롤링된 이미지 URL을 결과에 저장
  void _updateResultWithCrawledImage(String itemSeq, String crawledImageUrl) {
    debugPrint('🔄 [InferenceResult] 크롤링된 이미지 저장 시도: itemSeq=$itemSeq, URL=$crawledImageUrl');
    
    // 🚀 현재 결과에서 해당 itemSeq를 가진 항목 찾기
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      if (result == null) continue;
      
      debugPrint('🔍 [InferenceResult] 결과[$i] 검사 중: ${result.keys}');
      
      // summary에서 itemSeq 확인
      final summary = result['summary'] as List?;
      if (summary != null && summary.isNotEmpty) {
        final firstSummary = summary.first;
        if (firstSummary is Map<String, dynamic>) {
          final summaryItemSeq = firstSummary['itemSeq']?.toString();
          debugPrint('🔍 [InferenceResult] summary itemSeq: $summaryItemSeq vs 찾는 itemSeq: $itemSeq');
          if (summaryItemSeq == itemSeq) {
            // 🚀 크롤링된 이미지 URL 저장
            result['crawledImageUrl'] = crawledImageUrl;
            debugPrint('✅ [InferenceResult] 결과[$i] summary에 크롤링된 이미지 URL 저장: $crawledImageUrl');
            setState(() {}); // UI 업데이트
            return;
          }
        }
      }
      
      // top_k에서 itemSeq 확인
      final topK = result['top_k'] as List?;
      if (topK != null && topK.isNotEmpty) {
        final firstItem = topK.first;
        if (firstItem is Map<String, dynamic>) {
          final topKItemSeq = firstItem['itemSeq']?.toString();
          debugPrint('🔍 [InferenceResult] top_k itemSeq: $topKItemSeq vs 찾는 itemSeq: $itemSeq');
          if (topKItemSeq == itemSeq) {
            // 🚀 크롤링된 이미지 URL 저장
            result['crawledImageUrl'] = crawledImageUrl;
            debugPrint('✅ [InferenceResult] 결과[$i] top_k에 크롤링된 이미지 URL 저장: $crawledImageUrl');
            setState(() {}); // UI 업데이트
            return;
          }
        }
      }
    }
    
    debugPrint('⚠️ [InferenceResult] itemSeq=$itemSeq를 가진 결과를 찾을 수 없음');
    debugPrint('🔍 [InferenceResult] 현재 results 상태: ${results.map((r) => r?.keys).toList()}');
  }

  /// 특정 인덱스의 결과에서 이미지 URL 가져오기
  String? _getImageUrlFromResult(int index) {
    if (index < 0 || index >= results.length) return null;
    final result = results[index];
    if (result == null) return null;
    
    // 🚀 크롤링된 이미지 URL이 저장되어 있는지 확인 (우선순위 1)
    final crawledImageUrl = result['crawledImageUrl']?.toString();
    if (crawledImageUrl != null && crawledImageUrl.isNotEmpty && crawledImageUrl.contains('image-scrape')) {
      debugPrint('🖼️ [InferenceResult] 크롤링된 이미지 URL 사용: $crawledImageUrl');
      return crawledImageUrl;
    }
    
    // 🚀 summary에서 이미지 URL 찾기 (우선순위 2)
    final summary = result['summary'] as List?;
    if (summary != null && summary.isNotEmpty) {
      final firstSummary = summary.first;
      if (firstSummary is Map<String, dynamic>) {
        final imageUrl = firstSummary['imageUrl']?.toString();
        if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'assets/no_image.png') {
          debugPrint('🖼️ [InferenceResult] summary에서 이미지 URL 찾음: $imageUrl');
          return imageUrl;
        }
      }
    }
    
    // 🚀 top_k에서 이미지 URL 찾기 (우선순위 3)
    final topK = result['top_k'] as List?;
    if (topK != null && topK.isNotEmpty) {
      final firstItem = topK.first;
      if (firstItem is Map<String, dynamic>) {
        final imageUrl = firstItem['imageUrl']?.toString();
        if (imageUrl != null && imageUrl.isNotEmpty && imageUrl != 'assets/no_image.png') {
          debugPrint('🖼️ [InferenceResult] top_k에서 이미지 URL 찾음: $imageUrl');
          return imageUrl;
        }
      }
    }
    
    debugPrint('🖼️ [InferenceResult] 이미지 URL을 찾을 수 없음: index=$index');
    return null;
  }

  /// 이미지 크롤링을 포함한 이미지 URL 가져오기
  Future<String?> _getImageWithCrawling(Map<String, dynamic> item) async {
    final originalImage = item['imageUrl'];
    
    // 원본 이미지가 유효하면 그대로 사용
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      return originalImage;
    }

    // placeholder인 경우 크롤링 시도
    final itemSeq = item['itemSeq']?.toString();
    if (itemSeq != null && itemSeq.isNotEmpty) {
      try {
        print("🖼️ [InferenceResult] 이미지 크롤링 시작: $itemSeq");
        final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq});
        
        if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
          print("🖼️ [InferenceResult] 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
          
          // 🚀 크롤링된 이미지 URL이 image-scrape를 포함하는지 확인
          if (crawledImageUrl.contains('image-scrape')) {
            print("✅ [InferenceResult] 크롤링된 이미지 URL 확인됨: $crawledImageUrl");
            
            // 🚀 크롤링된 이미지 URL을 현재 선택된 인덱스의 결과에 저장
            _saveCrawledImageToCurrentResult(crawledImageUrl);
            
            return crawledImageUrl;
          } else {
            print("⚠️ [InferenceResult] 크롤링된 이미지 URL이 예상과 다름: $crawledImageUrl");
            return crawledImageUrl;
          }
        } else {
          print("❌ [InferenceResult] 이미지 크롤링 결과가 유효하지 않음: $crawledImageUrl");
        }
      } catch (e) {
        print("❌ [InferenceResult] 이미지 크롤링 실패: $itemSeq - $e");
      }
    }

    // 크롤링 실패시 기본 이미지 반환
    print("🖼️ [InferenceResult] 기본 이미지 사용: assets/no_image.png");
    return 'assets/no_image.png';
  }

  // ✅ OCR 문구를 다양한 형태에서 안전하게 꺼내서 한 줄로 반환
  String _extractOcrSeed(Map<String, dynamic> result) {
    // 1) message: "ocr 결과: ['TYLENOL']" 같은 문자열에서 추출
    final msg = result['message']?.toString() ?? '';
    final reg = RegExp(r"ocr 결과:\s*\[(.*?)\]", caseSensitive: false);
    final m = reg.firstMatch(msg);
    if (m != null) {
      final raw = m.group(1) ?? '';
      final parts = raw.split(',');
      final tokens = parts
          .map((e) => e
              .replaceAll("'", '')
              .replaceAll('"', '')
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('\\', '')
              .trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (tokens.isNotEmpty) return tokens.join(' ');
    }
    return '';
  }

  Widget _buildSafeImage(String? path, {double width = 60, double height = 60, String? crawledImageUrl}) {
    if (path == null || path.isEmpty) {
      return Image.asset('assets/no_image.png', width: width, height: height, fit: BoxFit.cover);
    }
    if (path.startsWith('http')) {
      // HTTP 이미지: 유효하면 그대로, placeholder면 크롤링 시도
      return FutureBuilder<String?>(
        future: _getImageWithCrawling({'imageUrl': path}),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          
          final finalImageUrl = snapshot.data;
          if (finalImageUrl != null && !ImageUtils.isPlaceholder(finalImageUrl)) {
            // 🚀 크롤링된 이미지는 인증 헤더 포함 렌더
            if (finalImageUrl.contains('image-scrape')) {
              return _authedNetworkImage(
                finalImageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
              );
            } else {
              // 일반 HTTP 이미지는 Image.network 사용
              return Image.network(
                finalImageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Image.asset('assets/no_image.png', width: width, height: height, fit: BoxFit.cover),
              );
            }
          } else {
            return Image.asset('assets/no_image.png', width: width, height: height, fit: BoxFit.cover);
          }
        },
      );
    } else if (crawledImageUrl != null && crawledImageUrl.startsWith('http')) {
      // 🚀 크롤링된 이미지 URL이 있는 경우 우선 사용
      debugPrint('🖼️ [InferenceResult] 크롤링된 이미지 사용: $crawledImageUrl');
      return crawledImageUrl.contains('image-scrape')
          ? _authedNetworkImage(
              crawledImageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
            )
          : Image.network(
              crawledImageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/no_image.png',
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            );
    } else {
      final file = File(path);
      if (!file.existsSync()) {
        return Image.asset('assets/no_image.png', width: width, height: height, fit: BoxFit.cover);
      }
      return Image.file(file, width: width, height: height, fit: BoxFit.cover);
    }
  }

  @override
  void initState() {
    super.initState();

    // Clear any previous state (thumbnails)
    results.clear();

    results = List.filled(widget.cleanImagePaths.length, null);
    results[0] = widget.initialResult;
    _startSequentialInference();
  }

  Future<void> _startSequentialInference() async {
    for (int i = 1; i < widget.cleanImagePaths.length; i++) {
      debugPrint('▶️ 순차 추론 시작: index=$i, path=${widget.cleanImagePaths[i]}');
      final result = await _inferSingleImage(
        widget.cleanImagePaths[i],
        fallbackImagePath: widget.bboxImagePaths[i],
      );
      debugPrint('✅ 순차 추론 완료: index=$i, result=${result != null}');
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

      debugPrint('📤 서버 요청 시작: $imagePath');

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

      debugPrint('📥 서버 응답 코드: ${response.statusCode}');

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분류 결과'),
        actions: [
          AnimatedBuilder(
            animation: CompareTray.instance,
            builder: (context, _) {
              final count = CompareTray.instance.count;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Image.asset('assets/compare-3d.png', height: 28),
                      tooltip: '비교함',
                      onPressed: () async {
                        bool pushed = false;
                        try {
                          await Navigator.pushNamed(context, '/cart');
                          pushed = true;
                        } catch (_) {}
                        if (!pushed) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        }
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: AnimatedScale(
                          scale: _cartBump ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: Text(
                                '$count',
                                key: ValueKey(count),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: CompareTray.instance,
        builder: (context, _) {
          return Column(
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
                            child: _buildSafeImage(
                              widget.cleanImagePaths[index], // 🚀 사용자 촬영 이미지 (썸네일용)
                              width: 80, 
                              height: 80,
                              crawledImageUrl: null, // 썸네일은 크롤링된 이미지 사용 안 함
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
                      debugPrint('⌛ 현재 index=$selectedIndex 결과 없음 (분석 중)');
                      return const Center(child: Text('아직 분석 중입니다...'));
                    }

                    // 순서(인덱스) 기반 매핑
                    final List<Map<String, dynamic>> topK = ((currentResult['top_k'] as List?) ?? [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                    final List<Map<String, dynamic>> summary = ((currentResult['summary'] as List?) ?? [])
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                    bool _isEmptyMap(Map m) => m.isEmpty || m.values.every(
                      (v) => v == null || (v is String && v.isEmpty),
                    );

                    final int len = math.min(topK.length, summary.length);

                    final List<Map<String, dynamic>> merged = List.generate(len, (i) {
                      final item = topK[i];
                      final s = summary[i];
                      final hasSummary = !_isEmptyMap(s);

                      return {
                        // summary 값 우선, 없으면 top_k 값
                        'itemSeq': hasSummary ? (s['itemSeq'] ?? item['itemSeq']) : item['itemSeq'],
                        'itemName': hasSummary ? (s['itemName'] ?? '알 수 없음') : '알 수 없음',
                        'entpName': hasSummary ? (s['entpName'] ?? s['ENTP_NAME']) : null,
                        'imageUrl': hasSummary ? s['imageUrl'] : 'assets/no_image.png',
                        'finalScore': item['finalScore'],
                        'yoloScore': item['yoloScore'],
                        'ocrScore': item['ocrScore'],
                        'colorScore': item['colorScore'],

                        // 디버깅용
                        'index': i,
                        'legacyItemSeq': item['itemSeq'],
                      };
                    });

                    // top_k가 더 길면 남은 것은 placeholder로 추가 (옵션)
                    if (topK.length > len) {
                      merged.addAll(topK.sublist(len).map((item) => {
                            'itemSeq': item['itemSeq'],
                            'itemName': '알 수 없음',
                            'entpName': null,
                            'imageUrl': 'assets/no_image.png',
                            'finalScore': item['finalScore'],
                            'yoloScore': item['yoloScore'],
                            'ocrScore': item['ocrScore'],
                            'colorScore': item['colorScore'],
                            'index': merged.length,
                            'legacyItemSeq': item['itemSeq'],
                          }));
                    }

                    // Save the merged results for passing to NoInferenceScreen
                    final imageResults = merged;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.60,
                            ),
                            itemCount: merged.length,
                            itemBuilder: (context, index) {
                              final item = merged[index];
                              final rawScore = item['finalScore'];
                              final double scoreNum = (rawScore is num) ? rawScore.toDouble() : 0.0;
                              final String seq = item['itemSeq']?.toString() ?? item['ITEM_SEQ']?.toString() ?? '';
                              final bool inCart = seq.isNotEmpty && CompareTray.instance.contains(seq);

                              return Card(
                                margin: const EdgeInsets.all(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          // 이미지 (약간 줄여서 여유 확보)
                                          SizedBox(
                                            height: 110,
                                            width: double.infinity,
                                            child: _buildResultImage(item),
                                          ),
                                          const SizedBox(height: 6),

                                          // 가운데 영역: 이름 + 정확도 + (여유공간) + 버튼들
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                // 약 이름 (최대 3줄)
                                                Text(
                                                  item['itemName'] ?? '알 수 없음',
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.2),
                                                ),
                                                const SizedBox(height: 4),
                                                // 정확도: 이름 바로 아래로 이동
                                                Text(
                                                  '정확도 ${(scoreNum * 100).toStringAsFixed(1)}%',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                ),
                                                const Spacer(),
                                                // [자세히] 버튼 (위)
                                                SizedBox(
                                                  height: 36,
                                                  width: double.infinity,
                                                  child: OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      side: BorderSide(color: Colors.grey.shade400),
                                                    ),
                                                    onPressed: () {
                                                      if (seq.isNotEmpty) {
                                                        _openFinalForItem(
                                                          seq,
                                                          fallbackImageUrl: (item['imageUrl'] is String) ? item['imageUrl'] as String : null,
                                                        );
                                                      }
                                                    },
                                                    child: const Text('약 정보 확인', style: TextStyle(fontSize: 13)),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                // [비교함 담기] 버튼 (아래)
                                                SizedBox(
                                                  height: 36,
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      backgroundColor: inCart ? const Color(0xFFFFD600) : Theme.of(context).colorScheme.primary,
                                                      foregroundColor: Colors.black,
                                                      elevation: 0,
                                                    ),
                                                    onPressed: () {
                                                      if (seq.isEmpty) return;
                                                      final Map<String, dynamic> toAdd = {
                                                        'itemSeq': seq,
                                                        'itemName': (item['itemName'] ?? item['ITEM_NAME'] ?? '알 수 없음').toString(),
                                                        'entpName': (item['entpName'] ?? item['ENTP_NAME']),
                                                        'imageUrl': (item['imageUrl'] is String && (item['imageUrl'] as String).startsWith('http'))
                                                            ? item['imageUrl']
                                                            : null,
                                                      };
                                                      CompareTray.instance.addFromDynamic(toAdd);
                                                      _bumpCart();
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비교함에 담았어요.')));
                                                    },
                                                    icon: Image.asset(inCart ? 'assets/compare-3d.png' : 'assets/compare-2d.png', height: 28),
                                                    label: Text(inCart ? '담김 (비교함)' : '비교함에 담기', style: const TextStyle(fontSize: 13)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          // Add the NoInferenceScreen primary button here
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.search, size: 22),
                                label: const Text('찾으시는 알약이 없으신가요?'),
                                onPressed: () {
                                  final Map<String, dynamic> current = (currentResult ?? {}) as Map<String, dynamic>;

                                  final List<Map<String, dynamic>> summary = ((current['summary'] as List?) ?? [])
                                      .whereType<Map>()
                                      .map((e) => Map<String, dynamic>.from(e))
                                      .toList();

                                  // ✅ OCR seed 추출 (기존 로직 유지)
                                  final seed = _extractOcrSeed(current);
                                  debugPrint('🔎 NoInferenceScreen seed="$seed"');

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NoInferenceScreen(
                                        summary: summary,
                                        initialFrontText: seed.isNotEmpty ? seed : null, // ← OCR 있으면 자동 프리필
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Removed old "찾으시는 알약이 없으신가요?" button (now above)

            ],
          );
        },
      ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}