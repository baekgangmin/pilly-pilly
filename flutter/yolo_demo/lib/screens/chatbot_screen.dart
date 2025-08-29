import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:yolo_demo/notifiers/typing_bubble.dart';
import 'package:yolo_demo/notifiers/home_button.dart';
import 'package:path_provider/path_provider.dart';

class ChatBotScreen extends StatefulWidget {
  final String itemName;
  final Map<String, dynamic> resultData;

  const ChatBotScreen({
    Key? key,
    required this.itemName,
    required this.resultData,
  }) : super(key: key);

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, dynamic>> messages = []; // ttsFile, ttsStatus 추가
  TextEditingController inputController = TextEditingController();
  bool _isBotTyping = false;
  bool _canSend = false;

  late Map<String, dynamic> drugData;
  String? imageUrl;
  
  // TTS 상태 관리
  final Map<String, bool> _ttsReady = {};   // messageId -> TTS 준비 상태
  final Map<String, String> _ttsFiles = {}; // messageId -> TTS 파일명
  final Map<String, String> _localTtsFiles = {}; // messageId -> 로컬 파일 경로
  final Map<String, bool> _ttsPlaying = {}; // messageId -> 재생 상태
  String? _currentPlayingId; // 현재 재생 중인 메시지 ID

  /// TTS 재생/정지 토글 함수
  Future<void> _toggleTTS(String messageId) async {
    if (!(_ttsReady[messageId] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TTS가 아직 준비되지 않았습니다')),
      );
      return;
    }

    // 현재 이 메시지가 재생 중이면 정지
    if (_currentPlayingId == messageId) {
      await _audioPlayer.stop();
      setState(() {
        _ttsPlaying[messageId] = false;
        _currentPlayingId = null;
      });
      debugPrint('⏹️ TTS 정지: $messageId');
      return;
    }
    
    // 다른 TTS가 재생 중이면 정지
    if (_currentPlayingId != null) {
      await _audioPlayer.stop();
      setState(() {
        if (_currentPlayingId != null) {
          _ttsPlaying[_currentPlayingId!] = false;
        }
        _currentPlayingId = null;
      });
      debugPrint('⏹️ 다른 TTS 정지: $_currentPlayingId');
    }

    // TTS 재생 시작
    await _playTTSFile(messageId);
  }

