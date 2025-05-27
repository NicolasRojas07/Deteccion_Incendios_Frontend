import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite/tflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(FireDetectorApp(camera: firstCamera));
}

class FireDetectorApp extends StatelessWidget {
  final CameraDescription camera;

  const FireDetectorApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Detector',
      theme: ThemeData.dark(),
      home: FireDetectorHome(camera: camera),
    );
  }
}

class FireDetectorHome extends StatefulWidget {
  final CameraDescription camera;

  const FireDetectorHome({super.key, required this.camera});

  @override
  State<FireDetectorHome> createState() => _FireDetectorHomeState();
}

class _FireDetectorHomeState extends State<FireDetectorHome> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isDetecting = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();

    loadModel();
  }

  Future<void> loadModel() async {
    await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
    );
  }

  void detectFrame(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      var recognitions = await Tflite.runModelOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResults: 2,
        threshold: 0.5,
      );

      setState(() {
        _result = recognitions?.map((r) => r['label']).join(', ') ?? 'No result';
      });
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fire Detector')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            _controller.startImageStream(detectFrame);
            return Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  bottom: 32,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black54,
                    child: Text(
                      'Detection: $_result',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                )
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
