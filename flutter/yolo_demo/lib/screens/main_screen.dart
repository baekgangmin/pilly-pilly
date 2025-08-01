import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yolo_demo/screens/feature_search.dart';
import 'package:yolo_demo/screens/favorite_screen.dart';
import 'package:yolo_demo/models/pill_item.dart' as item;
import 'package:yolo_demo/models/pill_data.dart' as data;
import 'package:yolo_demo/db_helper.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  List<data.PillData> recentPills = [];
  int _selectedIndex = 0;

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
    final pills = await DBHelper.getRecentPills();
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
            // 상단 헤더
            Container(
              width: double.infinity,
              height: 90,
              color: const Color.fromARGB(255, 255, 252, 223),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, bottom: 10),
                      child: Image.asset(
                        'assets/hi_logo.png',
                        height: 100,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 100, top: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'pilly pilly',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFD600),
                                ),
                              ),
                              TextSpan(
                                text: '는',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '누구나 쉽고 안전하게 약을 복용할 수 있도록 돕겠습니다.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // 검색 입력
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: '약 이름 또는 성분명 검색',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.search),
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
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recentPills.map<Widget>((p) {
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

            SizedBox(height: 24),
            // 세로 버튼 2개
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // 이미지 기반 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: ElevatedButton.icon(
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
                                      print("📸 이미지 기반 화면에서 돌아옴 → 최근 검색 재로딩");
                                      _loadRecentPills();
                                    });
                                  }
                                ),
                                ListTile(
                                  leading: Icon(Icons.photo_library),
                                  title: Text('앨범에서 선택'),
                                  onTap: () {
                                    Navigator.pop(context);
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
                      ),
                      icon: Icon(Icons.camera_alt),
                      label: Text('이미지 기반'),
                    ),
                  ),
                  SizedBox(height: 12),
                  // 특징 기반 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FeatureSearchScreen()),
                        ).then((_) {
                          print("🟡 특징 기반 검색에서 돌아옴 → 최근 검색 재로딩");
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
                      ),
                      icon: Icon(Icons.list_alt),
                      label: Text('특징 기반'),
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
