import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/api_services/favorite_db_service.dart';
import 'package:yolo_demo/screens/chatbot_screen.dart';
import 's_drug_info_screen.dart';
import 's_dur_info_screen.dart';
import 's_etc_info_screen.dart';

/// 공백/밀리그램 제거 및 괄호 안 내용 제거 함수
String cleanItemName(String name) {
  return name
      .replaceAll(RegExp(r'\(.*?\)'), '') // 괄호와 안의 내용 제거
      .replaceAll(RegExp(r'\s+'), '') // 공백 제거
      .trim();
}

/// 병용금기 비교용 normalize 함수 (괄호 제거 + 공백 제거 + 숫자 제거)
String normalizeName(String name) {
  return name
      .replaceAll(RegExp(r'\(.*?\)'), '') // 괄호 제거
      .replaceAll(RegExp(r'\s+'), '') // 공백 제거
      .replaceAll(RegExp(r'[0-9]'), '') // 숫자 제거
      .replaceAll('밀리그램', '') // 밀리그램 제거
      .trim();
}

class FinalResultScreen extends StatefulWidget {
  final Map<String, dynamic> resultData;

  const FinalResultScreen({Key? key, required this.resultData}) : super(key: key);

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  List<Map<String, dynamic>> selectedItems = [];
  int selectedIndex = 0;

  // 즐겨찾기 상태 관리
  Set<String> favoriteItemSeqs = {};
  Map<String, Set<String>> grouped = {}; // itemSeq → 저장된 폴더 목록
  bool isFavorite = false;

  // 병용금기 데이터
  List<Map<String, String>> interactionPairs = [];

  @override
  void initState() {
    super.initState();
    _processResultData();
  }

  /// 초기 데이터 처리
  Future<void> _processResultData() async {
    final resultMap = (widget.resultData['results'] as Map).cast<String, dynamic>();

    // API 응답 → UI 변환
    selectedItems = resultMap.entries.map<Map<String, dynamic>>((entry) {
      final itemSeq = entry.key;
      final data = entry.value;

      print("🔴 RAW full_data: ${data['permit']}");
      print("🔴 permitDetail keys: ${(data['permit']['permitDetail'] ?? {}).keys}");
      print("🔴 permitList keys: ${(data['permit']['permitList'] ?? {}).keys}");
      
      final permitDetail = data['permit']['permitDetail'] ?? {};
      final permitList = data['permit']['permitList'] ?? {};

      return {
        'item_seq': itemSeq,
        'name': permitDetail['itemName'] ?? '이름 없음',
        'image': permitList['imageUrl']?.isNotEmpty == true
            ? permitList['imageUrl']
            : 'https://via.placeholder.com/120',
        'efcy': (permitDetail['efficacy'] as List<dynamic>?)?.join(', ') ?? '효능 정보가 없습니다.',
        'full_data': data,
      };
    }).toList();

    // DB 즐겨찾기 불러오기
    final favorites = await DBHelper.getFavoritePills();
    grouped = {};
    for (var fav in favorites) {
      final itemSeq = fav['item_seq'].toString();
      final folder = fav['folder_name'] ?? '기본 폴더';
      grouped.putIfAbsent(itemSeq, () => {}).add(folder);
    }
    favoriteItemSeqs = grouped.keys.toSet();

    // 현재 아이템 즐겨찾기 상태
    if (selectedItems.isNotEmpty) {
      final currentItem = selectedItems[selectedIndex];
      isFavorite = grouped[currentItem['item_seq']]?.isNotEmpty == true;
    }

    // 병용금기 데이터 추출
    _checkDrugInteractions(resultMap);

    setState(() {});
  }

  /// 병용금기 체크 로직 (getUsjntTabooInfoList03 + getPwnmTabooInfoList03 병합, 양방향 매칭)
  void _checkDrugInteractions(Map<String, dynamic> resultMap) {
    interactionPairs.clear();

    // 선택된 약물 이름 집합
    final selectedNames = selectedItems.map((e) => normalizeName(e['name'])).toSet();
    print("🟢 선택된 약물 이름 리스트: $selectedNames");

    for (final entry in resultMap.entries) {
      final dur = entry.value['dur'] as Map<String, dynamic>? ?? {};

      // 두 리스트 병합
      final tabooList = [
        ...(dur['getUsjntTabooInfoList03'] as List<dynamic>? ?? []),
        ...(dur['getPwnmTabooInfoList03'] as List<dynamic>? ?? []),
      ];

      print("🔴 RAW DUR 리스트: $tabooList");

      for (final item in tabooList) {
        if (item['typeName'] == '병용금기') {
          final name1 = normalizeName(item['itemName'] ?? '');
          final name2 = normalizeName(item['mixtureItemName'] ?? '');

          print("🔍 DUR 병용금기 데이터: itemName=$name1 / mixtureItemName=$name2");

          // 양방향 매칭
          final isMatch = (selectedNames.contains(name1) && selectedNames.contains(name2)) ||
              (selectedNames.contains(name2) && selectedNames.contains(name1));

          if (isMatch) {
            print("✅ 병용금기 매칭 성공: $name1 + $name2");
            interactionPairs.add({'itemName': name1, 'mixtureItemName': name2});
          } else {
            print("❌ 매칭 실패 (선택된 약물에 없음)");
          }
        }
      }
    }
    print("최종 병용금기 페어: $interactionPairs");
  }

