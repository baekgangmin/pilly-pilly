import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:yolo_demo/api_services/api_helper.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';

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
  List<Map<String, String>> messages = [];
  TextEditingController inputController = TextEditingController();

  late Map<String, dynamic> drugData;
  String? imageUrl;

  /// TTS API 호출 및 재생
  Future<void> _playTTS(String text) async {
    try {
      final baseUrl = dotenv.env['TTS_BASE_URL'] ?? '';
      final ttsUrl = Uri.parse('$baseUrl/tts');

      // 1. TTS 요청
      final ttsResponse = await http.post(
        ttsUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      );

      if (ttsResponse.statusCode == 200) {
        final filename = jsonDecode(ttsResponse.body)['filename'];

        // 2. 스트리밍 URL
        final streamUrl = '$baseUrl/tts_stream?name=$filename';

        // 3. 재생
        await _audioPlayer.play(UrlSource(streamUrl));
      } else {
        print('❌ TTS 요청 실패: ${ttsResponse.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TTS 생성 실패')),
        );
      }
    } catch (e) {
      print('❌ TTS 오류: $e');
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

    messages.add({
      'sender': 'bot',
      'text': '${widget.itemName}에 대해 궁금한 것을 질문해주세요!',
    });
  }

  /// 챗봇 질문 보내기
  void handleSendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'sender': 'user', 'text': text});
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
        setState(() {
          messages.add({
            'sender': 'bot',
            'text': answerText,
          });
        });
      } else {
        setState(() {
          messages.add({
            'sender': 'bot',
            'text': '서버에서 응답을 받지 못했어요.',
          });
        });
      }
    } catch (e) {
      setState(() {
        messages.add({
          'sender': 'bot',
          'text': '오류가 발생했어요: $e',
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pilly에게 물어봐!'),
        backgroundColor: const Color.fromARGB(255, 255, 252, 223),
      ),
      body: Column(
        children: [
          // 상단 약 정보 카드
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        height: 60,
                        width: 60,
                        errorBuilder: (context, error, stackTrace) => Icon(Icons.image),
                      )
                    : Icon(Icons.image_not_supported, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.itemName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // 메시지 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isUser = msg['sender'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.grey[300] : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 봇 메시지일 때 Markdown + 스피커 아이콘
                        if (!isUser) ...[
                          Flexible(
                            child: MarkdownBody(
                              data: msg['text'] ?? '',
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 14, color: Colors.black),
                                strong: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 18, color: Colors.grey),
                            onPressed: () => _playTTS(msg['text'] ?? ''),
                          ),
                        ],

                        // 유저 메시지일 때
                        if (isUser)
                          Text(
                            msg['text'] ?? '',
                            style: const TextStyle(color: Colors.black),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 입력창
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 8, left: 8, bottom: 40),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  iconSize: 28,
                  color: Colors.grey,
                  onPressed: handleSendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}