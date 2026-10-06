part of dragonbones;

/// Color transform (multipliers + offsets).
class ColorTransform {
  double alphaMultiplier;
  double redMultiplier;
  double greenMultiplier;
  double blueMultiplier;
  double alphaOffset;
  double redOffset;
  double greenOffset;
  double blueOffset;

  ColorTransform({
    this.alphaMultiplier = 1.0,
    this.redMultiplier = 1.0,
    this.greenMultiplier = 1.0,
    this.blueMultiplier = 1.0,
    this.alphaOffset = 0.0,
    this.redOffset = 0.0,
    this.greenOffset = 0.0,
    this.blueOffset = 0.0,
  });

  void copyFrom(ColorTransform value) {
    this.alphaMultiplier = value.alphaMultiplier;
    this.redMultiplier = value.redMultiplier;
    this.greenMultiplier = value.greenMultiplier;
    this.blueMultiplier = value.blueMultiplier;
    this.alphaOffset = value.alphaOffset;
    this.redOffset = value.redOffset;
    this.greenOffset = value.greenOffset;
    this.blueOffset = value.blueOffset;
  }

  void identity() {
    this.alphaMultiplier = this.redMultiplier = this.greenMultiplier = this.blueMultiplier = 1.0;
    this.alphaOffset = this.redOffset = this.greenOffset = this.blueOffset = 0.0;
  }
}
