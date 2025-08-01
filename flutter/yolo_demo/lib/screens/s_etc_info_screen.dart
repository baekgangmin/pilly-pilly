import 'package:flutter/material.dart';

class SEtcInfoScreen extends StatelessWidget {
  final Map<String, dynamic> permitDetail;

  const SEtcInfoScreen({
    Key? key,
    required this.permitDetail,
  }) : super(key: key);

  /// 값이 null, 빈 문자열, 빈 리스트일 경우 '정보 없음' 처리
  /// 리스트일 경우 줄바꿈으로 변환
  String _safeValue(dynamic value) {
    if (value == null) return '정보 없음';

    if (value is List) {
      if (value.isEmpty) return '정보 없음';
      return value.map((e) => e.toString()).join('\n');
    }

    if (value is String && value.trim().isEmpty) return '정보 없음';

    return value.toString();
  }

  /// 섹션 타이틀
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// 섹션 내용 (Divider 포함)
  Widget _buildSectionContent(String label, dynamic content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(_safeValue(content)),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🔍 [SEtcInfoScreen] permitDetail: $permitDetail");

    return Scaffold(
      appBar: AppBar(
        title: const Text("효능효과/용법용량/사용상의주의사항"),
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 효능 효과 ---
            _buildSectionTitle("효능 효과"),
            const Divider(),
            Text(_safeValue(permitDetail['efficacy'])),

            const SizedBox(height: 16),

            // --- 용법 용량 ---
            _buildSectionTitle("용법 용량"),
            const Divider(),
            Text(_safeValue(permitDetail['dosage'])),

            const SizedBox(height: 16),

            // --- 사용상의 주의사항 ---
            _buildSectionTitle("사용상의 주의사항"),
            const Divider(),

            // 세부 구분: 금기, 경고, 주의사항
            _buildSectionContent("금기 사항", permitDetail['precautions']['contraindications']),
            _buildSectionContent("경고", permitDetail['precautions']['warnings']),
          ],
        ),
      ),
    );
  }
}