// 공용 위젯(헤더타일/탭/도넛/썸네일)
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'admin_theme.dart';
import '../admin_api.dart';

/// 상단 요약 타일
class HeaderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const HeaderTile({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 알약형 탭
class PillTabs extends StatelessWidget {
  final TabController tabController;
  final List<String> labels;
  final Color bg, active, border, textActive, textInactive;

  const PillTabs({
    super.key,
    required this.tabController,
    required this.labels,
    required this.bg,
    required this.active,
    required this.border,
    required this.textActive,
    required this.textInactive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: active,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        labelColor: textActive,
        unselectedLabelColor: textInactive,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: labels.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}

/// 도넛 차트 (fl_chart)
class PieDonut extends StatelessWidget {
  final double yolo, ocr, colorVal;
  final Color yoloColor, ocrColor, colorColor, labelBg;
  const PieDonut({
    super.key,
    required this.yolo,
    required this.ocr,
    required this.colorVal,
    required this.yoloColor,
    required this.ocrColor,
    required this.colorColor,
    required this.labelBg,
  });

  @override
  Widget build(BuildContext context) {
    final sum = yolo + ocr + colorVal;
    if (sum <= 0.0001) return const Center(child: Text('데이터 없음'));
    final sections = [
      _sec(yolo,  yoloColor,  'YOLO'),
      _sec(ocr,   ocrColor,   'OCR'),
      _sec(colorVal, colorColor, 'Color'),
    ].where((s) => s.value > 0).toList();

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 52,
        startDegreeOffset: -90,
        borderData: FlBorderData(show: false),
        sections: sections,
      ),
    );
  }

  PieChartSectionData _sec(double v, Color color, String title) {
    final pct = (v * 100).clamp(0, 100).toDouble();
    return PieChartSectionData(
      value: pct,
      color: color,
      radius: 46,
      title: '${pct.toStringAsFixed(0)}%',
      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      badgeWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ),
      badgePositionPercentageOffset: .98,
    );
  }
}

/// 썸네일 + 간단 캐시
class ImageThumb extends StatefulWidget {
  final AdminApi api;
  final String? imageId;
  final double size;
  const ImageThumb({super.key, required this.api, required this.imageId, this.size = 44});

  @override
  State<ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<ImageThumb> {
  static final Map<String, Uint8List> _cache = {};
  Uint8List? _bytes;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant ImageThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) _load();
  }

  Future<void> _load() async {
    final id = widget.imageId;
    if (id == null || id.isEmpty) return;
    if (_cache.containsKey(id)) { setState(() => _bytes = _cache[id]); return; }
    try {
      final res = await widget.api.getModelImage(id);
      if (res.statusCode == 200) {
        _cache[id] = res.bodyBytes;
        if (mounted) setState(() => _bytes = res.bodyBytes);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (_bytes == null)
          ? Container(width: s, height: s, color: Colors.white10, alignment: Alignment.center,
              child: const Icon(Icons.image, size: 18, color: Colors.white54))
          : Image.memory(_bytes!, width: s, height: s, fit: BoxFit.cover),
    );
  }
}

Widget thumbPlaceholder({double size = 44}) => Container(
  width: size, height: size,
  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
  alignment: Alignment.center,
  child: const Icon(Icons.image, size: 18, color: Colors.white54),
);

/// 인증 전 웰컴 블럭(간단)
class WelcomeBlock extends StatelessWidget {
  final TextEditingController adminKeyCtrl;
  final ValueNotifier<bool> keyVisible;
  final VoidCallback onApply;
  const WelcomeBlock({super.key, required this.adminKeyCtrl, required this.keyVisible, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminPalette.bg,
      body: Stack(
        children: [
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  AdminPalette.panel.withOpacity(.8),
                  AdminPalette.textSecondary.withOpacity(.25),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Admin Console',
                        style: TextStyle(
                          color: AdminPalette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('보안 키를 입력하고 대시보드를 시작하세요.',
                        style: TextStyle(color: AdminPalette.textPrimary.withOpacity(.7), fontSize: 16),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black12),
                          boxShadow: const [BoxShadow(blurRadius: 20, spreadRadius: -8, offset: Offset(0, 10), color: Color(0x1F000000))],
                        ),
                        child: Column(
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: keyVisible,
                              builder: (_, visible, __) {
                                return TextField(
                                  controller: adminKeyCtrl,
                                  obscureText: !visible,
                                  style: const TextStyle(color: AdminPalette.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'X-ADMIN-KEY',
                                    labelStyle: const TextStyle(color: AdminPalette.textPrimary),
                                    hintText: '예) sk_live_***',
                                    hintStyle: const TextStyle(color: AdminPalette.textSecondary),
                                    filled: true, fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      tooltip: visible ? '숨기기' : '표시',
                                      icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
                                          color: AdminPalette.textSecondary),
                                      onPressed: () => keyVisible.value = !visible,
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AdminPalette.panel2)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AdminPalette.accent, width: 2)),
                                  ),
                                  onSubmitted: (_) => onApply(),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity, height: 54,
                              child: ElevatedButton(
                                onPressed: onApply,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminPalette.accent, foregroundColor: Colors.white, elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('접속하기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text('키는 로컬 메모리에 저장되지 않습니다.',
                                style: TextStyle(color: AdminPalette.textPrimary.withOpacity(.6), fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: const [
                          _FeatureChip('모델 성능 통계', Icons.pie_chart_rounded),
                          _FeatureChip('user | DB 관리', Icons.verified_user_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label; final IconData icon;
  const _FeatureChip(this.label, this.icon);
  @override
  Widget build(BuildContext context) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      avatar: Icon(icon, color: AdminPalette.textSecondary),
      label: Text(label, style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w600)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminPalette.panel2),
      ),
    );
  }
}
