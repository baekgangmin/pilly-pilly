import 'package:flutter/material.dart';

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

  Widget _buildSummaryCard({
    required String pregnant,
    required String age,
    required String dose,
    required String elderly,
  }) {
    Color _statusColor(String text) {
      if (text == '해당 없음') return Colors.grey;
      if (text == '주의가 필요함') return Colors.orange;
      return Colors.redAccent;
    }

    Widget _item(String label, String value) {
      return Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: TextStyle(color: _statusColor(value)))),
        ],
      );
    }

    return Card(
      color: const Color.fromARGB(255, 255, 253, 240),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _item("임부금기", pregnant),
            const SizedBox(height: 9),
            _item("특정 연령 금기", age),
            const SizedBox(height: 9),
            _item("용량주의", dose),
            const SizedBox(height: 9),
            _item("노인주의", elderly),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    return Card(
      color: const Color.fromARGB(255, 255, 253, 240),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_safeValue(item['typeName']),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            if (item['mixtureItemName'] != null)
              Row(
                children: [
                  const Icon(Icons.medication, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text("금기 약물: ${_safeValue(item['mixtureItemName'])}")),
                ],
              ),
            if (item['mixtureIngredient'] != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.science, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text("성분: ${_safeValue(item['mixtureIngredient'])}")),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: "사유: ",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: _safeValue(item['prohibitContent']),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (item['remark'] != null && item['remark'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text("비고: ${item['remark']}"),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        if (items.isEmpty)
          const Text(
            '정보 없음',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          )
        else
          ...items.map((item) => _buildCard(item)).toList(),
        const SizedBox(height: 16),
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
      appBar: AppBar(
        title: const Text('DUR 품목 정보'),
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
        ),
      body: isAllEmpty
          ? const Center(child: Text("관련 DUR 정보가 없습니다."))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(
                    pregnant: _getSummaryStatus(pregnantList),
                    age: _getSummaryStatus(ageList),
                    dose: _getSummaryStatus(doseList),
                    elderly: _getSummaryStatus(elderlyList),
                  ),
                  _buildSection("병용금기", tabooList),
                ],
              ),
            ),
    );
  }
}