part of dragonbones;

/// 2D transform (faithful port of `geom/Transform.ts`).
class Transform {
  static const double PI = math.pi;
  static const double PI_D = math.pi * 2.0;
  static const double PI_H = math.pi / 2.0;
  static const double PI_Q = math.pi / 4.0;
  static const double RAD_DEG = 180.0 / math.pi;
  static const double DEG_RAD = math.pi / 180.0;

  static double normalizeRadian(double value) {
    value = _jsMod(value + math.pi, math.pi * 2.0);
    value += value > 0.0 ? -math.pi : math.pi;
    return value;
  }

  double x;
  double y;
  double skew;
  double rotation;
  double scaleX;
  double scaleY;

  Transform([this.x = 0.0, this.y = 0.0, this.skew = 0.0, this.rotation = 0.0, this.scaleX = 1.0, this.scaleY = 1.0]);

  Transform copyFrom(Transform value) {
    this.x = value.x;
    this.y = value.y;
    this.skew = value.skew;
    this.rotation = value.rotation;
    this.scaleX = value.scaleX;
    this.scaleY = value.scaleY;
    return this;
  }

  Transform identity() {
    this.x = this.y = 0.0;
    this.skew = this.rotation = 0.0;
    this.scaleX = this.scaleY = 1.0;
    return this;
  }

  Transform add(Transform value) {
    this.x += value.x;
    this.y += value.y;
    this.skew += value.skew;
    this.rotation += value.rotation;
    this.scaleX *= value.scaleX;
    this.scaleY *= value.scaleY;
    return this;
  }

  Transform minus(Transform value) {
    this.x -= value.x;
    this.y -= value.y;
    this.skew -= value.skew;
    this.rotation -= value.rotation;
    this.scaleX /= value.scaleX;
    this.scaleY /= value.scaleY;
    return this;
  }

  Transform fromMatrix(Matrix matrix) {
    final backupScaleX = this.scaleX, backupScaleY = this.scaleY;
    const piQ = Transform.PI_Q;

    this.x = matrix.tx;
    this.y = matrix.ty;
    this.rotation = math.atan(matrix.b / matrix.a);
    double skewX = math.atan(-matrix.c / matrix.d);

    this.scaleX = (this.rotation > -piQ && this.rotation < piQ) ? matrix.a / math.cos(this.rotation) : matrix.b / math.sin(this.rotation);
    this.scaleY = (skewX > -piQ && skewX < piQ) ? matrix.d / math.cos(skewX) : -matrix.c / math.sin(skewX);

    if (backupScaleX >= 0.0 && this.scaleX < 0.0) {
      this.scaleX = -this.scaleX;
      this.rotation = this.rotation - math.pi;
    }

    if (backupScaleY >= 0.0 && this.scaleY < 0.0) {
      this.scaleY = -this.scaleY;
      skewX = skewX - math.pi;
    }

    this.skew = skewX - this.rotation;

    return this;
  }

  Transform toMatrix(Matrix matrix) {
    if (this.rotation == 0.0) {
      matrix.a = 1.0;
      matrix.b = 0.0;
    } else {
      matrix.a = math.cos(this.rotation);
      matrix.b = math.sin(this.rotation);
    }

    if (this.skew == 0.0) {
      matrix.c = -matrix.b;
      matrix.d = matrix.a;
    } else {
      matrix.c = -math.sin(this.skew + this.rotation);
      matrix.d = math.cos(this.skew + this.rotation);
    }

    if (this.scaleX != 1.0) {
      matrix.a *= this.scaleX;
      matrix.b *= this.scaleX;
    }

    if (this.scaleY != 1.0) {
      matrix.c *= this.scaleY;
      matrix.d *= this.scaleY;
    }

    matrix.tx = this.x;
    matrix.ty = this.y;

    return this;
  }
}
