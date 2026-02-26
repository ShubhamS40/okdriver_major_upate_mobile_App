import 'dart:math' as math;

/// Calculate Euclidean distance between two points
double euclideanDistance(List<double> p1, List<double> p2) {
  if (p1.length != p2.length) return 0.0;

  double sum = 0.0;
  for (int i = 0; i < p1.length; i++) {
    sum += math.pow(p1[i] - p2[i], 2);
  }
  return math.sqrt(sum);
}

/// Calculate Eye Aspect Ratio (EAR)
/// Based on the formula from main.py:
/// EAR = (A + B) / (2.0 * C)
/// where A and B are vertical distances, C is horizontal distance
double calculateEAR(List<List<double>> eyeLandmarks) {
  if (eyeLandmarks.length < 6) return 0.0;

  // Vertical distances
  final A = euclideanDistance(eyeLandmarks[1], eyeLandmarks[5]);
  final B = euclideanDistance(eyeLandmarks[2], eyeLandmarks[4]);

  // Horizontal distance
  final C = euclideanDistance(eyeLandmarks[0], eyeLandmarks[3]);

  if (C == 0) return 0.0;

  return (A + B) / (2.0 * C);
}

/// Calculate Mouth Aspect Ratio (MAR)
/// Based on the formula from main.py:
/// MAR = (A + B) / (2.0 * C)
double calculateMAR(List<List<double>> mouthLandmarks) {
  if (mouthLandmarks.length < 7) return 0.0;

  // Vertical distances
  final A = euclideanDistance(mouthLandmarks[2], mouthLandmarks[6]);
  final B = euclideanDistance(mouthLandmarks[3], mouthLandmarks[5]);

  // Horizontal distance
  final C = euclideanDistance(mouthLandmarks[0], mouthLandmarks[1]);

  if (C == 0) return 0.0;

  return (A + B) / (2.0 * C);
}
