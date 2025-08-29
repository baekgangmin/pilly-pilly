import 'package:flutter/material.dart';
import 'package:yolo_demo/notifiers/home_button.dart';

class SDurInfoScreen extends StatelessWidget {
  final Map<String, dynamic> durData;

  const SDurInfoScreen({Key? key, required this.durData}) : super(key: key);

  String _safeValue(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return '정보 없음';
    }
    return value.toString();
  }

  String _getSummaryStatus(List<dynamic> items) {
    if (items.isEmpty) {
      return '해당 없음';
    }
    final prohibitContents = items
        .map((item) => item['prohibitContent'])
        .where((content) => content != null && content.toString().trim().isNotEmpty)
        .toList();
    if (prohibitContents.isEmpty) {
      return '주의가 필요함';
    }
    return prohibitContents.first.toString();
  }

  Color _getStatusColor(String text) {
    if (text == '해당 없음') return Colors.grey.shade400;
    if (text == '주의가 필요함') return Colors.orange.shade600;
    return Colors.red.shade500;
  }

  IconData _getStatusIcon(String text) {
    if (text == '해당 없음') return Icons.check_circle_outline;
    if (text == '주의가 필요함') return Icons.warning_amber_rounded;
    return Icons.error_outline;
  }

  Widget _buildSummaryCard({
    required String pregnant,
    required String age,
    required String dose,
    required String elderly,
    required BuildContext context,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color.fromARGB(255, 255, 253, 240),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'DUR 요약 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusItem("임부금기", pregnant),
            const SizedBox(height: 16),
            _buildStatusItem("특정 연령 금기", age),
            const SizedBox(height: 16),
            _buildStatusItem("용량주의", dose),
            const SizedBox(height: 16),
            _buildStatusItem("노인주의", elderly),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    final color = _getStatusColor(value);
    final icon = _getStatusIcon(value);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _safeValue(item['typeName']),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (item['mixtureItemName'] != null) ...[
              _buildInfoRow(
                Icons.medication_outlined,
                "금기 약물",
                _safeValue(item['mixtureItemName']),
                Colors.red.shade600,
              ),
              const SizedBox(height: 12),
            ],
            
            if (item['mixtureIngredient'] != null) ...[
              _buildInfoRow(
                Icons.science_outlined,
                "성분",
                _safeValue(item['mixtureIngredient']),
                Colors.blue.shade600,
              ),
              const SizedBox(height: 12),
            ],
            
            _buildInfoRow(
              Icons.warning_amber_rounded,
              "사유",
              _safeValue(item['prohibitContent']),
              Colors.red.shade600,
            ),
            
            if (item['remark'] != null && item['remark'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.info_outline,
                "비고",
                item['remark'].toString(),
                Colors.grey.shade600,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  '관련 정보가 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...items.map((item) => _buildCard(item, context)).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabooList = durData['getUsjntTabooInfoList03'] ?? [];
    final pregnantList = durData['getPwnmTabooInfoList03'] ?? [];
    final ageList = durData['getSpcifyAgrdeTabooInfoList03'] ?? [];
    final doseList = durData['getCpctyAtentInfoList03'] ?? [];
    final elderlyList = durData['getOdsnAtentInfoList03'] ?? [];

    final isAllEmpty = [tabooList, pregnantList, ageList, doseList, elderlyList]
        .every((list) => list.isEmpty);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('DUR 품목 정보'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: isAllEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "관련 DUR 정보가 없습니다",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(
                    pregnant: _getSummaryStatus(pregnantList),
                    age: _getSummaryStatus(ageList),
                    dose: _getSummaryStatus(doseList),
                    elderly: _getSummaryStatus(elderlyList),
                    context: context,
                  ),
                  _buildSection("병용금기", tabooList, context),
                ],
              ),
            ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}