import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import 'inference_delay_screen.dart';
import '../../models/model_type.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
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

  double _currentZoomLevel = 1.0; // 기본은 1배
  double _cameraMinZoom = 1.0;
  double _cameraMaxZoom = 1.0;

  bool _showYoloView = true;

  bool _isCapturing = false; // 중복 촬영 방지 & 로딩 오버레이

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
        debugPrint('✅ 모델 복사 성공: ${file.path}');
      } else {
        debugPrint('📦 이미 존재하는 모델 파일: ${file.path}');
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

  /// clean 촬영 원본을 정사각형(센터 크롭)으로 변환해 저장
  Future<File> _cropToSquareFile(String srcPath) async {
    try {
      final Uint8List bytes = await File(srcPath).readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image img = frame.image;

      final int size = math.min(img.width, img.height);
      final double sx = (img.width - size) / 2.0;
      final double sy = (img.height - size) / 2.0;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Rect src = Rect.fromLTWH(sx, sy, size.toDouble(), size.toDouble());
      final Rect dst = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
      canvas.drawImageRect(img, src, dst, Paint());

      final ui.Image square = await recorder.endRecording().toImage(size, size);
      final ByteData? bd = await square.toByteData(format: ui.ImageByteFormat.png);
      if (bd == null) throw Exception('square toByteData == null');

      final Directory dir = await getTemporaryDirectory();
      final String outPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_clean_square.png';
      final File outFile = File(outPath);
      await outFile.writeAsBytes(bd.buffer.asUint8List());

      return outFile;
    } catch (e) {
      debugPrint('⚠️ 정사각형 크롭 실패, 원본 유지: $e');
      return File(srcPath);
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

    // 줌 범위 가져오기 및 클램프
    try {
      _cameraMinZoom = await _cameraController!.getMinZoomLevel();
      _cameraMaxZoom = await _cameraController!.getMaxZoomLevel();
    } catch (e) {
      debugPrint('⚠️ 줌 범위 조회 실패: $e');
      _cameraMinZoom = 1.0;
      _cameraMaxZoom = 8.0; // 안전한 가정치
    }

    final targetZoom = _currentZoomLevel.clamp(_cameraMinZoom, _cameraMaxZoom);

    // 줌 강제 적용 (클램프된 값)
    try {
      await _cameraController!.setZoomLevel(targetZoom);
      debugPrint('📸 clean 촬영 카메라 줌 적용됨: $targetZoom (min=$_cameraMinZoom, max=$_cameraMaxZoom)');
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('⚠️ clean 카메라 줌 적용 실패: $e');
    }

    debugPrint('📸 카메라 초기화 완료: ${_cameraController!.value.isInitialized}');
    setState(() {});
  }

  Future<void> _captureProcedure() async {
    if (_isCapturing) return; // 중복 방지
    setState(() => _isCapturing = true);

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
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('YOLOView 캡처 실패: $e');
      }

      // 2. clean 촬영 (→ 정사각형 파일로 센터 크롭 저장)
      await _initializeCamera();
      final XFile cleanImage = await _cameraController!.takePicture();

      // 원본을 정사각형으로 크롭해서 임시 디렉토리에 저장
      final File squareFile = await _cropToSquareFile(cleanImage.path);
      cleanFrames.add(squareFile.path);
      debugPrint('🟢 clean 저장(정사각형): ${squareFile.path}');
      if (mounted) setState(() {});

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

      // 화면 갱신 (상단 썸네일 등)
      setState(() {});
    } catch (e) {
      debugPrint('캡처 절차 실패: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// 썸네일 삭제
  void _deleteFrame(int index) {
    setState(() {
      if (index < capturedFrames.length) {
        final f = File(capturedFrames[index]);
        if (f.existsSync()) { f.deleteSync(); }
        capturedFrames.removeAt(index);
      }
      if (index < cleanFrames.length) {
        final f = File(cleanFrames[index]);
        if (f.existsSync()) { f.deleteSync(); }
        cleanFrames.removeAt(index);
      }
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
    return Stack(
      children: [
        Scaffold(
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
                  itemCount: math.max(capturedFrames.length, cleanFrames.length),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final bool hasClean = index < cleanFrames.length;
                    final bool hasBbox  = index < capturedFrames.length;
                    final String? thumbPath = hasClean
                        ? cleanFrames[index]
                        : (hasBbox ? capturedFrames[index] : null);
                    return Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black38, width: 1),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (thumbPath != null && File(thumbPath).existsSync())
                                ? Image.file(
                                    File(thumbPath),
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image_not_supported, size: 28),
                          ),
                        ),
                        // ⬇️ 삭제(X) 탭 영역 확대 & 터치 개선
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _deleteFrame(index),
                            child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
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
                    onPressed: () async {
                      setState(() {
                        _currentZoomLevel = 1.0;
                      });
                      _yoloController.setZoomLevel(_currentZoomLevel);
                      if (_cameraController?.value.isInitialized == true) {
                        final z = _currentZoomLevel.clamp(_cameraMinZoom, _cameraMaxZoom);
                        try {
                          await _cameraController!.setZoomLevel(z);
                        } catch (e) {
                          debugPrint('⚠️ 1배 줌 적용 실패: $e');
                        }
                      }
                    },
                    child: const Text('1배 줌'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _currentZoomLevel = 3.0;
                      });
                      _yoloController.setZoomLevel(_currentZoomLevel);
                      if (_cameraController?.value.isInitialized == true) {
                        final z = _currentZoomLevel.clamp(_cameraMinZoom, _cameraMaxZoom);
                        try {
                          await _cameraController!.setZoomLevel(z);
                        } catch (e) {
                          debugPrint('⚠️ 3배 줌 적용 실패: $e');
                        }
                      }
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
                onPressed: _isCapturing ? null : _captureProcedure,
                child: _isCapturing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
              ),
              const SizedBox(height: 16),
              // 촬영 완료 버튼
              ElevatedButton(
                onPressed: _isCapturing ? null : _sendAllCleanFrames,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.85),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('촬영 완료', style: TextStyle(color: Colors.black)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        // ⬇️ 전역 로딩 오버레이 (중복 터치 차단)
        if (_isCapturing)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}