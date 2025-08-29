import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/models/pill_data.dart'; // PillData 모델 파일 경로에 맞춰 수정해줘
import 'package:yolo_demo/utils/image_utils.dart';
import 'final_result.dart';

class RecentAllScreen extends StatefulWidget {
  const RecentAllScreen({Key? key}) : super(key: key);

  @override
  State<RecentAllScreen> createState() => _RecentAllScreenState();
}

class _RecentAllScreenState extends State<RecentAllScreen> {
  static const double _kTitleBoxHeight = 76; // enough for up to ~4 lines at large text settings
  bool _loading = true;
  List<PillData> _items = [];

  // ---- In-memory memoization to avoid duplicate crawling/requests ----
  final Map<String, Future<String?>> _crawlUrlFutures = {};      // itemSeq -> future(crawled url)
  final Map<String, String?> _crawlUrlCache = {};                // itemSeq -> last successful url

  Future<Uint8List?> _fetchCrawledImageBytes({required String itemSeq}) async {
    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/image-scrape?item_seq=$itemSeq');
      final headers = await ApiHelper.getAuthHeaders();
      final filtered = <String, String>{};
      final authValue = headers['Authorization'];
      if (authValue != null) filtered['Authorization'] = authValue;
      final res = await http.get(uri, headers: filtered);
      if (res.statusCode == 200) return res.bodyBytes;
      debugPrint('⚠️ 크롤링된 이미지 바이트 요청 실패: ${res.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ 이미지 바이트 로드 오류: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  String _normalizeCrawledUrl(String url) {
    try {
      final u = Uri.parse(url);
      if (!u.path.contains('/image-scrape')) return url;

      // Keep only item_seq; drop token and others
      final itemSeq = u.queryParameters['item_seq'];
      if (itemSeq == null || itemSeq.isEmpty) return url;

      final normalized = Uri(
        scheme: u.scheme,
        host: u.host,
        port: u.hasPort ? u.port : null,
        path: u.path,
        queryParameters: { 'item_seq': itemSeq },
      );
      return normalized.toString();
    } catch (_) {
      return url;
    }
  }

  bool _isCrawledUrl(String? url) {
    return url != null && url.contains('/image-scrape');
  }
  Future<void> _loadRecent() async {
    setState(() => _loading = true);
    try {
      final list = await DBHelper.getRecentPills(); // 최신순으로 오도록 DBHelper에서 정렬되어 있으면 그대로 사용
      setState(() {
        _items = list;
      });
    } catch (e) {
      debugPrint('최근검색 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('최근검색을 불러오는 중 오류가 발생했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('최근검색 전체 삭제'),
        content: const Text('최근검색을 모두 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await DBHelper.deleteRecentPills();
      await _loadRecent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최근검색을 모두 삭제했어요.')),
        );
      }
      Navigator.pop(context, true); // 메인에 리프레시 신호
    } catch (e) {
      debugPrint('전체 삭제 오류: $e');
    }
  }

  Future<void> _deleteOne(PillData pill) async {
    try {
      await DBHelper.deleteRecentPill(pill.itemSeq);
      setState(() => _items.remove(pill));
    } catch (e) {
      debugPrint('단건 삭제 오류: $e');
    }
  }

  Future<void> _openDetail(PillData pill) async {
    // 상세 조회 → FinalResultScreen → 복귀 시 본 화면 업데이트
    try {
      // Show loading while requesting detail
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/v2/log');
      final headers = await ApiHelper.getAuthHeaders();

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode([pill.itemSeq]),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 성공 시 상세로 이동
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FinalResultScreen(resultData: data)),
        );

        // 복귀 시 최신 목록 갱신
        await _loadRecent();
      } else {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상세 조회 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: '전체 삭제',
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('최근검색이 비어 있어요.'))
              : RefreshIndicator(
                onRefresh: _loadRecent,
                child: Builder(
                  builder: (context) {
                    final sections = _groupByDateDesc(_items);
                    // (Optional) Debug: print section lengths
                    for (final s in sections) {
                      debugPrint('  • 섹션 ${s.key} length=${s.value.length}');
                    }
                    if (sections.isEmpty && _items.isNotEmpty) {
                      // 폴백: 섹션이 0인데 아이템은 있는 경우 기본 그리드로 표시
                      debugPrint('🛟 섹션=0, items=${_items.length} → 폴백 그리드 표시');
                      final cs = Theme.of(context).colorScheme;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final pill = _items[index];
                          final imageUrl = pill.imageUrl;
                          return InkWell(
                            onTap: () => _openDetail(pill),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.primary.withOpacity(0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    offset: const Offset(0, 2),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Column(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 10, // wider box to reduce vertical padding for wide images
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: FutureBuilder<String?>(
                                        future: _getImageWithCrawling({
                                          'itemSeq': pill.itemSeq,
                                          'imageUrl': pill.imageUrl,
                                        }),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) {
                                            return Container(
                                              color: Colors.grey.shade200,
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              ),
                                            );
                                          }

                                          final raw = snapshot.data;
                                          final cleaned = (raw == null) ? null : _normalizeCrawledUrl(raw);

                                          if (cleaned != null && !ImageUtils.isPlaceholder(cleaned)) {
                                            if (_isCrawledUrl(cleaned)) {
                                              return FutureBuilder<Uint8List?>(
                                                future: _fetchCrawledImageBytes(itemSeq: pill.itemSeq ?? ''),
                                                builder: (context, bytesSnap) {
                                                  if (bytesSnap.connectionState == ConnectionState.waiting) {
                                                    return Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Center(
                                                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                                      ),
                                                    );
                                                  }
                                                  final bytes = bytesSnap.data;
                                                  if (bytes == null || bytes.isEmpty) {
                                                    return Center(
                                                      child: Icon(
                                                        Icons.medication_rounded,
                                                        size: 44,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                      ),
                                                    );
                                                  }
                                                  return Image.memory(
                                                    bytes,
                                                    fit: BoxFit.contain,
                                                    gaplessPlayback: true,
                                                  );
                                                },
                                              );
                                            }

                                            // 일반 URL → 헤더 불필요
                                            return Image.network(
                                              cleaned,
                                              fit: BoxFit.contain,
                                              gaplessPlayback: true,
                                              errorBuilder: (_, __, ___) => Center(
                                                child: Icon(
                                                  Icons.medication_rounded,
                                                  size: 44,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                ),
                                              ),
                                            );
                                          } else {
                                            return Center(
                                              child: Icon(
                                                Icons.medication_rounded,
                                                size: 44,
                                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: _kTitleBoxHeight,
                                    child: Text(
                                      pill.itemName,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 4, // 3~4줄만 보이게 고정
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                        height: 1.22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }

                    // 정상: 날짜 섹션 + 그리드 (간단 ListView 버전)
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: sections.length,
                      itemBuilder: (context, sectionIndex) {
                        final section = sections[sectionIndex];
                        final date = section.key;
                        final list = section.value;
                        final cs = Theme.of(context).colorScheme;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 날짜 헤더
                              Row(
                                children: [
                                  Text(
                                    date,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Divider(color: Theme.of(context).dividerColor, thickness: 1)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 섹션 그리드
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.65,
                                ),
                                itemCount: list.length,
                                itemBuilder: (context, index) {
                                  final pill = list[index];
                                  final imageUrl = pill.imageUrl;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _openDetail(pill),
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: cs.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: cs.primary.withOpacity(0.12)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.05),
                                                offset: const Offset(0, 2),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              AspectRatio(
                                                aspectRatio: 16 / 10, // wider box to reduce vertical padding for wide images
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: FutureBuilder<String?>(
                                                    future: _getImageWithCrawling({
                                                      'itemSeq': pill.itemSeq,
                                                      'imageUrl': pill.imageUrl,
                                                    }),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                                        return Container(
                                                          color: Colors.grey.shade200,
                                                          child: const Center(
                                                            child: SizedBox(
                                                              width: 16,
                                                              height: 16,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      
                                                      final finalImageUrl = snapshot.data;
                                                      final cleaned = (finalImageUrl == null) ? null : _normalizeCrawledUrl(finalImageUrl);
                                                      if (cleaned != null && !ImageUtils.isPlaceholder(cleaned)) {
                                                        if (_isCrawledUrl(cleaned)) {
                                                          return FutureBuilder<Uint8List?>(
                                                            future: _fetchCrawledImageBytes(itemSeq: pill.itemSeq ?? ''),
                                                            builder: (context, bytesSnap) {
                                                              if (bytesSnap.connectionState == ConnectionState.waiting) {
                                                                return Container(
                                                                  color: Colors.grey.shade200,
                                                                  child: const Center(
                                                                    child: SizedBox(
                                                                      width: 16,
                                                                      height: 16,
                                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                              final bytes = bytesSnap.data;
                                                              if (bytes == null || bytes.isEmpty) {
                                                                return Center(
                                                                  child: Icon(
                                                                    Icons.medication_rounded,
                                                                    size: 44,
                                                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                                  ),
                                                                );
                                                              }
                                                              return Image.memory(
                                                                bytes,
                                                                fit: BoxFit.contain,
                                                                gaplessPlayback: true,
                                                              );
                                                            },
                                                          );
                                                        }
                                                        // 일반 URL → 헤더 불필요
                                                        return Image.network(
                                                          cleaned,
                                                          fit: BoxFit.contain,
                                                          gaplessPlayback: true,
                                                          errorBuilder: (_, __, ___) => Center(
                                                            child: Icon(
                                                              Icons.medication_rounded,
                                                              size: 44,
                                                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                            ),
                                                          ),
                                                        );
                                                      } else {
                                                        return Center(
                                                          child: Icon(
                                                            Icons.medication_rounded,
                                                            size: 44,
                                                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: _kTitleBoxHeight,
                                                child: Text(
                                                  pill.itemName,
                                                  textAlign: TextAlign.center,
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 4, // 3~4줄만 보이게 고정
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: cs.onSurface,
                                                    height: 1.22,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder: const CircleBorder(),
                                              onTap: () => _deleteOne(pill),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: cs.surface.withOpacity(0.9),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.08),
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(Icons.close_rounded, size: 16, color: cs.onSurface.withOpacity(0.7)),
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
                        );
                      },
                    );
                  },
                ),
              ),
    );
  }

  /// ISO timestamp -> 'YYYY-MM-DD'
  String _dateKey(String iso) {
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '';
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    } catch (_) {
      return '';
    }
  }

  /// 날짜별 그룹핑(내림차순 정렬, 빈 timestamp는 '기타'로 묶고 '기타'는 맨 뒤로)
  List<MapEntry<String, List<PillData>>> _groupByDateDesc(List<PillData> items) {
    final map = <String, List<PillData>>{};
    debugPrint('🧩 그룹핑 시작: items=${items.length}');
    for (final p in items) {
      final k0 = _dateKey(p.timestamp);
      final k = (k0.isEmpty) ? '기타' : k0; // 파싱 실패도 '기타'로 묶기
      map.putIfAbsent(k, () => []).add(p);
    }
    debugPrint('🧩 그룹 수: ${map.length}  (keys=${map.keys.join(', ')})');
    final entries = map.entries.toList();
    // '기타'는 항상 맨 뒤로 정렬
    entries.sort((a, b) {
      if (a.key == '기타') return 1;
      if (b.key == '기타') return -1;
      return b.key.compareTo(a.key);
    });
    return entries;
  }

  Future<String?> _getImageWithCrawling(Map<String, String?> data) {
    final itemSeq = data['itemSeq'];
    final imageUrl = data['imageUrl'];

    // If original url is valid (non-placeholder), just use it
    if (imageUrl != null && !ImageUtils.isPlaceholder(imageUrl)) {
      return Future.value(imageUrl);
    }

    if (itemSeq == null || itemSeq.isEmpty) {
      return Future.value(null);
    }

    // Return cached value if available
    final cached = _crawlUrlCache[itemSeq];
    if (cached != null) {
      return Future.value(cached);
    }

    // De-duplicate concurrent crawl URL requests per itemSeq
    final inflight = _crawlUrlFutures[itemSeq];
    if (inflight != null) return inflight;

    final future = ImageUtils.getImageWithCrawling({'itemSeq': itemSeq, 'imageUrl': imageUrl})
        .then((url) async {
          if (url == null || ImageUtils.isPlaceholder(url)) return null;
          final normalized = _normalizeCrawledUrl(url);
          debugPrint('🖼️ [RecentAll] 이미지 크롤링 성공: $itemSeq -> $normalized');
          try {
            await DBHelper.updateRecentImage(itemSeq: itemSeq, imageUrl: normalized);
          } catch (e) {
            debugPrint('⚠️ [RecentAll] recent image update failed: $e');
          }
          _crawlUrlCache[itemSeq] = normalized;
          return normalized;
        }).whenComplete(() {
          _crawlUrlFutures.remove(itemSeq);
        });

    _crawlUrlFutures[itemSeq] = future;
    return future;
  }

  String _prettyTime(String iso) {
    // 간단 포맷 (YYYY-MM-DD)
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return '';
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    } catch (_) {
      return '';
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
