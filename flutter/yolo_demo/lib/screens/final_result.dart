import 'dart:convert';
import 'dart:typed_data'; // Uint8List 추가
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/api_services/favorite_db_service.dart';
import 'package:yolo_demo/db_helper.dart';
import 'package:yolo_demo/models/pill_data.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:yolo_demo/screens/chatbot_screen.dart';
import 'package:yolo_demo/screens/s_drug_info_screen.dart';
import 'package:yolo_demo/screens/s_dur_info_screen.dart';
import 'package:yolo_demo/screens/s_etc_info_screen.dart';
import 'package:yolo_demo/utils/image_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

/// 크롤링된 URL에서 토큰을 제거하고 표준화하는 함수
String normalizeCrawledUrl(String url) {
  if (url.contains('image-scrape')) {
    // image-scrape URL에서 item_seq만 추출하여 표준화
    final uri = Uri.parse(url);
    final itemSeq = uri.queryParameters['item_seq'];
    if (itemSeq != null) {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      return '$baseUrl/image-scrape?item_seq=$itemSeq';
    }
  }
  return url;
}

class FinalResultScreen extends StatefulWidget {
  final Map<String, dynamic> resultData;

  const FinalResultScreen({Key? key, required this.resultData}) : super(key: key);

  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  // Track attempted crawling itemSeqs to avoid duplicate crawling attempts
  final Set<String> _attemptedCrawlingItemSeqs = {};
  String _safeItemSeq(String? key, Map detail, Map list) {
    if (key != null && key.trim().isNotEmpty) return key;
    if (detail['itemSeq'] != null && detail['itemSeq'].toString().trim().isNotEmpty) {
      return detail['itemSeq'].toString();
    }
    if (list['itemSeq'] != null && list['itemSeq'].toString().trim().isNotEmpty) {
      return list['itemSeq'].toString();
    }
    return '';
  }
  String? _parseEffect(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return raw.trim();
    if (raw is List) {
      return raw.whereType<String>().join(', ').trim();
    }
    return raw.toString();
  }
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
    // 🚀 빈 데이터 체크 (다이얼로그 표시하지 않음)
    if (widget.resultData.isEmpty || 
        widget.resultData['results'] == null || 
        (widget.resultData['results'] is Map && (widget.resultData['results'] as Map).isEmpty)) {
      print("⚠️ [FinalResult] 빈 데이터 감지: ${widget.resultData}");
      
      // 🚀 빈 데이터 상태로 설정 (사용자 촬영 이미지 표시용)
      setState(() {
        selectedItems = [];
        selectedIndex = 0;
        isFavorite = false;
        interactionPairs = [];
      });
      
      // 🚀 다이얼로그 표시하지 않고 빈 결과 화면으로 계속 진행
      print("✅ [FinalResult] 빈 결과지만 정상 화면 표시 계속");
      return;
    }

    final resultMap = (widget.resultData['results'] as Map).cast<String, dynamic>();

    // API 응답 → UI 변환
    selectedItems = resultMap.entries.map<Map<String, dynamic>>((entry) {
      final data = entry.value;
      final permit = (data['permit'] as Map?) ?? {};
      final permitDetail = (permit['permitDetail'] as Map?) ?? {};
      final permitList = (permit['permitList'] as Map?) ?? {};

      final itemSeq = _safeItemSeq(entry.key?.toString(), permitDetail, permitList);
      if (itemSeq.isEmpty) {
        print("⚠️ itemSeq 없음 → 스킵");
        return {};
      }

      print("🔴 RAW full_data.permit: $permit");
      print("🔴 permitDetail keys: ${permitDetail.keys}");
      print("🔴 permitList keys: ${permitList.keys}");

      // 비어있는 허가정보 처리 플래그
      final bool isSparse = permitDetail.isEmpty && permitList.isEmpty;

      // efcy 우선순위: edrug.effect → permitDetail.efficacy(list)
      final String? edrugEffect = _parseEffect(data['edrug']?['effect']);
      final List<String>? efficacyList = (permitDetail['efficacy'] as List?)
          ?.whereType<String>()
          .toList();
      final String? efficacyJoined = (efficacyList != null && efficacyList.isNotEmpty)
          ? efficacyList.join(', ')
          : null;
      final String efcy = (edrugEffect != null && edrugEffect.isNotEmpty)
          ? edrugEffect
          : (efficacyJoined ?? '효능 정보가 없습니다.');

      // 취하/유효기간만료 판정: cancleName이 '취하' 또는 '유효기간만료'인 경우
      final String? cancleName = permitList['cancleName']?.toString();
      final bool withdrawn = (cancleName == '취하' || cancleName == '유효기간만료');
      
      // 정보가 없는 약 판정: permitDetail/permitList가 모두 빈 경우
      final bool hasNoInfo = permitDetail.isEmpty && permitList.isEmpty;

      return {
        'item_seq': itemSeq,
        'name': permitDetail['itemName'] ?? '이름 없음',
        'entp_name': permitList['entpName'] ?? permitDetail['entpName'],
        'image': (permitList['imageUrl'] is String && (permitList['imageUrl'] as String).isNotEmpty)
            ? (permitList['imageUrl'] as String)
            : 'https://via.placeholder.com/120',
        'efcy': efcy,
        'isSparse': isSparse,
        'full_data': data,
        'withdrawn': withdrawn,
        'hasNoInfo': hasNoInfo,
        'cancle_name': cancleName, // 🚀 취하 사유 추가
      };
    }).where((item) => item.isNotEmpty).toList();

