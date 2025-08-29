import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yolo_demo/screens/feature_search.dart';
import 'package:yolo_demo/screens/favorite_screen.dart';
import 'package:yolo_demo/screens/cart_screen.dart';
import 'package:yolo_demo/models/pill_item.dart' as item;
import 'package:yolo_demo/models/pill_data.dart' as data;
import 'package:yolo_demo/db_helper.dart';
import 'name_search.dart';
import 'package:yolo_demo/notifiers/cart_notifier.dart';
import 'package:provider/provider.dart';
import 'package:yolo_demo/presentation/screens/gallery_edit_screen.dart';
import 'package:yolo_demo/presentation/screens/camera_guide_screen.dart';
import 'package:yolo_demo/presentation/screens/gallery_guide_screen.dart' show showGalleryGuideIfNeeded;
import 'package:yolo_demo/api_services/name_search_service.dart';
import 'package:yolo_demo/screens/name_search.dart';
import 'package:yolo_demo/notifiers/compare_tray.dart';
import 'package:yolo_demo/notifiers/home_button.dart';

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:yolo_demo/screens/final_result.dart';
import 'package:yolo_demo/screens/recent_all_screen.dart';
import 'package:yolo_demo/utils/image_utils.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  List<data.PillData> recentPills = [];
  List<Map<String, dynamic>> topPills = []; // top 10 데이터
  bool isSearchFocused = false; // 검색창 포커스 상태

  final _searchController = TextEditingController();
  final _nameSearchService = NameSearchService();

  int _selectedIndex = 0;

  double? _recentMaxCardHeight; // 최근검색 카드들 중 가장 큰 높이

  // --- Added for suggestion mode/focus node ---
  late FocusNode _searchFocusNode;
  bool _suggestionMode = false;

  // --- Crawl dedupe & cooldown ---
  final Map<String, String> _crawlUrlCache = {};            // itemSeq -> resolved url

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode = FocusNode();
    _loadRecentPills();
    _loadTopPills();
    _loadCartCount();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecentPills();
      _loadTopPills();
      _loadCartCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 키보드 열림 여부는 매번 안전하게 계산해서 사용 (전역 변수 의존 X)
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      // 추천 모드(검색창 전용 화면) vs 홈 모드(기존 메인) 분기
      body: _suggestionMode ? _buildSuggestionMode() : _buildHomeMode(),
      // 하단 네비게이션은 추천 모드가 아닐 때만 노출
      bottomNavigationBar: _suggestionMode ? null : _buildBottomNavigation(),
      floatingActionButton: _suggestionMode ? const HomeFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }


  // 검색 제안 모드 (하얀 배경 + Top 10)
  Widget _buildSuggestionMode() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => setState(() {}),
              onTap: () {
                if (!_suggestionMode) {
                  setState(() {
                    _suggestionMode = true;
                    isSearchFocused = true;
                  });
                  FocusScope.of(context).unfocus();
                } else {
                  _searchFocusNode.requestFocus();
                }
              },
              onSubmitted: (_) => _onSearch(),
              decoration: InputDecoration(
                hintText: '약물명을 입력하세요',
                prefixIcon: IconButton(
                  icon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                  onPressed: _onSearch,
                ),
                suffixIcon: (_searchController.text.isNotEmpty)
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Top 10 섹션
          _buildTopPillsSection(context),
        ],
      ),
    );
  }

  // 홈 모드 (기존 화면)
  Widget _buildHomeMode() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 스크롤 영역
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 로고와 비교함 버튼
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                        child: Row(
                          children: [
                            Image.asset('assets/logo-p.png', height: 40),
                            SizedBox(width: 10),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _openCompareTray,
                              child: AnimatedBuilder(
                                animation: CompareTray.instance,
                                builder: (_, __) {
                                  final count = CompareTray.instance.count;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                       Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: Image.asset('assets/compare-3d.png', height: 28),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          right: 0,
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
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                      // 검색창
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onTap: () {
                            if (!_suggestionMode) {
                              setState(() {
                                _suggestionMode = true;
                                isSearchFocused = true;
                              });
                              FocusScope.of(context).unfocus();
                            } else {
                              _searchFocusNode.requestFocus();
                            }
                          },
                          onTapOutside: (event) {
                            setState(() {
                              _suggestionMode = false;
                              isSearchFocused = false;
                            });
                          },
                          onEditingComplete: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _suggestionMode = false;
                              isSearchFocused = false;
                            });
                          },
                          onSubmitted: (_) => _onSearch(),
                          decoration: InputDecoration(
                            hintText: '약물명을 입력하세요',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                            ),
                            prefixIcon: IconButton(
                              icon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                              onPressed: _onSearch,
                            ),
                            suffixIcon: (_searchController.text.isNotEmpty)
                                ? IconButton(
                                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      // 버튼들
                      if (!isSearchFocused) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 170),
                                  child: FilledButton.tonal(
                                    onPressed: () async {
                                      await _showImagePickDialog(context);
                                    },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 22),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.12)),
                                      elevation: 1,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: const Offset(0, -6),
                                          child: Image.asset('assets/image_search-3d.png', height: 88),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text('이미지로', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 6),
                                        Text(
                                          '검색하기',
                                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minHeight: 170),
                                  child: FilledButton.tonal(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const FeatureSearchScreen()),
                                      ).then((_) {
                                        _loadRecentPills();
                                        _loadCartCount();
                                      });
                                    },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 22),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.12)),
                                      elevation: 1,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Transform.translate(
                                          offset: const Offset(0, -6),
                                          child: Image.asset('assets/feature_search-3d.png', height: 88),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text('특징으로', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 6),
                                        Text(
                                          '검색하기',
                                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 비교함 열기
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 62),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openCompareTray,
                                icon: Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Image.asset('assets/compare-3d.png', height: 44),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                label: const Text(
                                  '비교함 열기',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                             // 최근검색 섹션 (위치 조정)
               if (!_suggestionMode) ...[
                 Container(
                   color: Colors.transparent,
                   child: Padding(
                     padding: EdgeInsets.fromLTRB(0, 8, 0, math.max(4, bottomInset)),
                     child: _buildRecentCarousel(context),
                   ),
                 ),
               ],
            ],
          );
        },
      ),
    );
  }

  // Top 10 섹션
  Widget _buildTopPillsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            '실시간 검색어 Top 10',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ),
        if (topPills.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.trending_up, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '데이터를 불러오는 중...',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topPills.length,
            itemBuilder: (context, index) {
              final pill = topPills[index];
              final pillName = (pill['itemName'] ?? '').toString();

              return InkWell(
                onTap: () => _onTopPillTap(pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: index < 3 ? Colors.orange : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pillName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // 최근검색 캐러셀
  Widget _buildRecentCarousel(BuildContext context) {
    if (recentPills.isEmpty) {
      return const SizedBox.shrink();
    }

    final textScale = MediaQuery.of(context).textScaleFactor;
    // Grow card height as text grows, but gently (60% of text scaling) and cap it.
    final double _scaledCardHeight = (132.0 * (textScale <= 1 ? 1 : (1 + (textScale - 1) * 0.6))).clamp(132.0, 200.0);
    // Keep image height mostly stable; slightly shrink if text is huge to avoid overflow.
    final double _scaledImageHeight = (72.0 - ((textScale - 1) * 16.0)).clamp(56.0, 72.0);
    final int _titleMaxLines = textScale >= 1.3 ? 3 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text(
                '최근검색',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: _openRecentAll,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: const StadiumBorder(),
                  elevation: 0,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      '검색기록 전체보기',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              for (final pill in recentPills) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final seq = (pill.itemSeq).toString();
                    if (seq.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('itemSeq가 없어 이동할 수 없습니다.')),
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
                      final res = await http.post(
                        uri,
                        headers: headers,
                        body: json.encode([seq]),
                      );
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                      if (res.statusCode == 200) {
                        final data = json.decode(res.body);
                        // 상세 결과 화면으로 이동
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FinalResultScreen(resultData: data),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('서버 오류: ${res.statusCode}')),
                        );
                      }
                    } catch (e) {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  },
                  child: SizedBox(
                    width: 108,
                    height: _scaledCardHeight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Transform.translate(
                        offset: const Offset(0, -2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 이미지 영역
                            Container(
                              height: _scaledImageHeight,
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (() {
                                  final crawlFuture = _getImageWithCrawling({
                                    'itemSeq': pill.itemSeq,
                                    'imageUrl': pill.imageUrl,
                                  });
                                  return FutureBuilder<String?>(
                                    future: crawlFuture,
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
                                      final cleaned = finalImageUrl == null ? null : _normalizeCrawledUrl(finalImageUrl);
                                      if (cleaned != null && !ImageUtils.isPlaceholder(cleaned)) {
                                        if (_isCrawledUrl(cleaned)) {
                                          return FutureBuilder<Map<String, String>>(
                                            future: ApiHelper.getAuthHeaders(),
                                            builder: (context, snap) {
                                              final headers = snap.data;
                                              if (snap.connectionState == ConnectionState.waiting) {
                                                return Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                                  ),
                                                );
                                              }
                                              return Image.network(
                                                cleaned,
                                                headers: headers,
                                                fit: BoxFit.contain,
                                                gaplessPlayback: true,
                                                errorBuilder: (_, __, ___) => Image.asset('assets/no_image.png', fit: BoxFit.contain),
                                              );
                                            },
                                          );
                                        }
                                        return Image.network(
                                          cleaned,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                          errorBuilder: (_, __, ___) => Image.asset('assets/no_image.png', fit: BoxFit.contain),
                                        );
                                      } else {
                                        return Image.asset('assets/no_image.png', fit: BoxFit.contain);
                                      }
                                    },
                                  );
                                })(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 약물명
                            Text(
                              pill.itemName,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: _titleMaxLines,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // 전체보기 카드 추가
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openRecentAll,
                child: SizedBox(
                  width: 108,
                  height: _scaledCardHeight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Transform.translate(
                      offset: const Offset(0, -2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            height: _scaledImageHeight,
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.20)),
                              ),
                              child: Icon(
                                Icons.list_alt,
                                size: 24,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '전체보기',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 하단 네비게이션
  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      iconSize: 28,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        BottomNavigationBarItem(icon: Icon(Icons.medical_information), label: '복약이력저장'),
      ],
      currentIndex: _selectedIndex,
      onTap: (index) async {
        // Home tab -> just ensure we’re at Home
        if (index == 0) {
          if (mounted) {
            setState(() => _selectedIndex = 0);
          }
          return;
        }

        // Settings tab -> push and then reset back to Home
        if (index == 1) {
          await Navigator.pushNamed(context, '/settings');
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
          _loadRecentPills();
          _loadCartCount();
          return;
        }

        // Favorite (복약이력저장) tab -> push and then reset back to Home
        if (index == 2) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FavoriteScreen()),
          );
          if (!mounted) return;
          setState(() => _selectedIndex = 0);
          _loadRecentPills();
          _loadCartCount();
          return;
        }
      },
    );
  }

  // 기존 메서드들 (간단하게 구현)
  void _onTopPillTap(Map<String, dynamic> pill) {
    final itemName = pill['itemName']?.toString() ?? '';
    if (itemName.isEmpty) return;

    _searchController.text = itemName;

    // 추천 오버레이 닫고 키보드 내리기
    setState(() {
      _suggestionMode = false;
      isSearchFocused = false;
    });
    FocusScope.of(context).unfocus();

    // 실제 검색 실행
    _onSearch();
  }

  Future<void> _loadTopPills() async {
    try {
      final pills = await ApiHelper.getTopPills();
      setState(() {
        topPills = pills;
      });
    } catch (e) {
      debugPrint('Top 10 로드 실패: $e');
    }
  }

  Future<void> _loadRecentPills() async {
    try {
      final pills = await DBHelper.getRecentPills();
      setState(() {
        recentPills = pills;
      });
    } catch (e) {
      debugPrint('최근검색 로드 실패: $e');
    }
  }

  Future<void> _loadCartCount() async {
    // 카트 개수 로드 로직
  }

  void _openCompareTray() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CartScreen()),
    ).then((_) {
      if (mounted) {
        _loadRecentPills();
        _loadCartCount();
      }
    });
  }

  void _openRecentAll() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecentAllScreen()),
    ).then((_) {
      if (mounted) {
        _loadRecentPills();
      }
    });
  }

  Future<void> _showImagePickDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '이미지로 검색하기',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // 카메라로 촬영
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('카메라로 촬영'),
                    onPressed: () async {
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      await showCameraGuideIfNeeded(context);
                      if (mounted) {
                        _loadRecentPills();
                        _loadCartCount();
                      }
                    },
                  )
                ),
                const SizedBox(height: 10),

                // 앨범에서 선택
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('앨범에서 선택'),
                    onPressed: () async {
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      await showGalleryGuideIfNeeded(context);
                      if (mounted) {
                        await _loadRecentPills();
                        await _loadCartCount();
                      }
                    },
                  )
                ),

                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 카메라 가이드가 '건너뛰기'로 설정되어 있으면 바로 카메라 플로우로,
  /// 아니면 가이드를 먼저 띄우고 '시작하기'를 누른 경우에만 카메라 플로우로 진입.
  /// * 가이드는 반드시 `Navigator.push`로 띄워서 뒤로 스와이프가 정상 동작하도록 한다.
  Future<void> showCameraGuideIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Backward compatible: prefer new key, fallback to legacy inverted key.
    final bool? newSkip = prefs.getBool('skip_camera_guide');           // true = skip guide
    final bool? legacyShow = prefs.getBool('show_camera_guide');        // true = show guide
    // If new key exists, use it. Otherwise, derive from legacy key (show => !skip).
    final bool skip = (newSkip != null) ? newSkip : !(legacyShow ?? true);

    debugPrint('📌 [GuideFlow] skip_camera_guide(new)=$newSkip, show_camera_guide(legacy)=$legacyShow → skip=$skip');

    if (skip) {
      // ⏭️ Skip guide → go straight to **camera** flow (NOT the guide)
      // NOTE: Replace the route below with your actual camera entry route.
      // If your app previously used '/camera_guide' to show the guide UI,
      // you must point to the real camera/capture route here (e.g. '/camera_inference').
      const cameraEntryRoute = '/camera_inference';
      try {
        await Navigator.pushNamed(context, cameraEntryRoute);
      } catch (_) {
        // Fallback: if named route isn't registered, try pushing the guide screen but ask it to auto-start camera.
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CameraGuideScreen()),
        );
      }
      if (mounted) {
        await _loadRecentPills();
      }
      return;
    }

    // 📖 Show guide first → when "시작하기" pressed, CameraGuideScreen should `Navigator.pop(context, true)`
    final proceed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CameraGuideScreen()),
    );

    if (proceed == true && mounted) {
      await showCameraGuideIfNeeded(context);
    }

    if (mounted) {
      await _loadRecentPills();
    }
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // 추천 오버레이/포커스 닫기
    setState(() {
      _suggestionMode = false;
      isSearchFocused = false;
    });
    FocusScope.of(context).unfocus();

    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 실제 검색 실행
      final resultList = await _nameSearchService.searchByName(query);

      // 로딩 다이얼로그 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (resultList.isNotEmpty && mounted) {
        // 검색 결과가 있으면 결과 화면으로 이동
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NameSearchScreen(
              searchResults: resultList,
              searchKeyword: query,
            ),
          ),
        );
      } else if (mounted) {
        // 검색 결과가 없으면 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$query"에 대한 검색 결과가 없습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // 에러 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('검색 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('검색 오류: $e');
    } finally {
      if (mounted) {
        _loadRecentPills();
        _loadCartCount();
      }
    }
  }

  String _normalizeCrawledUrl(String url) {
    try {
      final u = Uri.parse(url);
      if (u.path.contains('/image-scrape')) {
        final newQuery = Map<String, String>.from(u.queryParameters);
        newQuery.remove('token');
        final cleaned = u.replace(queryParameters: newQuery).toString();
        return cleaned;
      }
      return url;
    } catch (_) {
      return url;
    }
  }

  bool _isCrawledUrl(String? url) => url != null && url.contains('/image-scrape');

  Future<String?> _getImageWithCrawling(Map<String, String?> data) async {
    final itemSeq = data['itemSeq'];
    final imageUrl = data['imageUrl'];

    // 1) 원본 이미지가 유효하면 그대로 사용
    if (imageUrl != null && !ImageUtils.isPlaceholder(imageUrl)) {
      return imageUrl;
    }

    // 2) itemSeq 없으면 포기
    if (itemSeq == null || itemSeq.isEmpty) {
      return null;
    }

    // 3) 캐시된 성공 결과가 있으면 즉시 반환
    final cached = _crawlUrlCache[itemSeq];
    if (cached != null) {
      return cached;
    }

    // 4) 크롤링이 필요하지만 재요청하지 않음 - 원본 반환
    debugPrint('⏭️ [MainScreen] 크롤링 필요하지만 재요청 안함: $itemSeq');
    return imageUrl;
  }
}