  /// TTS 파일 재생 함수
  Future<void> _playTTSFile(String messageId) async {
    final ttsFile = _ttsFiles[messageId];
    if (ttsFile == null || ttsFile.isEmpty) {
      debugPrint('⚠️ TTS 파일명이 비어있음: $messageId');
      return;
    }

    try {
      // 1. 로컬 파일이 있으면 로컬에서 재생
      if (_localTtsFiles.containsKey(messageId)) {
        final localPath = _localTtsFiles[messageId]!;
        debugPrint('🎵 로컬 TTS 파일 재생: $localPath');
        
        try {
          await _startTTSPlayback(messageId, localPath);
          return;
        } catch (localError) {
          debugPrint('⚠️ 로컬 재생 실패: $localError');
          // 로컬 파일 삭제 후 다시 다운로드
          _localTtsFiles.remove(messageId);
        }
      }

      // 2. 로컬 파일이 없으면 다운로드 후 재생
      debugPrint('📥 TTS 파일 다운로드 시작: $ttsFile');
      final localPath = await _downloadTTSFile(messageId, ttsFile);
      
      if (localPath != null) {
        _localTtsFiles[messageId] = localPath;
        await _startTTSPlayback(messageId, localPath);
      } else {
        throw Exception('TTS 파일 다운로드 실패');
      }
      
    } catch (e) {
      debugPrint('❌ TTS 재생 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('TTS 재생 실패: ${e.toString().split('.').first}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// TTS 재생 시작 및 상태 관리
  Future<void> _startTTSPlayback(String messageId, String localPath) async {
    await _audioPlayer.play(DeviceFileSource(localPath));
    
    setState(() {
      _currentPlayingId = messageId;
      _ttsPlaying[messageId] = true;
    });
    
    debugPrint('✅ TTS 재생 시작: $messageId');
  }

  /// TTS 파일 다운로드
  Future<String?> _downloadTTSFile(String messageId, String ttsFile) async {
    try {
      final baseUrl = dotenv.env['TTS_BASE_URL'] ?? '';
      if (baseUrl.isEmpty) {
        debugPrint('⚠️ TTS_BASE_URL이 설정되지 않음');
        return null;
      }

      final downloadUrl = '$baseUrl/tts_stream?name=$ttsFile';
      debugPrint('📥 다운로드 URL: $downloadUrl');

      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        // 임시 디렉토리에 파일 저장
        final tempDir = await getTemporaryDirectory();
        final fileName = 'tts_$messageId.wav';
        final filePath = '${tempDir.path}/$fileName';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        debugPrint('✅ TTS 파일 다운로드 완료: $filePath');
        return filePath;
      } else {
        debugPrint('❌ TTS 파일 다운로드 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ TTS 파일 다운로드 오류: $e');
      return null;
    }
  }

  /// TTS 생성 요청 함수
  Future<void> _requestTTS(String text, String messageId) async {
    try {
      debugPrint('🎵 TTS 생성 요청 시작: $messageId');
      debugPrint('  - 텍스트: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}');
      
      final ttsBaseUrl = dotenv.env['TTS_BASE_URL'] ?? '';
      if (ttsBaseUrl.isEmpty) {
        debugPrint('❌ TTS_BASE_URL이 설정되지 않음');
        return;
      }
      
      final ttsUrl = Uri.parse('$ttsBaseUrl/tts');
      debugPrint('  - TTS URL: $ttsUrl');
      
      final response = await http.post(
        ttsUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      ).timeout(const Duration(seconds: 30)); // 30초 타임아웃

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final ttsFile = responseBody['filename'];
        
        debugPrint('  - 응답: $responseBody');
        
        if (ttsFile != null && ttsFile.isNotEmpty) {
          setState(() {
            _ttsFiles[messageId] = ttsFile;  // 파일명 맵에 저장
            _ttsReady[messageId] = true;     // 준비 상태
          });
          debugPrint('✅ TTS 준비 완료: $messageId -> $ttsFile');
        } else {
          debugPrint('⚠️ TTS 파일명이 비어있음: $responseBody');
          setState(() {
            _ttsReady[messageId] = false;
          });
        }
      } else {
        debugPrint('❌ TTS 생성 실패: ${response.statusCode} - ${response.body}');
        setState(() {
          _ttsReady[messageId] = false;
        });
      }
    } catch (e) {
      debugPrint('❌ TTS 생성 요청 실패: $e');
      // TTS 생성 실패 시에도 UI는 계속 사용 가능하도록
      setState(() {
        _ttsReady[messageId] = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    final results = Map<String, dynamic>.from(widget.resultData['results'] ?? {});

    if (results.isNotEmpty) {
      final firstKey = results.keys.first;
      final data = results[firstKey];

      drugData = {firstKey: data};
      imageUrl = data['permit']?['permitList']?['imageUrl'];
    } else {
      drugData = {};
      imageUrl = null;
    }

    // 오디오 플레이어 초기화
    _initAudioPlayer();

    final welcomeMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    messages.add({
      'id': welcomeMessageId,
      'sender': 'bot',
      'text': '${widget.itemName}에 대해 궁금한 것을 질문해주세요!',
      'timestamp': DateTime.now(),
    });
    
    // 환영 메시지에 대해 TTS 요청
    _requestTTS('${widget.itemName}에 대해 궁금한 것을 질문해주세요!', welcomeMessageId);

    // 입력 변화 감지
    inputController.addListener(() {
      final hasText = inputController.text.trim().isNotEmpty;
      if (_canSend == hasText) {
        setState(() {
        _canSend = hasText;
        });
      }
    });
  }

  /// 오디오 플레이어 초기화
  Future<void> _initAudioPlayer() async {
    try {
      // 오디오 플레이어 설정 (1회 재생)
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setPlaybackRate(1.0);
      debugPrint('✅ 오디오 플레이어 초기화 완료');
      
      // 재생 완료 리스너 설정
      _audioPlayer.onPlayerComplete.listen((event) {
        if (_currentPlayingId != null) {
          setState(() {
            _ttsPlaying[_currentPlayingId!] = false;
            _currentPlayingId = null;
          });
          debugPrint('🏁 TTS 재생 완료');
        }
      });
    } catch (e) {
      debugPrint('⚠️ 오디오 플레이어 초기화 실패: $e');
    }
  }

  /// 챗봇 질문 보내기
  void handleSendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    final userMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      messages.add({
        'id': userMessageId,
        'sender': 'user', 
        'text': text,
        'timestamp': DateTime.now(),
      });
      _isBotTyping = true;
    });

    inputController.clear();

    try {
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final headers = await ApiHelper.getAuthHeaders();
      final url = Uri.parse('$baseUrl/api/v2/chatbot');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode({
          'drug_info': {'results': drugData},
          'user_input': text,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final answerText = decoded['answer'] ?? '답변을 받을 수 없어요.';

        final botMessageId = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          messages.add({
            'id': botMessageId,
            'sender': 'bot',
            'text': answerText,
            'timestamp': DateTime.now(),
          });
        });

        // 봇 응답과 동시에 TTS 요청 (비동기)
        _requestTTS(answerText, botMessageId);
      } else {
        final errorMessageId = DateTime.now().millisecondsSinceEpoch.toString();
        setState(() {
          messages.add({
            'id': errorMessageId,
            'sender': 'bot',
            'text': '서버에서 응답을 받지 못했어요.',
            'timestamp': DateTime.now(),
          });
        });
      }
    } catch (e) {
      final errorMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        messages.add({
          'id': errorMessageId,
          'sender': 'bot',
          'text': '오류가 발생했어요: $e',
          'timestamp': DateTime.now(),
        });
      });
    } finally {
      if (mounted) setState(() => _isBotTyping = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    
    // 로컬 TTS 파일들 정리
    _cleanupLocalTtsFiles();
    
    super.dispose();
  }

  /// 로컬 TTS 파일들 정리
  Future<void> _cleanupLocalTtsFiles() async {
    try {
      for (final filePath in _localTtsFiles.values) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ 로컬 TTS 파일 삭제: $filePath');
        }
      }
      _localTtsFiles.clear();
    } catch (e) {
      debugPrint('⚠️ 로컬 파일 정리 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Pilly에게 물어봐!',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        bottom: _isBotTyping
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // 상단 약 정보 카드 (그라데이션 + 그림자)
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // 약물 이미지 (원형 + 그림자)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: imageUrl != null && imageUrl!.isNotEmpty
                          ? Image.network(
                              imageUrl!,
                              height: 64,
                              width: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 64,
                                width: 64,
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.medication_rounded,
                                  size: 32,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : Container(
                              height: 64,
                              width: 64,
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.medication_rounded,
                                size: 32,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // 약물 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '현재 약물',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.itemName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: theme.colorScheme.onSurface,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 메시지 리스트
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16, keyboardOpen ? 16 : 100),
              itemCount: messages.length + (_isBotTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // 마지막 인덱스가 typing bubble이면
                if (_isBotTyping && index == messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        // 봇 아바타
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.smart_toy_rounded,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 타이핑 버블
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.outline.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const TypingBubble(),
                        ),
                      ],
                    ),
                  );
                }

