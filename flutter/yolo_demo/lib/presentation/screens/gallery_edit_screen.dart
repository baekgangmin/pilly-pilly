import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yolo_demo/presentation/screens/inference_delay_screen.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryEditScreen extends StatefulWidget {
  const GalleryEditScreen({
    Key? key,
    required this.initialPaths,
    this.selectedImagePath,
  }) : super(key: key);

  /// 사용자가 선택한(또는 전달된) 이미지 목록
  final List<String> initialPaths;

  /// 초기 선택 이미지 경로(옵션). 없으면 initialPaths의 첫 번째 항목을 사용
  final String? selectedImagePath;

  @override
  State<GalleryEditScreen> createState() => _GalleryEditScreenState();
}

class _GalleryEditScreenState extends State<GalleryEditScreen> {
  File? _editedImage;
  File? _baseImageFile; // 초기 원본(정규화 전) 파일
  late TransformationController _controller;
  late Matrix4 _savedState;

  double _rotationAngle = 0.0; // 라디안 단위

  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    _editedImage = null; // ✅ 강제 초기화
    super.initState();
    _controller = TransformationController(Matrix4.identity());
    _savedState = Matrix4.identity();

    // 초기 파일 결정: selectedImagePath 우선, 없으면 initialPaths 첫 항목
    final String? initialPath = widget.selectedImagePath ??
        (widget.initialPaths.isNotEmpty ? widget.initialPaths.first : null);

