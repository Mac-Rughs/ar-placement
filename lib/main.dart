import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );

  runApp(MyApp(camera: backCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Shape Detection',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ARShapeDetectionPage(camera: camera),
    );
  }
}

class ARShapeDetectionPage extends StatefulWidget {
  final CameraDescription camera;

  const ARShapeDetectionPage({Key? key, required this.camera}) : super(key: key);

  @override
  _ARShapeDetectionPageState createState() => _ARShapeDetectionPageState();
}

class _ARShapeDetectionPageState extends State<ARShapeDetectionPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  ARLocationManager? arLocationManager;

  final ImageLabeler _imageLabeler = GoogleMlKit.vision.imageLabeler();
  String _dominantShape = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
    _initializeControllerFuture.then((_) {
      if (mounted) {
        setState(() {});
        _startImageStream();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    arSessionManager?.dispose();
    _imageLabeler.close();
    super.dispose();
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager,
      ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    this.arSessionManager?.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: "assets/triangle.png",
      showWorldOrigin: true,
    );
    this.arObjectManager?.onInitialize();
  }

  void _startImageStream() {
    _controller.startImageStream((CameraImage image) {
      if (_isProcessing) return;

      _isProcessing = true;
      detectAndDisplayShape(image).then((_) {
        _isProcessing = false;
      });
    });
  }

  Future<void> detectAndDisplayShape(CameraImage image) async {
    final inputImage = InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    final List<ImageLabel> labels = await _imageLabeler.processImage(inputImage);

    String dominantShape = '';
    double maxConfidence = 0;

    for (ImageLabel label in labels) {
      if (label.confidence > maxConfidence &&
          (label.label == 'Square' || label.label == 'Circle' || label.label == 'Triangle')) {
        dominantShape = label.label;
        maxConfidence = label.confidence;
      }
    }

    if (dominantShape != _dominantShape) {
      setState(() {
        _dominantShape = dominantShape;
      });

      if (_dominantShape.isNotEmpty) {
        await _addARObject(_dominantShape);
      }
    }
  }

  Future<void> _addARObject(String shape) async {
    if (arObjectManager != null) {
      var newNode = ARNode(
        type: NodeType.localGLTF2,
        uri: "assets/${shape.toLowerCase()}.gltf",
        scale: vector.Vector3(0.2, 0.2, 0.2),
        position: vector.Vector3(0, 0, -1), // 1 meter away
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      );
      bool? didAddNodeSuccess = await arObjectManager?.addNode(newNode);
      if (didAddNodeSuccess == true) {
        print("Successfully added $shape to the AR scene");
      } else {
        print("Failed to add $shape to the AR scene");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Shape Detection')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                ARView(onARViewCreated: onARViewCreated),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(
                    'Dominant Shape: $_dominantShape',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
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