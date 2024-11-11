import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Thư viện nhận diện văn bản từ hình ảnh
import 'package:image_cropper/image_cropper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(MyApp(
    camera: firstCamera,
  ));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(
        camera: camera,
      ),
      theme: ThemeData.dark(),
    );
  }
}

class HomePage extends StatefulWidget {
  final CameraDescription camera;
  const HomePage({super.key, required this.camera});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController controller;
  bool _isFlashOn = false;
  double _brightness = 1.0;

  @override
  void initState() {
    super.initState();
    controller = CameraController(widget.camera, ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((e) {
      if (kDebugMode) {
        print(e);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Hàm lấy nét
  Future<void> _setFocusPoint(
      TapDownDetails details, BoxConstraints constraints) async {
    final offsetX = details.localPosition.dx / constraints.maxWidth;
    final offsetY = details.localPosition.dy / constraints.maxHeight;
    final point = Offset(offsetX, offsetY);

    try {
      await controller.setFocusPoint(point);
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  // Bật/tắt đèn flash
  Future<void> _toggleFlash() async {
    try {
      if (_isFlashOn) {
        await controller.setFlashMode(FlashMode.off);
      } else {
        await controller.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void _updateBrightness(double value) {
    setState(() {
      _brightness = value; // Cập nhật độ sáng
    });
    controller
        .setExposureOffset(value * 2 - 1); // Giá trị độ sáng từ -1.0 đến 1.0
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR App')),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) => _setFocusPoint(details, constraints),
                child: CameraPreview(controller),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
              size: 30,
            ),
            onPressed: _toggleFlash,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 500),
            child: Slider(
              value: _brightness,
              onChanged: _updateBrightness,
              min: -1.0,
              max: 2.0,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final image = await controller.takePicture();
                    if (context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ResultPage(imagePath: image.path),
                        ),
                      );
                    }
                  } catch (e) {
                    Fluttertoast.showToast(msg: e.toString());
                  }
                },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(20),
                ),
                child: const Icon(Icons.camera_alt, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultPage extends StatefulWidget {
  final String imagePath;
  const ResultPage({super.key, required this.imagePath});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  String? croppedImagePath;

  @override
  void initState() {
    super.initState();
    cropImage(widget.imagePath);
  }

  // Hàm để crop ảnh
  Future<void> cropImage(String imagePath) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            backgroundColor: ThemeData.dark().scaffoldBackgroundColor,
            toolbarColor: ThemeData.dark().scaffoldBackgroundColor,
            statusBarColor: ThemeData.dark().scaffoldBackgroundColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            hideBottomControls: true,
          )
        ]);

    if (croppedFile != null) {
      setState(() {
        croppedImagePath = croppedFile.path;
      });
      performOCR(InputImage.fromFilePath(croppedFile.path));
    }
  }

  String recognizedText = "Loading...";

  // Hàm xử lý ảnh --> văn bản
  void performOCR(InputImage inputImage) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);
    setState(() {
      this.recognizedText = recognizedText.text;
    });
    textRecognizer.close();
  }

  void _copyTextToClipboard() {
    Clipboard.setData(ClipboardData(text: recognizedText))
        .then((_) => Fluttertoast.showToast(msg: "Đã sao chép"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả'),
        actions: [
          IconButton(
            tooltip: "Sao chép",
            icon: const Icon(Icons.copy),
            onPressed: _copyTextToClipboard,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
        child: Text(
          recognizedText,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
