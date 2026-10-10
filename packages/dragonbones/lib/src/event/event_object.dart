part of '../../dragonbones.dart';

/// - The event dispatcher interface.
///
/// DragonBones dispatches its events *through the engine binding*, so the
/// binding implements this interface — it never needs to know what an event
/// means, only where to deliver it.
///
/// Port of `.ref/dragonBones-ts/event/IEventDispatcher.ts`.
///
/// Two deliberate deviations from upstream:
///
/// - Upstream's `addDBEventListener` takes `(type, listener, thisObject)`.
///   Dart closures capture their own context, so `thisObject` is dropped.
/// - `listener` is typed as `void Function(EventObject)` rather than upstream's
///   bare `Function`, so a wrong callback signature is a compile error instead
///   of a runtime surprise.
abstract class IEventDispatcher {
  /// - Checks whether any listener is registered for [type].
  ///
  /// The runtime calls this before allocating an event object, so returning
  /// `false` for everything is a legal (and cheap) "I listen to nothing".
  bool hasDBEventListener(String type);

  /// - Dispatches [eventObject] to every listener registered for [type].
  void dispatchDBEvent(String type, EventObject eventObject);

  /// - Registers [listener] for [type].
  void addDBEventListener(String type, void Function(EventObject event) listener);

  /// - Unregisters [listener] for [type].
  void removeDBEventListener(String type, void Function(EventObject event) listener);
}

/// - The properties of the object carry basic information about an event, which
/// are passed as parameter (or parameter's parameter) to event listeners when an
/// event occurs.
///
/// Port of `.ref/dragonBones-ts/event/EventObject.ts`.
///
/// Instances are buffered by [DragonBones] and dispatched *after* the frame has
/// been advanced — see [DragonBones.bufferEvent]. A listener may therefore
/// safely call back into the armature (play another animation, dispose a child)
/// without mutating the timeline mid-update.
class EventObject extends BaseObject {
  /// - Animation start play.
  static const String START = 'start';

  /// - Animation loop play complete once.
  static const String LOOP_COMPLETE = 'loopComplete';

  /// - Animation play complete.
  static const String COMPLETE = 'complete';

  /// - Animation fade in start.
  static const String FADE_IN = 'fadeIn';

  /// - Animation fade in complete.
  static const String FADE_IN_COMPLETE = 'fadeInComplete';

  /// - Animation fade out start.
  static const String FADE_OUT = 'fadeOut';

  /// - Animation fade out complete.
  static const String FADE_OUT_COMPLETE = 'fadeOutComplete';

  /// - Animation frame event.
  static const String FRAME_EVENT = 'frameEvent';

  /// - Animation frame sound event.
  static const String SOUND_EVENT = 'soundEvent';

  /// @internal
  ///
  /// Fills [instance] from a parsed [data] action. Note that a `Play` action
  /// (a `gotoAndPlay` the animator set in the editor) is delivered as a
  /// [FRAME_EVENT] — upstream does the same, so the two are indistinguishable
  /// on the listener side.
  static void actionDataToInstance(ActionData data, EventObject instance, Armature armature) {
    if (data.type == ActionType.Play) {
      instance.type = EventObject.FRAME_EVENT;
    } else {
      instance.type = data.type == ActionType.Frame ? EventObject.FRAME_EVENT : EventObject.SOUND_EVENT;
    }

    instance.name = data.name;
    instance.armature = armature;
    instance.actionData = data;
    instance.data = data.data;

    if (data.bone != null) {
      instance.bone = armature.getBone(data.bone!.name);
    }

    if (data.slot != null) {
      instance.slot = armature.getSlot(data.slot!.name);
    }
  }

  /// - If it is a frame event, the time (in seconds) the event sits at on the
  /// animation timeline.
  double time = 0.0;

  /// - The event type. One of the constants above.
  String type = '';

  /// - The event name (the frame event name, or the frame sound name).
  String name = '';

  /// - The armature that dispatched the event.
  Armature? armature;

  /// - The bone that dispatched the event, if the action named one.
  Bone? bone;

  /// - The slot that dispatched the event, if the action named one.
  Slot? slot;

  /// - The animation state that dispatched the event.
  AnimationState? animationState;

  /// @internal
  ActionData? actionData;

  /// - The custom data the action carries (`ints` / `floats` / `strings` from
  /// the skeleton JSON).
  UserData? data;

  @override
  void _onClear() {
    this.time = 0.0;
    this.type = '';
    this.name = '';
    this.armature = null;
    this.bone = null;
    this.slot = null;
    this.animationState = null;
    this.actionData = null;
    this.data = null;
  }
}
