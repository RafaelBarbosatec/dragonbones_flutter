import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'player.dart';

/// How the armature is placed inside the widget's box.
enum DragonBonesFit {
  /// Draw at the armature's own coordinates (use [DragonBonesPlayer.offset] to
  /// place it yourself).
  none,

  /// Scale and centre the armature so it fits the box.
  contain,
}

/// Plays a [DragonBonesPlayer] and repaints it every frame.
///
/// A convenience wrapper — if you already own a frame loop (a Flame component,
/// a Bonfire game, a custom `CustomPainter`), call
/// [DragonBonesPlayer.update] and [DragonBonesPlayer.render] directly and skip
/// this widget entirely.
class DragonBonesWidget extends StatefulWidget {
  const DragonBonesWidget({
    super.key,
    required this.player,
    this.animation,
    this.playing = true,
    this.fit = DragonBonesFit.contain,
  });

  final DragonBonesPlayer player;

  /// Animation to start. If null, whatever the player already does is used.
  final String? animation;

  /// Whether to advance time. False gives a static pose.
  final bool playing;

  final DragonBonesFit fit;

  @override
  State<DragonBonesWidget> createState() => _DragonBonesWidgetState();
}

class _DragonBonesWidgetState extends State<DragonBonesWidget>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _last = Duration.zero;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    if (widget.animation != null) {
      widget.player.play(widget.animation);
    }
    if (widget.playing) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt <= 0) {
      return;
    }
    widget.player.update(dt);
    _repaint.value++;
  }

  @override
  void didUpdateWidget(DragonBonesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.playing != oldWidget.playing) {
      if (widget.playing) {
        _startTicker();
      } else {
        _ticker?.dispose();
        _ticker = null;
      }
    }
    if (widget.animation != oldWidget.animation && widget.animation != null) {
      widget.player.play(widget.animation);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DragonBonesPainter(
        player: widget.player,
        repaint: _repaint,
        fit: widget.fit,
      ),
      size: Size.infinite,
    );
  }
}

class _DragonBonesPainter extends CustomPainter {
  _DragonBonesPainter({
    required this.player,
    required this.repaint,
    required this.fit,
  }) : super(repaint: repaint);

  final DragonBonesPlayer player;
  final Listenable repaint;
  final DragonBonesFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    if (fit == DragonBonesFit.none || size.isEmpty) {
      player.render(canvas);
      return;
    }

    final bounds = player.computeBounds();
    if (bounds == null || bounds.isEmpty) {
      player.render(canvas);
      return;
    }

    final scale = (size.width / bounds.width) < (size.height / bounds.height)
        ? size.width / bounds.width
        : size.height / bounds.height;

    // Centre the armature's bounds in the box.
    final offset = Offset(
      size.width / 2 - bounds.center.dx * scale,
      size.height / 2 - bounds.center.dy * scale,
    );

    player.render(canvas, scale: scale, offset: offset);
  }

  @override
  bool shouldRepaint(covariant _DragonBonesPainter oldDelegate) =>
      oldDelegate.player != player || oldDelegate.fit != fit;
}

/// A tiny helper for callers that want the same placement logic the widget uses.
extension DragonBonesPlayerGeometry on DragonBonesPlayer {
  /// Bounding box of the current pose, in armature coordinates.
  ///
  /// Computed from the sprite quads and the posed mesh vertices, so it moves
  /// with the animation. Returns null when there is nothing to draw.
  Rect? computeBounds() {
    Rect? result;

    void include(double x, double y) {
      result = result == null
          ? Rect.fromLTWH(x, y, 0, 0)
          : result!.expandToInclude(Rect.fromLTWH(x, y, 0, 0));
    }

    for (final data in drawList) {
      if (!data.visible || data.texture == null) {
        continue;
      }
      final m = data.matrix;

      final mesh = data.mesh;
      if (mesh != null) {
        // A mesh has no quad: its extent is the posed triangle list, already in
        // armature space but still to be transformed by the slot matrix.
        for (var i = 0; i < mesh.vertices.length; i += 2) {
          final px = mesh.vertices[i];
          final py = mesh.vertices[i + 1];
          include(m.a * px + m.c * py + m.tx, m.b * px + m.d * py + m.ty);
        }
        continue;
      }

      for (final corner in data.localQuad) {
        include(m.a * corner[0] + m.c * corner[1] + m.tx,
            m.b * corner[0] + m.d * corner[1] + m.ty);
      }
    }
    return result;
  }
}
