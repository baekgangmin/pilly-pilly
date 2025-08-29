
import 'package:yolo_demo/db_helper.dart';
import 'final_result.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_services/feature_search_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:yolo_demo/screens/cart_screen.dart';
import 'package:yolo_demo/utils/image_utils.dart';

class FeatureSearchResultScreen extends StatefulWidget {
  final List<String>? shape;
  final List<String> selectedColors;
  final String? frontText;
  final String? backText;

  const FeatureSearchResultScreen({
    super.key,
    this.shape,
    required this.selectedColors,
    this.frontText,
    this.backText,
  });

  @override
  State<FeatureSearchResultScreen> createState() => _FeatureSearchResultScreenState();
}

class _FeatureSearchResultScreenState extends State<FeatureSearchResultScreen> {
  final Map<String, List<String>> colorPatterns = {
    '하양': ['하양'],
    '투명': ['투명'],
    '회색': ['회색'],
    '빨강': ['빨강'],
    '분홍': ['분홍'],
    '자주': ['자주'],
    '노랑': ['노랑'],
    '주황': ['주황'],
    '연두': ['연두'],
    '초록': ['초록'],
    '청록': ['청록'],
    '파랑': ['파랑'],
    '남색': ['남색'],
    '보라': ['보라'],
    '갈색': ['갈색'],
    '검정': ['검정'],
  };
  final _api = FeatureSearchService();
  bool isLoading = true;
  List<Map<String, dynamic>> searchResults = [];

  // ====== 비교함(CompareTray) ======
  bool _cartBump = false;

  @override
  void initState() {
    super.initState();
    CompareTray.instance.addListener(_onTrayChanged);
    _searchPills();
  }

  @override
  void dispose() {
    CompareTray.instance.removeListener(_onTrayChanged);
    super.dispose();
  }

  void _onTrayChanged() {
    if (!mounted) return;
    setState(() {}); // rebuild to reflect tray count / contains
  }

