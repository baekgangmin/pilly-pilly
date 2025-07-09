import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'inference_result_screen.dart';
import 'inference_delay_screen.dart';
import '../../models/model_type.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  double _currentZoomLevel = 3.0; // ⭐️ 기본 3배 줌

  bool _showYoloView = true;

  @override
  void initState() {
    super.initState();
    _loadModelForPlatform();
  }

  Future<void> _loadModelForPlatform() async {
    setState(() {
      _isModelLoading = true;
    });
    try {
      final fileName = 'best_8n_float16.tflite';
      final ByteData data = await rootBundle.load('assets/models/$fileName');

      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory modelDir = Directory('${appDir.path}/assets/models');
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }

      final File file = File('${modelDir.path}/$fileName');
      if (!await file.exists()) {
        await file.writeAsBytes(data.buffer.asUint8List());
      }

      if (mounted) {
        setState(() {
          _modelPath = file.path;
          _isModelLoading = false;
        });
        _yoloController.setZoomLevel(_currentZoomLevel);
      }
    } catch (e) {
      debugPrint('모델 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isModelLoading = false;
        });
      }
    }
  }

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
  }

  Future<void> _sendAllCleanFrames() async {
    debugPrint('📴 YOLO 종료 시도 - 촬영 완료');
    await _yoloController.stop();

    setState(() {
      _showYoloView = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InferenceDelayScreen(
          bboxImagePaths: capturedFrames,
          cleanImagePaths: cleanFrames,
        ),
      ),
    );
  }

  Future<void> _captureProcedure() async {
    try {
      debugPrint('▶️ YOLOView 캡처 시작');
      RenderRepaintBoundary boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      String yoloPath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_yolo.png';
      await File(yoloPath).writeAsBytes(pngBytes);
      debugPrint('YOLOView 캡처 완료: $yoloPath');

      // ✅ 먼저 YOLOView stop
      debugPrint('YOLOView stop 호출');
      await _yoloController.stop();

      await Future.delayed(const Duration(milliseconds: 300));
      // await _yoloController.dispose(); // ensure proper cleanup - removed as dispose() does not exist

      // ✅ 플랫폼 측 세션 완전 종료 기다림
      await Future.delayed(const Duration(milliseconds: 300));

      // ✅ 그 다음 UI에서 YOLOView 제거
      setState(() {
        capturedFrames.add(yoloPath);
        _showYoloView = false;
      });

      // ✅ 카메라 초기화
      debugPrint('CameraController 초기화');
      await _initializeCamera();

      // ✅ 카메라 촬영
      debugPrint('CameraController 촬영');
      final XFile cleanImage = await _cameraController!.takePicture();
      cleanFrames.add(cleanImage.path);
      debugPrint('깨끗한 캡처 완료: ${cleanImage.path}');

      await Future.delayed(const Duration(milliseconds: 300)); // 안정적인 타이밍 확보

      // ✅ 카메라 세션 해제
      debugPrint('CameraController dispose');
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          await _cameraController!.dispose();
        } catch (e) {
          debugPrint('📛 dispose 중 오류 발생: $e');
        } finally {
          _cameraController = null;
        }
      }

      await Future.delayed(const Duration(milliseconds: 500)); // 안전한 타이밍 확보

      // ✅ YOLOView 재로드
      debugPrint('YOLOView 재로드');
      setState(() {
        _yoloViewKey = GlobalKey<YOLOViewState>(); // 강제 리프레시
        _showYoloView = true;
      });

      _yoloController.setZoomLevel(_currentZoomLevel);
    } catch (e) {
      debugPrint('캡처 절차 실패: $e');
      debugPrint('캡처 예외 상세: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    debugPrint('📴 CameraInferenceScreen dispose 호출됨');

    // YOLOView 종료
    _yoloController.stop(); // gracefully stop if needed

    // 카메라 리소스 해제
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_modelPath != null && !_isModelLoading && _showYoloView)
            RepaintBoundary(
              key: _captureKey,
              child: YOLOView(
                key: _yoloViewKey,
                controller: _yoloController,
                modelPath: _modelPath!,
                task: _selectedModel.task,
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          Positioned(
            top: 32,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Positioned(
            top: 32,
            right: 16,
            child: SizedBox(
              width: 80,
              child: Column(
                children: [
                  Container(
                    height: 500,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: capturedFrames.isEmpty
                        ? const Center(
                            child: Text(
                              'No\nFrame',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          )
                        : ListView.builder(
                            itemCount: capturedFrames.length,
                            itemBuilder: (context, idx) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(capturedFrames[idx]),
                                  fit: BoxFit.cover,
                                  height: 48,
                                  width: 48,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.85),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _sendAllCleanFrames,
                      child: const Text('촬영 완료', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _currentZoomLevel = 1.0);
                    _yoloController.setZoomLevel(1.0);
                  },
                  child: Text(
                    '1배',
                    style: TextStyle(
                      color: _currentZoomLevel == 1.0 ? Colors.yellow : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    setState(() => _currentZoomLevel = 3.0);
                    _yoloController.setZoomLevel(3.0);
                  },
                  child: Text(
                    '3배',
                    style: TextStyle(
                      color: _currentZoomLevel == 3.0 ? Colors.yellow : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _captureProcedure,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}