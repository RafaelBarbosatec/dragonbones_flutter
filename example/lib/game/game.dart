import 'package:bonfire/bonfire.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'floor.dart';
import 'player.dart';

/// A small side-scrolling platformer, wired the Bonfire way.
///
/// Everything that can come from the engine does: `BonfireWidget` builds the
/// game, the `Keyboard` and `Joystick` controllers feed the player's input
/// callbacks, `GlobalForcesSettings` owns gravity, the `Floor`s are collidable
/// components, and the camera follows the player. The player class only adds
/// the DragonBones rendering.
class GameExample extends StatefulWidget {
  const GameExample({super.key});

  @override
  State<GameExample> createState() => _GameExampleState();
}

class _GameExampleState extends State<GameExample> {
  static final Vector2 _mapSize = Vector2(1200, 550);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bonfire + DragonBones')),
      body: BonfireWidget(
        map: WorldMap.empty(size: _mapSize),
        backgroundColor: const Color(0xFF102030),
        // Two controllers, one behaviour: the keyboard and the touch joystick
        // both end up in the player's `onJoystick*` callbacks.
        playerControllers: [
          Keyboard(
            config: KeyboardConfig(
              directionalKeys: [
                KeyboardDirectionalKeys.arrows(),
                KeyboardDirectionalKeys.wasd(),
              ],
            ),
          ),
          Joystick(
            directional: JoystickDirectional(),
            actions: [
              JoystickAction(
                actionId: LogicalKeyboardKey.space,
                size: 60,
                margin: const EdgeInsets.only(bottom: 60, right: 40),
              ),
              JoystickAction(
                actionId: LogicalKeyboardKey.keyF,
                size: 60,
                color: Colors.red,
                margin: const EdgeInsets.only(bottom: 60, right: 130),
              ),
            ],
          ),
        ],
        player: ScorpionPlayer(
          position: Vector2(60, 0),
          size: Vector2(200, 160),
        ),
        // Gravity is a global force: it is applied to every component that uses
        // `WithForces`, so the player only has to turn the mixin on.
        globalForces: GlobalForcesSettings(gravity: Vector2(0, 600)),
        components: [
          Floor(
            size: Vector2(_mapSize.x, 32),
            position: Vector2(0, _mapSize.y - 32),
          ),
          Floor(
            size: Vector2(220, 32),
            position: Vector2(360, _mapSize.y - 162),
          ),
          Floor(
            size: Vector2(220, 32),
            position: Vector2(700, _mapSize.y - 282),
            color: const Color(0xFF1565C0),
          ),
        ],
        cameraConfig: CameraConfig(
          initialMapZoomFit: InitialMapZoomFitEnum.fitHeight,
          moveOnlyMapArea: true,
        ),
      ),
    );
  }
}
