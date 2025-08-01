import 'package:flutter/material.dart';

class SDrugInfoScreen extends StatelessWidget {
  final Map<String, dynamic> permitDetail; // 약 상세 정보
  final Map<String, dynamic>? permitList;  // 약 리스트 정보 (옵션)

  const SDrugInfoScreen({
    Key? key,
    required this.permitDetail,
    this.permitList,
  }) : super(key: key);

  /// 값이 null이거나 빈 문자열이면 '정보 없음'으로 표시
  String _safeValue(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return '정보 없음';
    }
    return value.toString();
  }

  /// 라벨 + 값 UI Row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("🔍 [SDrugInfoScreen] permitDetail: $permitDetail");
    print("🔍 [SDrugInfoScreen] permitList: $permitList");
    return Scaffold(
      appBar: AppBar(
        title: const Text("약제 정보"),
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 기본 정보 섹션 ---
            const Text(
              "기본 정보",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow("제품명", _safeValue(permitDetail['itemName'])),
            _buildInfoRow("영문명", _safeValue(permitDetail['engName'])),
            _buildInfoRow("제조사", _safeValue(permitList?['entpName'])),
            _buildInfoRow("허가일", _safeValue(permitDetail['permitDate'])),
            _buildInfoRow("제품 유형", _safeValue(permitList?['prductType'])),
            _buildInfoRow("전문/일반", _safeValue(permitList?['specltyPblc'])),

            const SizedBox(height: 16),

            // --- 제형/보관 섹션 ---
            const Text(
              "제형 및 보관",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow("성상", _safeValue(permitDetail['chart'])),
            _buildInfoRow("포장 단위", _safeValue(permitDetail['packUnit'])),
            _buildInfoRow("유통기한", _safeValue(permitDetail['validTerm'])),
            _buildInfoRow("보관 방법", _safeValue(permitDetail['storageMethod'])),

            const SizedBox(height: 16),

            // --- 성분 섹션 ---
            const Text(
              "성분 정보",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow("주성분", _safeValue(permitDetail['mainIngredient'])),
            _buildInfoRow("주성분(영문)", _safeValue(permitDetail['mainIngredientEng'])),
            _buildInfoRow("원료/첨가제", _safeValue(permitDetail['materialInfo'])),
            _buildInfoRow("첨가제 목록", _safeValue(permitDetail['excipients'])),
          ],
        ),
      ),
    );
  }
}