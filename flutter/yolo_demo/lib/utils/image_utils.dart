import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'dart:io' as io;
import 'package:http/http.dart' as http;

/// 크롤링 결과 클래스
class CrawlingResult {
  final bool isSuccess;
  final Duration duration;
  final String? errorType;
  final String? errorMessage;
  final int? statusCode;
  
  CrawlingResult.success(this.duration)
      : isSuccess = true,
        errorType = null,
        errorMessage = null,
        statusCode = null;
        
  CrawlingResult.failure(this.duration, this.errorType, this.errorMessage, this.statusCode)
      : isSuccess = false;
}

/// 크롤링 시도 기록 클래스
class CrawlingAttempt {
  final DateTime timestamp;
  final CrawlingResult result;
  
  CrawlingAttempt({required this.timestamp, required this.result});
}

/// 크롤링 통계 클래스
class CrawlingStats {
  int totalAttempts = 0;
  int successCount = 0;
  Duration totalDuration = Duration.zero;
  DateTime? lastSuccess;
  DateTime? lastFailure;
  
  double get successRate => totalAttempts > 0 ? successCount / totalAttempts : 0.0;
  Duration get averageDuration => totalAttempts > 0 ? 
    Duration(milliseconds: totalDuration.inMilliseconds ~/ totalAttempts) : Duration.zero;
}

/// 크롤링 분석 클래스
class CrawlingAnalytics {
  static final Map<String, List<CrawlingAttempt>> _attempts = {};
  static final Map<String, CrawlingStats> _stats = {};
  
  /// 크롤링 시도 기록
  static void recordAttempt(String itemSeq, CrawlingResult result) {
    if (!_attempts.containsKey(itemSeq)) {
      _attempts[itemSeq] = [];
      _stats[itemSeq] = CrawlingStats();
    }
    
    _attempts[itemSeq]!.add(CrawlingAttempt(
      timestamp: DateTime.now(),
      result: result,
    ));
    
    final stats = _stats[itemSeq]!;
    stats.totalAttempts++;
    stats.successCount += result.isSuccess ? 1 : 0;
    stats.totalDuration += result.duration;
    
    if (result.isSuccess) {
      stats.lastSuccess = DateTime.now();
    } else {
      stats.lastFailure = DateTime.now();
    }
  }
  
  /// 분석 결과 출력
  static void printAnalysis() {
    debugPrint('📊 크롤링 분석 결과');
    debugPrint('=' * 50);
    
    if (_attempts.isEmpty) {
      debugPrint('📝 분석할 크롤링 데이터가 없습니다.');
      return;
    }
    
    for (final entry in _attempts.entries) {
      final itemSeq = entry.key;
      final attempts = entry.value;
      final stats = _stats[itemSeq]!;
      
      debugPrint('약물 $itemSeq:');
      debugPrint('  - 총 시도: ${stats.totalAttempts}');
      debugPrint('  - 성공: ${stats.successCount} (${(stats.successRate * 100).toStringAsFixed(1)}%)');
      debugPrint('  - 실패: ${stats.totalAttempts - stats.successCount} (${((1 - stats.successRate) * 100).toStringAsFixed(1)}%)');
      debugPrint('  - 평균 응답시간: ${stats.averageDuration.inMilliseconds}ms');
      
      if (stats.lastSuccess != null) {
        debugPrint('  - 마지막 성공: ${stats.lastSuccess!.toString().substring(11, 19)}');
      }
      if (stats.lastFailure != null) {
        debugPrint('  - 마지막 실패: ${stats.lastFailure!.toString().substring(11, 19)}');
      }
      
      // 실패 원인 분석
      final failures = attempts.where((a) => !a.result.isSuccess);
      if (failures.isNotEmpty) {
        final failureReasons = <String, int>{};
        
        for (final failure in failures) {
          final reason = failure.result.errorType ?? 'unknown';
          failureReasons[reason] = (failureReasons[reason] ?? 0) + 1;
        }
        
        debugPrint('  - 실패 원인:');
        for (final reason in failureReasons.entries) {
          debugPrint('    * ${reason.key}: ${reason.value}회');
        }
      }
      debugPrint('');
    }
    
    // 전체 통계
    final totalAttempts = _stats.values.fold(0, (sum, stats) => sum + stats.totalAttempts);
    final totalSuccess = _stats.values.fold(0, (sum, stats) => sum + stats.successCount);
    final overallSuccessRate = totalAttempts > 0 ? totalSuccess / totalAttempts : 0.0;
    
    debugPrint('📈 전체 통계:');
    debugPrint('  - 총 시도: $totalAttempts');
    debugPrint('  - 총 성공: $totalSuccess');
    debugPrint('  - 전체 성공률: ${(overallSuccessRate * 100).toStringAsFixed(1)}%');
    debugPrint('=' * 50);
  }
  
