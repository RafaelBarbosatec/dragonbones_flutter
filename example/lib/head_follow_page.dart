// Interactive posing test: the Dragon's `head` bone follows the mouse / the
// finger, while the animation keeps playing underneath.
//
// Two things this page demonstrates.
//
// 1. The runtime's external-control hook. Every bone's local transform is:
//
//        global = setup(origin) + offset(external) + animationPose(animation)
//
//    The animation owns `animationPose`; we write into `head.offset` every frame
//    and call `invalidUpdate()`. Because the offset is additive, the head aims
//    at the pointer without disturbing anything else, and the child bones
//    (`eyeR` / `eyeL`) and slots follow for free.
//
// 2. Mirroring only the head. When the pointer crosses to the other side we
//    flip the head bone horizontally (`head.offset.scaleY = -1`) so the dragon
//    keeps its body still and turns its face around, instead of twisting the
//    neck ~180° and ending up upside down.
//
// Three pitfalls are worth knowing, and all are handled here:
//
//   * `head.global.rotation` already *includes* the offset you wrote last
//     frame, so `offset = target - global` double-counts and oscillates. Recover
//     the un-offset pose first (`base = global - offset`) and aim from there.
//   * The head bone's +x axis is not where the face points (the Dragon's tail
//     sticks out at +x, and the bone points up), so rotating the bone axis at
//     the target makes the dragon look *away*. We calibrate the real face
//     direction once, from the geometry, and aim that instead.
//   * The head bone points up, so a left-right mirror is `scaleY = -1`, not
//     `scaleX`. Mirroring `scaleX` would flip the head upside down.
import 'dart:math' as math;

import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter/material.dart' hide Transform;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

class HeadFollowPage extends StatefulWidget {
  const HeadFollowPage({super.key});

  @override
  State<HeadFollowPage> createState() => _HeadFollowPageState();
}

