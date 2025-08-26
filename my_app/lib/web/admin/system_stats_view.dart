// 시스템 통계 메인 뷰
// - TODAY KPI 숫자
// - 시계열(일/주/월): 월/주=막대, 일=라인(도트)
// - 알약 TOP(Top 10, "더보기"는 bottom sheet에서 limit로 확장 조회 + 스크롤)
// - 제품군별 TOP(아이콘 그리드 → 디테일 bottom sheet 스크롤, overflow 방지)
// - identify 쿼리: 필터(user_id), 총 건수, 미니 바차트(일자별), 예쁜 카드 리스트

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'admin_theme.dart';
import '../admin_api.dart';
import 'widgets.dart';

class SystemStatsView extends StatefulWidget {
  final AdminApi? api;
  final void Function(String, {bool error}) toast;
  const SystemStatsView({super.key, required this.api, required this.toast});

  @override
  State<SystemStatsView> createState() => _SystemStatsViewState();
}

class _SystemStatsViewState extends State<SystemStatsView> {
  AdminApi? get _client => widget.api;

  // 공통 상태
  final _gran = ValueNotifier<String>('day'); // day|week|month
  DateTime _rangeStart = DateTime.now().subtract(const Duration(days: 6));
  DateTime _rangeEnd = DateTime.now();
  int _tzOffset = DateTime.now().timeZoneOffset.inMinutes;

  // TODAY
  bool _loadingToday = false;
  int? _todayTotal, _todayNew, _todayReturning;

  // 시계열
  bool _loadingSeries = false;
  List<_Point> _seriesTotal = [], _seriesNew = [], _seriesReturning = [];

  // TOP pills
  bool _loadingTopPills = false;
  List<_TopRow> _topPills = [];

  // By-type
  bool _loadingByType = false;
  List<_TypeGroup> _typeGroups = [];

  // Identify
  bool _loadingIdentify = false;
  List<_IdentifyRow> _identifyRows = [];
  Map<String,int> _identifyDaily = {}; // 간단 빈도
  final _identifyUserCtrl = TextEditingController(); // user_id 필터

