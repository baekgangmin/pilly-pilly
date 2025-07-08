import 'package:flutter/material.dart';

class ChatBotScreen extends StatefulWidget {
  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  // 대화창에 표시할 메시지
  List<Map<String, String>> messages = [];

  // 현재 단계
  String currentStep = 'gender'; // gender -> age -> symptom -> done

  // 선택한 옵션 저장
  Map<String, String> selectedOptions = {};

  TextEditingController inputController = TextEditingController();

  final Map<String, List<String>> options = {
    'gender': ['남성', '여성'],
    'age': [
      '10대',
      '20대',
      '30대',
      '40대',
      '50대',
      '60대',
      '70대',
      '80대',
      '90대',
      '100세 이상'
    ],
    'symptom': [
      '복통',
      '두통',
      '명치통증',
      '관절통증',
      '근육통',
      '발열',
      '구토',
      '설사',
      '기침',
      '재채기',
      '목통증',
      '코막힘',
      '코피',
      '가려움증',
      '피부발진',
      '알레르기',
      '피로감',
      '어지러움',
      '리스트에 없습니다.'
    ],
  };

  String getQuestionText(String step) {
    switch (step) {
      case 'gender':
        return '성별';
      case 'age':
        return '나이대';
      case 'symptom':
        return '증상';
      default:
        return '';
    }
  }

  void handleOptionSelect(String value) {
    setState(() {
      selectedOptions[currentStep] = value;

      if (currentStep == 'gender') {
        currentStep = 'age';
      } else if (currentStep == 'age') {
        currentStep = 'symptom';
      } else if (currentStep == 'symptom') {
        currentStep = 'done';
      }
    });
  }

  void handleSendMessage() {
    final text = inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({
        'sender': 'user',
        'text': text,
      });

      // 챗봇 답변 예시
      messages.add({
        'sender': 'bot',
        'text': '아직 FastAPI 연동은 안됐어요 :)',
      });

      inputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Pilly에게 물어봐!'),
        backgroundColor: const Color.fromARGB(255, 255, 252, 223),
      ),
      body: Column(
        children: [
          // 상단 선택 요약 박스
          if (selectedOptions.isNotEmpty)
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: selectedOptions.entries.map((entry) {
                        return Text(
                          '${getQuestionText(entry.key)}: ${entry.value}',
                          style: TextStyle(fontSize: 14),
                        );
                      }).toList(),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedOptions.clear();
                        currentStep = 'gender';
                      });
                    },
                    child: Text(
                      '재선택',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 대화창
          Expanded(
            child: Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isUser = msg['sender'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      margin: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.grey[300] : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg['text'] ?? ''),
                    ),
                  );
                },
              ),
            ),
          ),

          // 선택형 버튼 리스트
          if (currentStep != 'done')
            Container(
              height: 70,
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: options[currentStep]?.length ?? 0,
                separatorBuilder: (_, __) => SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = options[currentStep]![index];
                  return ElevatedButton(
                    onPressed: () => handleOptionSelect(item),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    child: Text(item),
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
            padding: EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 8, left: 8, bottom: 40),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
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