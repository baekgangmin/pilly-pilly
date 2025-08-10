import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../db_helper.dart';
import '../main.dart';
import 'package:yolo_demo/api_services/api_helper.dart'; // 인증 헤더 불러오기
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'final_result.dart'; // FinalResultScreen import 추가

class FavoritePillListScreen extends StatefulWidget {
  final String folderName;
  const FavoritePillListScreen({super.key, required this.folderName});

  @override
  State<FavoritePillListScreen> createState() => _FavoritePillListScreenState();
}

class _FavoritePillListScreenState extends State<FavoritePillListScreen> with RouteAware {
  List<Map<String, dynamic>> _pills = [];
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadPills();
  }

  /// DB에서 해당 폴더의 즐겨찾기 약 불러오기
  Future<void> _loadPills() async {
    final list = await DBHelper.getFavoritePillsByFolder(widget.folderName);
    setState(() => _pills = list);
  }

  /// 즐겨찾기 삭제 (서버 + 로컬 동기화)
  Future<void> _deletePill(String itemSeq) async {
    final headers = await ApiHelper.getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/api/v2/favorite'); // DELETE 엔드포인트

    try {
      // DELETE 요청에 folder_name + item_seq 전송
      final request = http.Request('DELETE', uri)
        ..headers.addAll(headers)
        ..body = jsonEncode({
          "folder_name": widget.folderName, // 폴더 이름 포함
          "item_seq": itemSeq,
        });

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

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
      } else {
        debugPrint('❌ 서버 삭제 실패: ${response.statusCode} → $responseBody');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 동기화 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('🔥 즐겨찾기 삭제 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 오류 발생: $e')),
      );
    }
  }

  /// 폴더 삭제 (서버 + 로컬 동기화)
  Future<void> _deleteFolder() async {
    final headers = await ApiHelper.getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/api/v2/favorite/folder/delete');

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({"folder_name": widget.folderName}),
      );

      if (response.statusCode == 200) {
        await DBHelper.deleteFolder(widget.folderName);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('폴더 삭제 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('폴더 삭제 중 오류 발생: $e')),
      );
    }
  }

  /// 서버에서 약 상세정보 조회 후 FinalResultScreen으로 이동
  Future<void> _navigateToFinalResult(String itemSeq) async {
    final headers = await ApiHelper.getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/api/v2/log'); // 상세조회 API

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode([itemSeq]), // 서버가 리스트 형태로 받으므로 그대로 전송
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 최근 검색 기록에 추가
        // userId를 실제 유저 ID로 대체하세요.
        String currentUserId = 'default_user'; // TODO: 실제 유저 ID로 대체
        await DBHelper.addRecentPill(
          itemSeq: itemSeq,
          itemName: data[0]['itemName'] ?? '',
          timestamp: DateTime.now().toIso8601String(),
          userId: currentUserId,
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FinalResultScreen(resultData: data),
          ),
        );
      } else {
        debugPrint('❌ 상세조회 실패: ${response.statusCode} → ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('🔥 상세조회 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상세 조회 중 오류 발생: $e')),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    _loadPills(); // 화면 복귀 시 데이터 새로고침
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.folderName} 폴더'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
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
      body: _pills.isEmpty
          ? const Center(child: Text("약이 없습니다 🥹"))
          : ListView.builder(
              itemCount: _pills.length,
              itemBuilder: (context, index) {
                final pill = _pills[index];

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
                    return await showDialog(
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
                  child: ListTile(
                    leading: pill['image_url'] != null && pill['image_url'].isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: pill['image_url'],
                            width: 40,
                            height: 40,
                            placeholder: (_, __) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.image_not_supported, size: 40),
                          )
                        : const Icon(Icons.medication, size: 40),
                    title: Text(pill['item_name'] ?? ''),
                    // 🔹 약 클릭 시 FinalResultScreen으로 이동
                    onTap: () => _navigateToFinalResult(pill['item_seq']),
                  ),
                );
              },
            ),
    );
  }
}