  /// 특정 약물의 통계 가져오기
  static CrawlingStats? getStats(String itemSeq) {
    return _stats[itemSeq];
  }
  
  /// 모든 통계 초기화
  static void clearAll() {
    _attempts.clear();
    _stats.clear();
  }
  
  /// 크롤링 분석 실행 (디버그용)
  static void analyzeCrawling() {
    printAnalysis();
  }
  
  /// 특정 약물의 크롤링 통계 가져오기
  static CrawlingStats? getCrawlingStats(String itemSeq) {
    return getStats(itemSeq);
  }
  
  /// 크롤링 성공률이 낮은 약물들 찾기 (성공률 50% 미만)
  static List<String> getLowSuccessRateItems({double threshold = 0.5}) {
    return _stats.entries
        .where((entry) => entry.value.successRate < threshold)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// 크롤링 응답시간이 긴 약물들 찾기 (평균 5초 이상)
  static List<String> getSlowResponseItems({Duration threshold = const Duration(seconds: 5)}) {
    return _stats.entries
        .where((entry) => entry.value.averageDuration > threshold)
        .map((entry) => entry.key)
        .toList();
  }
}

class ImageUtils {
  /// 이미지가 placeholder인지 확인
  static bool isPlaceholder(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return true;
    return imageUrl.contains('placeholder') || 
           imageUrl.contains('no_image') ||
           !imageUrl.startsWith('http');
  }

  /// 이미지 URL을 가져오거나 크롤링하여 가져오기
  static Future<String?> getImageWithCrawling(dynamic pill, {String? itemSeq}) async {
    // 먼저 기존 이미지 URL 확인
    final imageUrl = _extractImageUrl(pill);
    
    // 이미지가 있고 유효한 경우 그대로 반환
    if (!isPlaceholder(imageUrl)) {
      print("✅ 기존 이미지 사용: $imageUrl");
      return imageUrl;
    }

    // 이미지가 없거나 placeholder인 경우에만 크롤링 시도
    print("🔄 이미지 크롤링 필요: 기존 이미지=$imageUrl");
    
    try {
      // itemSeq가 직접 전달되지 않은 경우 pill에서 추출
      String? finalItemSeq = itemSeq;
      if (finalItemSeq == null || finalItemSeq.isEmpty) {
        finalItemSeq = _extractItemSeq(pill);
      }
      
      if (finalItemSeq == null || finalItemSeq.isEmpty) {
        print("⚠️ itemSeq를 찾을 수 없습니다");
        return null;
      }

      print("🖼️ 크롤링 시도: itemSeq=$finalItemSeq");
      
      // 크롤링 시작 시간 기록
      final startTime = DateTime.now();
      
      final crawledImageUrl = await ApiHelper.fetchCrawledImage(finalItemSeq);
      
      // 크롤링 완료 시간 및 소요 시간 계산
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      if (crawledImageUrl != null) {
        print("✅ 크롤링 성공: $crawledImageUrl (소요시간: ${duration.inMilliseconds}ms)");
        
        // 크롤링된 URL의 유효성 검증
        try {
          // 인증 헤더를 포함하여 요청
          final headers = await ApiHelper.getAuthHeaders();
          final response = await http.get(
            Uri.parse(crawledImageUrl),
            headers: headers,
          );
          if (response.statusCode == 200) {
            final contentType = response.headers['content-type'];
            if (contentType?.startsWith('image/') == true) {
              print("✅ 크롤링된 이미지 유효성 확인 성공: $crawledImageUrl");
              
              // 성공 기록
              CrawlingAnalytics.recordAttempt(
                finalItemSeq, 
                CrawlingResult.success(duration)
              );
              
              return crawledImageUrl;
            } else {
              print("⚠️ 크롤링된 URL이 이미지가 아님: $contentType");
              
              // 실패 기록 (잘못된 콘텐츠 타입)
              CrawlingAnalytics.recordAttempt(
                finalItemSeq, 
                CrawlingResult.failure(duration, 'invalid_content_type', '이미지가 아닌 콘텐츠', response.statusCode)
              );
            }
          } else if (response.statusCode == 504) {
            print("⚠️ 크롤링된 URL 타임아웃 (504): 백엔드 서버 응답 없음 - 크롤링 서버 상태 확인 필요");
            
            // 실패 기록 (타임아웃)
            CrawlingAnalytics.recordAttempt(
              finalItemSeq, 
              CrawlingResult.failure(duration, 'timeout', '백엔드 서버 응답 없음', response.statusCode)
            );
          } else {
            print("⚠️ 크롤링된 URL 접근 실패: ${response.statusCode}");
            
            // 실패 기록 (HTTP 오류)
            CrawlingAnalytics.recordAttempt(
              finalItemSeq, 
              CrawlingResult.failure(duration, 'http_error', 'HTTP ${response.statusCode} 오류', response.statusCode)
            );
          }
        } catch (e) {
          print("⚠️ 크롤링된 URL 유효성 검증 실패: $e");
          
          // 실패 기록 (네트워크 오류)
          CrawlingAnalytics.recordAttempt(
            finalItemSeq, 
            CrawlingResult.failure(duration, 'network_error', '네트워크 오류: $e', null)
          );
        }
        
        // 크롤링된 URL이 유효하지 않으면 null 반환
        return null;
      } else {
        print("❌ 크롤링 실패 (소요시간: ${duration.inMilliseconds}ms)");
        
        // 실패 기록 (크롤링 실패)
        CrawlingAnalytics.recordAttempt(
          finalItemSeq, 
          CrawlingResult.failure(duration, 'crawling_failed', '백엔드 크롤링 실패', null)
        );
        
        return null;
      }
    } catch (e) {
      print("❌ 크롤링 중 오류 발생: $e");
      
      // 예외 발생 시에도 기록 (예외 오류)
      if (itemSeq != null || _extractItemSeq(pill) != null) {
        final finalItemSeq = itemSeq ?? _extractItemSeq(pill);
        CrawlingAnalytics.recordAttempt(
          finalItemSeq!, 
          CrawlingResult.failure(Duration.zero, 'exception', '예외 발생: $e', null)
        );
      }
      
      return null;
    }
  }