  void _bumpCart() {
    if (!mounted) return;
    setState(() => _cartBump = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _cartBump = false);
    });
  }


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
        // 최근검색 저장
        final resultMap = data['results'] as Map<String, dynamic>?;
        if (resultMap != null) {
          for (final k in resultMap.keys) {
            final it = resultMap[k];
            final itemName = it['permit']?['permitDetail']?['itemName'];
            final ts = DateTime.now().toIso8601String();
            final dynamic extracted =
                it['permit']?['permitDetail']?['itemImage'] ??
                it['permit']?['permitDetail']?['images']?['main'] ??
                it['permit']?['permitList']?['imageUrl'] ??
                it['images']?['main'] ??
                it['imageUrl'] ??
                it['ITEM_IMAGE'];
            String? img = (extracted is String && (extracted.startsWith('http://') || extracted.startsWith('https://'))) ? extracted : null;
            if (img == null && fallbackImageUrl != null && fallbackImageUrl.startsWith('http')) {
              img = fallbackImageUrl;
            }
            if (itemName != null) {
              // 약 상태 확인 (취하/만료/정보없음이면 최근검색 저장 스킵)
              final permitDetail = it['permit']?['permitDetail'];
              final permitList   = it['permit']?['permitList'];
              final cancleName   = permitList?['cancleName']?.toString();
              final cancleDate   = permitList?['cancleDate'];

              final bool hasInfo = (permitDetail != null) || (permitList != null);
              final bool isNormal = (cancleName == null || cancleName == '정상') &&
                                    (cancleDate == null || cancleDate.toString().trim().isEmpty);
              final bool shouldSave = hasInfo && isNormal;

              if (shouldSave) {
                // 크롤링된 이미지 URL 가져오기 (정상 약만 저장)
                print("🔄 [FeatureSearchResult] 크롤링 시작: itemSeq=$k, 원본이미지=$img");
                final crawledImageUrl = await _getImageWithCrawling({'itemSeq': k, 'imageUrl': img});
                print("🖼️ [FeatureSearchResult] 크롤링 결과: $crawledImageUrl");

                final finalImageUrl = (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl))
                    ? crawledImageUrl
                    : img;

                print("💾 [FeatureSearchResult] 최종 저장할 이미지: $finalImageUrl");

                await DBHelper.addRecentPill(
                  itemSeq: k,
                  itemName: itemName,
                  userId: 'guest',
                  timestamp: ts,
                  imageUrl: finalImageUrl,
                );
                print("✅ [FeatureSearchResult] DB 저장 완료(정상): itemSeq=$k, imageUrl=$finalImageUrl");
              } else {
                final statusLabel = (cancleName ?? '정보없음').toString();
                print("🚫 [FeatureSearchResult] 최근검색 저장 스킵: itemSeq=$k, 상태=$statusLabel, cancleDate=$cancleDate");
              }
            }
          }
        }
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => FinalResultScreen(resultData: data)));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('서버 오류: ${response.statusCode}')));
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _searchPills() async {
    debugPrint('=== 검색 시작 ===');
    setState(() {
      isLoading = true;
    });

    final data = await _api.fetchPillInfo(
      printFront: widget.frontText,
      printBack: widget.backText,
      shape: widget.shape?.isNotEmpty == true ? widget.shape!.first : null,
      colorClass1: widget.selectedColors.isNotEmpty ? widget.selectedColors.first : null,
    );

    if (mounted) {
      setState(() {
        isLoading = false;
        final items = data?['results'];
        if (items != null && items is List) {
          final allItems = List<Map<String, dynamic>>.from(items);

          searchResults = allItems.where((item) {
            bool shapeMatch = true;
            bool colorMatch = true;

            if (widget.shape != null && widget.shape!.isNotEmpty) {
              shapeMatch = widget.shape!.contains(item['DRUG_SHAPE']);
            }

            if (widget.selectedColors.isNotEmpty) {
              colorMatch = widget.selectedColors.any((selectedColorKey) {
                final patterns = colorPatterns[selectedColorKey];
                if (patterns == null) return false;

                final value = (item['COLOR_CLASS1'] ?? '').toString();
                return patterns.any((p) => value.contains(p));
              });
            }

            return shapeMatch && colorMatch;
          }).toList();
        }
      });
    }
  }

  /// 이미지 크롤링을 포함한 이미지 URL 가져오기
  Future<String?> _getImageWithCrawling(Map<String, dynamic> item) async {
    final originalImage = item['imageUrl'];
    print("🔍 [FeatureSearchResult] _getImageWithCrawling 호출: originalImage=$originalImage");
    
    // 원본 이미지가 유효하면 그대로 사용
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      print("✅ [FeatureSearchResult] 원본 이미지 사용: $originalImage");
      return originalImage;
    }

    // placeholder인 경우 크롤링 시도
    final itemSeq = item['itemSeq']?.toString();
    print("🔄 [FeatureSearchResult] 크롤링 시도: itemSeq=$itemSeq");
    
    if (itemSeq != null && itemSeq.isNotEmpty) {
      try {
        print("🖼️ [FeatureSearchResult] ImageUtils.getImageWithCrawling 호출");
        final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq, 'imageUrl': originalImage});
        print("🖼️ [FeatureSearchResult] ImageUtils 결과: $crawledImageUrl");
        
        if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
          print("✅ [FeatureSearchResult] 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
          return crawledImageUrl;
        } else {
          print("⚠️ [FeatureSearchResult] 크롤링 결과가 유효하지 않음: $crawledImageUrl");
        }
      } catch (e) {
        print("❌ [FeatureSearchResult] 이미지 크롤링 실패: $itemSeq - $e");
      }
    } else {
      print("⚠️ [FeatureSearchResult] itemSeq가 없음: $itemSeq");
    }

    // 크롤링 실패시 기본 이미지 반환
    print("🔄 [FeatureSearchResult] 기본 이미지 반환: assets/no_image.png");
    return 'assets/no_image.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('검색 결과'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: AnimatedBuilder(
              animation: CompareTray.instance,
              builder: (context, _) {
                final count = CompareTray.instance.count;
                return Stack(
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
                        if (mounted) setState(() {}); // 🔄 돌아오면 즉시 리빌드
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 0,
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
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '총 ${searchResults.length}개의 결과가 검색되었습니다',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: CompareTray.instance,
                    builder: (context, _) {
                      if (searchResults.isEmpty) {
                        return const Center(child: Text('검색 결과가 없습니다.'));
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: searchResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = searchResults[index];

                          final String seq = (item['ITEM_SEQ'] ?? '').toString();
                          final bool inCart = seq.isNotEmpty && CompareTray.instance.contains(seq);

                          final String itemName = (item['ITEM_NAME'] ?? '이름 없음').toString();
                          final String? entpName = (item['ENTP_NAME'] is String && (item['ENTP_NAME'] as String).trim().isNotEmpty)
                              ? item['ENTP_NAME'] as String
                              : null;
                          final String? imageUrl = (() {
                            final raw = item['ITEM_IMAGE']?.toString();
                            if (raw == null) return null;
                            final fixed = raw.startsWith('//') ? 'https:$raw' : raw;
                            return (fixed.startsWith('http://') || fixed.startsWith('https://')) ? fixed : null;
                          })();

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.25), width: 1),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 큰 이미지
                                  Container(
                                    height: 180,
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    child: (imageUrl != null)
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 64),
                                          )
                                        : const Icon(Icons.image_not_supported, size: 64),
                                  ),
                                  const SizedBox(height: 12),

                                  // 텍스트 영역
                                  Text(
                                    itemName,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
                                  ),
                                  if (entpName != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      entpName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // 버튼들
                                  SizedBox(
                                    height: 40,
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
                                          _openFinalForItem(seq, fallbackImageUrl: imageUrl);
                                        }
                                      },
                                      child: const Text('약 정보 확인', style: TextStyle(fontSize: 14)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 40,
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor: inCart
                                            ? const Color(0xFFFFD600)
                                            : Theme.of(context).colorScheme.primary,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        CompareTray.instance.addFromDynamic({
                                          'ITEM_SEQ': seq,
                                          'ITEM_NAME': itemName,
                                          'ENTP_NAME': entpName,
                                          'ITEM_IMAGE': imageUrl,
                                          'source': 'feature',
                                        });
                                        _bumpCart();
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비교함에 담았어요.')));
                                      },
                                      icon: Image.asset(inCart ? 'assets/compare-3d.png' : 'assets/compare-2d.png', height: 28),
                                      label: Text(inCart ? '담김 (비교함)' : '비교함에 담기', style: const TextStyle(fontSize: 14)),
                                    ),
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
              ],
            ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
