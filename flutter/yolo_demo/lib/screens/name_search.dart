import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/db_helper.dart';
import 'final_result.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:yolo_demo/screens/cart_screen.dart';
import 'package:yolo_demo/utils/image_utils.dart';

class NameSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> searchResults;
  final String searchKeyword;

  const NameSearchScreen({
    Key? key,
    required this.searchResults,
    required this.searchKeyword,
  }) : super(key: key);

  @override
  State<NameSearchScreen> createState() => _NameSearchScreenState();
}

class _NameSearchScreenState extends State<NameSearchScreen> {
  bool _cartBump = false;

  @override
  void initState() {
    super.initState();
  }

  void _bumpCart() {
    if (!mounted) return;
    setState(() => _cartBump = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _cartBump = false);
    });
  }

  // 취하 여부 판별
  bool _isWithdrawnFromDetail(dynamic detail) {
    if (detail is! Map) return false;

    // 형태 A: detail['permit']['permitList'] 내부
    final permit = (detail['permit'] is Map) ? detail['permit'] as Map : null;
    final permitList = (permit != null && permit['permitList'] is Map)
        ? permit['permitList'] as Map
        : null;

    // 백엔드 키 오탈자(cancleName/cancelName)와 날짜 모두 대응
    final cancleName = permitList != null
        ? (permitList['cancleName'] ?? permitList['cancelName'])?.toString()
        : null;
    final cancleDate = permitList != null ? permitList['cancleDate']?.toString() : null;

    // cancleName 이 '정상' 이 아니거나, cancleDate 가 존재하면 취하로 간주
    if (cancleName != null && cancleName.trim().isNotEmpty && cancleName.trim() != '정상') {
      return true;
    }
    if (cancleDate != null && cancleDate.trim().isNotEmpty && cancleDate.trim().toLowerCase() != 'null') {
      return true;
    }

    // 다른 형태 B 대비: 상위에 status/withdrawn 같은 키가 올 수 있음
    final status = detail['status']?.toString();
    if (status != null && (status.contains('취하') || status.contains('폐') || status.toLowerCase().contains('withdraw'))) {
      return true;
    }

    return false;
  }

  Future<void> _addToUnifiedCart(Map<String, dynamic> item) async {
    try {
      // CompareTray가 알아서 정규화(addFromDynamic) 처리
      CompareTray.instance.addFromDynamic(item);
      if (!mounted) return;
      _bumpCart();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비교함에 담았어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('비교함 오류: $e')));
    }
  }

  Future<void> _openDetail(BuildContext context, Map<String, dynamic> item) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final itemSeq = item['itemSeq']?.toString() ?? item['ITEM_SEQ']?.toString();
    final itemName = (item['itemName'] ?? item['ITEM_NAME'])?.toString();

    if (itemSeq == null || itemSeq.isEmpty) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uri = Uri.parse('$baseUrl/api/v2/log');
      final headers = await ApiHelper.getAuthHeaders();
      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode([itemSeq]), // 단일 itemSeq도 리스트로 전달 (서버 규격 맞춤)
      );

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 닫기
      }

      if (resp.statusCode == 200) {
        final resultData = jsonDecode(resp.body);

        // 최근 검색 저장 (네트워크 이미지 URL만 저장)
        final timestamp = DateTime.now().toIso8601String();

        // 서버 응답 형태 A: { results: { "<itemSeq>": {...} } }
        if (resultData is Map<String, dynamic> && resultData['results'] is Map<String, dynamic>) {
          final Map<String, dynamic> resultMap = resultData['results'] as Map<String, dynamic>;
          final dynamic detail = resultMap[itemSeq];
          // ✅ 취하된 약은 최근검색 저장 스킵
          if (_isWithdrawnFromDetail(detail)) {
            // 디버그 로그
            // print('⛔ withdrawn, skip recent-save: $itemSeq');
          } else {
            if (detail != null) {
              // 이미지 URL 후보 수집
              dynamic extracted =
                  detail['permit']?['permitDetail']?['itemImage'] ??
                  detail['permit']?['permitDetail']?['images']?['main'] ??
                  detail['permit']?['permitList']?['imageUrl'] ??
                  detail['images']?['main'] ??
                  detail['imageUrl'] ??
                  detail['ITEM_IMAGE'] ??
                  item['imageUrl'] ??
                  item['thumbnail'] ??
                  item['thumbUrl'];

              // //로 시작하면 보정
              if (extracted is String && extracted.startsWith('//')) {
                extracted = 'https:$extracted';
              }

              final String? imageUrlForDb = (extracted is String &&
                      (extracted.startsWith('http://') || extracted.startsWith('https://')))
                  ? extracted
                  : null;

              if (itemName != null) {
                // 크롤링된 이미지 URL 가져오기
                final crawledImageUrl = await _getImageWithCrawling(item);
                final finalImageUrl = (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl))
                    ? crawledImageUrl
                    : imageUrlForDb;
                
                await DBHelper.addRecentPill(
                  itemSeq: itemSeq,
                  itemName: itemName,
                  userId: 'guest',
                  timestamp: timestamp,
                  imageUrl: finalImageUrl,
                );
              }
            }
          }
        } else {
          // 형태 B(리스트/미정형): 취하 여부 확인이 어려우므로 최근검색 저장을 생략
          // 상세 화면으로만 이동
        }

        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalResultScreen(resultData: resultData),
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상세 조회 실패 (${resp.statusCode})')),
        );
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // 로딩 닫기 (예외 시)
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  /// 이미지 크롤링을 포함한 이미지 URL 가져오기
  Future<String?> _getImageWithCrawling(Map<String, dynamic> item) async {
    final originalImage = item['imageUrl'] ?? item['ITEM_IMAGE'];
    
    // 원본 이미지가 유효하면 그대로 사용
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      return originalImage;
    }

    // placeholder인 경우 크롤링 시도
    final itemSeq = item['itemSeq']?.toString() ?? item['ITEM_SEQ']?.toString();
    if (itemSeq != null && itemSeq.isNotEmpty) {
      try {
        final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq});
        if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
          print("🖼️ [NameSearch] 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
          return crawledImageUrl;
        }
      } catch (e) {
        print("❌ [NameSearch] 이미지 크롤링 실패: $itemSeq - $e");
      }
    }

    // 크롤링 실패시 기본 이미지 반환
    return 'assets/no_image.png';
  }

  Widget _buildFloatingCartButton(BuildContext context) {
    return AnimatedBuilder(
      animation: CompareTray.instance,
      builder: (context, _) {
        final count = CompareTray.instance.count;
        return Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Ink(
                decoration: const ShapeDecoration(
                  color: Colors.white,
                  shape: CircleBorder(),
                ),
                child: IconButton(
                  icon: Image.asset('assets/compare-3d.png', height: 24),
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
              ),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: AnimatedScale(
                    scale: _cartBump ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = widget.searchResults;
    final searchKeyword = widget.searchKeyword;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = bottomInset > 0;
    final viewPaddingBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Stack(
          children: [
            // 메인 컨텐츠
            SafeArea(
              child: searchResults.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔍 검색어
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 20, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  searchKeyword,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onBackground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 📊 개수 안내
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            '${searchResults.length}개의 검색결과가 있습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                            ),
                          ),
                        ),
                        // 🔄 리스트 (CompareTray 변경에 반응하도록 AnimatedBuilder로 감쌈)
                        Expanded(
                          child: AnimatedBuilder(
                            animation: CompareTray.instance,
                            builder: (context, _) {
                              return ListView.builder(
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 100,
                                ),
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) {
                                  final item = searchResults[index];
                                  final String seq = (item['itemSeq']?.toString() ?? item['ITEM_SEQ']?.toString() ?? '').trim();
                                  final String? imageUrl = item['imageUrl']?.toString();
                                  final String itemName = (item['itemName'] ?? item['ITEM_NAME'] ?? '이름 없음').toString();
                                  final String entpName = (item['entpName'] ?? item['ENTP_NAME'] ?? '정보 없음').toString();

                                  // ✅ CompareTray 상태를 매 빌드마다 조회
                                  final bool inCart = seq.isNotEmpty && CompareTray.instance.contains(seq);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.15)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                                                height: 190,
                                                alignment: Alignment.center,
                                                child: FutureBuilder<String?>(
                                                  future: _fetchImageUrl(item),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                                      return SizedBox(
                                                        height: 190,
                                                        child: Center(
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        ),
                                                      );
                                                    }
                                                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                                                      return FutureBuilder<Widget>(
                                                        future: _buildImageWithAuth(snapshot.data!),
                                                        builder: (context, imgSnapshot) {
                                                          if (imgSnapshot.connectionState == ConnectionState.waiting) {
                                                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                                          }
                                                          return imgSnapshot.data ??
                                                              Icon(Icons.medication, size: 64, color: Colors.grey.shade400);
                                                        },
                                                      );
                                                    } else {
                                                      return Container(
                                                        color: Colors.grey.shade100,
                                                        child: Icon(
                                                          Icons.medication,
                                                          size: 64,
                                                          color: Colors.grey.shade400,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),

                                            Text(
                                              itemName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 18,
                                                height: 1.25,
                                                fontWeight: FontWeight.w800,
                                                color: Theme.of(context).colorScheme.onBackground,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              entpName,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                                              ),
                                            ),

                                            const SizedBox(height: 14),
                                            const Divider(height: 1),

                                            const SizedBox(height: 12),

                                            Builder(
                                              builder: (context) {
                                                final scale = MediaQuery.of(context).textScaleFactor;
                                                final double btnHeight = (48 * scale.clamp(1.0, 1.35)).clamp(48.0, 64.0);
                                                return Row(
                                                  children: [
                                                    // 약 정보 확인 (좌)
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: btnHeight,
                                                        child: OutlinedButton(
                                                          style: OutlinedButton.styleFrom(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            side: BorderSide(color: Colors.grey.shade400),
                                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                                          ),
                                                          onPressed: () => _openDetail(context, item),
                                                          child: const FittedBox(
                                                            fit: BoxFit.scaleDown,
                                                            child: Text(
                                                              '약 정보 확인',
                                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),

                                                    // 비교함 (우)
                                                    Expanded(
                                                      child: SizedBox(
                                                        height: btnHeight,
                                                        child: ElevatedButton.icon(
                                                          style: ElevatedButton.styleFrom(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            backgroundColor: inCart
                                                                ? const Color(0xFFFFD600)
                                                                : Theme.of(context).colorScheme.primary,
                                                            foregroundColor: Colors.black,
                                                            elevation: 0,
                                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                                          ),
                                                          onPressed: () {
                                                            final normalized = {
                                                              'itemSeq': seq,
                                                              'itemName': itemName,
                                                              'entpName': entpName == '정보 없음' ? null : entpName,
                                                              'imageUrl': (imageUrl != null && imageUrl.startsWith('http')) ? imageUrl : null,
                                                            };
                                                            _addToUnifiedCart(normalized);
                                                          },
                                                          icon: Image.asset(inCart ? 'assets/compare-3d.png' : 'assets/compare-2d.png', height: 24),
                                                          label: Flexible(
                                                            child: Text(
                                                              inCart ? '담김 (비교함)' : '비교함 담기',
                                                              maxLines: 1,
                                                              softWrap: false,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
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
            ),
            // 오른쪽 상단 떠있는 비교함 버튼
            if (!isKeyboardOpen)
              Positioned(
                right: 16,
                top: 56,
                child: _buildFloatingCartButton(context),
              ),
          ],
        ),
      ),
      floatingActionButton: isKeyboardOpen ? null : const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
  Future<Widget> _buildImageWithAuth(String url) async {
    try {
      final headers = await ApiHelper.getAuthHeaders();
      final resp = await http.get(Uri.parse(url), headers: headers);
      if (resp.statusCode == 200) {
        return Image.memory(
          resp.bodyBytes,
          fit: BoxFit.contain,
        );
      } else {
        print("❌ 이미지 로드 실패: ${resp.statusCode}");
      }
    } catch (e) {
      print("❌ 이미지 요청 중 오류: $e");
    }
    return Container(
      color: Colors.grey.shade100,
      child: Icon(Icons.medication, size: 64, color: Colors.grey.shade400),
    );
  }
  Future<String?> _fetchImageUrl(Map<String, dynamic> item) async {
    // 1. Try direct image fields first
    final List<dynamic> candidates = [
      item['imageUrl'],
      item['ITEM_IMAGE'], 
    ];
    for (final val in candidates) {
      if (val is String && val.trim().isNotEmpty) {
        final url = val.trim();
        if ((url.startsWith('http://') || url.startsWith('https://')) && !ImageUtils.isPlaceholder(url)) {
          return url;
        }
      }
    }
    // 2. Fallback to backend crawl endpoint
    final itemSeq = item['itemSeq']?.toString() ?? item['ITEM_SEQ']?.toString();
    if (itemSeq == null || itemSeq.isEmpty) {
      return null;
    }
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
    final crawlUrl = '$baseUrl/image-scrape?item_seq=$itemSeq';
    return crawlUrl;
  }