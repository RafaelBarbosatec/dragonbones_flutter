part of '../../dragonbones.dart';

/// 2D point.
class Point {
  double x;
  double y;

  Point([this.x = 0.0, this.y = 0.0]);

  void clear() {
    this.x = 0.0;
    this.y = 0.0;
  }
}
