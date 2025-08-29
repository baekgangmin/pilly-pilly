import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/screens/final_result.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:yolo_demo/utils/image_utils.dart';

class PositionedFillLoading extends StatelessWidget {
  const PositionedFillLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: ColoredBox(
          color: Color(0x11000055),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _loading = false;

  Future<void> _saveRecentsFromResponse(Map<String, dynamic> data) async {
    try {
      final resultMap = data['results'] as Map<String, dynamic>?;
      if (resultMap == null) return;
      for (final itemSeq in resultMap.keys) {
        final item = resultMap[itemSeq];

        // itemName
        final itemName = item['permit']?['permitDetail']?['itemName'];

        // pick imageUrl from multiple possible locations
        final dynamic extracted =
            item['permit']?['permitDetail']?['itemImage'] ??
            item['permit']?['permitDetail']?['images']?['main'] ??
            item['permit']?['permitList']?['imageUrl'] ??
            item['images']?['main'] ??
            item['imageUrl'];

        final String? imageUrlForDb =
            (extracted is String && extracted.startsWith('http')) ? extracted : null;

        if (itemName != null) {
          await DBHelper.addRecentPill(
            itemSeq: itemSeq.toString(),
            itemName: itemName.toString(),
            userId: 'guest',
            timestamp: DateTime.now().toIso8601String(),
            imageUrl: imageUrlForDb,
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ save recents error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _removeOne(String itemSeq) async {
    await CompareTray.instance.remove(itemSeq);
    if (mounted) setState(() {}); // trigger rebuild
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('비교함의 모든 항목을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await CompareTray.instance.clear();
      if (mounted) setState(() {});
    }
  }

  String? _imageOf(Map<String, dynamic> m) {
    final v = m['imageUrl'] ?? m['ITEM_IMAGE'] ?? m['thumbnail'] ?? m['thumbUrl'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  /// 이미지 크롤링을 포함한 이미지 URL 가져오기
  Future<String?> _getImageWithCrawling(Map<String, dynamic> m) async {
    final originalImage = _imageOf(m);
    
    // 원본 이미지가 유효하면 그대로 사용
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      return originalImage;
    }

    // placeholder인 경우 크롤링 시도
    final itemSeq = _seqOf(m);
    if (itemSeq.isNotEmpty) {
      try {
        final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq});
        if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
          print("🖼️ [CartScreen] 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
          return crawledImageUrl;
        }
      } catch (e) {
        print("❌ [CartScreen] 이미지 크롤링 실패: $itemSeq - $e");
      }
    }

    // 크롤링 실패시 기본 이미지 반환
    return 'assets/no_image.png';
  }

  String _nameOf(Map<String, dynamic> m) {
    return (m['itemName'] ?? m['ITEM_NAME'] ?? '').toString();
  }

  String _seqOf(Map<String, dynamic> m) {
    return (m['itemSeq'] ?? m['ITEM_SEQ'] ?? '').toString();
  }

  String _entpOf(Map<String, dynamic> m) {
    final v = m['entpName'] ??
        m['ENTP_NAME'] ??
        m['entp'] ??
        m['ENTP'] ??
        m['entp_name'] ??
        m['ENTP_NM'];
    return (v ?? '').toString();
  }

  Widget _buildEmptyCompareView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              '아직 담긴 약이 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '검색 결과에서 ‘비교함에 담기’를 눌러\n두 제품 이상 담으면\n함께 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.search),
              label: const Text('검색하러 가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _openFinalForOne(String itemSeq) async {
    try {
      setState(() => _loading = true);
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/v2/log');
      final headers = await ApiHelper.getAuthHeaders();
      final res = await http.post(uri, headers: headers, body: jsonEncode([itemSeq]));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _saveRecentsFromResponse(data);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FinalResultScreen(resultData: data)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFinalForAll() async {
    final items = CompareTray.instance.items;
    if (items.isEmpty) return;
    try {
      setState(() => _loading = true);
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final uri = Uri.parse('$baseUrl/api/v2/log');
      final headers = await ApiHelper.getAuthHeaders();
      final seqs = items.map((e) => _seqOf(e)).where((s) => s.isNotEmpty).toList();
      final res = await http.post(uri, headers: headers, body: jsonEncode(seqs));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await _saveRecentsFromResponse(data);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FinalResultScreen(resultData: data)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CompareTray.instance,
      builder: (context, _) {
        final items = CompareTray.instance.items;
        return Scaffold(
          appBar: AppBar(
            title: const Text('비교함'),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: '전체 삭제',
                  icon: const Icon(Icons.delete_forever_outlined),
                  onPressed: _clearAll,
                ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Unified header always shown
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1) Top line: "비교할 약 n개" left-aligned
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '비교할 약 ${items.length}개',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 2) Second line: "비교함이 무엇인가요?" right-aligned
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 헤더
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Image.asset('assets/compare-3d.png', height: 32),
                                        ),
                                        const SizedBox(height: 20),
                                        
                                        // 제목
                                        Text(
                                          '비교함이란?',
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        
                                        // 설명 항목들
                                        _buildInfoItem(
                                          icon: Icons.add_shopping_cart_rounded,
                                          text: '여러 약을 동시에 비교할 수 있는 기능입니다.',
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        _buildInfoItem(
                                          icon: Icons.search_rounded,
                                          text: '검색 결과에서 비교함에 담기를 눌러 약을 추가하세요.',
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(height: 16),
                                        
                                        _buildInfoItem(
                                          icon: Icons.compare_rounded,
                                          text: '두 제품 이상 담으면 함께 비교하여 확인할 수 있어요.',
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        
                                        const SizedBox(height: 24),
                                        
                                        // 닫기 버튼
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton(
                                            onPressed: () => Navigator.pop(context),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              '확인했어요',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '비교함이 무엇인가요?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? _buildEmptyCompareView(context)
                        : ListView.separated(
                            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 96),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final m = items[index];
                              final name = _nameOf(m);
                              final seq = _seqOf(m);
                              final image = _imageOf(m);
                              final entp = _entpOf(m);
                              return InkWell(
                                onTap: () => _openFinalForOne(seq),
                                child: Card(
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: SizedBox(
                                            width: 80,
                                            height: 80,
                                            child: FutureBuilder<String?>(
                                              future: _getImageWithCrawling(m),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                
                                                final imageUrl = snapshot.data;
                                                if (imageUrl != null && !ImageUtils.isPlaceholder(imageUrl)) {
                                                  return Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => Image.asset('assets/no_image.png'),
                                                  );
                                                } else {
                                                  return Image.asset('assets/no_image.png');
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.isNotEmpty ? name : '이름 없음',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                entp.isNotEmpty ? entp : '제조사 정보 없음',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: '삭제',
                                          onPressed: () => _removeOne(seq),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              if (_loading) const PositionedFillLoading(),
            ],
          ),
          bottomNavigationBar: items.isEmpty
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openFinalForAll,
                            icon: const Icon(Icons.search),
                            label: const Text('비교함 검색하기'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('전체 삭제'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
