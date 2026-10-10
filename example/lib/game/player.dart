import 'dart:math';

import 'package:bonfire/bonfire.dart';
import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter/services.dart';

/// The playable character: a Bonfire [Player] whose clips come from a
/// DragonBones armature.
///
/// Bonfire already provides almost everything for a platformer:
///
/// * horizontal movement — the `Keyboard`/`Joystick` controllers are fed into
///   `onJoystickChangeDirectional`, and `Player`'s `MovementByJoystick` mixin
///   turns that into `velocity`;
/// * gravity — `WithForces` applies the game's `GlobalForcesSettings.gravity`
///   every frame;
/// * collision — `WithCollision` stops the movement against the floor's
///   hitbox;
/// * jumping — `WithJumper` owns the jump state and resets it on landing.
///
/// The only thing this class adds is the bridge to [DragonBonesPlayer]: advance
/// it in `update`, paint it in `render`, and pick a clip from the state.
class ScorpionPlayer extends Player with WithForces, WithCollision, WithJumper {
  ScorpionPlayer({required super.position, required super.size})
      : super(speed: 200);

  late DragonBonesPlayer _player;
  late Armature _armature;

  /// Currently selected clip, so `play` is only called when it actually changes
  /// (calling it every frame would restart the animation).
  String _animation = '';

  /// Whether a horizontal direction is held. Up/down are ignored on purpose:
  /// a platformer moves on the X axis only.
  bool _moving = false;

  /// Seconds left of a one-shot clip (attack). While it runs it owns the pose.
  double _actionTimer = 0;

  @override
  Future<void> onLoad() async {
    await _loadDragonBones();

    // Collide with the legs only, so the mecha can walk under floating
    // platforms without bumping its head into them.
    add(
      RectangleHitbox(
        position: Vector2(0, size.y / 2),
        size: Vector2(size.x, size.y / 2 - 15),
      ),
    );
  }

  // --- Input ------------------------------------------------------------------

  @override
  void onJoystickAction(JoystickActionEvent event) {
    // While a one-shot clip runs the character is committed to it: no chained
    // actions and no jump until it finishes.
    if (event.event == ActionEvent.DOWN && _actionTimer <= 0) {
      if (event.id == LogicalKeyboardKey.space) {
        // ~150 px of apex with the game's gravity of 600.
        jumper.jump(jumpSpeed: 430);
      } else if (event.id == LogicalKeyboardKey.keyF) {
        _startAction('skill_04');
      }
    }
    super.onJoystickAction(event);
  }

  @override
  void onJoystickChangeDirectional(JoystickDirectionalEvent event) {
    // Collapse diagonals and ignore up/down. `MovementByJoystick` would happily
    // move the player vertically otherwise, fighting gravity.
    var directional = JoystickMoveDirectional.IDLE;
    if (event.directional.isRight) {
      directional = JoystickMoveDirectional.MOVE_RIGHT;
      _armature.flipX = false;
    } else if (event.directional.isLeft) {
      directional = JoystickMoveDirectional.MOVE_LEFT;
      _armature.flipX = true;
    }

    _moving = directional != JoystickMoveDirectional.IDLE;
    _refreshAnimation();

    super.onJoystickChangeDirectional(event.copyWith(directional: directional));
  }

  // --- Animation --------------------------------------------------------------

  /// Plays [clip] once for as long as the armature says it lasts.
  void _startAction(String clip) {
    _actionTimer = _armature.armatureData.getAnimation(clip)?.duration ?? 0.6;
    _play(clip);
  }

  void _refreshAnimation() {
    if (_actionTimer > 0) {
      return; // A one-shot clip is still owning the pose.
    }
    // This rig has no jump/fall clip, so locomotion is enough while airborne.
    _play(_moving ? 'walk' : 'idle');
  }

  void _play(String clip) {
    if (clip == _animation) {
      return;
    }
    _animation = clip;
    _player.play(clip);
  }

  // --- Bonfire lifecycle ------------------------------------------------------

  @override
  void update(double dt) {
    // The other half of the renderer's contract: `play` only *selects* a clip
    // and `flipX` only marks the armature dirty. It is `update(dt)` ->
    // `advanceTime` that evaluates the timelines and recomputes the bone/slot
    // matrices that `render` reads back.
    _player.update(dt);

    if (_actionTimer > 0) {
      // Freeze horizontal motion while the clip plays. Zeroing `x` here, before
      // `super.update` runs the movement, is enough to hold the character: the
      // joystick re-applies its direction at the end of the frame and we zero
      // it again next frame. Gravity is left alone, so an attack in mid-air
      // still falls naturally.
      velocity.x = 0;

      _actionTimer -= dt;
      if (_actionTimer <= 0) {
        _actionTimer = 0;
        _refreshAnimation();
      }
    }

    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    _player.render(canvas);
    super.render(canvas);
  }

  // --- DragonBones setup ------------------------------------------------------

  Future<void> _loadDragonBones() async {
    final assets = await DragonBonesAssets.loadAsset(
      bundle: rootBundle,
      skeleton: 'assets/mecha_2903/ske.json',
      texture: 'assets/mecha_2903/tex.json',
      image: 'assets/mecha_2903/tex.png',
    );

    // `mecha_2903d` is the armoured variant, and the only armature in the file
    // with locomotion *and* action clips.
    final armature = assets.buildArmature('mecha_2903d');
    if (armature == null) {
      throw StateError('armature "mecha_2903d" not found');
    }
    _armature = armature;
    _player = DragonBonesPlayer(_armature, resolveImage: assets.imageFor);

    // Pose the first frame before measuring it.
    _player.play('idle');
    _player.update(0);

    // Fit the armature's bounds into the component box. `computeBounds` is in
    // armature space and its left/top are negative, so `abs` is exactly the
    // offset that pins the sprite's top-left onto the component's origin.
    final bounds = _player.computeBounds()!;
    final scale = min(size.x, size.y) / min(bounds.width, bounds.height);
    _player
      ..scale = scale
      ..offset = Offset(bounds.left.abs() * scale, bounds.top.abs() * scale);
    _animation = 'idle';
  }
}
