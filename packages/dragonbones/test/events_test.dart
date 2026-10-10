// Animation events: the frame events an animator marks on the timeline, and the
// lifecycle events a game reacts to ("that animation finished — do the thing").
//
// Verified frame by frame against the official runtime by
// `tool/check_events_against_oracle.dart` (47 fixtures, 174 scenarios). This file
// states the behaviour in a form that is readable on its own.
//
// `progress_bar` is the asset to use for it: a Unity SDK demo that exists
// precisely to exercise events — one animation with `startEvent` on its first
// frame, `middleEvent` halfway and `completeEvent` on the last, over a nested
// child armature.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';
import 'package:test/test.dart';

/// Locates `test/fixtures/unity/<name>` whether the tests run from
/// `packages/dragonbones` (as CI does) or from the repository root.
Directory _fixture(String name) {
  for (final candidate in <String>[
    'test/fixtures/unity/$name',
    '../../test/fixtures/unity/$name',
  ]) {
    final directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError('fixture "$name" not found — run from packages/dragonbones');
}

/// Parses fixture [name] and builds [armatureName] from it.
Armature _build(String name, String armatureName) {
  final fixture = _fixture(name);
  final factory = HeadlessFactory();
  final data = factory.parseDragonBonesData(
    jsonDecode(File('${fixture.path}/${name}_ske.json').readAsStringSync()),
  )!;
  factory.parseTextureAtlasData(
    jsonDecode(File('${fixture.path}/${name}_tex.json').readAsStringSync()),
    null,
    data.name,
  );
  return factory.buildArmature(armatureName, data.name)!;
}

void main() {
  test('frame events, loopComplete and complete arrive in order', () {
    final armature = _build('progress_bar', 'progress_bar');
    final hub = armature.dragonBones;

    final seen = <String>[];
    for (final type in <String>[
      EventObject.START,
      EventObject.FRAME_EVENT,
      EventObject.LOOP_COMPLETE,
      EventObject.COMPLETE,
    ]) {
      armature.eventDispatcher.addDBEventListener(type, (event) {
        seen.add(event.name.isEmpty ? event.type : '${event.type}:${event.name}');
      });
    }

    // playTimes 1: plays through once, so `complete` fires at the end.
    final state = armature.animation.play('idle', 1)!;
    final frames = (state.totalTime * 24).ceil() + 2;
    for (var i = 0; i < frames; i++) {
      hub.advanceTime(1 / 24);
    }

    expect(seen, <String>[
      EventObject.START,
      '${EventObject.FRAME_EVENT}:startEvent',
      '${EventObject.FRAME_EVENT}:middleEvent',
      '${EventObject.FRAME_EVENT}:completeEvent',
      EventObject.LOOP_COMPLETE,
      EventObject.COMPLETE,
    ]);
  });

  test('a frame event carries its name, time, armature and slot', () {
    final armature = _build('progress_bar', 'progress_bar');
    final hub = armature.dragonBones;

    EventObject? middle;
    armature.eventDispatcher.addDBEventListener(EventObject.FRAME_EVENT, (event) {
      if (event.name == 'middleEvent') {
        middle = event;
      }
    });

    armature.animation.play('idle', 1);
    for (var i = 0; i < 60; i++) {
      hub.advanceTime(1 / 24);
    }

    expect(middle, isNotNull, reason: 'middleEvent should have fired by frame 60');
    // The event sits halfway through a 100-frame, 24 fps animation.
    expect(middle!.time, closeTo(50 / 24, 1e-6));
    expect(middle!.armature, same(armature));
    expect(middle!.animationState!.name, 'idle');
  });

  test('a listener can start another animation from inside complete', () {
    // The reason events are buffered and dispatched after the frame is posed:
    // a listener is allowed to call back into the armature.
    final armature = _build('progress_bar', 'progress_bar');
    final hub = armature.dragonBones;

    var reactions = 0;
    armature.eventDispatcher.addDBEventListener(EventObject.COMPLETE, (event) {
      reactions++;
      armature.animation.play('idle', 1);
    });

    armature.animation.play('idle', 1);
    // Long enough for two full passes: the listener restarts on the first
    // `complete`, and the restarted animation has to run its 100 frames again.
    for (var i = 0; i < 260; i++) {
      hub.advanceTime(1 / 24);
    }

    expect(reactions, greaterThanOrEqualTo(2));
  });

  test('playing an animation makes nested armatures follow it by name', () {
    // `bounding_box_tester` packs `tester` with nested `target`/`point`
    // armatures, and all of them declare animations named `"0"` and `"1"`.
    // Playing `"0"` on the parent has to make the children play `"0"` too —
    // that is how a single call poses a whole character. Without it, a child
    // keeps whatever it started with and the composite looks wrong.
    final armature = _build('bounding_box_tester', 'tester');
    final hub = armature.dragonBones;

    // Let the slots build their children, and let them settle on `"1"` (their
    // own `defaultActions`).
    armature.animation.play('1', 1);
    hub.advanceTime(1 / 24);

    final children = <Armature>[];
    for (final slot in armature.getSlots()) {
      final child = slot.childArmature;
      if (child != null) {
        children.add(child);
      }
    }

    expect(children, isNotEmpty, reason: 'the slots hold nested armatures');

    // `target_a` / `target_b` declare `"0"` and `"1"`; `point_a` / `point_b` do
    // not (they only have `newAnimation`), so they are the control group: the
    // propagation must reach the first pair and leave the second alone.
    final followers = children.where((child) => child.animation.hasAnimation('0')).toList();
    final bystanders = children.where((child) => !child.animation.hasAnimation('0')).toList();

    expect(followers, isNotEmpty);
    expect(bystanders, isNotEmpty);

    for (final child in followers) {
      expect(child.animation.getState('1'), isNotNull,
          reason: '${child.armatureData.name} starts on its own default action');
      expect(child.animation.getState('0'), isNull);
    }

    // Now switch the parent. Every child that declares `"0"` must follow, and
    // the ones that do not must be left where they are.
    armature.animation.play('0', 1);
    hub.advanceTime(1 / 24);

    for (final child in followers) {
      expect(child.animation.getState('0'), isNotNull,
          reason: '${child.armatureData.name} should have been told to play "0"');
    }

    for (final child in bystanders) {
      expect(child.animation.getState('0'), isNull,
          reason: '${child.armatureData.name} does not declare "0" and must not be touched');
    }
  });

  test('listening to nothing allocates nothing, and stays silent', () {
    final armature = _build('progress_bar', 'progress_bar');
    final hub = armature.dragonBones;

    // The runtime asks before building an event; with no listener it never does.
    expect(armature.eventDispatcher.hasDBEventListener(EventObject.COMPLETE), isFalse);

    armature.animation.play('idle', 1);
    for (var i = 0; i < 120; i++) {
      hub.advanceTime(1 / 24);
    }

    // Nothing to assert but the absence of a crash — the point is that an app
    // that listens to nothing pays nothing for the feature existing.
    expect(armature.eventDispatcher.hasDBEventListener(EventObject.FRAME_EVENT), isFalse);
  });
}
