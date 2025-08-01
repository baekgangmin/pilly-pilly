import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'inference_delay_screen.dart';
import '../../models/model_type.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CameraInferenceScreen extends StatefulWidget {
  const CameraInferenceScreen({super.key});

  @override
  State<CameraInferenceScreen> createState() => _CameraInferenceScreenState();
}

class _CameraInferenceScreenState extends State<CameraInferenceScreen> {
  final GlobalKey _captureKey = GlobalKey();
  GlobalKey<YOLOViewState> _yoloViewKey = GlobalKey<YOLOViewState>();
  final YOLOViewController _yoloController = YOLOViewController();

  final List<String> capturedFrames = [];
  final List<String> cleanFrames = [];

  bool _isModelLoading = false;
  String? _modelPath;
  ModelType _selectedModel = ModelType.detect;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  double _currentZoomLevel = 3.0;
  bool _showYoloView = true;

  @override
  void initState() {
    super.initState();
    _loadModelForPlatform();
  }

  /// 모델 로드
  Future<void> _loadModelForPlatform() async {
    setState(() => _isModelLoading = true);
    try {
      final fileName = dotenv.env['MODEL_FILE_NAME'] ?? '';
      final Directory appDir = await getApplicationDocumentsDirectory();
      final File file = File('${appDir.path}/$fileName');

      if (!await file.exists()) {
        final ByteData data = await rootBundle.load('assets/models/$fileName');
        await file.writeAsBytes(data.buffer.asUint8List());
        print('✅ 모델 복사 성공: ${file.path}');
      } else {
        print('📦 이미 존재하는 모델 파일: ${file.path}');
      }

      if (mounted) {
        setState(() {
          _modelPath = file.path;
          _isModelLoading = false;
        });
      }
    } catch (e) {
      debugPrint('모델 로드 오류: $e');
      if (mounted) setState(() => _isModelLoading = false);
    }
  }

  /// clean 촬영용 카메라 초기화
  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    final CameraDescription camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();

    // 줌 강제 적용
    try {
      await _cameraController!.setZoomLevel(_currentZoomLevel);
      print('📸 clean 촬영 카메라 줌 적용됨: $_currentZoomLevel');
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      print('⚠️ clean 카메라 줌 적용 실패: $e');
    }

    print('📸 카메라 초기화 완료: ${_cameraController!.value.isInitialized}');
    setState(() {});
  }

  /// 캡처 절차
  Future<void> _captureProcedure() async {
    try {
      // 1. YOLOView 캡처 (bbox 있는 이미지 저장)
      String yoloPath = '';
      try {
        RenderRepaintBoundary boundary =
            _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        var image = await boundary.toImage(pixelRatio: 1.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        Uint8List pngBytes = byteData!.buffer.asUint8List();

        final directory = await getTemporaryDirectory();
        yoloPath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_yolo.png';
        await File(yoloPath).writeAsBytes(pngBytes);
        capturedFrames.add(yoloPath);
        debugPrint('🟢 bbox 저장 완료: $yoloPath');
      } catch (e) {
        debugPrint('YOLOView 캡처 실패: $e');
      }

      // 2. clean 촬영
      await _initializeCamera();
      final XFile cleanImage = await _cameraController!.takePicture();
      cleanFrames.add(cleanImage.path);
      debugPrint('🟢 clean 저장 완료: ${cleanImage.path}');

      // clean 카메라 닫기
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          await _cameraController!.dispose();
        } catch (e) {
          debugPrint('dispose 중 오류: $e');
        } finally {
          _cameraController = null;
        }
      }

      setState(() {});
    } catch (e) {
      debugPrint('캡처 절차 실패: $e');
    }
  }

  /// 썸네일 삭제
  void _deleteFrame(int index) {
    setState(() {
      File(capturedFrames[index]).deleteSync();
      File(cleanFrames[index]).deleteSync();
      capturedFrames.removeAt(index);
      cleanFrames.removeAt(index);
    });
  }

  /// 결과 화면 이동
  Future<void> _sendAllCleanFrames() async {
    // 디버깅 로그
    debugPrint('📤 sendAllCleanFrames 호출됨');
    debugPrint('capturedFrames: ${capturedFrames.length}, cleanFrames: ${cleanFrames.length}');

    // YOLO 중지
    await _yoloController.stop();
    setState(() => _showYoloView = false);
    _yoloViewKey = GlobalKey<YOLOViewState>();

    // fallback: cleanFrames 비어있으면 bboxFrames 넘김
    final framesToSend = cleanFrames.isNotEmpty ? cleanFrames : capturedFrames;
    debugPrint('전송할 이미지: $framesToSend');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InferenceDelayScreen(
          bboxImagePaths: capturedFrames,
          cleanImagePaths: framesToSend,
        ),
      ),
    ).then((_) {
      setState(() {
        _yoloViewKey = GlobalKey<YOLOViewState>();
        _showYoloView = true;
      });
    });
  }

  @override
  void dispose() {
    _yoloController.stop();
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: Column(
        children: [
          const SizedBox(height: 32),

          // 상단 썸네일
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: capturedFrames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black38, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(capturedFrames[index]),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _deleteFrame(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 줌 버튼 복원
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentZoomLevel = 1.0;
                    _yoloController.setZoomLevel(_currentZoomLevel);
                  });
                },
                child: const Text('1배 줌'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentZoomLevel = 3.0;
                    _yoloController.setZoomLevel(_currentZoomLevel);
                  });
                },
                child: const Text('3배 줌'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // YOLOView
          AspectRatio(
            aspectRatio: 1,
            child: Builder(
              builder: (context) {
                if (_modelPath == null || _isModelLoading || !_showYoloView) {
                  return const Center(child: CircularProgressIndicator());
                }

                return RepaintBoundary(
                  key: _captureKey,
                  child: YOLOView(
                    key: _yoloViewKey,
                    controller: _yoloController,
                    modelPath: _modelPath!,
                    task: _selectedModel.task,
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // 촬영 버튼
          FloatingActionButton(
            onPressed: _captureProcedure,
            child: const Icon(Icons.camera_alt),
          ),

          const SizedBox(height: 16),

          // 촬영 완료 버튼
          ElevatedButton(
            onPressed: _sendAllCleanFrames,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.85),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('촬영 완료', style: TextStyle(color: Colors.black)),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}