  // Keyword
  bool _loadingKeyword = false;
  List<_KeywordRow> _keywordRows = [];
  Map<String,int> _keywordDaily = {}; // 일자별 키워드 검색 횟수
  List<_KeywordStat> _keywordStats = []; // 키워드별 집계 통계
  final _keywordUserCtrl = TextEditingController(); // user_id 필터

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant SystemStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) _loadAll();
  }

  void _loadAll() {
    _loadToday();
    _loadSeries();
    _loadTopPills(limit: 10);
    _loadByType();
    _loadIdentify();
    _loadKeyword();
  }

  // ---------- LOADERS ----------
  Future<void> _loadToday() async {
    final c = _client; if (c == null) return;
    setState(()=>_loadingToday=true);
    try {
      final r = await c.getStatsToday(tzOffsetMinutes: _tzOffset);
      _todayTotal = r['total_users_today'] as int?;
      _todayNew = r['new_users_today'] as int?;
      _todayReturning = r['returning_users_today'] as int?;
    } catch (e) {
      widget.toast('TODAY 로드 실패: $e', error:true);
    } finally { if(mounted) setState(()=>_loadingToday=false); }
  }

  Future<void> _loadSeries() async {
    final c = _client; if (c == null) return;
    setState(()=>_loadingSeries=true);
    try {
      final s = DateFormat('yyyy-MM-dd').format(_rangeStart);
      final e = DateFormat('yyyy-MM-dd').format(_rangeEnd);
      final r = await c.getUsageSeries(
        granularity: _gran.value, start: s, end: e, tzOffsetMinutes: _tzOffset);
      final List series = (r['series'] as List?) ?? [];
      _seriesTotal = series.map<_Point>((e) => _Point(e['bucket'], (e['total_users'] ?? 0).toDouble())).toList();
      _seriesNew   = series.map<_Point>((e) => _Point(e['bucket'], (e['new_users']   ?? 0).toDouble())).toList();
      _seriesReturning = series.map<_Point>((e) => _Point(e['bucket'], (e['returning_users'] ?? 0).toDouble())).toList();
    } catch (e) {
      widget.toast('시계열 로드 실패: $e', error:true);
    } finally { if(mounted) setState(()=>_loadingSeries=false); }
  }

  Future<void> _loadTopPills({required int limit}) async {
    final c = _client; if (c == null) return;
    setState(()=>_loadingTopPills=true);
    try {
      final s = DateFormat('yyyy-MM-dd').format(_rangeStart);
      final e = DateFormat('yyyy-MM-dd').format(_rangeEnd);
      final r = await c.getTopPills(start:s, end:e, tzOffsetMinutes:_tzOffset, limit:limit);
      final rows = (r['rows'] as List?)??[];
      _topPills = rows.map((m)=>_TopRow(
        name: m['itemName']??'-',
        count: (m['count']??0) as int,
        prductType: m['prductType']??'',
        entpName: m['entpName']??'',
      )).toList();
    } catch(e){ widget.toast('TOP 알약 로드 실패: $e', error:true); }
    finally { if(mounted) setState(()=>_loadingTopPills=false); }
  }

  Future<void> _loadByType() async {
    final c = _client; if (c == null) return;
    setState(()=>_loadingByType=true);
    try {
      final s = DateFormat('yyyy-MM-dd').format(_rangeStart);
      final e = DateFormat('yyyy-MM-dd').format(_rangeEnd);
      final r = await c.getTopByType(start:s, end:e, tzOffsetMinutes:_tzOffset, topK:20);
      final groups = (r['groups'] as List?)??[];
      _typeGroups = groups.map((g)=>_TypeGroup(
        prductType: g['prductType']??'-',
        items: ((g['top']??[]) as List).map<_TopRow>((i)=>_TopRow(
          name: i['itemName']??'-',
          count: (i['count']??0) as int,
          prductType: g['prductType']??'',
          entpName: '',
        )).toList(),
      )).toList();
    } catch(e){ 
      widget.toast('제품군별 TOP 로드 실패: $e', error:true); 
    } finally { 
      if(mounted) setState(()=>_loadingByType=false); 
    }
  }

  Future<void> _loadIdentify({String? userId}) async {
    final c = _client; if (c == null) return;
    setState(()=>_loadingIdentify=true);
    try {
      final s = DateFormat('yyyy-MM-dd').format(_rangeStart);
      final e = DateFormat('yyyy-MM-dd').format(_rangeEnd);
      final r = await c.getIdentifyQueries(
        start:s, end:e, tzOffsetMinutes:_tzOffset, limit:200, userId: userId?.trim().isEmpty==true? null : userId,
      );
      final rows = (r['logs'] as List?)??[];
      _identifyRows = rows.map((m)=>_IdentifyRow(
        userId: m['user_id']??'-',
        timestamp: DateTime.tryParse(m['timestamp']?.toString()??'')?.toLocal(),
        query: (m['query'] is Map<String,dynamic>) ? (m['query'] as Map<String,dynamic>) : null,
      )).toList();

      // 간단 일자별 카운트
      _identifyDaily.clear();
      for (final it in _identifyRows) {
        if (it.timestamp == null) continue;
        final k = DateFormat('yyyy-MM-dd').format(it.timestamp!);
        _identifyDaily[k] = (_identifyDaily[k]??0) + 1;
      }
    } catch(e){ widget.toast('identify 로드 실패: $e', error:true); }
    finally { if(mounted) setState(()=>_loadingIdentify=false); }
  }

  Future<void> _loadKeyword({String? userId}) async {
    final c = _client; if (c == null) return;
    setState(()=>_loadingKeyword=true);
    try {
      final s = DateFormat('yyyy-MM-dd').format(_rangeStart);
      final e = DateFormat('yyyy-MM-dd').format(_rangeEnd);
      final r = await c.getKeywordQueries(
        start:s, end:e, tzOffsetMinutes:_tzOffset, limit:200, userId: userId?.trim().isEmpty==true? null : userId,
      );
      
      // 일자별 통계
      final dailyStats = (r['daily_stats'] as List?)??[];
      _keywordDaily.clear();
      for (final day in dailyStats) {
        final date = day['date'] as String?;
        final count = (day['count'] as int?)??0;
        if (date != null) _keywordDaily[date] = count;
      }

      // 키워드별 집계 통계
      final keywordStats = (r['keyword_stats'] as List?)??[];
      _keywordStats = keywordStats.map((s)=>_KeywordStat(
        keyword: s['keyword']??'-',
        searchCount: (s['search_count']??0) as int,
        totalItems: (s['total_items']??0) as int,
        sampleQueries: (s['sample_queries'] as List?)??[],
      )).toList();

      // 최신 개별 로그
      final recentLogs = (r['recent_logs'] as List?)??[];
      _keywordRows = recentLogs.map((m)=>_KeywordRow(
        userId: m['user_id']??'-',
        keyword: m['keyword']??'-',
        timestamp: DateTime.tryParse(m['timestamp']?.toString()??'')?.toLocal(),
        itemsCount: (m['items_count']??0) as int,
        query: (m['query'] is Map<String,dynamic>) ? (m['query'] as Map<String,dynamic>) : null,
      )).toList();
    } catch(e){ widget.toast('키워드 검색 로드 실패: $e', error:true); }
    finally { if(mounted) setState(()=>_loadingKeyword=false); }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, bx) {
      final maxW = bx.maxWidth;
      const gap = 16.0;

      double cardW;
      if (maxW >= 1200) {
        cardW = (maxW - gap*4)/3;
      } else if (maxW >= 820) {
        cardW = (maxW - gap*3)/2;
      } else {
        cardW = maxW - gap*2;
      }

      return Container(
        color: AdminPalette.bg,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 상단 범위/그라뉼 설정
              _rangePickerBar(),

              const SizedBox(height: gap),
              Wrap(
                spacing: gap, runSpacing: gap,
                children: [
                  SizedBox(width: cardW, child: _section(
                    icon: Icons.today_rounded,
                    title: 'TODAY 사용자',
                    trailing: _ghost('새로고침', onTap: _loadingToday? null : _loadToday),
                    child: _todayKpis(),
                  )),

                  // 사용량 시계열: 박스 높이 축소(요청)
                  SizedBox(width: cardW*2 + gap, child: _section(
                    icon: Icons.show_chart_rounded,
                    title: '사용자 일/주/월 별 통계',
                    trailing: _granTabs(),
                    child: _usageChart(height: 220),
                  )),

                  SizedBox(width: cardW, child: _section(
                    icon: Icons.leaderboard_rounded,
                    title: '알약 검색 TOP랭킹 (Top 10)',
                    trailing: _ghost('더보기', onTap: _loadingTopPills? null : ()=>_openTopPillsDetail()),
                    child: _topPillsRanking(maxRows: 10),
                  )),
                  SizedBox(width: cardW*2 + gap, child: _section(
                    icon: Icons.category_rounded,
                    title: '제품군별 TOP랭킹 (식약처 분류)',
                    child: _typeGrid(),
                  )),
                  SizedBox(width: cardW, child: _section(
                    icon: Icons.search_rounded,
                    title: '식별 검색 통계/확인',
                    trailing: _ghost('새로고침', onTap: _loadingIdentify? null : ()=>_loadIdentify(userId: _identifyUserCtrl.text)),
                    child: _identifyBlock(),
                  )),
                  SizedBox(width: cardW, child: _section(
                    icon: Icons.keyboard_rounded,
                    title: '키워드 검색 통계/확인',
                    trailing: _ghost('새로고침', onTap: _loadingKeyword? null : _loadKeyword),
                    child: _keywordBlock(),
                  )),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _rangePickerBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminPalette.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          const Icon(Icons.calendar_month, color: AdminPalette.textPrimary),
          _dateBtn('시작', _rangeStart, (d){ setState(()=>_rangeStart=d); _loadAll(); }),
          _dateBtn('종료', _rangeEnd, (d){ setState(()=>_rangeEnd=d); _loadAll(); }),
          const SizedBox(width: 8),
          _ghost('지난 7일', onTap: (){
            setState((){ _rangeEnd = DateTime.now(); _rangeStart = _rangeEnd.subtract(const Duration(days: 6)); });
            _loadAll();
          }),
          _ghost('지난 30일', onTap: (){
            setState((){ _rangeEnd = DateTime.now(); _rangeStart = _rangeEnd.subtract(const Duration(days: 29)); });
            _loadAll();
          }),
        ],
      ),
    );
  }

  Widget _dateBtn(String label, DateTime value, ValueChanged<DateTime> onPick) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.event, size: 18, color: AdminPalette.textPrimary),
      label: Text(DateFormat('yyyy-MM-dd').format(value), style: const TextStyle(color: AdminPalette.textPrimary)),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(now.year-2),
          lastDate: DateTime(now.year+1),
          builder: (ctx, child)=>Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: AdminPalette.accent,
                surface: Colors.white,
                onSurface: AdminPalette.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminPalette.textPrimary,
        side: const BorderSide(color: AdminPalette.panel2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---- sections ----
  Widget _section({required IconData icon, required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminPalette.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _iconBadge(icon),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(
                color: AdminPalette.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
              if (trailing!=null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AdminPalette.panel2),
    ),
    child: Icon(icon, color: AdminPalette.textPrimary),
  );

  Widget _ghost(String label, {VoidCallback? onTap}) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AdminPalette.textPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      side: const BorderSide(color: AdminPalette.panel2),
    ),
    child: Text(label),
  );

  // ---- TODAY ----
  Widget _todayKpis() {
    if (_loadingToday) return const Center(child: Padding(
      padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    final kpi = <_Kpi>[
      _Kpi('오늘 접속', _todayTotal),
      _Kpi('신규', _todayNew),
      _Kpi('재방문', _todayReturning),
    ];
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: kpi.map((e)=>_kpiCard(e.label, e.value)).toList(),
    );
  }

  Widget _kpiCard(String label, int? value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${value ?? '-'}', style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w900, color: AdminPalette.textPrimary)),
        ],
      ),
    );
  }

  // ---- SERIES ----
  Widget _granTabs() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ghost('일', onTap: (){ _gran.value='day'; _loadSeries(); }),
        const SizedBox(width: 6),
        _ghost('주', onTap: (){ _gran.value='week'; _loadSeries(); }),
        const SizedBox(width: 6),
        _ghost('월', onTap: (){ _gran.value='month'; _loadSeries(); }),
      ],
    );
  }

  Widget _usageChart({double height = 260}) {
    if (_loadingSeries) {
      return SizedBox(height: height, child: const Center(child: CircularProgressIndicator()));
    }
    final gran = _gran.value;

    if (gran == 'month' || gran == 'week') {
      // ---- 막대 그래프 (월/주) ----
      final series = _seriesTotal;
      final seriesNew = _seriesNew;
      final seriesReturning = _seriesReturning;
      
      return Column(
        children: [
          // 범례 추가
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('총 사용자', const Color(0xFF3DA3B9), Icons.people),
              const SizedBox(width: 20),
              _buildLegendItem('신규 사용자', const Color(0xFF4CAF50), Icons.person_add),
              const SizedBox(width: 20),
              _buildLegendItem('재방문 사용자', const Color(0xFFFF9800), Icons.person_outline),
            ],
          ),
          const SizedBox(height: 8),
          
          // 차트
          SizedBox(height: height - 40, child: BarChart(
            BarChartData(
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i<0 || i>=series.length) return const SizedBox.shrink();
                    final dt = DateTime.parse(series[i].bucket);
                    final f = (gran == 'month') ? 'MM' : 'MM/dd';
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(DateFormat(f).format(dt),
                          style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 10)),
                    );
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 10)),
                )),
              ),
              barGroups: List.generate(series.length, (i){
                final total = series[i].value;
                final newUsers = i < seriesNew.length ? seriesNew[i].value : 0.0;
                final returning = i < seriesReturning.length ? seriesReturning[i].value : 0.0;
                
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    // 총 사용자 (가장 큰 막대)
                    BarChartRodData(
                      toY: total, 
                      width: 20, 
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFF3DA3B9),
                    ),
                    // 신규 사용자 (중간 막대)
                    BarChartRodData(
                      toY: newUsers, 
                      width: 16, 
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFF4CAF50),
                    ),
                    // 재방문 사용자 (가장 작은 막대)
                    BarChartRodData(
                      toY: returning, 
                      width: 12, 
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFFFF9800),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (touchedSpot) => AdminPalette.panel,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final i = group.x.toInt();
                    if (i < 0 || i >= series.length) return null;
                    
                    final total = series[i].value;
                    final newUsers = i < seriesNew.length ? seriesNew[i].value : 0.0;
                    final returning = i < seriesReturning.length ? seriesReturning[i].value : 0.0;
                    
                    String title;
                    double value;
                    Color color;
                    
                    switch (rodIndex) {
                      case 0:
                        title = '총 사용자';
                        value = total;
                        color = const Color(0xFF3DA3B9);
                        break;
                      case 1:
                        title = '신규 사용자';
                        value = newUsers;
                        color = const Color(0xFF4CAF50);
                        break;
                      case 2:
                        title = '재방문 사용자';
                        value = returning;
                        color = const Color(0xFFFF9800);
                        break;
                      default:
                        return null;
                    }
                    
                    return BarTooltipItem(
                      '$title\n${value.toInt()}명',
                      TextStyle(color: color, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
            ),
          )),
        ],
      );
    } else {
      // ---- 라인(일) : 얇은 라인 + 도트 ----
      final lines = <LineChartBarData>[
        _line(_seriesTotal, withDots: true, thickness: 2, color: const Color(0xFF3DA3B9)),
        _line(_seriesNew,   withDots: true, thickness: 1, color: const Color(0xFF4CAF50)),
        _line(_seriesReturning, withDots: true, thickness: 1, color: const Color(0xFFFF9800)),
      ];
      final maxY = [
        ..._seriesTotal.map((e)=>e.value),
        ..._seriesNew.map((e)=>e.value),
        ..._seriesReturning.map((e)=>e.value),
      ].fold<double>(0, (p,c)=>max(p,c)) * 1.2 + 1;

      return Column(
        children: [
          // 범례 추가
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('총 사용자', const Color(0xFF3DA3B9), Icons.people),
              const SizedBox(width: 20),
              _buildLegendItem('신규 사용자', const Color(0xFF4CAF50), Icons.person_add),
              const SizedBox(width: 20),
              _buildLegendItem('재방문 사용자', const Color(0xFFFF9800), Icons.person_outline),
            ],
          ),
          const SizedBox(height: 8),
          
          // 차트
          SizedBox(height: height - 40, child: LineChart(LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles:true, interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i<0 || i>=_seriesTotal.length) return const SizedBox.shrink();
                  final dt = DateTime.parse(_seriesTotal[i].bucket);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateFormat('MM/dd').format(dt),
                        style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 10)),
                  );
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 10)),
              )),
            ),
            lineBarsData: lines,
            lineTouchData: LineTouchData(
              enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => AdminPalette.panel,
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    final i = touchedSpot.x.toInt();
                    if (i < 0 || i >= _seriesTotal.length) return null;
                    
                    String title;
                    double value;
                    Color color;
                    
                    switch (touchedSpot.barIndex) {
                      case 0:
                        title = '총 사용자';
                        value = _seriesTotal[i].value;
                        color = const Color(0xFF3DA3B9);
                        break;
                      case 1:
                        title = '신규 사용자';
                        value = _seriesNew[i].value;
                        color = const Color(0xFF4CAF50);
                        break;
                      case 2:
                        title = '재방문 사용자';
                        value = _seriesReturning[i].value;
                        color = const Color(0xFFFF9800);
                        break;
                      default:
                        return null;
                    }
                    
                    return LineTooltipItem(
                      '$title\n${value.toInt()}명',
                      TextStyle(color: color, fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
          ))),
        ],
      );
    }
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AdminPalette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<_Point> pts, {required bool withDots, double thickness=2, required Color color}) {
    final spots = List.generate(pts.length, (i)=>FlSpot(i.toDouble(), pts[i].value));
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      barWidth: thickness,
      color: color,
      dotData: FlDotData(show: withDots),
      isStrokeCapRound: true,
    );
  }

  // ---- TOP PILLS (랭킹 보드) ----
  Widget _topPillsRanking({required int maxRows}) {
    if (_loadingTopPills) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final rows = _topPills.take(maxRows).toList();
    if (rows.isEmpty) {
      return const Text('데이터 없음',
          style: TextStyle(color: AdminPalette.textPrimary));
    }

    return Column(
      children: List.generate(rows.length, (i) {
        final r = rows[i];
        final rank = i + 1;
        final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE7E7E7)),
          ),
          child: Row(
            children: [
              SizedBox(width: 34, child: Text(medal, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AdminPalette.textPrimary))),
              const SizedBox(width: 8),
              Expanded(child: Text(r.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AdminPalette.textPrimary))),
              const SizedBox(width: 8),
              Text('${r.count}', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminPalette.textPrimary)),
            ],
          ),
        );
      }),
    );
  }

  void _openTopPillsDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminPalette.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final ctrl = TextEditingController(text: '50');
        List<_TopRow> localRows = List.of(_topPills);
        bool localLoading = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> fetchInModal(int limit) async {
              setModalState(() => localLoading = true);
              try {
                final s = DateFormat('yyyy-MM-dd').format(_rangeStart);
                final e = DateFormat('yyyy-MM-dd').format(_rangeEnd);
                final r = await _client!.getTopPills(
                  start: s, end: e, tzOffsetMinutes: _tzOffset, limit: limit,
                );
                final rows = (r['rows'] as List?) ?? [];
                localRows = rows.map((m) => _TopRow(
                  name: m['itemName'] ?? '-',
                  count: (m['count'] ?? 0) as int,
                  prductType: m['prductType'] ?? '',
                  entpName: m['entpName'] ?? '',
                )).toList();
              } catch (e) {
                widget.toast('TOP 알약 로드 실패: $e', error: true);
              } finally {
                setModalState(() => localLoading = false);
              }
            }

            final maxH = MediaQuery.of(ctx).size.height * .8;

            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.leaderboard_rounded,
                          color: AdminPalette.textPrimary),
                      SizedBox(width: 8),
                      Text('알약 검색 TOP',
                          style: TextStyle(
                              color: AdminPalette.textPrimary,
                              fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Text('limit:',
                          style: TextStyle(color: AdminPalette.textPrimary)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          style:
                              const TextStyle(color: AdminPalette.textPrimary),
                          decoration: _input('예: 50'),
                          onSubmitted: (_) {
                            final v = int.tryParse(ctrl.text.trim()) ?? 50;
                            fetchInModal(v.clamp(1, 100));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ghost('조회', onTap: () {
                        final v = int.tryParse(ctrl.text.trim()) ?? 50;
                        fetchInModal(v.clamp(1, 100));
                      }),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: localLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.separated(
                              itemCount: localRows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: AdminPalette.panel2),
                                                             itemBuilder: (_, i) {
                                 final r = localRows[i];
                                 final rank = i + 1;
                                 final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
                                 return Container(
                                   margin: const EdgeInsets.symmetric(vertical: 6),
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                   decoration: BoxDecoration(
                                     color: Colors.white,
                                     borderRadius: BorderRadius.circular(10),
                                     border: Border.all(color: const Color(0xFFE7E7E7)),
                                   ),
                                   child: Row(
                                     children: [
                                       SizedBox(width: 34, child: Text(medal, textAlign: TextAlign.center,
                                           style: const TextStyle(fontWeight: FontWeight.w900, color: AdminPalette.textPrimary))),
                                       const SizedBox(width: 8),
                                       Expanded(child: Text(r.name,
                                           maxLines: 1, overflow: TextOverflow.ellipsis,
                                           style: const TextStyle(fontWeight: FontWeight.w800, color: AdminPalette.textPrimary))),
                                       const SizedBox(width: 8),
                                       Text('${r.count}', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminPalette.textPrimary)),
                                     ],
                                   ),
                                 );
                               },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- BY TYPE ----
  Widget _typeGrid() {
    if (_loadingByType) return const Padding(
      padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));

    final groups = _typeGroups;
    if (groups.isEmpty) return const Text('데이터 없음', style: TextStyle(color: AdminPalette.textPrimary));

    IconData iconFor(String code) {
      if (code.contains('항악성종양')) return Icons.biotech_rounded;
      if (code.contains('항히스타민')) return Icons.sick_rounded;
      if (code.contains('소화')) return Icons.restaurant_rounded;
      if (code.contains('호흡기') || code.contains('진해거담')) return Icons.air_rounded;
      if (code.contains('혈압') || code.contains('순환')) return Icons.favorite_rounded;
      if (code.contains('항생') || code.contains('화학요법')) return Icons.medication_rounded;
      if (code.contains('정신') || code.contains('신경')) return Icons.psychology_rounded;
      if (code.contains('비타민')) return Icons.local_florist_rounded;
      return Icons.category_rounded;
    }

    return Wrap(
      spacing: 12, runSpacing: 12,
      children: groups.map((g){
        final label = g.prductType;
        return InkWell(
          onTap: () => _openTypeDetail(g),
          child: Container(
            width: 160, height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E7E7)),
              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconFor(label), color: AdminPalette.textPrimary),
                const Spacer(),
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AdminPalette.textPrimary)),
                const SizedBox(height: 4),
                Text('Top ${g.items.length}', style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _openTypeDetail(_TypeGroup g) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminPalette.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (_) {
        final maxH = MediaQuery.of(context).size.height * 0.8;
        return Padding(
          padding: EdgeInsets.only(left:16,right:16,top:16,
            bottom: MediaQuery.of(context).viewInsets.bottom+16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.category_rounded, color: AdminPalette.textPrimary),
                const SizedBox(width: 8),
                Expanded(child: Text(g.prductType, style: const TextStyle(
                  color: AdminPalette.textPrimary, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: min(20, g.items.length),
                  separatorBuilder: (_, __)=>const Divider(color: AdminPalette.panel2),
                  itemBuilder: (_, i){
                    final r = g.items[i];
                    return ListTile(
                      dense: true,
                      title: Text(r.name, style: const TextStyle(color: AdminPalette.textPrimary)),
                      trailing: Text('${r.count}', style: const TextStyle(
                        color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
                    );
                  },
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ---- IDENTIFY ----
  Widget _identifyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 필터 바 (user_id)
        Row(children: [
          const Text('user_id:', style: TextStyle(color: AdminPalette.textPrimary)),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _identifyUserCtrl,
            style: const TextStyle(color: AdminPalette.textPrimary),
            decoration: _input('특정 사용자만 (선택)'),
            onSubmitted: (_) => _loadIdentify(userId: _identifyUserCtrl.text),
          )),
          const SizedBox(width: 8),
          _ghost('조회', onTap: ()=>_loadIdentify(userId: _identifyUserCtrl.text)),
        ]),
        const SizedBox(height: 12),

        // 미니 바차트 (일자별 검색 수)
        if (_loadingIdentify)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('일자별 식별 검색 횟수', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
              Text('총 ${_identifyRows.length}건', style: const TextStyle(color: AdminPalette.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          if (_identifyRows.isEmpty)
            const Text('최근 식별 검색이 없습니다.', style: TextStyle(color: AdminPalette.textPrimary))
          else _identifyMiniBar(),
          const SizedBox(height: 10),
          const Text('최근 식별 쿼리', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SizedBox(
            height: 230,
            child: ListView.separated(
              itemCount: _identifyRows.length,
              separatorBuilder: (_, __)=>const Divider(color: AdminPalette.panel2),
              itemBuilder: (_, i){
                final r = _identifyRows[i];
                final ts = r.timestamp!=null ? DateFormat('yyyy-MM-dd HH:mm').format(r.timestamp!) : '-';
                final q = r.query ?? {};
                final src = (q['source'] ?? '-').toString();
                final itemSeq = (q['item_seq'] ?? q['itemSeq'] ?? '-').toString();

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE7E7E7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1행: 시간 + user
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AdminPalette.panel2, borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(ts, style: const TextStyle(
                              color: AdminPalette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r.userId,
                            style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(src, style: const TextStyle(color: AdminPalette.textPrimary)),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(color: AdminPalette.panel2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 2행: 쿼리 요약/JSON 미리보기
                      Text(
                        itemSeq != '-' ? 'item_seq: $itemSeq' : 'query: ${q.toString()}',
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AdminPalette.textPrimary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _identifyMiniBar() {
    final keys = _identifyDaily.keys.toList()..sort();
    final vals = keys.map((k)=>_identifyDaily[k]!.toDouble()).toList();
    final maxV = (vals.isEmpty ? 1.0 : vals.fold<double>(0, (p,c)=>max(p,c))) + 1;

    return SizedBox(height: 120, child: BarChart(BarChartData(
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, interval: 1,
          getTitlesWidget: (v, _){
            final i = v.toInt();
            if (i<0 || i>=keys.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(keys[i].substring(5),
                  style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 10)),
            );
          },
        )),
      ),
      barGroups: List.generate(keys.length, (i)=>BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: vals[i], width: 10, borderRadius: BorderRadius.circular(4))],
      )),
      maxY: maxV,
      barTouchData: BarTouchData(enabled: true),
    )));
  }

  // ---- KEYWORD ----
  Widget _keywordBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 필터 바 (user_id)
        Row(children: [
          const Text('user_id:', style: TextStyle(color: AdminPalette.textPrimary)),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            controller: _keywordUserCtrl,
            style: const TextStyle(color: AdminPalette.textPrimary),
            decoration: _input('특정 사용자만 (선택)'),
            onSubmitted: (_) => _loadKeyword(userId: _keywordUserCtrl.text),
          )),
          const SizedBox(width: 8),
          _ghost('조회', onTap: ()=>_loadKeyword(userId: _keywordUserCtrl.text)),
        ]),
        const SizedBox(height: 12),

        // 미니 바차트 (일자별 키워드 검색 수)
        if (_loadingKeyword)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('일자별 키워드 검색 횟수', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
              Text('총 ${_keywordDaily.length}일', style: const TextStyle(color: AdminPalette.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          if (_keywordDaily.isEmpty)
            const Text('최근 키워드 검색이 없습니다.', style: TextStyle(color: AdminPalette.textPrimary))
          else _keywordMiniBar(),
          const SizedBox(height: 10),
          
          // 키워드별 집계 통계 (상위 20개)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('키워드별 집계 통계 (상위 20개)', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
              _ghost('더보기', onTap: _loadingKeyword? null : ()=>_openKeywordStatsDetail()),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: ListView.separated(
              itemCount: min(20, _keywordStats.length),
              separatorBuilder: (_, __)=>const Divider(color: AdminPalette.panel2),
              itemBuilder: (_, i){
                final s = _keywordStats[i];
                return ListTile(
                  dense: true,
                  title: Text(s.keyword, style: const TextStyle(color: AdminPalette.textPrimary)),
                  subtitle: Text('검색: ${s.searchCount}회, 결과: ${s.totalItems}개', 
                    style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 12)),
                  trailing: Text('${s.searchCount}', style: const TextStyle(
                    color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          
          // 최신 개별 로그 (상위 20개)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('최신 키워드 검색 로그 (상위 20개)', style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
              _ghost('더보기', onTap: _loadingKeyword? null : ()=>_openKeywordLogsDetail()),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: ListView.separated(
              itemCount: min(20, _keywordRows.length),
              separatorBuilder: (_, __)=>const Divider(color: AdminPalette.panel2),
              itemBuilder: (_, i){
                final r = _keywordRows[i];
                final ts = r.timestamp!=null ? DateFormat('MM/dd HH:mm').format(r.timestamp!) : '-';
                return ListTile(
                  dense: true,
                  title: Text(r.keyword, style: const TextStyle(color: AdminPalette.textPrimary)),
                  subtitle: Text('${r.userId} • $ts • 결과: ${r.itemsCount}개', 
                    style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 12)),
                  trailing: Text('${r.itemsCount}', style: const TextStyle(
                    color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _keywordMiniBar() {
    final keys = _keywordDaily.keys.toList()..sort();
    final vals = keys.map((k)=>_keywordDaily[k]!.toDouble()).toList();
    final maxV = (vals.isEmpty ? 1.0 : vals.fold<double>(0, (p,c)=>max(p,c))) + 1;

    return SizedBox(height: 120, child: BarChart(BarChartData(
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, interval: 1,
          getTitlesWidget: (v, _){
            final i = v.toInt();
            if (i<0 || i>=keys.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(keys[i].substring(5),
                  style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 10)),
            );
          },
        )),
      ),
      barGroups: List.generate(keys.length, (i)=>BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: vals[i], width: 10, borderRadius: BorderRadius.circular(4))],
      )),
      maxY: maxV,
      barTouchData: BarTouchData(enabled: true),
    )));
  }

  void _openKeywordStatsDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminPalette.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final maxH = MediaQuery.of(context).size.height * 0.8;
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.keyboard_rounded, color: AdminPalette.textPrimary),
                  SizedBox(width: 8),
                  Text('키워드별 집계 통계',
                      style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _keywordStats.length,
                    separatorBuilder: (_, __) => const Divider(color: AdminPalette.panel2),
                    itemBuilder: (_, i) {
                      final s = _keywordStats[i];
                      final rank = i + 1;
                      final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE7E7E7)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 34, child: Text(medal, textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: AdminPalette.textPrimary))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.keyword, style: const TextStyle(fontWeight: FontWeight.w800, color: AdminPalette.textPrimary)),
                                  Text('검색: ${s.searchCount}회, 결과: ${s.totalItems}개', 
                                    style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${s.searchCount}', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminPalette.textPrimary)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openKeywordLogsDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminPalette.panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final maxH = MediaQuery.of(context).size.height * 0.8;
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.keyboard_rounded, color: AdminPalette.textPrimary),
                  SizedBox(width: 8),
                  Text('최신 키워드 검색 로그',
                      style: TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _keywordRows.length,
                    separatorBuilder: (_, __) => const Divider(color: AdminPalette.panel2),
                    itemBuilder: (_, i) {
                      final r = _keywordRows[i];
                      final ts = r.timestamp!=null ? DateFormat('yyyy-MM-dd HH:mm').format(r.timestamp!) : '-';
                      final q = r.query ?? {};
                      final src = (q['source'] ?? '-').toString();
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE7E7E7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1행: 시간 + user + 키워드
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminPalette.panel2, borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(ts, style: const TextStyle(
                                    color: AdminPalette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(r.userId,
                                  style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(r.keyword, style: const TextStyle(color: AdminPalette.textPrimary)),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(color: AdminPalette.panel2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // 2행: 결과 개수 + 쿼리 정보
                            Row(
                              children: [
                                Text('결과: ${r.itemsCount}개', 
                                  style: const TextStyle(color: AdminPalette.textPrimary, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 16),
                                Text('source: $src', 
                                  style: const TextStyle(color: AdminPalette.textPrimary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- common ----
  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AdminPalette.textPrimary),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminPalette.panel2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AdminPalette.accent),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _Kpi { final String label; final int? value; _Kpi(this.label, this.value); }
class _Point { final String bucket; final double value; _Point(this.bucket, this.value); }
class _TopRow { final String name; final int count; final String prductType; final String entpName;
  _TopRow({required this.name, required this.count, required this.prductType, required this.entpName}); }
class _TypeGroup { final String prductType; final List<_TopRow> items; _TypeGroup({required this.prductType, required this.items}); }
class _IdentifyRow { final String userId; final DateTime? timestamp; final Map<String,dynamic>? query;
  _IdentifyRow({required this.userId, required this.timestamp, required this.query}); }
class _KeywordStat { final String keyword; final int searchCount; final int totalItems; final List sampleQueries;
  _KeywordStat({required this.keyword, required this.searchCount, required this.totalItems, required this.sampleQueries}); }
class _KeywordRow { final String userId; final String keyword; final DateTime? timestamp; final int itemsCount; final Map<String,dynamic>? query;
  _KeywordRow({required this.userId, required this.keyword, required this.timestamp, required this.itemsCount, required this.query}); }
