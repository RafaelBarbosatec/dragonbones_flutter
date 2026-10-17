import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'player.dart';

/// Plays a [DragonBonesPlayer] and repaints it every frame.
///
/// A convenience wrapper — if you already own a frame loop (an engine component,
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
    this.align = Alignment.center,
  });

  final DragonBonesPlayer player;

  /// Animation to start. If null, whatever the player already does is used.
  final String? animation;

  /// Whether to advance time. False gives a static pose.
  final bool playing;

  final DragonBonesFit fit;

  final Alignment align;

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
        align: widget.align,
      ),
      size: Size.infinite,
    );
  }
}

class _DragonBonesPainter extends CustomPainter {
  _DragonBonesPainter({
    required this.player,
    required this.repaint,
    this.fit = DragonBonesFit.contain,
    this.align = Alignment.center,
  }) : super(repaint: repaint);

  final DragonBonesPlayer player;
  final Listenable repaint;
  final DragonBonesFit fit;
  final Alignment align;

  @override
  void paint(Canvas canvas, Size size) {
    // `fit` computes and stores the placement; for `DragonBonesFit.none` (or
    // an empty box / pose) it is a no-op, so a hand-authored scale/offset on
    // the player survives.
    player.fit(size: size, fit: fit, align: align);
    player.render(canvas);
  }

  @override
  bool shouldRepaint(covariant _DragonBonesPainter oldDelegate) =>
      oldDelegate.player != player || oldDelegate.fit != fit;
}