  /// 즐겨찾기 저장 다이얼로그
  Future<void> _addToMultipleFolders(String itemSeq, String itemName, String imageUrl) async {
    final folders = await DBHelper.getAllFolders();
    final favorites = await DBHelper.getFavoritePills();

    final Set<String> alreadySavedFolders = favorites
        .where((fav) => fav['item_seq'] == itemSeq)
        .map((fav) => fav['folder_name'].toString())
        .toSet();

    Map<String, bool> localFolderSelection = {
      for (var f in folders) f['folder_name']: alreadySavedFolders.contains(f['folder_name'])
    };

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('저장할 폴더 선택'),
          content: SizedBox(
            height: 300,
            width: double.maxFinite,
            child: ListView(
              children: folders.map<Widget>((folder) {
                final name = folder['folder_name'];
                return CheckboxListTile(
                  title: Text(name),
                  value: localFolderSelection[name],
                  onChanged: (bool? value) {
                    setState(() {
                      localFolderSelection[name] = value ?? false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                for (var entry in localFolderSelection.entries) {
                  if (entry.value) {
                    await DBHelper.addFavoritePill(
                      itemSeq: itemSeq,
                      itemName: itemName,
                      imageUrl: imageUrl,
                      userId: 'default_user',
                      folderName: entry.key,
                    );

                    await FavoriteDbService.sendFavorite(
                      folderName: entry.key,
                      itemSeq: itemSeq,
                      itemName: itemName,
                      imageUrl: imageUrl,
                    );
                  } else {
                    await DBHelper.removeFavoritePill(
                      itemSeq: itemSeq,
                      folderName: entry.key,
                    );
                  }
                }

                Navigator.pop(context);
                await _processResultData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('즐겨찾기 상태가 업데이트되었습니다.')),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedItems.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selectedDrug = selectedItems[selectedIndex];

    // 병용금기 여부 판단
    final hasInteraction = interactionPairs.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        title: const Text('결과 화면'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // DUR 경고 박스
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasInteraction ? Colors.yellow[100] : Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasInteraction ? Icons.warning : Icons.info,
                  color: hasInteraction ? Colors.orange : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: hasInteraction
                      ? _buildInteractionRichText()
                      : Text(
                          selectedItems.length == 1
                              ? '단일 약물 정보입니다.' // 1개 약일 때 문구
                              : '이 약물들은 함께 복용 시 특별한 주의사항이 확인되지 않았어요.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 약 선택 버튼
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(selectedItems.length, (index) {
                final item = selectedItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedIndex == index
                          ? const Color(0xFFFFD600)
                          : Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedIndex = index;
                        isFavorite =
                            grouped[selectedItems[index]['item_seq']]?.isNotEmpty == true;
                      });
                    },
                    // 이름 정제 후 표시
                    child: Text(cleanItemName(item['name'] ?? '이름 없음')),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // 상세 카드
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 질문/즐겨찾기 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatBotScreen(
                              itemName: cleanItemName(selectedDrug['name'] ?? '이름없음'),
                              resultData: {
                                'results': {
                                  selectedDrug['item_seq']: selectedDrug['full_data'],
                                }
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.question_answer),
                      label: const Text('질문하기'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: () async {
                        await _addToMultipleFolders(
                          selectedDrug['item_seq'],
                          cleanItemName(selectedDrug['name']),
                          selectedDrug['image'] ?? 'assets/no_image.png',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Image.network(
                  selectedDrug['image'],
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image, size: 80),
                ),
                const SizedBox(height: 8),

                Text(
                  selectedDrug['efcy'],
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildDetailButton(
                        label: '약제정보',
                        onTap: () {
                          final detail = selectedDrug['full_data']['permit']['permitDetail'] ?? {};
                          final list = selectedDrug['full_data']['permit']['permitList'] ?? {};

                          print("🔍 permitDetail keys: ${detail.keys}");
                          print("🔍 permitList keys: ${list.keys}");
                        
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SDrugInfoScreen(
                                permitDetail: selectedDrug['full_data']['permit']['permitDetail'] ?? {},
                                permitList: selectedDrug['full_data']['permit']['permitList'] ?? {},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDetailButton(
                        label: '효능효과/용법용량/\n사용상의주의사항',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SEtcInfoScreen(
                              permitDetail:
                                  selectedDrug['full_data']['permit']['permitDetail'] ?? {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _buildDetailButton(
                  label: 'DUR 품목 정보',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SDurInfoScreen(durData: selectedDrug['full_data']['dur']),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        foregroundColor: Colors.black,
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back),
      ),
    );
  }

  /// 병용금기 문구를 카드 스타일로
  Widget _buildInteractionRichText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✖︎ 이 약들은 같이 드시면 안돼요! (병용금기) ✖︎',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        ...interactionPairs.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "${p['itemName']}  ⟺  ${p['mixtureItemName']}",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
      ],
    );
  }

  /// 공통 버튼 빌더
  Widget _buildDetailButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, textAlign: TextAlign.center)),
      ),
    );
  }
}