    if (initialPath != null && initialPath.isNotEmpty) {
      _baseImageFile = File(initialPath);
      _initializeImage(_baseImageFile!);
    } else {
      // 초기 경로가 전혀 없을 때는 편집 불가 상태로 유지
      debugPrint('⚠️ GalleryEditScreen: 초기 이미지 경로가 없습니다.');
    }
  }

  Future<void> _initializeImage(File file) async {
    print("🔄 이미지 초기화 시작: ${file.path}");
    final converted = await _normalizeImage(file);
    setState(() {
      _editedImage = converted;
      _baseImageFile = file;
    });
  }

  Future<bool> _isHeifFile(File file) async {
    try {
      final bytes = await file.openRead(0, 12).first;
      final header = String.fromCharCodes(bytes);
      return header.contains('ftypheic') ||
          header.contains('ftypheix') ||
          header.contains('ftyphevc') ||
          header.contains('ftypmif1');
    } catch (e) {
      return false;
    }
  }

  Future<File> _normalizeImage(File file) async {
    try {
      // 파일 존재 및 크기 체크
      if (!file.existsSync()) {
        print("❌ 파일이 존재하지 않습니다: ${file.path}");
        return file;
      }

      final fileSize = file.lengthSync();
      print("ℹ️ 원본 파일 크기: $fileSize bytes");

      if (fileSize == 0) {
        print("⚠️ 파일 크기가 0바이트입니다. 변환 스킵 → 원본 사용");
        return file;
      }

      final bytes = await file.readAsBytes();
      print("ℹ️ 바이트 읽기 완료: ${bytes.length} bytes");

      final decoded = img.decodeImage(bytes);

      if (decoded == null || decoded.width == 0 || decoded.height == 0) {
        print("⚠️ 디코드 실패 또는 잘못된 크기 → 원본 반환");
        return file;
      }

      print("✅ 디코드 성공: width=${decoded.width}, height=${decoded.height}");

      // Orientation 정규화
      final normalized = img.bakeOrientation(decoded);

      // JPEG 저장 경로
      final newPath = file.path.replaceAll(
        RegExp(r'\.(heic|heif|jpeg|jpg|png)$', caseSensitive: false),
        '.jpg',
      );

      // Orientation만 적용한 이미지로 JPEG 인코딩
      final jpgBytes = img.encodeJpg(normalized, quality: 95);
      final newFile = File(newPath)..writeAsBytesSync(jpgBytes);
      print("이미지 변환 완료 → JPEG 저장: $newPath");

      return newFile;
    } catch (e) {
      print("이미지 변환 중 예외 발생 → 원본 반환: $e");
      return file;
    }
  }

  /// 새 로직: 사용자가 보는 프레임 그대로 캡처하는 방식
  Future<File> _captureFrameAsImage() async {
    RenderRepaintBoundary boundary =
        _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    final tempDir = Directory.systemTemp;
    final file = await File('${tempDir.path}/captured_frame.png').create();
    await file.writeAsBytes(pngBytes);

    print("✅ Frame captured: ${file.path}");
    return file;
  }

  void _rotateClockwise() {
    setState(() {
      _rotationAngle += 90 * 3.1415926535 / 180;
      if (_rotationAngle >= 2 * 3.1415926535) {
        _rotationAngle = 0.0;
      }
    });
  }

  void _rotateCounterClockwise() {
    setState(() {
      _rotationAngle -= 90 * 3.1415926535 / 180;
      if (_rotationAngle <= -2 * 3.1415926535) {
        _rotationAngle = 0.0;
      }
    });
  }

  void _onConfirmAndInference() async {
    print("🧹 이전 썸네일, 결과 상태 초기화 시작");
    // 이전 결과 초기화 (상태 리셋)
    setState(() {
      _editedImage = null;
      // clear previous inference results or thumbnails if applicable
      // summaryList.clear(); inferenceResults.clear();
    });

    final cropped = await _captureFrameAsImage();
    setState(() {
      _editedImage = cropped;
    });
    print("크롭 완료! 이미지 저장 경로: ${cropped.path}");

    // Clear previous inference cache (if any)
    // This ensures thumbnails and results won't persist across new runs
    // 예시: summaryList.clear(); inferenceResults.clear();
    // 실제로 사용하는 경우, 여기서 관련 전역/정적 리스트를 초기화하세요.

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InferenceDelayScreen(
          bboxImagePaths: [cropped.path],
          cleanImagePaths: [cropped.path],
        ),
      ),
    );
    print("🚀 추론 화면으로 이동 완료");
  }

  void _showLivePhotoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("지원되지 않는 이미지"),
        content: const Text("라이브 포토는 지원되지 않습니다.\n사진 앱에서 '라이브 끄기' 후 다시 선택해주세요."),
        actions: [
          TextButton(
            child: const Text("확인"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = _editedImage ?? _baseImageFile;

    return Scaffold(
      appBar: AppBar(
        title: const Text("이미지 편집"),
        backgroundColor: const Color.fromARGB(255, 255, 251, 206),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 60.0),
            child: Text(
              "프레임 안에 한 개의 알약만 넣고\n추론하기를 눌러주세요!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _rotateCounterClockwise,
                  child: const Text("⟲ 반시계"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _rotateClockwise,
                  child: const Text("시계 ⟳"),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final frameWidth = constraints.maxWidth * 0.7;
                  final frameHeight = constraints.maxHeight * 0.7;
                  print("LayoutBuilder frameWidth: $frameWidth, frameHeight: $frameHeight");
                  return SizedBox(
                    width: frameWidth,
                    height: frameHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RepaintBoundary(
                          key: _previewKey,
                          child: ClipRect(
                            child: InteractiveViewer(
                              transformationController: _controller,
                              minScale: 1.0,
                              maxScale: 3.0,
                              child: (currentFile != null)
                                  ? Image.file(
                                      currentFile!,
                                      fit: BoxFit.cover,
                                      width: frameWidth,
                                      height: frameHeight,
                                    )
                                  : const Center(
                                      child: Text(
                                        '이미지 경로가 없습니다',
                                        style: TextStyle(color: Colors.redAccent),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Container(
                            width: frameWidth,
                            height: frameHeight,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 60.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  child: const Text("추론하기"),
                  onPressed: _onConfirmAndInference,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}