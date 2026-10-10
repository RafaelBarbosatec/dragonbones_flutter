import 'dart:ui';

import 'package:bonfire/bonfire.dart';

/// A solid, static block of the level: the ground and the floating platforms.
///
/// It is a plain [GameComponent] with a single [RectangleHitbox]. The player's
/// `WithCollision` reads that hitbox to stop movement — standing on top of it,
/// or bumping into its side.
class Floor extends GameComponent {
  Floor({
    required Vector2 size,
    required Vector2 position,
    this.color = const Color(0xFF2E7D32),
  }) {
    this.size = size;
    this.position = position;
  }

  final Color color;

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(size: size));
    return super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = color,
    );
    super.render(canvas);
  }
}
