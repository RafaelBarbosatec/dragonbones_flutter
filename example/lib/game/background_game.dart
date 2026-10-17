import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart' hide Image;

class BackgroundGame extends GameBackground {
  final Vector2 mapSize;
  BackgroundGame(this.mapSize);
  late Image backgroundImage;
  @override
  void render(
    Canvas canvas,
  ) {
    canvas.drawImage(backgroundImage, const Offset(0, -450), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, mapSize.x, mapSize.y),
      Paint()..color = const Color.fromARGB(120, 7, 26, 61),
    );
  }

  @override
  Future<void> onLoad() async {
    backgroundImage = await Flame.images.load('magma_v2.png');
    return super.onLoad();
  }
}
