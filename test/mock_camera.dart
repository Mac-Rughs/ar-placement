import 'package:camera/camera.dart';

class MockCamera extends CameraDescription {
  MockCamera()
      : super(
    name: 'mock',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 0,
  );
}