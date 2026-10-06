part of dragonbones;

/// @private
class AnimationData extends BaseObject {
  int frameIntOffset = 0;
  int frameFloatOffset = 0;
  int frameOffset = 0;
  int blendType = AnimationBlendType.None;
  int frameCount = 0;
  int playTimes = 0;
  double duration = 0.0;
  double scale = 1.0;
  double fadeInTime = 0.0;
  double cacheFrameRate = 0.0;
  String name = '';
  final List<bool> cachedFrames = <bool>[];
  final Map<String, List<TimelineData>> boneTimelines = <String, List<TimelineData>>{};
  final Map<String, List<TimelineData>> slotTimelines = <String, List<TimelineData>>{};
  final Map<String, List<TimelineData>> constraintTimelines = <String, List<TimelineData>>{};
  final Map<String, List<TimelineData>> animationTimelines = <String, List<TimelineData>>{};
  final Map<String, List<int>> boneCachedFrameIndices = <String, List<int>>{};
  final Map<String, List<int>> slotCachedFrameIndices = <String, List<int>>{};
  TimelineData? actionTimeline;
  TimelineData? zOrderTimeline;
  ArmatureData? parent;

  @override
  void _onClear() {
    this.boneTimelines.clear();
    this.slotTimelines.clear();
    this.constraintTimelines.clear();
    this.animationTimelines.clear();
    this.boneCachedFrameIndices.clear();
    this.slotCachedFrameIndices.clear();
    this.frameIntOffset = 0;
    this.frameFloatOffset = 0;
    this.frameOffset = 0;
    this.blendType = AnimationBlendType.None;
    this.frameCount = 0;
    this.playTimes = 0;
    this.duration = 0.0;
    this.scale = 1.0;
    this.fadeInTime = 0.0;
    this.cacheFrameRate = 0.0;
    this.name = '';
    this.cachedFrames.length = 0;
    this.actionTimeline = null;
    this.zOrderTimeline = null;
    this.parent = null;
  }

  static void _add(Map<String, List<TimelineData>> map, String timelineName, TimelineData timeline) {
    final timelines = map.containsKey(timelineName) ? map[timelineName]! : (map[timelineName] = <TimelineData>[]);
    if (!timelines.contains(timeline)) {
      timelines.add(timeline);
    }
  }

  void addBoneTimeline(String timelineName, TimelineData timeline) => _add(this.boneTimelines, timelineName, timeline);
  void addSlotTimeline(String timelineName, TimelineData timeline) => _add(this.slotTimelines, timelineName, timeline);
  void addConstraintTimeline(String timelineName, TimelineData timeline) => _add(this.constraintTimelines, timelineName, timeline);
  void addAnimationTimeline(String timelineName, TimelineData timeline) => _add(this.animationTimelines, timelineName, timeline);

  List<TimelineData>? getBoneTimelines(String timelineName) => this.boneTimelines[timelineName];
  List<TimelineData>? getSlotTimelines(String timelineName) => this.slotTimelines[timelineName];
  List<TimelineData>? getConstraintTimelines(String timelineName) => this.constraintTimelines[timelineName];
  List<TimelineData>? getAnimationTimelines(String timelineName) => this.animationTimelines[timelineName];
  List<int>? getBoneCachedFrameIndices(String boneName) => this.boneCachedFrameIndices[boneName];
  List<int>? getSlotCachedFrameIndices(String slotName) => this.slotCachedFrameIndices[slotName];
}

/// @private
class TimelineData extends BaseObject {
  int type = TimelineType.BoneAll;
  int offset = 0;
  int frameIndicesOffset = -1;

  @override
  void _onClear() {
    this.type = TimelineType.BoneAll;
    this.offset = 0;
    this.frameIndicesOffset = -1;
  }
}

/// @private
class AnimationTimelineData extends TimelineData {
  double x = 0.0;
  double y = 0.0;

  @override
  void _onClear() {
    super._onClear();
    this.x = 0.0;
    this.y = 0.0;
  }
}
