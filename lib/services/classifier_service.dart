import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

// One guess of the model: a label and how sure it is (0.0 - 1.0)
class Prediction {
  final String label;
  final double confidence;

  Prediction({required this.label, required this.confidence});
}

class ClassificationResult {
  // Sorted from the most likely to the least likely, at most 3 items
  final List<Prediction> topPredictions;

  ClassificationResult({required this.topPredictions});

  Prediction get best => topPredictions[0];

  // The second guess is saved with the scan; null if there is none
  Prediction? get second =>
      topPredictions.length > 1 ? topPredictions[1] : null;

  // Below 60% the app asks the farmer to retake the photo
  bool get isLowConfidence => best.confidence < ClassifierService.minConfidence;
}

// Runs the MobileNetV2 model bundled in assets/models.
class ClassifierService {
  static const String modelPath = 'assets/models/pinepal_mobilenetv2.tflite';
  static const String labelsPath = 'assets/models/labels.txt';
  static const double minConfidence = 0.60;

  Interpreter? _interpreter;
  List<String> _labels = [];

  int _inputSize = 224;
  int _numClasses = 0;

  bool get isReady => _interpreter != null && _labels.isNotEmpty;

  Future<void> initialize() async {
    if (_interpreter != null) return;

    final options = InterpreterOptions()..threads = 2;
    final interpreter = await Interpreter.fromAsset(modelPath, options: options);
    interpreter.allocateTensors();

    // Read the shapes from the model instead of hard-coding them,
    // so a re-exported model does not silently break the app.
    final inputShape = interpreter.getInputTensor(0).shape; // [1, 224, 224, 3]
    final outputShape = interpreter.getOutputTensor(0).shape; // [1, numClasses]

    if (inputShape.length != 4 || inputShape[3] != 3) {
      interpreter.close();
      throw StateError('Unexpected input shape $inputShape, expected [1, H, W, 3].');
    }

    _inputSize = inputShape[1];
    _numClasses = outputShape.last;

    final rawLabels = await rootBundle.loadString(labelsPath);
    _labels = rawLabels
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // labels.txt must have the same classes, in the same order, as the model
    if (_labels.length != _numClasses) {
      interpreter.close();
      throw StateError(
        'labels.txt has ${_labels.length} labels but the model has '
        '$_numClasses outputs.',
      );
    }

    _interpreter = interpreter;
  }

  Future<ClassificationResult> classifyImage(String imagePath) async {
    if (_interpreter == null) {
      throw StateError('Call initialize() before classifyImage().');
    }

    // Decoding and resizing is slow in Dart, so it runs off the UI thread.
    final input = await compute(_preprocessImage, (imagePath, _inputSize));

    final output = List.generate(1, (_) => List.filled(_numClasses, 0.0));
    _interpreter!.run([input], output);

    final scores = _toProbabilities(List<double>.from(output[0]));

    // Pair every label with its score, then sort from highest to lowest
    final all = <Prediction>[
      for (var i = 0; i < scores.length; i++)
        Prediction(label: _labels[i], confidence: scores[i]),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return ClassificationResult(topPredictions: all.take(3).toList());
  }

  // Some exported models already end with softmax and some return raw
  // numbers (logits), so softmax is applied only when it is still needed.
  List<double> _toProbabilities(List<double> raw) {
    final sum = raw.fold<double>(0.0, (a, b) => a + b);
    final hasNegative = raw.any((v) => v < 0);

    if (!hasNegative && (sum - 1.0).abs() < 0.05) return raw;

    final maxValue = raw.reduce(math.max);
    final exps = raw.map((v) => math.exp(v - maxValue)).toList();
    final expSum = exps.fold<double>(0.0, (a, b) => a + b);
    return exps.map((v) => v / expSum).toList();
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _labels = [];
  }
}

// Top-level so compute() can run it in another isolate.
// Returns a [height][width][3] list of RGB values scaled to 0.0 - 1.0.
List<List<List<double>>> _preprocessImage((String, int) args) {
  final (path, size) = args;

  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    throw const FormatException('Could not read the image.');
  }

  // Camera photos can be rotated by EXIF data; fix it so the model
  // does not see a sideways pineapple.
  final upright = img.bakeOrientation(decoded);
  final resized = img.copyResize(
    upright,
    width: size,
    height: size,
    interpolation: img.Interpolation.linear,
  );

  return List.generate(size, (y) {
    return List.generate(size, (x) {
      final pixel = resized.getPixel(x, y);
      return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
    });
  });
}
