import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:yolo_demo/api_services/api_helper.dart';

class MedicationFolderPDFGenerator {
  static bool _needsAuthHeader(String? url) {
    if (url == null) return false;
    // our backend proxy path that requires Authorization header
    return url.contains('/image-scrape');
  }

  static String _normalizeImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasQuery) return url;
      final qp = Map<String, String>.from(uri.queryParameters);
      qp.remove('token'); // 쿼리 토큰 제거
      final normalized = uri.replace(queryParameters: qp);
      return normalized.toString();
    } catch (_) {
      return url; // 파싱 실패 시 원본 유지
    }
  }

  static Future<Uint8List?> _fetchImageBytes(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      // 1) URL 정규화: 쿼리의 token 제거
      final normalizedUrl = _normalizeImageUrl(url);
      final uri = Uri.parse(normalizedUrl);

      // 2) 헤더 구성: /image-scrape일 경우 Authorization 포함
      final headers = <String, String>{};
      if (_needsAuthHeader(normalizedUrl)) {
        final auth = await ApiHelper.getAuthHeaders();
        if (auth != null) {
          headers.addAll(auth);
        }
      }

      // 3) 요청 (PDF 생성은 동기 렌더이므로 타임아웃 유지)
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        return res.bodyBytes;
      }
      debugPrint('⚠️ [PDF] image GET ${res.statusCode} for $normalizedUrl');
      return null;
    } catch (e) {
      debugPrint('❌ [PDF] image fetch failed for $url: $e');
      return null;
    }
  }
  /// 복약이력 폴더 PDF 생성
  static Future<File> generateFolderPDF({
    required String folderName,
    String? folderDescription,
    required List<Map<String, dynamic>> medications,
  }) async {
    // 한글 지원 폰트(NotoSansKR) 임베드
    final fontRegular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
    final fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
    pw.Font? fontItalic;
    try {
      fontItalic = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKR-Italic.ttf'));
    } catch (_) {
      fontItalic = null; // Italic 없는 경우에도 동작
    }
    final koreanFont = fontRegular;
    debugPrint('✅ PDF 내장 폰트: NotoSansKR Regular/Bold (and Italic if present)');

    // 사전 이미지 로딩 (동기 렌더를 위해 바이트 캐시를 준비)
    final List<Map<String, dynamic>> medsWithImages = [];
    for (final med in medications) {
      final imageUrl = (med['image_url'] ?? med['imageUrl'] ?? med['ITEM_IMAGE']) as String?;
      Uint8List? bytes;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        bytes = await _fetchImageBytes(imageUrl);
      }
      medsWithImages.add({
        ...med,
        '_image_bytes': bytes, // Uint8List? or null
      });
    }

    // 문서 전역 테마에 폰트 적용
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic ?? fontRegular,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 헤더 섹션
              _buildHeader(folderName, folderDescription, koreanFont),
              pw.SizedBox(height: 30),

              // 약물 목록 테이블
              if (medsWithImages.isNotEmpty) ...[
                _buildMedicationsTable(medsWithImages, koreanFont),
                pw.SizedBox(height: 20),
              ],

              // 출력 정보
              _buildFooter(koreanFont),
            ],
          );
        },
      ),
    );
    
    // PDF 파일 저장
    final output = await getTemporaryDirectory();
    final fileName = '복약이력_${folderName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }      
  
  /// 헤더 섹션 생성
  static pw.Widget _buildHeader(String folderName, String? folderDescription, pw.Font? koreanFont) {
    return pw.Container(
      padding: pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [PdfColors.blue50, PdfColors.indigo50],
        ),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColors.blue200, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 아이콘과 제목
          pw.Row(
            children: [
              pw.Container(
                width: 48,
                height: 48,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue100,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'MED',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '복약이력 관리',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.normal,
                        color: PdfColors.blue600,
                        font: koreanFont,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      folderName,
                      style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        font: koreanFont,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          
          // 폴더 설명
          if (folderDescription != null && folderDescription.isNotEmpty) ...[
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.blue200, width: 1),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'i',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue600,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      folderDescription,
                      style: pw.TextStyle(
                        fontSize: 15,
                        color: PdfColors.blue800,
                        font: koreanFont,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'i',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '폴더 설명이 없습니다',
                    style: pw.TextStyle(
                      fontSize: 15,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                      font: koreanFont,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 약물 목록 테이블 생성
  static pw.Widget _buildMedicationsTable(List<Map<String, dynamic>> medications, pw.Font? koreanFont) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
        borderRadius: pw.BorderRadius.circular(16),

      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 테이블 헤더
          pw.Container(
            padding: pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: [PdfColors.grey50, PdfColors.grey100],
              ),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(16),
                topRight: pw.Radius.circular(16),
              ),
              border: pw.Border.all(color: PdfColors.grey200, width: 1),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 40,
                  height: 40,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'MED',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '저장된 약물 목록',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                          font: koreanFont,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '총 ${medications.length}개의 약물이 저장되어 있습니다',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey600,
                          font: koreanFont,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 테이블 내용
          pw.Table(
            border: pw.TableBorder(
              left: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              right: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              horizontalInside: pw.BorderSide(color: PdfColors.grey100, width: 0.5),
              verticalInside: pw.BorderSide(color: PdfColors.grey100, width: 0.5),
            ),
            columnWidths: {
              0: pw.FlexColumnWidth(1.0), // 이미지
              1: pw.FlexColumnWidth(2.8), // 이름
              2: pw.FlexColumnWidth(2.2), // 제조사
              3: pw.FlexColumnWidth(1.5), // 추가일자
            },
            children: [
              // 테이블 헤더 행
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.blue200, width: 1),
                  ),
                ),
                children: [
                  _buildTableCell('이미지', isHeader: true, koreanFont: koreanFont),
                  _buildTableCell('약물명', isHeader: true, koreanFont: koreanFont),
                  _buildTableCell('제조사', isHeader: true, koreanFont: koreanFont),
                  _buildTableCell('추가일자', isHeader: true, koreanFont: koreanFont),
                ],
              ),
              
              // 약물 데이터 행들
              ...medications.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                final isEven = index % 2 == 0;
                
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : PdfColors.grey50,
                  ),
                  children: [
                    _buildImageCell(med['_image_bytes'] as Uint8List?),
                    _buildTableCell((med['item_name'] ?? med['itemName'] ?? '이름 없음').toString(), koreanFont: koreanFont),
                    _buildTableCell((med['entp_name'] ?? med['entpName'] ?? '제조사 정보 없음').toString(), koreanFont: koreanFont),
                    _buildTableCell(_formatDate(med['timestamp'] ?? med['createdAt']), koreanFont: koreanFont),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
  
  /// 테이블 셀 생성
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.Font? koreanFont}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blue800 : PdfColors.grey700,
          font: koreanFont,
        ),

      ),
    );
  }
  
  /// 이미지 셀 생성 (바이트가 있으면 실제 이미지, 없으면 아이콘)
  static pw.Widget _buildImageCell(Uint8List? bytes) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      alignment: pw.Alignment.center,
      child: pw.Container(
        width: 50,
        height: 50,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColors.grey200, width: 1),
        ),
        child: (bytes != null && bytes.isNotEmpty)
            ? pw.ClipRRect(
                horizontalRadius: 12,
                verticalRadius: 12,
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  width: 50,
                  height: 50,
                  fit: pw.BoxFit.cover,
                ),
              )
            : pw.Center(
                child: pw.Text(
                  'MED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
      ),
    );
  }
  
  /// 날짜 포맷팅
  static String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '날짜 없음';
    
    try {
      if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } else if (timestamp is DateTime) {
        return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '날짜 오류';
    }
    
    return '날짜 없음';
  }
  
  /// 푸터 섹션 생성
  static pw.Widget _buildFooter(pw.Font? koreanFont) {
    final now = DateTime.now();
    final formattedDate = '${now.year}년 ${now.month}월 ${now.day}일';
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    return pw.Container(
      margin: pw.EdgeInsets.only(top: 30),
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [PdfColors.grey50, PdfColors.grey100],
        ),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        children: [
          // 구분선
          pw.Container(
            height: 1,
            color: PdfColors.grey300,
          ),
          pw.SizedBox(height: 16),
          
          // 정보 행
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'DATE',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue600,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '출력일자: $formattedDate',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                      font: koreanFont,
                    ),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'TIME',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue600,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    '출력시간: $formattedTime',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                      font: koreanFont,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 12),
          
          // 앱 정보
          pw.Center(
            child: pw.Text(
              'Pilly - 복약이력 관리 시스템',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
                font: koreanFont,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