                final msg = messages[index];
                final isUser = msg['sender'] == 'user';
                final messageId = msg['id'] as String?;
                final isTTSReady = messageId != null && (_ttsReady[messageId] ?? false);
                final ttsFile = messageId != null ? _ttsFiles[messageId] : null;
                final isPlaying = messageId != null && (_ttsPlaying[messageId] ?? false);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isUser) ...[
                        // 봇 아바타
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.smart_toy_rounded,
                            size: 18,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      
                      // 메시지 버블
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUser 
                                ? theme.colorScheme.primary 
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isUser ? 20 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isUser ? theme.colorScheme.primary : theme.colorScheme.outline)
                                    .withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                // 봇 메시지 내용
                                MarkdownBody(
                                  data: msg['text'] ?? '',
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      fontSize: 15,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                    strong: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // TTS 버튼 (봇 메시지만)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        !isTTSReady 
                                            ? Icons.volume_off
                                            : isPlaying 
                                                ? Icons.stop_rounded
                                                : Icons.play_arrow_rounded,
                                        size: 20,
                                        color: isTTSReady 
                                            ? (isPlaying 
                                                ? Colors.red 
                                                : theme.colorScheme.primary)
                                            : theme.colorScheme.onSurface.withOpacity(0.4),
                                      ),
                                      onPressed: isTTSReady 
                                          ? () => _toggleTTS(messageId!)
                                          : null,
                                      style: IconButton.styleFrom(
                                        backgroundColor: isTTSReady 
                                            ? (isPlaying 
                                                ? Colors.red.withOpacity(0.1)
                                                : theme.colorScheme.primary.withOpacity(0.1))
                                            : Colors.transparent,
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                    if (!isTTSReady) ...[
                                      const SizedBox(width: 4),
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.primary.withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ],

                                  ],
                                ),
                              ] else ...[
                                // 사용자 메시지 내용
                                Text(
                                  msg['text'] ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      if (isUser) ...[
                        const SizedBox(width: 12),
                        // 사용자 아바타
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 18,
                            color: theme.colorScheme.onSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

                    // 입력창 (그라데이션 + 그림자)
          SafeArea(
            bottom: true,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surface.withOpacity(0.95),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // 입력 필드
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: inputController,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (value) {
                          final hasText = value.trim().isNotEmpty;
                          if (_canSend != hasText) {
                            setState(() => _canSend = hasText);
                          }
                        },
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (_canSend && !_isBotTyping) {
                            handleSendMessage();
                          }
                        },
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Pilly에게 궁금한 것을 물어보세요...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 전송 버튼
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _canSend && !_isBotTyping
                            ? [theme.colorScheme.primary, theme.colorScheme.secondary]
                            : [theme.colorScheme.outline.withOpacity(0.3), theme.colorScheme.outline.withOpacity(0.3)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _canSend && !_isBotTyping
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: _canSend && !_isBotTyping
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      iconSize: 24,
                      onPressed: (_canSend && !_isBotTyping)
                          ? handleSendMessage
                          : null,
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: keyboardOpen
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 120), // 입력창과 겹치지 않도록 더 위로
              child: const HomeFab(),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}