class _HeadFollowPageState extends State<HeadFollowPage>
    with SingleTickerProviderStateMixin {
  DragonBonesPlayer? _player;
  Bone? _head;
  Object? _error;

  /// Forward direction of the face, in the head bone's local space. Calibrated
  /// once at load; see [_calibrateFace].
  Offset? _faceLocal;

  /// Whether the head is currently mirrored left-right (see [_updateFacing]).
  bool _mirrored = false;

  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Pointer position in widget-local coordinates, or null when released.
  Offset? _pointer;

  /// The armature is placed from its bounds; re-placed when it flips, because
  /// the Dragon's tail makes its extent asymmetric.
  bool _placed = false;
  Size? _viewport;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await DragonBonesAssets.loadAsset(
        bundle: rootBundle,
        skeleton: 'assets/dragon/ske.json',
        texture: 'assets/dragon/tex.json',
        image: 'assets/dragon/tex.png',
      );

      final armature = assets.buildArmature('Dragon');
      if (armature == null) {
        throw StateError('armature "Dragon" not found');
      }

      final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
      player.play(); // default animation
      player.update(1 / 60); // seed the pose

      final head = armature.getBone('head');
      if (head == null) {
        throw StateError('bone "head" not found');
      }

      if (!mounted) return;
      setState(() {
        _player = player;
        _head = head;
        _faceLocal = _calibrateFace(armature, head);
      });

      _ticker = createTicker(_tick)..start();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  /// Works out which way the face points, in the head bone's local space.
  ///
  /// The Dragon is a side view: the tail sticks out at +x (the back) and the
  /// face looks towards -x. The bone's own +x axis points up, so aiming the
  /// bone axis at the pointer makes it look away. We take the vector "from the
  /// mane towards the eyes" at rest and express it in the head's local frame;
  /// after that any bone orientation can be aimed by rotating this vector.
  ///
  /// This is rig-specific by nature — for another character point it at a
  /// different pair of feature bones (or a hand-authored constant).
  static Offset _calibrateFace(Armature armature, Bone head) {
    final eyeR = armature.getBone('eyeR');
    final eyeL = armature.getBone('eyeL');
    final mane = armature.getBone('hair');
    if (eyeR == null || eyeL == null || mane == null) {
      return const Offset(1, 0); // fallback: the bone's own axis
    }

    final eyeMid = Offset(
      (eyeR.globalTransformMatrix.tx + eyeL.globalTransformMatrix.tx) / 2,
      (eyeR.globalTransformMatrix.ty + eyeL.globalTransformMatrix.ty) / 2,
    );
    final forward = eyeMid -
        Offset(mane.globalTransformMatrix.tx, mane.globalTransformMatrix.ty);

    // Express `forward` in the head's local frame (inverse of the 2x2 part).
    final m = head.globalTransformMatrix;
    final det = m.a * m.d - m.b * m.c;
    if (det == 0) {
      return const Offset(1, 0);
    }
    final lx = (m.d * forward.dx - m.c * forward.dy) / det;
    final ly = (-m.b * forward.dx + m.a * forward.dy) / det;
    final length = math.sqrt(lx * lx + ly * ly);
    return length == 0 ? const Offset(1, 0) : Offset(lx / length, ly / length);
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt <= 0) {
      return;
    }
    _updateFacing(); // may flip the armature and refresh the matrices
    _aimHead(); // before update, so the offset lands on this frame
    _player?.update(dt);
    _repaint.value++;
  }

  /// Mirrors the head left-right when the pointer is clearly on the other side
  /// of it, with a dead zone so it does not flicker near the vertical.
  ///
  /// Only the head bone is mirrored — the body keeps playing untouched.
  void _updateFacing() {
    final player = _player;
    final head = _head;
    final pointer = _pointer;
    if (player == null || head == null || pointer == null) {
      return;
    }

    const deadZone = 15.0;
    final targetX = _toArmature(player, pointer).dx;
    final headX = head.globalTransformMatrix.tx;
    var mirror = _mirrored;
    if (!mirror && targetX > headX + deadZone) {
      mirror = true;
    } else if (mirror && targetX < headX - deadZone) {
      mirror = false;
    }
    if (mirror == _mirrored) {
      return;
    }

    _mirrored = mirror;
    // The head bone points up, so a left-right mirror is `scaleY = -1`.
    head.offset.scaleY = mirror ? -1.0 : 1.0;
    head.invalidUpdate();
    player.update(0); // refresh the matrix so _aimHead() sees the mirror
  }

  /// Points the face at [_pointer].
  void _aimHead() {
    final head = _head;
    final player = _player;
    final faceLocal = _faceLocal;
    if (head == null || player == null || faceLocal == null) {
      return;
    }

    if (_pointer == null) {
      // Released: drop the offset and fall back to the animated pose.
      head.offset.rotation = 0.0;
      head.offset.scaleY = 1.0;
      _mirrored = false;
      head.invalidUpdate();
      return;
    }

    final target = _toArmature(player, _pointer!);
    final hx = head.globalTransformMatrix.tx;
    final hy = head.globalTransformMatrix.ty;
    final desired = math.atan2(target.dy - hy, target.dx - hx);

    // Rotate the calibrated face vector into armature space.
    final m = head.globalTransformMatrix;
    final faceX = m.a * faceLocal.dx + m.c * faceLocal.dy;
    final faceY = m.b * faceLocal.dx + m.d * faceLocal.dy;
    final faceAngle = math.atan2(faceY, faceX);

    // Recover the face angle *without* the current offset, then aim the
    // un-offset pose at the target. Reusing `faceAngle` directly would
    // double-count last frame's offset and oscillate. The mirror
    // (`scaleY = -1`) is already baked into the matrix, so it needs no sign
    // correction here.
    final faceBase = faceAngle - head.offset.rotation;
    head.offset.rotation = Transform.normalizeRadian(desired - faceBase);
    head.invalidUpdate(); // or: armature.invalidUpdate('head', true)
  }

  Offset _toArmature(DragonBonesPlayer player, Offset point) {
    final scale = player.scale;
    final offset = player.offset;
    return Offset((point.dx - offset.dx) / scale, (point.dy - offset.dy) / scale);
  }

  /// Fits the armature to the viewport using a fixed scale/offset.
  void _place(DragonBonesPlayer player, Size size) {
    final bounds = player.computeBounds();
    if (bounds == null || bounds.isEmpty) {
      player.scale = 1.0;
      player.offset = Offset(size.width / 2, size.height / 2);
      return;
    }

    final scale =
        math.min(size.width / bounds.width, size.height / bounds.height) * 0.75;
    player.scale = scale;
    player.offset = Offset(
      size.width / 2 - bounds.center.dx * scale,
      size.height / 2 - bounds.center.dy * scale,
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      appBar: AppBar(title: const Text('Head follows the pointer')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: const Color(0xFF102030),
              child: _error != null
                  ? Center(
                      child: Text(
                        '$_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : player == null
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (BuildContext context,
                              BoxConstraints constraints) {
                            if (constraints.maxWidth.isFinite &&
                                constraints.maxHeight.isFinite) {
                              _viewport = constraints.biggest;
                            }
                            if (!_placed && _viewport != null) {
                              _place(player, _viewport!);
                              _placed = true;
                            }

                            return Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerHover: (event) =>
                                  _pointer = event.localPosition,
                              onPointerMove: (event) =>
                                  _pointer = event.localPosition,
                              onPointerDown: (event) =>
                                  _pointer = event.localPosition,
                              onPointerUp: (_) => _pointer = null,
                              onPointerCancel: (_) => _pointer = null,
                              child: CustomPaint(
                                painter: _PlayerPainter(
                                  player,
                                  repaint: _repaint,
                                  pointer: () => _pointer,
                                ),
                                size: Size.infinite,
                              ),
                            );
                          },
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              'Move the mouse (or drag a finger) over the canvas. The head turns '
              'to look at the pointer and mirrors left-right when the pointer '
              'crosses to the other side. The animation never stops: the '
              'rotation goes into the additive `bone.offset`, on top of the '
              'animated pose.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerPainter extends CustomPainter {
  _PlayerPainter(this.player, {required this.repaint, required this.pointer})
      : super(repaint: repaint);

  final DragonBonesPlayer player;
  final Listenable repaint;
  final Offset? Function() pointer;

  @override
  void paint(Canvas canvas, Size size) {
    player.render(canvas);

    final target = pointer();
    if (target == null) {
      return;
    }
    canvas.drawCircle(target, 5, Paint()..color = const Color(0xFFFF5252));
    canvas.drawCircle(
      target,
      10,
      Paint()
        ..color = const Color(0x88FF5252)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayerPainter oldDelegate) =>
      oldDelegate.player != player;
}
