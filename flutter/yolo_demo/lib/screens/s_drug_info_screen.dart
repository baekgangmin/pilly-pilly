import 'package:flutter/material.dart';
import 'package:yolo_demo/notifiers/home_button.dart';

class SDrugInfoScreen extends StatelessWidget {
  final Map<String, dynamic> permitDetail;
  final Map<String, dynamic>? permitList;

  const SDrugInfoScreen({
    Key? key,
    required this.permitDetail,
    this.permitList,
  }) : super(key: key);

  String _safeValue(dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return '정보 없음';
    }
    return value.toString();
  }

  String _formatValue(dynamic v) {
    if (v == null) return '정보 없음';
    if (v is List) {
      // 리스트는 점으로 구분해 한 줄 가독성 확보
      return v.where((e) => e != null && e.toString().trim().isNotEmpty)
              .map((e) => e.toString())
              .join(' · ');
    }
    if (v is Map) {
      return v.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' / ');
    }
    final s = v.toString().trim();
    return s.isEmpty ? '정보 없음' : s;
  }

  Widget _buildInfoTile(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(this as BuildContext);
    // NOTE: we can't access context here; switch signature to pass BuildContext
    throw UnimplementedError();
  }

  Widget _buildSection(String title, IconData icon, BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.6)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        titleSpacing: 16,
        title: Text(
          '약제 정보',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onPrimary,
          ),
        ),
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '기본 정보',
              Icons.info_rounded,
              context,
              [
                _buildInfoTile(
                  context,
                  label: '제품명',
                  value: _formatValue(permitDetail['itemName']),
                  icon: Icons.medication_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '영문명',
                  value: _formatValue(permitDetail['engName']),
                  icon: Icons.language_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '제조사',
                  value: _formatValue(permitList?['entpName']),
                  icon: Icons.business_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '허가일',
                  value: _formatValue(permitDetail['permitDate']),
                  icon: Icons.calendar_today_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '제품 유형',
                  value: _formatValue(permitList?['prductType']),
                  icon: Icons.category_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '전문/일반',
                  value: _formatValue(permitList?['specltyPblc']),
                  icon: Icons.medical_services_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            _buildSection(
              '제형 및 보관',
              Icons.inventory_2_rounded,
              context,
              [
                _buildInfoTile(
                  context,
                  label: '성상',
                  value: _formatValue(permitDetail['chart']),
                  icon: Icons.visibility_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '포장 단위',
                  value: _formatValue(permitDetail['packUnit']),
                  icon: Icons.inventory_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '유통기한',
                  value: _formatValue(permitDetail['validTerm']),
                  icon: Icons.schedule_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '보관 방법',
                  value: _formatValue(permitDetail['storageMethod']),
                  icon: Icons.warehouse_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            _buildSection(
              '성분 정보',
              Icons.science_rounded,
              context,
              [
                _buildInfoTile(
                  context,
                  label: '주성분',
                  value: _formatValue(permitDetail['mainIngredient']),
                  icon: Icons.science_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '주성분(영문)',
                  value: _formatValue(permitDetail['mainIngredientEng']),
                  icon: Icons.translate_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '원료/첨가제',
                  value: _formatValue(permitDetail['materialInfo']),
                  icon: Icons.add_circle_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                _buildInfoTile(
                  context,
                  label: '첨가제 목록',
                  value: _formatValue(permitDetail['excipients']),
                  icon: Icons.list_alt_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: const HomeFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}