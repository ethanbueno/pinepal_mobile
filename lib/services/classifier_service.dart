import 'dart:convert';
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
  // How sure the model is that the photo shows a pineapple (0.0 - 1.0).
  // null for an older model that has no pineapple check.
  final double? pineappleScore;

  // False when the photo does not look like a pineapple. The disease guesses
  // are then meaningless and the scan must not be saved.
  final bool isPineapple;

  // Sorted from the most likely to the least likely, at most 3 items
  final List<Prediction> topPredictions;

  ClassificationResult({
    required this.topPredictions,
    this.pineappleScore,
    this.isPineapple = true,
  });

  Prediction get best => topPredictions[0];

  // The second guess is saved with the scan; null if there is none
  Prediction? get second =>
      topPredictions.length > 1 ? topPredictions[1] : null;

  // Below the threshold the app says "Not sure" and asks for a retake
  bool get isLowConfidence => best.confidence < ClassifierService.minConfidence;
}

// Runs the PinePal model bundled in assets/models.
//
// The v2 model (MobileNetV3-Large) has one output of [1, 7]:
//   index 0     = how sure it is that the photo is a pineapple
//   indexes 1-6 = the 6 conditions, in labels.txt order
// The file names and both thresholds come from pinepal_model_config.json, so a
// retrained model only needs its three files replaced.
class ClassifierService {
  static const String configPath = 'assets/models/pinepal_model_config.json';
  static const String modelsDir = 'assets/models';

  // Used until the config is read, and if it can't be read
  static const String defaultModelFile = 'pinepal_model.tflite';
  static const String defaultLabelsFile = 'labels.txt';

  // Below this disease confidence the app says "Not sure". Updated from the
  // config when the model loads; the report screen reads it too.
  static double minConfidence = 0.60;

  // Below this pineapple score the photo is rejected
  static double pineappleThreshold = 0.5;

  Interpreter? _interpreter;
  List<String> _labels = [];

  int _inputSize = 224;
  int _numOutputs = 0;
  bool _hasPineappleOutput = false;

  bool get isReady => _interpreter != null && _labels.isNotEmpty;

  Future<void> initialize() async {
    if (_interpreter != null) return;

    var modelFile = defaultModelFile;
    var labelsFile = defaultLabelsFile;
    try {
      final config =
          jsonDecode(await rootBundle.loadString(configPath))
              as Map<String, dynamic>;
      modelFile = config['model'] as String? ?? modelFile;
      labelsFile = config['labels_file'] as String? ?? labelsFile;
      pineappleThreshold =
          (config['gate_threshold'] as num?)?.toDouble() ?? pineappleThreshold;
      minConfidence =
          (config['disease_threshold'] as num?)?.toDouble() ?? minConfidence;
    } catch (e) {
      debugPrint('Could not read $configPath, using defaults: $e');
    }

    final options = InterpreterOptions()..threads = 2;
    final interpreter = await Interpreter.fromAsset(
      '$modelsDir/$modelFile',
      options: options,
    );
    interpreter.allocateTensors();

    // Read the shapes from the model instead of hard-coding them,
    // so a re-exported model does not silently break the app.
    final inputShape = interpreter.getInputTensor(0).shape; // [1, 224, 224, 3]
    final outputShape = interpreter.getOutputTensor(0).shape; // [1, 7]

    if (inputShape.length != 4 || inputShape[3] != 3) {
      interpreter.close();
      throw StateError(
        'Unexpected input shape $inputShape, expected [1, H, W, 3].',
      );
    }

    _inputSize = inputShape[1];
    _numOutputs = outputShape.last;

    final rawLabels = await rootBundle.loadString('$modelsDir/$labelsFile');
    _labels = rawLabels
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // labels.txt lists the conditions only. The v2 model has one extra output
    // in front of them for the pineapple check; an old model has none.
    if (_numOutputs == _labels.length + 1) {
      _hasPineappleOutput = true;
    } else if (_numOutputs == _labels.length) {
      _hasPineappleOutput = false;
    } else {
      interpreter.close();
      throw StateError(
        '$labelsFile has ${_labels.length} labels but the model has '
        '$_numOutputs outputs.',
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

    final output = List.generate(1, (_) => List.filled(_numOutputs, 0.0));
    _interpreter!.run([input], output);

    final raw = List<double>.from(output[0]);
    double? pineappleScore;
    var diseaseRaw = raw;
    if (_hasPineappleOutput) {
      pineappleScore = raw[0];
      diseaseRaw = raw.sublist(1);
    }

    final scores = _toProbabilities(diseaseRaw);

    // Pair every label with its score, then sort from highest to lowest
    final all = <Prediction>[
      for (var i = 0; i < scores.length; i++)
        Prediction(label: _labels[i], confidence: scores[i]),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return ClassificationResult(
      topPredictions: all.take(3).toList(),
      pineappleScore: pineappleScore,
      isPineapple:
          pineappleScore == null || pineappleScore >= pineappleThreshold,
    );
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
