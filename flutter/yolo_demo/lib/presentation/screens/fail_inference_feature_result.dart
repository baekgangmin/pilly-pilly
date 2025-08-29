import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import '../../screens/final_result.dart';
import 'package:yolo_demo/screens/cart_screen.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:flutter/animation.dart';
import 'dart:async';
import 'package:yolo_demo/utils/image_utils.dart';

class FailInferenceFeatureResultScreen extends StatefulWidget {
  final List<Map<String, String>> results;

  const FailInferenceFeatureResultScreen({
    Key? key,
    required this.results,
  }) : super(key: key);

  @override
  State<FailInferenceFeatureResultScreen> createState() => _FailInferenceFeatureResultScreenState();
}

class _FailInferenceFeatureResultScreenState extends State<FailInferenceFeatureResultScreen> {
  bool _cartBump = false;

  // 이미지 크롤링 중복 방지 & 캐시
  final Set<String> _crawlInFlight = {};
  final Map<String, String> _crawledUrlCache = {};

  void _bumpCart() {
    if (!mounted) return;
    setState(() => _cartBump = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _cartBump = false);
    });
  }

  void _addToCompareTray(Map<String, dynamic> src) {
    final seq = (src['itemSeq'] ?? src['ITEM_SEQ'] ?? '').toString().trim();
    if (seq.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('잘못된 항목입니다. (itemSeq 없음)')));
      }
      return;
    }
    CompareTray.instance.addFromDynamic(src);
    if (!mounted) return;
    setState(() {
      _cartBump = true;
    });
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() => _cartBump = false);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비교함에 담았어요.')));
  }

  bool _isPlaceholder(String? url) {
    if (url == null) return true;
    if (url.isEmpty) return true;
    // 앱에서 사용하는 no_image, 'about:blank' 등은 플레이스홀더로 간주
    return url.contains('no_image') || url == 'about:blank';
  }

  bool _isCrawledUrl(String url) {
    // 백엔드 프록시 경로 패턴
    return url.contains('/image-scrape');
  }

  String _normalizeCrawledUrl(String raw) {
    // 혹시 토큰이 쿼리에 붙어온 경우 제거 (서버는 헤더 인증만 허용)
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    if (uri.queryParameters.containsKey('token')) {
      final newQuery = Map.of(uri.queryParameters);
      newQuery.remove('token');
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
        queryParameters: newQuery.isEmpty ? null : newQuery,
      ).toString();
    }
    return raw;
  }

  Widget _placeholderIcon({double size = 72}) {
    return Icon(
      Icons.medication,
      size: size,
      color: Colors.grey.shade400,
    );
  }

  Widget _authedNetworkImage(String url) {
    return FutureBuilder<Map<String, String>>(
      future: ApiHelper.getAuthHeaders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final headers = snapshot.data;
        return Image.network(
          url,
          headers: headers,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholderIcon(),
        );
      },
    );
  }

  /// 카드 썸네일용: 플레이스홀더면 1회 크롤링 트리거
  Widget _buildResultImage(Map<String, String> r) {
    final String seq = (r['itemSeq'] ?? '').toString();
    final String given = (r['imageUrl'] ?? '').toString();

    // 1) 캐시된 크롤링 URL 우선
    final String? cached = _crawledUrlCache[seq];
    if (cached != null && !_isPlaceholder(cached)) {
      final normalized = _normalizeCrawledUrl(cached);
      return _isCrawledUrl(normalized)
          ? _authedNetworkImage(normalized)
          : Image.network(
              normalized,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _placeholderIcon(),
            );
    }

    // 2) 원래 주어진 이미지가 유효하면 그대로
    if (!_isPlaceholder(given)) {
      return Image.network(
        given,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholderIcon(),
      );
    }

    // 3) itemSeq 없으면 플레이스홀더
    if (seq.isEmpty) {
      return _placeholderIcon();
    }

    // 4) 아직 크롤링 안 했으면 1회 트리거
    if (!_crawlInFlight.contains(seq)) {
      _crawlInFlight.add(seq);
      // 한 프레임 뒤에 비동기 실행하여 build 안전
      scheduleMicrotask(() async {
        try {
          final crawled = await ImageUtils.getImageWithCrawling({'itemSeq': seq});
          if (crawled != null && !_isPlaceholder(crawled)) {
            final normalized = _normalizeCrawledUrl(crawled);
            if (mounted) {
              setState(() {
                _crawledUrlCache[seq] = normalized;
              });
            }
          }
        } catch (e) {
          debugPrint('⚠️ [fail_feature] 크롤링 실패: $e');
        } finally {
          _crawlInFlight.remove(seq);
        }
      });
    }

    // 5) 로딩 플레이스홀더
    return _placeholderIcon();
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildCartButton(BuildContext context, Map<String, String> r) {
    final String seq = (r['itemSeq'] ?? '').toString();
    final bool inCart = seq.isNotEmpty && CompareTray.instance.contains(seq);
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(36),
        backgroundColor: inCart ? const Color(0xFFFFD600) : Theme.of(context).colorScheme.surface,
        foregroundColor: inCart ? Colors.black : Theme.of(context).colorScheme.onSurface,
        side: inCart ? BorderSide.none : BorderSide(color: Theme.of(context).dividerColor),
        elevation: inCart ? 1 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Image.asset(inCart ? 'assets/compare-3d.png' : 'assets/compare-2d.png', height: 28),
      label: Text(inCart ? '담김 (비교함)' : '비교함에 담기'),
      onPressed: () {
        if (seq.isEmpty) return;
        _addToCompareTray({
          'itemSeq': r['itemSeq'] ?? '',
          'itemName': r['itemName'] ?? '',
          'entpName': r['entpName'] ?? '',
          'imageUrl': r['imageUrl'] ?? '',
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🟢 결과 화면 빌드, 개수: ${widget.results.length}');
    if (widget.results.isNotEmpty) {
      debugPrint('🟢 샘플: ${widget.results.first}');
      debugPrint('🟢 타입: '
          'itemSeq=${widget.results.first['itemSeq']?.runtimeType}, '
          'itemName=${widget.results.first['itemName']?.runtimeType}, '
          'entpName=${widget.results.first['entpName']?.runtimeType}, '
          'imageUrl=${widget.results.first['imageUrl']?.runtimeType}');
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(true); // 메인으로 true 전달 → 돌아가면 refresh
        return false; // 우리가 pop 처리했으므로 기본 pop 막기
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('이미지 실패용 유사 검색 결과'),
          actions: [
            // 비교함 버튼 + 배지
            AnimatedBuilder(
              animation: CompareTray.instance,
              builder: (context, _) {
                final count = CompareTray.instance.count;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Image.asset('assets/compare-2d.png', height: 28),
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
                        // no manual reload; CompareTray notifies listeners
                      },
                      tooltip: '비교함',
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: AnimatedScale(
                          scale: _cartBump ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: AnimatedBuilder(
          animation: CompareTray.instance,
          builder: (context, _) {
            return widget.results.isEmpty
                ? const Center(
                    child: Text(
                      '유사한 검색 결과가 없습니다.',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.results.length,
                    itemBuilder: (context, index) {
                      final r = widget.results[index];
                      final imageUrl = r['imageUrl'] ?? '';
                      final itemName = r['itemName'] ?? '';
                      final entpName = r['entpName'] ?? '';
                      debugPrint('검색 결과 아이템: $r');
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 2,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final itemSeq = r['itemSeq'] ?? '';
                            if (itemSeq.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('itemSeq가 없어 결과 화면으로 이동할 수 없습니다.')),
                              );
                              return;
                            }

                            // 로딩 다이얼로그
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
                              final uri = Uri.parse('$baseUrl/api/v2/log');
                              final headers = await ApiHelper.getAuthHeaders();

                              // 단일 itemSeq를 리스트로 보내기
                              final response = await http.post(
                                uri,
                                headers: headers,
                                body: json.encode([itemSeq]),
                              );

                              // 로딩 닫기
                              if (Navigator.of(context).canPop()) Navigator.of(context).pop();

                              if (response.statusCode == 200) {
                                final data = json.decode(response.body);

                                try {
                                  final resultMap = data['results'] as Map<String, dynamic>?;
                                  if (resultMap != null) {
                                    for (final itemSeq in resultMap.keys) {
                                      final item = resultMap[itemSeq];
                                      final itemName = item['permit']?['permitDetail']?['itemName'];
                                      final timestamp = DateTime.now().toIso8601String();

                                      // 이미지 URL 후보 (확정 경로 우선)
                                      dynamic extracted =
                                          item['permit']?['permitDetail']?['itemImage'] ??
                                          item['permit']?['permitDetail']?['images']?['main'] ??
                                          item['permit']?['permitList']?['imageUrl'];

                                      // 프로토콜 보정: //로 시작하면 https: 붙이기
                                      if (extracted is String && extracted.startsWith('//')) {
                                        extracted = 'https:' + extracted;
                                      }

                                      // http/https 로 시작하는 URL만 저장
                                      final String? imageUrlForDb =
                                          (extracted is String && (extracted.startsWith('http://') || extracted.startsWith('https://')))
                                              ? extracted
                                              : null;

                                      // 크롤링 성공 캐시가 있으면 그걸로 대체
                                      final cachedCrawled = _crawledUrlCache[itemSeq.toString()];
                                      final String? finalImageForDb = (cachedCrawled != null && !_isPlaceholder(cachedCrawled))
                                          ? cachedCrawled
                                          : imageUrlForDb;

                                      debugPrint('🖼️ [fail_feature] itemSeq=' + itemSeq.toString() +
                                          ' candidates: itemImage=' + (item['permit']?['permitDetail']?['itemImage']?.toString() ?? 'null') +
                                          ', permit.images.main=' + (item['permit']?['permitDetail']?['images']?['main']?.toString() ?? 'null') +
                                          ', permit.list.image=' + (item['permit']?['permitList']?['imageUrl']?.toString() ?? 'null') +
                                          ' → chosen=' + (finalImageForDb ?? 'null'));

                                      if (itemName != null) {
                                        await DBHelper.addRecentPill(
                                          itemSeq: itemSeq.toString(),
                                          itemName: itemName.toString(),
                                          userId: 'guest', // 필요 시 실제 사용자 ID로 교체
                                          timestamp: timestamp,
                                          imageUrl: finalImageForDb, // 자산 경로는 DB에 저장하지 않음
                                        );
                                      }
                                      // 카드 썸네일도 즉시 반영
                                      if (finalImageForDb != null && finalImageForDb.isNotEmpty) {
                                        r['imageUrl'] = finalImageForDb;
                                        if (mounted) setState(() {});
                                      }
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('최근검색 저장 중 오류: $e');
                                }
                                // final_result.dart로 이동
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FinalResultScreen(resultData: data),
                                  ),
                                );
                                // 돌아와도 현재 화면 유지 (유사 검색 결과로 복귀)
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('서버 오류: ${response.statusCode}')),
                                );
                              }
                            } catch (e) {
                              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('오류 발생: $e')),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 큰 이미지
                                Container(
                                  height: 180, // 이미지 크게
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      color: Theme.of(context).colorScheme.surface,
                                      child: _buildResultImage(r),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 약명
                                Text(
                                  itemName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // 제조사명
                                Text(
                                  entpName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                // 액션 버튼 영역 (세로 배치: 자세히 / 장바구니)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 자세히
                                    OutlinedButton(
                                      onPressed: () async {
                                        final itemSeq = r['itemSeq'] ?? '';
                                        if (itemSeq.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('itemSeq가 없어 결과 화면으로 이동할 수 없습니다.')),
                                          );
                                          return;
                                        }
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
                                          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                                          if (response.statusCode == 200) {
                                            final data = json.decode(response.body);
                                            try {
                                              final resultMap = data['results'] as Map<String, dynamic>?;
                                              if (resultMap != null) {
                                                for (final itemSeq in resultMap.keys) {
                                                  final item = resultMap[itemSeq];
                                                  final itemName = item['permit']?['permitDetail']?['itemName'];
                                                  final timestamp = DateTime.now().toIso8601String();
                                                  dynamic extracted =
                                                      item['permit']?['permitDetail']?['itemImage'] ??
                                                      item['permit']?['permitDetail']?['images']?['main'] ??
                                                      item['permit']?['permitList']?['imageUrl'];
                                                  if (extracted is String && extracted.startsWith('//')) {
                                                    extracted = 'https:' + extracted;
                                                  }
                                          final String? imageUrlForDb =
                                              (extracted is String && (extracted.startsWith('http://') || extracted.startsWith('https://')))
                                                  ? extracted
                                                  : null;
                                          // 크롤링 성공 캐시가 있으면 그걸로 대체
                                          final cachedCrawled = _crawledUrlCache[itemSeq.toString()];
                                          final String? finalImageForDb = (cachedCrawled != null && !_isPlaceholder(cachedCrawled))
                                              ? cachedCrawled
                                              : imageUrlForDb;
                                          if (itemName != null) {
                                            await DBHelper.addRecentPill(
                                              itemSeq: itemSeq.toString(),
                                              itemName: itemName.toString(),
                                              userId: 'guest',
                                              timestamp: timestamp,
                                              imageUrl: finalImageForDb,
                                            );
                                          }
                                          // 카드 썸네일도 즉시 반영
                                          if (finalImageForDb != null && finalImageForDb.isNotEmpty) {
                                            r['imageUrl'] = finalImageForDb;
                                            if (mounted) setState(() {});
                                          }
                                                }
                                              }
                                            } catch (e) {
                                              debugPrint('최근검색 저장 중 오류: $e');
                                            }
                                            await Navigator.push(
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
                                        } catch (e) {
                                          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('오류 발생: $e')),
                                          );
                                        }
                                      },
                                      child: const Text('약 정보 확인'),
                                    ),
                                    const SizedBox(height: 8),
                                    // 비교함 담기 버튼 (CompareTray 리스닝으로 즉시 반영)
                                    _buildCartButton(context, r),
                                  ],
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
        floatingActionButton: const HomeFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