  /// pill 데이터에서 이미지 URL 추출
  static String? _extractImageUrl(dynamic pill) {
    try {
      // top 10 데이터인 경우
      if (pill is Map<String, dynamic>) {
        // samples 배열에서 imageUrl 찾기
        if (pill['samples'] != null && pill['samples'] is List) {
          final samples = pill['samples'] as List;
          if (samples.isNotEmpty) {
            final firstSample = samples.first;
            if (firstSample is Map<String, dynamic>) {
              final imageUrl = firstSample['imageUrl'];
              if (imageUrl is String && imageUrl.isNotEmpty) {
                return imageUrl;
              }
            }
          }
        }
        
        // 직접 imageUrl 찾기
        final v = pill['imageUrl'] ?? pill['image'];
        if (v is String && v.isNotEmpty) {
          return v;
        }
      }
      // 최근검색 데이터인 경우
      else {
        final v = (pill as dynamic).imageUrl;
        if (v is String && v.isNotEmpty) {
          return v;
        }
      }
    } catch (_) {}
    return null;
  }

  /// pill 데이터에서 itemSeq 추출
  static String? _extractItemSeq(dynamic pill) {
    try {
      // top 10 데이터인 경우
      if (pill is Map<String, dynamic>) {
        // samples 배열에서 itemSeq 찾기
        if (pill['samples'] != null && pill['samples'] is List) {
          final samples = pill['samples'] as List;
          if (samples.isNotEmpty) {
            final firstSample = samples.first;
            if (firstSample is Map<String, dynamic>) {
              final itemSeq = firstSample['itemSeq']?.toString();
              if (itemSeq != null && itemSeq.isNotEmpty) {
                return itemSeq;
              }
            }
          }
        }
        
        // 직접 itemSeq 찾기
        final v = pill['itemSeq'];
        if (v != null && v.toString().isNotEmpty) {
          return v.toString();
        }
      }
      // 최근검색 데이터인 경우
      else {
        final v = (pill as dynamic).itemSeq;
        if (v != null && v.toString().isNotEmpty) {
          return v.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  /// 이미지 URL을 처리하여 최종 URL 반환
  static String? processImageUrl(String? imageUrl) {
    if (isPlaceholder(imageUrl)) return null;
    return imageUrl;
  }

  /// 캐시된 네트워크 이미지 위젯 생성
  static Widget cachedNetworkImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (isPlaceholder(imageUrl)) {
      return errorWidget ?? 
             Container(
               width: width,
               height: height,
               color: Colors.grey.shade100,
               child: Icon(
                 Icons.medication,
                 size: 24,
                 color: Colors.grey.shade400,
               ),
             );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder != null ? (context, url) => placeholder : null,
      errorWidget: errorWidget != null ? (context, url, error) => errorWidget : null,
    );
  }
  
  /// 크롤링 분석 실행
  static void analyzeCrawling() {
    CrawlingAnalytics.analyzeCrawling();
  }
  
  /// 크롤링 통계 초기화
  static void clearCrawlingStats() {
    CrawlingAnalytics.clearAll();
  }
  
  /// 특정 약물의 크롤링 통계 가져오기
  static CrawlingStats? getCrawlingStats(String itemSeq) {
    return CrawlingAnalytics.getCrawlingStats(itemSeq);
  }
}
