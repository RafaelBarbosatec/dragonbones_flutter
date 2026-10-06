part of dragonbones;

/// @private
class AnimationConfig extends BaseObject {
  bool pauseFadeOut = true;
  int fadeOutMode = AnimationFadeOutMode.All;
  int fadeOutTweenType = TweenType.Line;
  double fadeOutTime = -1.0;
  bool pauseFadeIn = true;
  bool actionEnabled = true;
  bool additive = false;
  bool displayControl = true;
  bool resetToPose = true;
  int fadeInTweenType = TweenType.Line;
  int playTimes = -1;
  int layer = 0;
  double position = 0.0;
  double duration = -1.0;
  double timeScale = -100.0;
  double weight = 1.0;
  double fadeInTime = -1.0;
  double autoFadeOutTime = -1.0;
  String name = '';
  String animation = '';
  String group = '';
  final List<String> boneMask = <String>[];

  @override
  void _onClear() {
    this.pauseFadeOut = true;
    this.fadeOutMode = AnimationFadeOutMode.All;
    this.fadeOutTweenType = TweenType.Line;
    this.fadeOutTime = -1.0;
    this.actionEnabled = true;
    this.additive = false;
    this.displayControl = true;
    this.pauseFadeIn = true;
    this.resetToPose = true;
    this.fadeInTweenType = TweenType.Line;
    this.playTimes = -1;
    this.layer = 0;
    this.position = 0.0;
    this.duration = -1.0;
    this.timeScale = -100.0;
    this.weight = 1.0;
    this.fadeInTime = -1.0;
    this.autoFadeOutTime = -1.0;
    this.name = '';
    this.animation = '';
    this.group = '';
    this.boneMask.length = 0;
  }

  void clear() => _onClear();
}