    // 이미지 크롤링 시도 (placeholder인 경우)
    await _processImagesForPlaceholders();

    // DB 즐겨찾기 불러오기
    final favorites = await DBHelper.getFavoritePills();
    grouped = {};
    for (var fav in favorites) {
      final itemSeq = fav['item_seq'].toString();
      final folder = (fav['folder_name'] ?? '').toString();
      if (folder.isNotEmpty) {
        grouped.putIfAbsent(itemSeq, () => {}).add(folder);
      }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedItems.isNotEmpty) {
        final current = selectedItems[selectedIndex];
        final bool isWithdrawn = (current['withdrawn'] == true);
        final bool hasNoInfo = (current['hasNoInfo'] == true);
        
        // 취하된 약이거나 정보가 없는 약인 경우 WithdrawnNoticeScreen으로 이동
        if (isWithdrawn || hasNoInfo) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => WithdrawnNoticeScreen(
                drugName: cleanItemName(current['name'] ?? '이름 없음'),
                isWithdrawn: isWithdrawn,
                cancleName: current['cancle_name']?.toString(), // 🚀 취하 사유 전달
              ),
            ),
          );
        }
      }
    });
  }



  /// placeholder 이미지에 대해 크롤링 시도 (itemSeq별 중복 방지)
  Future<void> _processImagesForPlaceholders() async {
    // Set을 사용하여 이미 시도한 itemSeq를 추적
    final Set<String> attemptedItemSeqs = {};
    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      final currentImage = item['image'] as String;
      if (ImageUtils.isPlaceholder(currentImage)) {
        final itemSeq = item['item_seq'] as String;
        if (attemptedItemSeqs.contains(itemSeq)) {
          // 이 itemSeq는 이미 시도했으므로 스킵
          continue;
        }
        attemptedItemSeqs.add(itemSeq);
        try {
          final crawledImageUrl = await ApiHelper.fetchCrawledImage(itemSeq);
          if (crawledImageUrl != null && crawledImageUrl.isNotEmpty) {
            // 크롤링 성공 시 이미지 업데이트
            setState(() {
              selectedItems[i]['image'] = crawledImageUrl;
            });
            print("🖼️ 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
          }
        } catch (e) {
          print("❌ 이미지 크롤링 실패: $itemSeq - $e");
        }
      }
    }
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
    // 복약이력저장 안내팝업 표시
    await _showMedicationHistoryInfoDialog();
    
    final folders = await DBHelper.getAllFolders();
    final favorites = await DBHelper.getFavoritePills();
    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> folderList = folders.map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row)).toList();
    // 🚫 기본 폴더류는 UI에서 숨김 처리
    bool _isReservedName(String s) {
      final n = s.trim();
      if (n.isEmpty) return false;
      final lower = n.toLowerCase();
      return n == '기본 폴더' || n == '기본폴더' || n == '기본' || lower == 'default' || lower == 'default folder';
    }

    // folderList 필터링
    folderList.removeWhere((f) => _isReservedName((f['folder_name'] ?? '').toString()));

    // ⚠️ 폴더가 하나도 없으면 먼저 새 폴더 만들기 모달을 바로 띄워준다.
    if (folderList.isEmpty) {
      final nameController = TextEditingController();
      final descController = TextEditingController();
      final created = await showDialog<Map<String, String>?>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('새 폴더 만들기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '폴더 이름 (필수)',
                  hintText: '예: 아침약 / 비상약',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '폴더 설명 (선택)',
                  hintText: '예: 매일 아침 복용',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                final n = nameController.text.trim();
                if (n.isEmpty) return;
                Navigator.pop(context, {'name': n, 'desc': descController.text.trim()});
              },
              child: const Text('추가'),
            ),
          ],
        ),
      );
      if (created != null) {
        final n = created['name']!.trim();
        final d = (created['desc'] ?? '').trim();
        if (!_isReservedName(n)) {
          try { await DBHelper.addFolder(n); } catch (_) {}
          await prefs.setString('folder_desc__' + n, d);
          folderList.add({'folder_name': n, 'desc': d});
        }
      }
    }

    // 폴더 설명 필드 추가 (SharedPreferences)
    for (final f in folderList) {
      final fname = (f['folder_name'] ?? '').toString();
      if (fname.isNotEmpty) {
        f['desc'] = prefs.getString('folder_desc__' + fname) ?? '';
      }
    }

    // favorites는 아래에서 Set으로 만들 때 동일 규칙으로 거름
    final Set<String> alreadySavedFolders = favorites
        .where((fav) => fav['item_seq'] == itemSeq)
        .map((fav) => fav['folder_name'].toString())
        .where((name) => !_isReservedName(name))
        .toSet();

    Map<String, bool> localFolderSelection = {
      for (var f in folderList) f['folder_name']: alreadySavedFolders.contains(f['folder_name'])
    };

    try {
      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('저장할 폴더 선택'),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: '폴더 추가',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    final nameController = TextEditingController();
                    final descController = TextEditingController();
                    final newData = await showDialog<Map<String, String>?>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('새 폴더 만들기'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: '폴더 이름 (필수)',
                                hintText: '예: 아침약 / 비상약',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: descController,
                              decoration: const InputDecoration(
                                labelText: '폴더 설명 (선택)',
                                hintText: '예: 매일 아침 복용',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                // 이름 필수
                                return;
                              }
                              Navigator.pop(context, {
                                'name': name,
                                'desc': descController.text.trim(),
                              });
                            },
                            child: const Text('추가'),
                          ),
                        ],
                      ),
                    );

                    if (newData != null) {
                      final n = newData['name']!.trim();
                      final d = (newData['desc'] ?? '').trim();

                      if (_isReservedName(n)) {
                        await showDialog(
                          context: context,
                          builder: (_) => const AlertDialog(
                            title: Text('이 이름은 사용할 수 없어요'),
                            content: Text('“기본 폴더/Default”는 예약된 이름입니다. 다른 이름을 입력해주세요.'),
                          ),
                        );
                        return;
                      }

                      // ✅ DB에도 폴더가 반드시 존재하도록 보장 (이미 있으면 내부에서 무시되도록 try/catch)
                      try {
                        await DBHelper.addFolder(n);
                      } catch (_) {}

                      setState(() {
                        if (!localFolderSelection.containsKey(n)) {
                          localFolderSelection[n] = true; // 방금 만든 폴더를 기본 선택
                          folderList.add({'folder_name': n, 'desc': d});
                        } else {
                          localFolderSelection[n] = true;
                        }
                      });

                      // 메타(설명) 저장: SharedPreferences (UI용)
                      await prefs.setString('folder_desc__' + n, d);
                    }
                  },
                ),
              )
            ],
          ),
          content: SizedBox(
            height: 300,
            width: double.maxFinite,
            child: ListView(
              children: folderList.map<Widget>((folder) {
                final name = folder['folder_name'];
                final desc = (folder['desc'] ?? '') as String;
                return CheckboxListTile(
                  title: Text(name),
                  subtitle: desc.isNotEmpty ? Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54)) : null,
                  value: localFolderSelection[name] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      localFolderSelection[name] = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            StatefulBuilder(
              builder: (context, setStateBtn) {
                final bool hasPicked = localFolderSelection.values.any((v) => v == true);
                return ElevatedButton(
                  onPressed: hasPicked
                      ? () async {
                          final picked = localFolderSelection.entries.where((e) => e.value).map((e) => e.key).toList();
                          for (final fname in picked) {
                            // ✅ 폴더 보장 (기존 프로젝트에 같은 이름이 있으면 내부에서 무시되거나 에러 없이 통과)
                            try {
                              await DBHelper.addFolder(fname);
                            } catch (_) {}

                            await DBHelper.addFavoritePill(
                              itemSeq: itemSeq,
                              itemName: itemName,
                              entpName: selectedItems[selectedIndex]['entp_name'],
                              imageUrl: imageUrl,
                              userId: 'default_user',
                              folderName: fname,
                            );

                            // 서버 동기화
                            await FavoriteDbService.sendFavorite(
                              folderName: fname,
                              itemSeq: itemSeq,
                              itemName: itemName,
                              entpName: selectedItems[selectedIndex]['entp_name'],
                              imageUrl: imageUrl,
                            );
                            // try { await DBHelper.touchFolder(fname); } catch (_) {}
                          }
                          if (mounted) {
                            Navigator.pop(context); // close picker dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('복약이력에 저장했습니다.')),
                            );
                          }
                          await _processResultData(); // refresh current screen state
                        }
                      : null,
                  child: const Text('저장'),
                );
              },
            ),
          ],
        ),
      ),
    );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  /// 복약이력저장 안내팝업 표시
  Future<void> _showMedicationHistoryInfoDialog() async {
    await showDialog(
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
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              
              // 제목
              Text(
                '복약이력 저장이란?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // 설명 항목들
              _buildInfoItem(
                icon: Icons.folder_open_rounded,
                text: '복용한 약을 폴더별로 모아두고 나중에 쉽게 찾아볼 수 있어요.',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              
              _buildInfoItem(
                icon: Icons.category_rounded,
                text: '예: "감기 때 먹은 약", "부모님 약" 처럼 상황/가족별로 정리해두세요.',
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              
              _buildInfoItem(
                icon: Icons.touch_app_rounded,
                text: '폴더를 눌러 약을 추가/삭제할 수 있습니다.',
                color: Theme.of(context).colorScheme.tertiary,
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // 🚀 빈 데이터 상태 체크 (사용자 촬영 이미지 표시)
    if (selectedItems.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
          elevation: 0,
          title: const Text(
            '검색 결과',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.secondary.withOpacity(0.1),
                theme.colorScheme.background,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🚀 사용자 촬영 이미지 표시 (있다면)
                if (widget.resultData['userImage'] != null)
                  Container(
                    width: 200,
                    height: 200,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.resultData['userImage'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: Icon(
                            Icons.medication_rounded,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.search_off,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                const SizedBox(height: 24),
                Text(
                  '약물 정보를 찾을 수 없습니다',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '취하되었거나 유효기간이 만료되었거나 등록되지 않은 약입니다.\n다른 방법으로 다시 검색해보세요.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('돌아가기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/name_search');
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('수동 검색'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: const HomeFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    final selectedDrug = selectedItems[selectedIndex];
    final isWithdrawn = selectedDrug['withdrawn'] == true;
    final isSparse = selectedDrug['isSparse'] == true;
    final hasInteraction = interactionPairs.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        elevation: 0,
        title: const Text(
          '검색 결과',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.secondary.withOpacity(0.1),
              theme.colorScheme.background,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // DUR 경고 박스
            if (isSparse && !isWithdrawn)
              _buildWarningCard(
                icon: Icons.info_outline_rounded,
                title: '정보 부족',
                message: '공식 허가정보(이미지/상세)가 부족해요. 기본 요약만 표시됩니다.',
                color: Colors.blue,
                theme: theme,
              ),
            
            // 병용금기/상태 정보 카드
            _buildStatusCard(selectedDrug, hasInteraction, theme),
            const SizedBox(height: 16),

            // 약 선택 버튼
            _buildDrugSelector(theme),
            const SizedBox(height: 16),

            // 상세 정보 카드
            _buildDetailCard(selectedDrug, theme, isWithdrawn),
          ],
        ),
      ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// 병용금기 문구를 카드 스타일로 (깔끔한 칩 레이아웃)
  Widget _buildInteractionRichText() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👉 깔끔한 칩 레이아웃
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interactionPairs.map((p) {
              final a = p['itemName'] ?? '알 수 없음';
              final b = p['mixtureItemName'] ?? '알 수 없음';
              return _buildInteractionChipPair(a, b, theme);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionChipPair(String a, String b, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade100.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pillChip(a, theme),
          const SizedBox(width: 6),
          Icon(Icons.close_rounded, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          _pillChip(b, theme),
        ],
      ),
    );
  }

  Widget _pillChip(String text, ThemeData theme) {
    // 너무 긴 이름은 말줄임 처리
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade900,
          ),
        ),
      ),
    );
  }

  /// 공통 버튼 빌더
  Widget _buildDetailButton({
    required String label,
    required VoidCallback onTap,
    required IconData icon,
    required ThemeData theme,
    bool customLabelStyle = false, // 커스텀 스타일 사용 여부
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(height: 8),
              customLabelStyle
                ? Builder(
                    builder: (context) {
                      final baseStyle = theme.textTheme.bodyMedium!;
                      final scaler = MediaQuery.textScalerOf(context);

                      return RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '효능효과\n',
                              style: baseStyle.copyWith(
                                height: 1.3,
                                color: theme.colorScheme.onSurface,
                              ).apply(
                                fontSizeFactor: scaler.scale(1.0),
                              ),
                            ),
                            TextSpan(
                              text: '용법용량\n',
                              style: baseStyle.copyWith(
                                height: 1.3,
                                color: theme.colorScheme.onSurface,
                              ).apply(
                                fontSizeFactor: scaler.scale(1.0),
                              ),
                            ),
                            TextSpan(
                              text: '사용상의주의사항',
                              style: baseStyle.copyWith(
                                fontSize: (baseStyle.fontSize ?? 14) * 0.7, // 20% 작게
                                height: 1.1,
                                color: theme.colorScheme.onSurface,
                              ).apply(
                                fontSizeFactor: scaler.scale(1.0),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    required ThemeData theme,
  }) {
    // MaterialColor로 변환하여 shade 사용
    final materialColor = color is MaterialColor ? color : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: materialColor.shade50,
        border: Border.all(color: materialColor.shade200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: materialColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: materialColor.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: materialColor.shade600, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: materialColor.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: materialColor.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    Map<String, dynamic> selectedDrug,
    bool hasInteraction,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasInteraction 
                      ? Colors.orange.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  hasInteraction ? Icons.warning_rounded : Icons.info_rounded,
                  color: hasInteraction ? Colors.orange : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasInteraction ? '병용금기 주의' : '안전한 복용',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasInteraction
                          ? '이 약들은 함께 복용 시 주의가 필요합니다'
                          : selectedItems.length == 1
                              ? '단일 약물 정보입니다'
                              : '이 약물들은 함께 복용 시 특별한 주의사항이 확인되지 않았어요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasInteraction) ...[
            const SizedBox(height: 16),
            _buildInteractionRichText(),
          ],
        ],
      ),
    );
  }

  Widget _buildDrugSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '약물 선택',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(selectedItems.length, (index) {
                final item = selectedItems[index];
                final isSelected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                          isFavorite =
                              grouped[selectedItems[index]['item_seq']]?.isNotEmpty == true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: Text(
                          cleanItemName(item['name'] ?? '이름 없음'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected 
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    Map<String, dynamic> selectedDrug,
    ThemeData theme,
    bool isWithdrawn,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '약물 상세 정보',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 약물 이미지
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: FutureBuilder<String?>(
                future: _getImageWithCrawling(selectedDrug),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  
                  final finalImageUrl = snapshot.data;
                  // ① 아이콘 신호면 즉시 큰 아이콘
                  if (finalImageUrl == 'ICON_PLACEHOLDER') {
                    return Icon(
                      Icons.medication_rounded,
                      size: 80, // 크게
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    );
                  }

                  // ② 정상 URL이면 인증 요청 후 표시
                  if (finalImageUrl != null && !ImageUtils.isPlaceholder(finalImageUrl)) {
                    return FutureBuilder<Uint8List?>(
                      future: _fetchImageWithAuth(finalImageUrl),
                      builder: (context, imageSnapshot) {
                        if (imageSnapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }

                        if (imageSnapshot.hasData && imageSnapshot.data != null) {
                          return Image.memory(
                            imageSnapshot.data!,
                            height: 120,
                            fit: BoxFit.contain,
                          );
                        }

                        // 인증/요청 실패 → 큰 아이콘
                        return Icon(
                          Icons.medication_rounded,
                          size: 80,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        );
                      },
                    );
                  }

                  // ③ 그 외(널/플레이스홀더) → 큰 아이콘
                  return Icon(
                    Icons.medication_rounded,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 질문하기와 복약이력 저장 버튼
          Row(
            children: [
              // 질문하기 버튼 (작게)
              Expanded(
                flex: 2, // 2:3 비율로 질문하기 버튼을 작게
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // 패딩 감소
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
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
                  icon: Icon(
                    Icons.question_answer_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    '질문하기',
                    style: TextStyle(
                      fontSize: 11, // fontSize 감소 (from 14 to 11)
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 복약이력 저장 버튼 (크게)
              Expanded(
                flex: 3, // 2:3 비율로 복약이력저장 버튼을 크게
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), // 패딩 감소
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await _addToMultipleFolders(
                      selectedDrug['item_seq'],
                      cleanItemName(selectedDrug['name']),
                      selectedDrug['image'] ?? 'ICON_PLACEHOLDER',
                    );
                  },
                  icon: const Icon(
                    Icons.medical_information,
                    size: 22,
                  ),
                  label: Text(
                    '복약이력 저장',
                    style: TextStyle(
                      fontSize: 11, // fontSize 감소 (from 14 to 11)
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 효능 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '효능 및 효과',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildParsedEfficacyText(selectedDrug['efcy'], theme),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // 상세 정보 버튼들
          Row(
            children: [
              Expanded(
                child: _buildDetailButton(
                  label: '약제정보',
                  icon: Icons.medication_rounded,
                  onTap: () {
                    final detail = selectedDrug['full_data']['permit']['permitDetail'] ?? {};
                    final list = selectedDrug['full_data']['permit']['permitList'] ?? {};
                    
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
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailButton(
                  label: '효능효과\n용법용량\n사용상의주의사항',
                  icon: Icons.description_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SEtcInfoScreen(
                        permitDetail:
                            selectedDrug['full_data']['permit']['permitDetail'] ?? {},
                      ),
                    ),
                  ),
                  theme: theme,
                  customLabelStyle: true, // 커스텀 스타일 사용
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // DUR 품목 정보 버튼을 전체 너비로
          SizedBox(
            width: double.infinity,
            child: _buildDetailButton(
              label: 'DUR 품목 정보',
              icon: Icons.medical_information_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SDurInfoScreen(durData: selectedDrug['full_data']['dur']),
                ),
              ),
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  /// 효능 및 효과 텍스트를 파싱하여 "1.", "2.", "3." 등 메인 항목만 표시
  Widget _buildParsedEfficacyText(String? efcyText, ThemeData theme) {
    if (efcyText == null || efcyText.isEmpty) {
      return Text(
        '효능 정보가 없습니다.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final mainNumberPattern = RegExp(r'^\d+\.\s*.+$');
    final parts = efcyText.split(RegExp(r'[\n,]'));
    final mainItems = <Widget>[];

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (mainNumberPattern.hasMatch(trimmed)) {
        mainItems.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Text(
              trimmed,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.9),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        );
      }
    }

    // 👉 숫자. 로 시작하는 항목이 하나라도 있으면 그것만 출력
    if (mainItems.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mainItems,
      );
    }

    // 👉 없으면 원본 텍스트 전체 출력
    return Text(
      efcyText,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withOpacity(0.9),
        height: 1.4,
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

  /// 이미지를 크롤링하여 실제 URL을 반환하거나, 실패 시 null을 반환합니다.
  Future<String?> _getImageWithCrawling(Map<String, dynamic> item) async {
    final originalImage = item['image'];
    // 원본 이미지가 유효하면 그대로 사용
    if (originalImage != null && !ImageUtils.isPlaceholder(originalImage)) {
      return originalImage;
    }

    // Use class-level set to avoid duplicate crawling attempts per itemSeq
    final itemSeq = (item['itemSeq'] ?? item['item_seq'])?.toString();
    if (itemSeq == null || itemSeq.isEmpty) {
      return 'ICON_PLACEHOLDER';
    }
    if (_attemptedCrawlingItemSeqs.contains(itemSeq)) {
      // 이미 크롤링 시도한 itemSeq라면 다시 시도하지 않고 원본 반환 (또는 placeholder)
      return originalImage ?? 'ICON_PLACEHOLDER';
    }
    _attemptedCrawlingItemSeqs.add(itemSeq);

    try {
      final crawledImageUrl = await ImageUtils.getImageWithCrawling({'itemSeq': itemSeq, 'imageUrl': originalImage});
      if (crawledImageUrl != null && !ImageUtils.isPlaceholder(crawledImageUrl)) {
        print("🖼️ [FinalResult] 이미지 크롤링 성공: $itemSeq -> $crawledImageUrl");
        // 크롤링된 URL을 표준화하고 DB에 저장
        final normalized = normalizeCrawledUrl(crawledImageUrl);
        print("🔄 [FinalResult] URL 표준화: $normalized");
        // DB에 크롤링된 이미지 URL 저장
        try {
          final prefs = await SharedPreferences.getInstance();
          final uid = prefs.getString('user_id') ?? 'guest';
          await DBHelper.updateRecentImage(
            itemSeq: itemSeq,
            imageUrl: normalized,
            userId: uid,
          );
          print("✅ [FinalResult] DB 업데이트 성공: $itemSeq -> $normalized");
          // UI 업데이트를 위해 setState 호출
          if (mounted) {
            setState(() {
              // 이미지 URL을 업데이트하여 UI에 반영
              item['image'] = normalized;
            });
          }
        } catch (e) {
          print("❌ [FinalResult] DB 업데이트 실패: $e");
        }
        return normalized;
      }
    } catch (e) {
      print("❌ [FinalResult] 이미지 크롤링 실패: $itemSeq - $e");
    }
    // 크롤링 실패시 기본 이미지 반환
    return 'ICON_PLACEHOLDER';
  }

  /// 인증된 이미지를 가져오는 비동기 함수
  Future<Uint8List?> _fetchImageWithAuth(String imageUrl) async {
    try {
      // 크롤링된 이미지인 경우 인증 헤더 포함
      if (imageUrl.contains('image-scrape')) {
        final headers = await ApiHelper.getAuthHeaders();
        final response = await http.get(
          Uri.parse(imageUrl),
          headers: headers,
        );
        if (response.statusCode == 200) {
          print("✅ [FinalResult] 인증된 이미지 요청 성공: $imageUrl");
          return response.bodyBytes;
        } else {
          print("❌ [FinalResult] 인증된 이미지 요청 실패: $imageUrl, 상태 코드: ${response.statusCode}");
          return null;
        }
      } else {
        // 일반 이미지는 인증 없이 요청
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          print("✅ [FinalResult] 일반 이미지 요청 성공: $imageUrl");
          return response.bodyBytes;
        } else {
          print("❌ [FinalResult] 일반 이미지 요청 실패: $imageUrl, 상태 코드: ${response.statusCode}");
          return null;
        }
      }
    } catch (e) {
      print("❌ [FinalResult] 이미지 요청 중 오류 발생: $imageUrl - $e");
      return null;
    }
  }
}

class WithdrawnNoticeScreen extends StatelessWidget {
  final String drugName;
  final bool isWithdrawn;
  final String? cancleName; // 🚀 취하 사유 추가
  const WithdrawnNoticeScreen({
    super.key, 
    required this.drugName, 
    required this.isWithdrawn,
    this.cancleName, // 🚀 취하 사유 (선택적)
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 251, 206).withOpacity(0.3),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // 메인 아이콘
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(60),
                    border: Border.all(
                      color: Colors.orange.shade200,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 60,
                    color: Colors.orange.shade400,
                  ),
                ),

                const SizedBox(height: 32),

                // 메인 메시지
                Text(
                  '약물 정보를\n확인할 수 없습니다',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                // 추가 간격
                const SizedBox(height: 24),

                // 안내 컨테이너
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 32,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(height: 16),
                      // 취하/유효기간 안내 메시지로 교체
                      Text(
                        cancleName != null 
                          ? '${cancleName == '취하' ? '취하' : '유효기간 만료'}된 약물입니다'
                          : '취하되거나 유효기간이 만료되었거나\n등록되지 않은 약입니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.orange.shade600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // 이전화면으로 버튼만
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 24),
                    label: const Text(
                      '이전 화면으로',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}