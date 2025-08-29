import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/screens/final_result.dart';
import 'package:yolo_demo/utils/image_utils.dart';
import 'package:yolo_demo/utils/pdf_generator.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';


class FavoritePillListScreen extends StatefulWidget {
  final String folderName;
  final String? folderDescription;
  const FavoritePillListScreen({
    super.key,
    required this.folderName,
    this.folderDescription,
  });

  @override
  State<FavoritePillListScreen> createState() => _FavoritePillListScreenState();
}

class _FavoritePillListScreenState extends State<FavoritePillListScreen> with RouteAware {
  final Map<String, Future<String?>> _thumbFutureCache = {};
  List<Map<String, dynamic>> _pills = [];
  int _count = 0;
  DateTime? _lastSaved;
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  String? _folderDesc;

  String _formatKoreanDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _folderDesc = (widget.folderDescription?.trim().isNotEmpty ?? false)
        ? widget.folderDescription!.trim()
        : null;
    _loadPills();
    _loadFolderDescription(); // DB에서 설명 보강 로드
  }

  /// DB에서 폴더 설명을 추가로 로드(네비게이션에서 전달되지 않았을 때 대비)
  Future<void> _loadFolderDescription() async {
    try {
      // 📌 단일 조회 메서드가 없으므로, 통계 조회에서 설명 컬럼을 함께 사용
      final rows = await DBHelper.getAllFoldersWithStats();
      for (final r in rows) {
        final name = (r['folder_name'] ?? r['name'])?.toString();
        if (name == widget.folderName) {
          final d = (r['folder_description'] ?? r['description'])?.toString();
          if ((d?.trim().isNotEmpty ?? false) && d != _folderDesc) {
            if (!mounted) return;
            setState(() {
              _folderDesc = d!.trim();
            });
          }
          break;
        }
      }
    } catch (_) {
      // 설명이 없거나 조회 실패해도 화면은 정상 동작
    }
  }

  bool _isCrawledUrl(String? url) {
    if (url == null) return false;
    return url.contains('/image-scrape');
  }

  String _normalizeCrawledUrl(String? url) {
    if (url == null) return '';
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (!_isCrawledUrl(trimmed)) return trimmed;
    // Keep only item_seq (and optional refresh) — drop transient tokens
    try {
      final uri = Uri.parse(trimmed);
      final itemSeq = uri.queryParameters['item_seq'];
      final refresh = uri.queryParameters['refresh'];
      final cleaned = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
        queryParameters: {
          if (itemSeq != null) 'item_seq': itemSeq,
          if (refresh != null) 'refresh': refresh,
        },
      ).toString();
      return cleaned;
    } catch (_) {
      return trimmed;
    }
  }

  String? _extractItemSeqFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters['item_seq'];
    } catch (_) {
      return null;
    }
  }
  Future<String?> _crawlThumbUrl(String itemSeq) {
    // 캐시된 future 사용해 중복 호출 방지 (세션 내 중복 호출만 방지)
    return _thumbFutureCache[itemSeq] ??=
        ImageUtils.getImageWithCrawling({'itemSeq': itemSeq}).then((url) {
      final cleaned = _normalizeCrawledUrl(url);
      if (cleaned.isNotEmpty && !ImageUtils.isPlaceholder(cleaned)) {
        // UI 리스트에 즉시 반영
        final idx = _pills.indexWhere((e) => (e['item_seq']?.toString() ?? '') == itemSeq);
        if (idx != -1) {
          setState(() {
            _pills[idx] = {
              ..._pills[idx],
              'image_url': cleaned,
            };
          });
        }
        return cleaned;
      }
      return null;
    }).catchError((_) {
      return null;
    });
  }

  Future<Uint8List?> _fetchImageBytesWithAuth(String url) async {
    try {
      final headers = await ApiHelper.getAuthHeaders();
      Uri uri = Uri.parse(url);

      // 1st attempt
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 22));
      if (res.statusCode == 200) {
        return res.bodyBytes;
      }

      debugPrint('⚠️ [FavoritePillList] image GET ${res.statusCode} for $uri');

      // If Not Found and this is our crawl endpoint → retry ONCE with refresh=true
      if (res.statusCode == 404 && _isCrawledUrl(uri.toString())) {
        final qp = Map<String, String>.from(uri.queryParameters);
        qp['refresh'] = 'true';
        final refreshUri = uri.replace(queryParameters: qp);

        try {
          final res2 = await http.get(refreshUri, headers: headers).timeout(const Duration(seconds: 26));
          if (res2.statusCode == 200) {
            debugPrint('✅ [FavoritePillList] image GET ok after refresh for $refreshUri');
            return res2.bodyBytes;
          } else {
            debugPrint('❌ [FavoritePillList] image GET after refresh ${res2.statusCode} for $refreshUri');
          }
        } catch (e) {
          debugPrint('🔥 [FavoritePillList] image GET after refresh error for $refreshUri → $e');
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ [FavoritePillList] image GET error for $url → $e');
      return null;
    }
  }

  Widget _buildThumb(String? rawUrl) {
    final theme = Theme.of(context);

    final placeholderIcon = Icon(
      Icons.medication_rounded,
      size: 36,
      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
    );
    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: placeholderIcon),
    );

    // 1) 입력 URL 정규화
    final cleaned = _normalizeCrawledUrl(rawUrl);

    // 2) URL이 유효하면 그대로 표시
    if (cleaned.isNotEmpty && !ImageUtils.isPlaceholder(cleaned)) {
      if (_isCrawledUrl(cleaned)) {
        final _seq = _extractItemSeqFromUrl(cleaned);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<Uint8List?>(
            future: _fetchImageBytesWithAuth(cleaned),
            builder: (context, snap) {
              // Show a slightly more patient look-and-feel with same placeholder while waiting
              if (snap.connectionState == ConnectionState.waiting) return placeholder;
              final bytes = snap.data;
              if (bytes == null) return placeholder;
              return Image.memory(
                bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              );
            },
          ),
        );
      }
      // 일반 URL
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ImageUtils.cachedNetworkImage(
          imageUrl: cleaned,
          width: 72, height: 72,
          fit: BoxFit.cover,
        ),
      );
    }

    // 3) URL이 없으면 item_seq 기반 크롤링 1회 시도
    String? itemSeq;
    try {
      final found = _pills.firstWhere(
        (e) => (e['image_url'] as String?) == rawUrl,
        orElse: () => {},
      );
      itemSeq = (found['item_seq'] ?? found['ITEM_SEQ'])?.toString();
    } catch (_) {}

    if (itemSeq == null || itemSeq.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FutureBuilder<String?>(
        future: _crawlThumbUrl(itemSeq!),
        builder: (context, crawlSnap) {
          if (crawlSnap.connectionState == ConnectionState.waiting) return placeholder;
          final crawled = crawlSnap.data;
          if (crawled == null || ImageUtils.isPlaceholder(crawled)) return placeholder;

          // 크롤링된 URL은 인증 헤더 필요 가능성 있음 → 헤더 부착
          return FutureBuilder<Uint8List?>(
            future: _fetchImageBytesWithAuth(crawled),
            builder: (context, hdrSnap) {
              if (hdrSnap.connectionState == ConnectionState.waiting) return placeholder;
              final bytes = hdrSnap.data;
              if (bytes == null) return placeholder;
              return Image.memory(
                bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              );
            },
          );
        },
      ),
    );
  }

  /// DB에서 해당 폴더의 즐겨찾기 약 불러오기
  Future<void> _loadPills() async {
    final list = await DBHelper.getFavoritePillsByFolder(widget.folderName);
    DateTime? newest;
    for (final row in list) {
      final ts = row['timestamp'];
      if (ts is String) {
        final dt = DateTime.tryParse(ts);
        if (dt != null) {
          if (newest == null || dt.isAfter(newest)) newest = dt;
        }
      }
    }
    setState(() {
      _pills = list;
      _count = list.length;
      _lastSaved = newest;
    });
  }

  /// 즐겨찾기 삭제 (서버 + 로컬 동기화, ApiHelper.deleteWithAuth에서 401 자동 처리)
  Future<void> _deletePill(String itemSeq) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v2/favorite'); // DELETE 엔드포인트
      
      // 🚀 ApiHelper.deleteWithAuth에서 401 에러를 자동으로 처리
      final response = await ApiHelper.deleteWithAuth(
        uri,
        body: jsonEncode({
          "folder_name": widget.folderName, // 폴더 이름 포함
          "item_seq": itemSeq,
        }),
      );

      if (response.statusCode == 200) {
        // 서버 삭제 성공 → 로컬 DB에서도 삭제
        await DBHelper.removeFavoritePill(
          itemSeq: itemSeq,
          folderName: widget.folderName,
        );
        await _loadPills();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('삭제되었습니다')),
          );
        }
      } else if (response.statusCode == 403) {
        // 🚀 403 Forbidden: 권한 없음 - 사용자에게 안내 필요
        debugPrint('🚫 [FavoritePillList] 403 Forbidden - 권한 없음: 즐겨찾기 삭제');
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('권한 없음'),
                ],
              ),
              content: const Text(
                '즐겨찾기를 삭제할 권한이 없습니다.\n\n'
                '관리자에게 문의하거나, 계정 권한을 확인해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else {
        debugPrint('❌ [FavoritePillList] 서버 삭제 실패: ${response.statusCode}');
        
        // 🚀 사용자에게 에러를 보여주지 않고 자연스럽게 처리
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔥 [FavoritePillList] 즐겨찾기 삭제 중 오류: $itemSeq - $e');
      
      // 🚀 사용자에게 에러를 보여주지 않고 자연스럽게 처리
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 폴더 삭제 (서버 + 로컬 동기화, ApiHelper.postWithAuth에서 401 자동 처리)
  Future<void> _deleteFolder() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v2/favorite/folder/delete');
      
      // 🚀 ApiHelper.postWithAuth에서 401 에러를 자동으로 처리
      final response = await ApiHelper.postWithAuth(
        uri,
        body: jsonEncode({"folder_name": widget.folderName}),
      );

      if (response.statusCode == 200) {
        await DBHelper.deleteFolder(widget.folderName);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 403) {
        // 🚀 403 Forbidden: 권한 없음 - 사용자에게 안내 필요
        debugPrint('🚫 [FavoritePillList] 403 Forbidden - 권한 없음: 폴더 삭제');
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('권한 없음'),
                ],
              ),
              content: const Text(
                '폴더를 삭제할 권한이 없습니다.\n\n'
                '관리자에게 문의하거나, 계정 권한을 확인해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else {
        debugPrint('❌ [FavoritePillList] 폴더 삭제 실패: ${response.statusCode}');
        
        // 🚀 사용자에게 에러를 보여주지 않고 자연스럽게 처리
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('폴더 삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔥 [FavoritePillList] 폴더 삭제 중 오류: ${widget.folderName} - $e');
      
      // 🚀 사용자에게 에러를 보여주지 않고 자연스럽게 처리
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('폴더 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// PDF 출력 기능
  Future<void> _exportToPDF() async {
    if (_pills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📄 저장된 약이 없어 PDF를 생성할 수 없습니다.\n먼저 약을 저장해주세요!'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => Dialog(
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    'PDF 생성 중…',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // PDF 생성
      final pdfFile = await MedicationFolderPDFGenerator.generateFolderPDF(
        folderName: widget.folderName,
        folderDescription: _folderDesc,
        medications: _pills,
      );

      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);

      // PDF 옵션 다이얼로그 표시
      if (mounted) {
        await _showPDFOptions(pdfFile);
      }

    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF 생성 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// PDF 옵션 다이얼로그
  Future<void> _showPDFOptions(File pdfFile) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF 생성 완료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('복약이력 PDF가 생성되었습니다.'),
            const SizedBox(height: 8),
            Text(
              '파일명: ${pdfFile.path.split('/').last}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 150));
              await OpenFile.open(pdfFile.path);
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('열기'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.shareXFiles([XFile(pdfFile.path)]);
            },
            icon: const Icon(Icons.share),
            label: const Text('공유'),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0,4))],
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Folder avatar
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.folder_copy_rounded, size: 28),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.folderName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if ((_folderDesc ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _folderDesc!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: count chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '보관 약 $_count개',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Line 2: last saved chip
                      if (_lastSaved != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '최근: ${_formatKoreanDateTime(_lastSaved!)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // PDF 출력 버튼
            Container(
              decoration: BoxDecoration(
                color: _pills.isNotEmpty ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pills.isNotEmpty ? Colors.red.shade200 : Colors.grey.shade300,
                ),
              ),
              child: IconButton(
                onPressed: _exportToPDF,
                icon: Icon(
                  Icons.picture_as_pdf,
                  color: _pills.isNotEmpty ? Colors.red.shade700 : Colors.grey.shade500,
                  size: 24,
                ),
                tooltip: _pills.isNotEmpty ? 'PDF 출력' : '저장된 약이 없습니다',
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 서버에서 약 상세정보 조회 후 FinalResultScreen으로 이동 (ApiHelper.postWithAuth에서 401 자동 처리)
  Future<void> _navigateToFinalResult(String itemSeq) async {
    // Show loading dialog before sending HTTP request
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final uri = Uri.parse('$_baseUrl/api/v2/log'); // 상세조회 API
      
      // 🚀 ApiHelper.postWithAuth에서 401 에러를 자동으로 처리
      final response = await ApiHelper.postWithAuth(
        uri,
        body: jsonEncode([itemSeq]), // 서버가 리스트 형태로 받으므로 그대로 전송
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 최근 검색 기록 저장 코드 제거됨 (FavoritePillListScreen에서는 최근 검색에 추가하지 않음)

        // Dismiss loading dialog before navigation
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalResultScreen(resultData: data),
          ),
        );
      } else if (response.statusCode == 403) {
        // 🚀 403 Forbidden: 권한 없음 - 사용자에게 안내 필요
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        debugPrint('🚫 [FavoritePillList] 403 Forbidden - 권한 없음: 약물 상세조회');
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('권한 없음'),
                ],
              ),
              content: const Text(
                '약물 정보를 조회할 권한이 없습니다.\n\n'
                '관리자에게 문의하거나, 계정 권한을 확인해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else if (response.statusCode == 404) {
        // 🚀 404 Not Found: 취하/폐기된 약물 또는 유효기간만료
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        debugPrint('🔍 [FavoritePillList] 404 Not Found - 취하/폐기/유효기간만료: $itemSeq');
        
        if (mounted) {
          showDialog(
            context: context,
              builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red),
                  SizedBox(width: 8),
                  Text('약물 정보 없음'),
                ],
              ),
              content: const Text(
                '해당 약물은 취하되거나 폐기되었거나 유효기간이 만료되었습니다.\n\n'
                '최근 검색 기록에서 제거되며, 상세 정보를 조회할 수 없습니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else if (response.statusCode == 408) {
        // 🚀 408 Timeout: 요청 시간 초과 - 자동 재시도 후 실패
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        debugPrint('⏰ [FavoritePillList] 408 Timeout - 요청 시간 초과: $itemSeq');
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.timer, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('요청 시간 초과'),
                ],
              ),
              content: const Text(
                '서버 응답이 지연되고 있습니다.\n\n'
                '잠시 후 다시 시도해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToFinalResult(itemSeq); // 재시도
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }
      } else {
        // Dismiss loading dialog before showing error
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        debugPrint('❌ [FavoritePillList] 상세조회 실패: ${response.statusCode} → ${response.body}');
        
        // 🚀 사용자에게 에러를 보여주지 않고 자연스럽게 처리
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('약물 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog before showing error
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint('🔥 [FavoritePillList] 상세조회 중 오류: $itemSeq - $e');
      
      // 🚀 사용자에게 에러를 보여주지 않고 자연스럽게 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('약물 정보를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    _loadPills(); // 화면 복귀 시 데이터 새로고침
  }

  @override
  void dispose() {
    // routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        actions: [
          // PDF 출력 버튼
          IconButton(
            icon: Icon(
              Icons.picture_as_pdf,
              color: _pills.isNotEmpty ? Colors.red.shade700 : Colors.grey.shade400,
            ),
            onPressed: _exportToPDF,
            tooltip: _pills.isNotEmpty ? 'PDF 출력' : '저장된 약이 없습니다',
          ),
          // 폴더 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              if (widget.folderName == '기본 폴더') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('기본 폴더는 삭제할 수 없습니다.')),
                );
                return;
              }
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('폴더 삭제'),
                  content: Text(
                    '정말 "${widget.folderName}" 폴더를 삭제하시겠습니까?\n'
                    '폴더 안의 약들도 함께 삭제됩니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _deleteFolder();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFolderHeaderCard(context),
          Expanded(
            child: _pills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication_liquid_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "아직 저장된 약이 없습니다 🥹",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _pills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final pill = _pills[index];
                      final tsRaw = pill['timestamp'];
                      DateTime? savedAt;
                      if (tsRaw is String) {
                        savedAt = DateTime.tryParse(tsRaw);
                      }

                      final leading = _buildThumb(pill['image_url'] as String?);

                      return Dismissible(
                        key: Key(pill['item_seq']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('삭제 확인'),
                              content: Text('정말 "${pill['item_name']}" 약을 삭제하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) => _deletePill(pill['item_seq']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 1,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _navigateToFinalResult(pill['item_seq']),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    leading,
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pill['item_name'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.2,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.bookmark_border_rounded, size: 14),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  savedAt != null ? '저장: ${_formatKoreanDateTime(savedAt)}' : '저장 일시 정보 없음',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        fontSize: 10,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}