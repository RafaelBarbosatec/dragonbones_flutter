part of '../../dragonbones.dart';

/// 2D transform matrix (faithful port of `geom/Matrix.ts`).
class Matrix {
  double a;
  double b;
  double c;
  double d;
  double tx;
  double ty;

  Matrix([this.a = 1.0, this.b = 0.0, this.c = 0.0, this.d = 1.0, this.tx = 0.0, this.ty = 0.0]);

  Matrix copyFrom(Matrix value) {
    this.a = value.a;
    this.b = value.b;
    this.c = value.c;
    this.d = value.d;
    this.tx = value.tx;
    this.ty = value.ty;
    return this;
  }

  Matrix copyFromArray(List<num> value, [int offset = 0]) {
    this.a = value[offset].toDouble();
    this.b = value[offset + 1].toDouble();
    this.c = value[offset + 2].toDouble();
    this.d = value[offset + 3].toDouble();
    this.tx = value[offset + 4].toDouble();
    this.ty = value[offset + 5].toDouble();
    return this;
  }

  Matrix identity() {
    this.a = this.d = 1.0;
    this.b = this.c = 0.0;
    this.tx = this.ty = 0.0;
    return this;
  }

  Matrix concat(Matrix value) {
    double aA = this.a * value.a;
    double bA = 0.0;
    double cA = 0.0;
    double dA = this.d * value.d;
    double txA = this.tx * value.a + value.tx;
    double tyA = this.ty * value.d + value.ty;

    if (this.b != 0.0 || this.c != 0.0) {
      aA += this.b * value.c;
      bA += this.b * value.d;
      cA += this.c * value.a;
      dA += this.c * value.b;
    }

    if (value.b != 0.0 || value.c != 0.0) {
      bA += this.a * value.b;
      cA += this.d * value.c;
      txA += this.ty * value.c;
      tyA += this.tx * value.b;
    }

    this.a = aA;
    this.b = bA;
    this.c = cA;
    this.d = dA;
    this.tx = txA;
    this.ty = tyA;

    return this;
  }

  Matrix invert() {
    double aA = this.a;
    double bA = this.b;
    double cA = this.c;
    double dA = this.d;
    final txA = this.tx;
    final tyA = this.ty;

    if (bA == 0.0 && cA == 0.0) {
      this.b = this.c = 0.0;
      if (aA == 0.0 || dA == 0.0) {
        this.a = this.b = this.tx = this.ty = 0.0;
      } else {
        aA = this.a = 1.0 / aA;
        dA = this.d = 1.0 / dA;
        this.tx = -aA * txA;
        this.ty = -dA * tyA;
      }
      return this;
    }

    double determinant = aA * dA - bA * cA;
    if (determinant == 0.0) {
      this.a = this.d = 1.0;
      this.b = this.c = 0.0;
      this.tx = this.ty = 0.0;
      return this;
    }

    determinant = 1.0 / determinant;
    final k = this.a = dA * determinant;
    bA = this.b = -bA * determinant;
    cA = this.c = -cA * determinant;
    dA = this.d = aA * determinant;
    this.tx = -(k * txA + cA * tyA);
    this.ty = -(bA * txA + dA * tyA);

    return this;
  }

  void transformPoint(double x, double y, Point result, [bool delta = false]) {
    result.x = this.a * x + this.c * y;
    result.y = this.b * x + this.d * y;

    if (!delta) {
      result.x += this.tx;
      result.y += this.ty;
    }
  }
}
