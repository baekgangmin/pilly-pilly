import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yolo_demo/screens/feature_search.dart';
import 'package:yolo_demo/screens/favorite_screen.dart';
import 'package:yolo_demo/models/pill_item.dart' as item;
import 'package:yolo_demo/models/pill_data.dart' as data;
import 'package:yolo_demo/db_helper.dart';
import 'name_search.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:yolo_demo/presentation/screens/gallery_edit_screen.dart';
import 'package:yolo_demo/api_services/name_search_service.dart';
import 'package:yolo_demo/screens/name_search.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  List<data.PillData> recentPills = [];

  final _searchController = TextEditingController();
  final _nameSearchService = NameSearchService();

  int _selectedIndex = 0;

  void _onSearch() async {
    String query = _searchController.text.trim();
    if (query.isNotEmpty) {
      print("🔍 검색어: $query");

      final resultList = await _nameSearchService.searchByName(query);

      if (resultList.isNotEmpty && context.mounted) {
        // 키보드 닫기
        FocusScope.of(context).unfocus();

        // 검색 결과 화면으로 이동
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NameSearchScreen(
              searchResults: resultList,
              searchKeyword: query,
            ),
          ),
        );

        // 돌아왔을 때 최근 검색/입력칸 초기화
        if (!mounted) return;
        await _loadRecentPills(); // ✅ 이름 검색에서 상세 진입/뒤로가기 후 즉시 갱신
        _searchController.clear();
        setState(() {});
      } else {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('검색 실패'),
            content: const Text('검색 결과가 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecentPills(); // 시작 시 최근 검색 로딩
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("🔁 앱이 다시 포커싱됨 → 최근 검색 다시 불러오기");
      _loadRecentPills();
    }
  }

  Future<void> _loadRecentPills() async {
    print("📥 최근 검색 로드 시작");
    final pills = await DBHelper.getRecentPills(limit: 5); // limit 적용
    print("📦 불러온 개수: ${pills.length}");
    for (final p in pills) {
      print("🔹 ${p.itemSeq} - ${p.itemName}");
    }

    setState(() {
      recentPills = pills;
    });
  }

  Future<void> deletePill(String itemSeq) async {
    await DBHelper.deleteRecentPill(itemSeq);
    _loadRecentPills(); // 삭제 후 재로딩
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 새로운 상단 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/main_logo.png',
                        height: 40,
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '         오늘도 건강한 복약 되세요!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            // 검색 입력
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onSubmitted: (_) => _onSearch(), // 키보드 Enter 시 실행
                decoration: InputDecoration(
                  hintText: '약 이름 또는 성분명 검색',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  prefixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: _onSearch, // 아이콘 눌렀을 때 실행
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),

            // 최근 검색 이력 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '최근 검색 이력',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            ),
            SizedBox(height: 8),

            // 최근 검색 약 리스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: recentPills.take(5).map<Widget>((p) {
                    final pill = p as data.PillData;
                    return GestureDetector(
                      // 길게 누르면 이름 전체 보여주기
                      onLongPress: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(pill.itemName ?? '이름없음')),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 텍스트 줄임 처리
                            Flexible(
                              child: Text(
                                pill.itemName ?? '이름없음',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => deletePill(pill.itemSeq.toString()),
                              child: Icon(Icons.close, size: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            SizedBox(height: 16),
            // 버튼 2개 가로로
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: ElevatedButton(
                        onPressed: () async {
                          showModalBottomSheet(
                            context: context,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (context) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.camera_alt),
                                    title: Text('카메라로 촬영'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(context, '/camera_guide').then((_) {
                                        _loadRecentPills();
                                      });
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.photo_library),
                                    title: Text('앨범에서 선택'),
                                    onTap: () async {
                                      if (await Permission.storage.request().isGranted) {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(context, '/gallery_guide');
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("저장소 접근 권한이 필요합니다.")),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/image_main.png', height: 48),
                            SizedBox(height: 15),
                            Text('이미지로 검색하기', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FeatureSearchScreen()),
                          ).then((_) {
                            _loadRecentPills();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/pill_main.png', height: 48),
                            SizedBox(height: 15),
                            Text('특징으로 검색하기', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '즐겨찾기'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 1) {
            Navigator.pushNamed(context, '/settings');
            return;
          }

          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoriteScreen()),
            );
          }
        },
      ),
    );
  }
}
