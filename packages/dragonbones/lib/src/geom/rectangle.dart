part of dragonbones;

/// Rectangle.
class Rectangle {
  double x;
  double y;
  double width;
  double height;

  Rectangle([this.x = 0.0, this.y = 0.0, this.width = 0.0, this.height = 0.0]);

  void clear() {
    this.x = 0.0;
    this.y = 0.0;
    this.width = 0.0;
    this.height = 0.0;
  }
}
