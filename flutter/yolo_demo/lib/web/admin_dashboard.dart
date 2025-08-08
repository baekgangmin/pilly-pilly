import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AdminDashboard extends StatefulWidget {
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String currentView = 'modelStats';

  // 날짜별 데이터 구조를 리스트로 변경
  List<Map<String, dynamic>> pillDataList = [];

  // 선택된 날짜 범위
  DateTimeRange? selectedDateRange;

  // 선택된 이미지 날짜
  String? selectedImageDate;

  // 선택된 약 데이터 리스트 (top_k)
  List<Map<String, dynamic>> selectedTopK = [];

  @override
  void initState() {
    super.initState();
    _loadJsonData();
  }

  Future<void> _loadJsonData() async {
    final jsonString = await rootBundle.loadString('assets/ex.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);

    if (jsonData['timeSeries'] == null) {
      print('timeSeries 데이터가 없습니다.');
      return;
    }

    List<Map<String, dynamic>> parsedList = [];
    for (var entry in jsonData['timeSeries']) {
      parsedList.add({
        'date': entry['date'],
        'timestamp': entry['timestamp'],
        'realImage': entry['realImage'],
        'yolo': (entry['yolo'] as num).toDouble(),
        'ocr': (entry['ocr'] as num).toDouble(),
        'color': (entry['color'] as num).toDouble(),
        'top_k': (entry['top_k'] as List).map<Map<String, dynamic>>((item) {
          return {
            'itemName': item['itemName'],
            'imageUrl': item['imageUrl'],
            'finalScore': (item['finalScore'] as num).toDouble(),
            'YOLO': (item['yoloScore'] as num).toDouble(),
            'OCR': (item['ocrScore'] as num).toDouble(),
            'Color': (item['colorScore'] as num).toDouble(),
          };
        }).toList(),
      });
    }
    setState(() {
      pillDataList = parsedList;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
        selectedImageDate = null;
        selectedTopK = [];
      });
    }
  }

  void _selectDate(String timestamp) {
    setState(() {
      selectedImageDate = timestamp;
      final selected = pillDataList.firstWhere((item) => item['timestamp'] == timestamp, orElse: () => {});
      selectedTopK = List<Map<String, dynamic>>.from(selected['top_k'] ?? []);
      selectedTopK.sort((a, b) => (b['finalScore'] as double).compareTo(a['finalScore'] as double));
    });
  }

  Map<String, double> getAverageForDate(String timestamp) {
    final selected = pillDataList.firstWhere((item) => item['timestamp'] == timestamp, orElse: () => {});
    if (selected.isEmpty) return {'YOLO': 0, 'OCR': 0, 'Color': 0};
    return {
      'YOLO': selected['yolo'],
      'OCR': selected['ocr'],
      'Color': selected['color'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 헤더
          Container(
            width: double.infinity,
            height: 120,
            color: const Color.fromARGB(255, 255, 252, 223),
            alignment: Alignment.center,
            child: Text(
              "관리자 대시보드",
              style: TextStyle(fontSize: 28, color: const Color.fromARGB(255, 0, 0, 0), fontWeight: FontWeight.bold),
            ),
          ),

          // 메뉴
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _menuItem('모델 성능 통계', () => setState(() => currentView = 'modelStats')),
                Text('|', style: TextStyle(fontSize: 20)),
                _menuItem('응답 속도 통계', () => setState(() => currentView = 'responseStats')),
                Text('|', style: TextStyle(fontSize: 20)),
                _menuItem('사용자 패턴', () => setState(() => currentView = 'userPattern')),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[300]),

          // 메인 컨텐츠
          Expanded(
            child: Row(
              children: [
                _buildFilterPanel(),
                // 중앙 영역: 날짜별 이미지 + 선택 시 top_k 표시
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: EdgeInsets.all(12),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // 왼쪽: 날짜별 realImage 리스트
                        Expanded(
                          flex: 1,
                          child: ListView(
                            shrinkWrap: true,
                            physics: ClampingScrollPhysics(),
                            children: pillDataList.map((entry) {
                              final date = entry['date'];
                              final timestamp = entry['timestamp'];
                              // 날짜 필터 적용
                              if (selectedDateRange != null) {
                                final dateObj = DateTime.tryParse(date);
                                if (dateObj != null) {
                                  final start = DateTime(selectedDateRange!.start.year,
                                      selectedDateRange!.start.month, selectedDateRange!.start.day);
                                  final end = DateTime(selectedDateRange!.end.year,
                                      selectedDateRange!.end.month, selectedDateRange!.end.day);
                                  if (dateObj.isBefore(start) || dateObj.isAfter(end)) {
                                    return SizedBox.shrink();
                                  }
                                }
                              }
                              return GestureDetector(
                                onTap: () => _selectDate(timestamp),
                                child: Container(
                                  margin: EdgeInsets.only(bottom: 20), // Increased vertical spacing
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selectedImageDate == timestamp ? Colors.blue.shade100 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(date, style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      Image.network(
                                        entry['realImage'] ?? '',
                                        height: 80,
                                        width: 80,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(height: 80, width: 80, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        // Vertical divider and spacing between sections
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: VerticalDivider(
                            color: Colors.grey,
                            width: 32,
                            thickness: 1,
                          ),
                        ),
                        SizedBox(width: 24),
                        // 오른쪽: 선택한 날짜의 top_k 리스트
                        Expanded(
                          flex: 2,
                          child: selectedImageDate == null
                              ? Center(child: Text('날짜를 선택해주세요'))
                              : SingleChildScrollView(
                                  padding: EdgeInsets.all(0),
                                  physics: ClampingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 평균 도넛 + 3줄 퍼센트
                                      Center(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics: ClampingScrollPhysics(),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 260,
                                                height: 260,
                                                // margin removed to prevent clipping and allow full centering
                                                child: _buildPieChart(getAverageForDate(selectedImageDate!)),
                                              ),
                                              SizedBox(width: 32),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'YOLO: ${getAverageForDate(selectedImageDate!)['YOLO']?.toStringAsFixed(1)}%',
                                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    'OCR: ${getAverageForDate(selectedImageDate!)['OCR']?.toStringAsFixed(1)}%',
                                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    'Color: ${getAverageForDate(selectedImageDate!)['Color']?.toStringAsFixed(1)}%',
                                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      // top_k 리스트
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ...selectedTopK.map((item) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  MouseRegion(
                                                    cursor: SystemMouseCursors.click,
                                                    child: _HoverPopup(
                                                      child: Image.network(item['imageUrl'] ?? '', height: 60, width: 60,
                                                          errorBuilder: (context, error, stackTrace) =>
                                                              Container(height: 60, width: 60, color: Colors.grey)),
                                                      popup: Container(
                                                        width: 240,
                                                        height: 240,
                                                        padding: EdgeInsets.all(16),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(color: Colors.grey),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black26,
                                                              blurRadius: 8,
                                                              offset: Offset(2, 4),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Container(
                                                              width: 80,
                                                              height: 80,
                                                              child: _buildPieChart({
                                                                'YOLO': item['YOLO'],
                                                                'OCR': item['OCR'],
                                                                'Color': item['Color'],
                                                              }),
                                                            ),
                                                            SizedBox(height: 16),
                                                            Text(
                                                              'YOLO: ${item['YOLO'].toStringAsFixed(1)}%',
                                                              textAlign: TextAlign.center,
                                                            ),
                                                            Text(
                                                              'OCR: ${item['OCR'].toStringAsFixed(1)}%',
                                                              textAlign: TextAlign.center,
                                                            ),
                                                            Text(
                                                              'Color: ${item['Color'].toStringAsFixed(1)}%',
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(item['itemName'] ?? ''),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    '${(item['finalScore'] * 100).toStringAsFixed(1)}% 정확도',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                                  ),
                                                  SizedBox(height: 12),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(String text, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(text,
          style: TextStyle(fontSize: 18, color: currentView == text ? Colors.blue : Colors.black)),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      width: 200,
      margin: EdgeInsets.all(12),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            onPressed: _pickDateRange,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: Text('날짜 범위 선택'),
          ),
          SizedBox(height: 8),
          Text(
            selectedDateRange == null
                ? '날짜 범위 선택 (예정)'
                : '${selectedDateRange!.start.year}-${selectedDateRange!.start.month.toString().padLeft(2, '0')}-${selectedDateRange!.start.day.toString().padLeft(2, '0')} ~ '
                    '${selectedDateRange!.end.year}-${selectedDateRange!.end.month.toString().padLeft(2, '0')}-${selectedDateRange!.end.day.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 12),
          _buildCalendarPreview(),
        ],
      ),
    );
  }

  Widget _buildCalendarPreview() {
    if (selectedDateRange == null) return SizedBox();
    // Use the month of the selectedDateRange's start
    final DateTime monthDate = selectedDateRange!.start;
    final int year = monthDate.year;
    final int month = monthDate.month;
    // First day of month
    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    // Last day of month
    final DateTime lastDayOfMonth = DateTime(year, month + 1, 0);
    final int totalDays = lastDayOfMonth.day;
    final int firstWeekday = firstDayOfMonth.weekday % 7; // 0: Sun, 1: Mon, ..., 6: Sat

    // Set of selected days for quick lookup
    final DateTime selectedStart = DateTime(selectedDateRange!.start.year, selectedDateRange!.start.month, selectedDateRange!.start.day);
    final DateTime selectedEnd = DateTime(selectedDateRange!.end.year, selectedDateRange!.end.month, selectedDateRange!.end.day);

    // Build list of day numbers, with empty slots for days before the 1st
    List<Widget> dayWidgets = [];
    // Weekday labels
    final List<String> weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    dayWidgets.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekdays
            .map((w) => Expanded(
                  child: Center(
                    child: Text(w, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ),
                ))
            .toList(),
      ),
    );

    // Build grid rows
    List<Widget> rows = [];
    int day = 1;
    while (day <= totalDays) {
      List<Widget> weekRow = [];
      for (int i = 0; i < 7; i++) {
        int cellIndex = (rows.isEmpty ? i : i + rows.length * 7);
        if (rows.isEmpty && i < firstWeekday) {
          // Empty slots before 1st day
          weekRow.add(Expanded(child: Container()));
        } else if (day > totalDays) {
          weekRow.add(Expanded(child: Container()));
        } else {
          final currentDay = DateTime(year, month, day);
          final bool isSelected =
              !currentDay.isBefore(selectedStart) && !currentDay.isAfter(selectedEnd);
          weekRow.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Center(
                  child: isSelected
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                      : Text(
                          '$day',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.normal),
                        ),
                ),
              ),
            ),
          );
          day++;
        }
      }
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekRow,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...dayWidgets,
        ...rows,
      ],
    );
  }

  Widget _buildPieChart(Map<String, double> data) {
    final sections = data.entries.map((entry) {
      Color color;
      switch (entry.key) {
        case 'YOLO':
          color = Colors.blue;
          break;
        case 'OCR':
          color = Colors.orange;
          break;
        case 'Color':
          color = Colors.green;
          break;
        default:
          color = Colors.grey;
      }
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.value.toStringAsFixed(1)}%',
        color: color,
        radius: 40,
        titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 30,
        sectionsSpace: 2,
      ),
    );
  }
}

/// Hover popup
class _HoverPopup extends StatefulWidget {
  final Widget child;
  final Widget popup;
  const _HoverPopup({required this.child, required this.popup});

  @override
  State<_HoverPopup> createState() => _HoverPopupState();
}

class _HoverPopupState extends State<_HoverPopup> {
  OverlayEntry? _entry;

  void _showOverlay(BuildContext context) {
    if (_entry != null) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx + 70,
        top: offset.dy - 10,
        child: Material(
          color: Colors.transparent,
          child: widget.popup,
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showOverlay(context),
      onExit: (_) => _removeOverlay(),
      child: widget.child,
    );
  }
}