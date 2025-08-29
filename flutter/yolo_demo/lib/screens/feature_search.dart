import 'package:flutter/material.dart';
import 'feature_search_result.dart';

// 공통 배지 위젯 - 위치 통일을 위해
class ConsistentBadge extends StatelessWidget {
  final int count;
  final Widget child;
  
  const ConsistentBadge({
    Key? key,
    required this.count,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FeatureSearchScreen extends StatefulWidget {
  const FeatureSearchScreen({super.key});

  @override
  State<FeatureSearchScreen> createState() => _FeatureSearchScreenState();
}

class _FeatureSearchScreenState extends State<FeatureSearchScreen> {
  List<Map<String, dynamic>> cartItems = [];

  void addToCart(Map<String, dynamic> item) {
    if (!cartItems.any((e) => e['ITEM_SEQ'] == item['ITEM_SEQ'])) {
      setState(() {
        cartItems.add(item);
      });
    }
  }

  void removeFromCart(Map<String, dynamic> item) {
    setState(() {
      cartItems.removeWhere((e) => e['ITEM_SEQ'] == item['ITEM_SEQ']);
    });
  }

  Map<String, bool> selectedColors = {};
  Map<String, bool> groupSelected = {};
  TextEditingController frontTextController = TextEditingController();
  TextEditingController backTextController = TextEditingController();
  List<int> selectedShapeIndices = [];

  final List<Map<String, dynamic>> shapeList = [
    {'name': '원형', 'icon': 'assets/feature-shape/원형.png'},
    {'name': '타원형', 'icon': 'assets/feature-shape/타원형.png'},
    {'name': '장방형', 'icon': 'assets/feature-shape/장방형.png'},
    {'name': '반원형', 'icon': 'assets/feature-shape/반원.png'},
    {'name': '삼각형', 'icon': 'assets/feature-shape/삼각형.png'},
    {'name': '사각형', 'icon': 'assets/feature-shape/사각형.png'},
    {'name': '오각형', 'icon': 'assets/feature-shape/오각형.png'},
    {'name': '육각형', 'icon': 'assets/feature-shape/육각형.png'},
    {'name': '팔각형', 'icon': 'assets/feature-shape/팔각형.png'},
    {'name': '기타', 'icon': 'assets/feature-shape/기타.png'},
  ];

  final List<Map<String, dynamic>> colorGroups = [
    {'group': '흰색/투명', 'colors': ['하양', '투명']},
    {'group': '빨강/분홍/자주', 'colors': ['빨강', '분홍', '자주']},
    {'group': '노랑/주황', 'colors': ['노랑', '주황']},
    {'group': '연두/초록/청록', 'colors': ['연두', '초록', '청록']},
    {'group': '파랑/남색/보라', 'colors': ['파랑', '남색', '보라']},
    {'group': '갈색/회색/검정', 'colors': ['갈색', '회색', '검정']},
  ];

  final Map<String, Color> colorMap = {
    '하양': Colors.white,
    '투명': Colors.transparent,
    '회색': Colors.grey,
    '빨강': Colors.red,
    '분홍': Colors.pink,
    '자주': Colors.purple,
    '노랑': Colors.yellow,
    '주황': Colors.orange,
    '연두': Colors.lightGreen,
    '초록': Colors.green,
    '청록': Colors.teal,
    '파랑': Colors.blue,
    '남색': Colors.indigo,
    '보라': Colors.deepPurple,
    '갈색': Colors.brown,
    '검정': Colors.black,
  };

  final Map<String, String> colorLabels = {
    '하양': '흰색',
    '투명': '투명',
    '회색': '회색',
    '빨강': '빨강',
    '분홍': '분홍',
    '자주': '자주',
    '노랑': '노랑',
    '주황': '주황',
    '연두': '연두',
    '초록': '초록',
    '청록': '청록',
    '파랑': '파랑',
    '남색': '남색',
    '보라': '보라',
    '갈색': '갈색',
    '검정': '검정',
  };

  @override
  void initState() {
    super.initState();
    // 초기 상태: 모든 그룹/색상 false로 설정
    for (var g in colorGroups) {
      groupSelected[g['group']] = false;
      for (var c in g['colors']) {
        selectedColors[c] = false;
      }
    }
    frontTextController.addListener(_onFormChanged);
    backTextController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    frontTextController.removeListener(_onFormChanged);
    backTextController.removeListener(_onFormChanged);
    frontTextController.dispose();
    backTextController.dispose();
    super.dispose();
  }

  bool get hasSelection {
    // 최소 하나라도 선택되었는지 체크 → 검색 버튼 활성화 여부
    return selectedColors.containsValue(true) ||
        selectedShapeIndices.isNotEmpty ||
        frontTextController.text.isNotEmpty ||
        backTextController.text.isNotEmpty;
  }

  void _doSearch() {
    final selectedColorKeys = selectedColors.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    // 디버깅: 선택된 색상들 출력
    print("🎨 선택된 색상들: $selectedColorKeys");
    print("🔍 선택된 모양들: ${selectedShapeIndices.map((i) => shapeList[i]['name']).toList()}");
    print("📝 앞글씨: ${frontTextController.text.trim()}");
    print("📝 뒷글씨: ${backTextController.text.trim()}");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeatureSearchResultScreen(
          shape: selectedShapeIndices.isNotEmpty
              ? selectedShapeIndices.map((i) => shapeList[i]['name'] as String).toList()
              : null,
          selectedColors: selectedColorKeys,
          frontText: frontTextController.text.trim().isEmpty
              ? null
              : frontTextController.text.trim(),
          backText: backTextController.text.trim().isEmpty
              ? null
              : backTextController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        elevation: 0,
        title: const Text(
          '특징 기반 검색',
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              // 선택 초기화 버튼
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        selectedShapeIndices.clear();
                        frontTextController.clear();
                        backTextController.clear();
                        groupSelected.updateAll((key, value) => false);
                        selectedColors.updateAll((key, value) => false);
                      });
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    label: Text(
                      '선택 초기화',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 모양 선택기
              _buildShapeSelector(),
              const SizedBox(height: 24),
              
              // 텍스트 입력
              _buildTextInputRow(),
              const SizedBox(height: 24),
              
              // 색상 선택기
              _buildColorGroupsBox(),
              const SizedBox(height: 32),
              
              // 검색 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: hasSelection ? _doSearch : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: hasSelection 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.surfaceVariant,
                    foregroundColor: hasSelection 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: hasSelection ? 4 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '검색하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 기타 빌더 위젯 생략 - 기존 코드 유지

  Widget _buildShapeSelector() {
    final theme = Theme.of(context);
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
                Icons.shape_line_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '알약 모양',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grid 형태로 모든 모양을 한 번에 표시
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: shapeList.length,
            itemBuilder: (context, index) {
              final selected = selectedShapeIndices.contains(index);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      if (selected) {
                        selectedShapeIndices.remove(index);
                      } else {
                        selectedShapeIndices.add(index);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected 
                          ? theme.colorScheme.primary.withOpacity(0.25)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected 
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withOpacity(0.2),
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: selected ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          shapeList[index]['icon'],
                          width: 28,
                          height: 28,
                          color: selected 
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shapeList[index]['name'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputRow() {
    final theme = Theme.of(context);
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
                Icons.text_fields_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '알약 글씨',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: frontTextController,
                  decoration: InputDecoration(
                    hintText: '앞면 글씨',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.front_hand_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      size: 20,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    if (hasSelection) _doSearch();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: backTextController,
                  decoration: InputDecoration(
                    hintText: '뒷면 글씨',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.back_hand_rounded,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      size: 20,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    if (hasSelection) _doSearch();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorGroupsBox() {
    final theme = Theme.of(context);
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
                Icons.palette_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '알약 색상',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...colorGroups.map((group) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 그룹 헤더
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group['group'] as String,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      // 그룹 전체 선택 체크박스
                      Container(
                        decoration: BoxDecoration(
                          color: groupSelected[group['group']] == true
                              ? theme.colorScheme.primary.withOpacity(0.1)
                              : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Checkbox(
                          value: groupSelected[group['group']],
                          onChanged: (bool? value) {
                            setState(() {
                              groupSelected[group['group']] = value!;
                              // 그룹 내 모든 색상 선택/해제
                              for (var c in group['colors']) {
                                selectedColors[c] = value;
                              }
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 색상 선택기들
                  Row(
                    children: group['colors'].map<Widget>((colorKey) {
                      final selected = selectedColors[colorKey]!;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColors[colorKey] = !selected;
                              
                              // 개별 색상 선택/해제 시 그룹 상태 업데이트
                              final allSelected = group['colors'].every((c) => selectedColors[c]!);
                              final anySelected = group['colors'].any((c) => selectedColors[c]!);
                              
                              if (allSelected) {
                                groupSelected[group['group']] = true;
                              } else if (!anySelected) {
                                groupSelected[group['group']] = false;
                              } else {
                                // 일부만 선택된 경우 (indeterminate 상태)
                                groupSelected[group['group']] = false;
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2), // 4 -> 2로 간격 축소
                            child: Column(
                              children: [
                                Container(
                                  width: 52, // 56 -> 52로 크기 약간 축소
                                  height: 52, // 56 -> 52로 크기 약간 축소
                                  decoration: BoxDecoration(
                                    color: colorMap[colorKey],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected 
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline.withOpacity(0.3),
                                      width: selected ? 3 : 2,
                                    ),
                                    boxShadow: selected ? [
                                      BoxShadow(
                                        color: theme.colorScheme.primary.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ] : null,
                                  ),
                                  child: selected
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 26, // 28 -> 26으로 크기 조정
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 4), // 6 -> 4로 간격 축소
                                Text(
                                  colorLabels[colorKey]!,
                                  style: TextStyle(
                                    fontSize: 11, // 12 -> 11로 폰트 크기 축소
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                    color: selected 
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}