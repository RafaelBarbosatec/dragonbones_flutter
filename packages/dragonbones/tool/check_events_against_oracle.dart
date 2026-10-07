// Diffs this runtime's animation events, frame by frame, against the official
// DragonBones runtime.
//
// Companion to `check_against_oracle.dart` (which diffs poses). This one diffs
// the *event stream*: for every fixture it replays each animation twice — once
// with `playTimes: 1`, once with `playTimes: 2` — and compares the ordered list
// of (frame, type, name, time, armature, animationState, bone, slot) with the
// reference dumps in `tool/ground_truth/out/events__*.json`.
//
// A note on why this file can exist at all: the reference *harness* used to be
// unable to produce these dumps. `dump.js` runs the compiled runtime inside a
// `vm` context and then JSON-parses the skeleton in the parent realm, and the
// official parser tests `rawData instanceof Array` (ObjectDataParser.ts:1897) —
// an array from another realm fails that test, so every animation action was
// silently dropped. `dump_events.js` parses inside the runtime's context and
// sees them. See `tool/ground_truth/dump_events.js`.
//
//   dart run tool/check_events_against_oracle.dart
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

/// Fields compared for each event, in order.
const List<String> _fields = <String>[
  'type',
  'name',
  'armature',
  'animationState',
  'bone',
  'slot',
];

/// Float tolerance for `time` (the reference dump rounds to 1e-6).
const double _epsilon = 1e-6;

Directory _repoRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/tool/ground_truth/out').existsSync() &&
        Directory('${dir.path}/packages/dragonbones').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('could not find the repository root from ${Directory.current.path}');
}

/// A proxy that hears every event of every armature — including the nested ones,
/// which the factory builds mid-update, after any listener could have been
/// attached by hand.
class _CollectingProxy implements IArmatureProxy {
  _CollectingProxy(this.events, this.frame);

  final List<Map<String, Object?>> events;
  final int Function() frame;

  Armature? _armature;

  @override
  void dbInit(Armature armature) => _armature = armature;

  @override
  void dbClear() => _armature = null;

  @override
  void dbUpdate() {}

  @override
  Armature get armature => _armature!;

  @override
  Animation get animation => _armature!.animation;

  // Listen to everything: this is what makes the runtime build events at all.
  @override
  bool hasDBEventListener(String type) => true;

  @override
  void addDBEventListener(String type, void Function(EventObject event) listener) {}

  @override
  void removeDBEventListener(String type, void Function(EventObject event) listener) {}

  @override
  void dispatchDBEvent(String type, EventObject eventObject) {
    events.add(<String, Object?>{
      'frame': frame(),
      'type': type,
      'name': eventObject.name,
      'time': eventObject.time,
      'armature': eventObject.armature?.armatureData.name,
      'animationState': eventObject.animationState?.name,
      'bone': eventObject.bone?.name,
      'slot': eventObject.slot?.name,
    });
  }
}

/// Replays one scenario on this runtime. A fresh factory per scenario keeps them
/// independent: armatures — and their nested children — register on the hub's
/// clock, so reusing a hub would advance the previous scenario too.
List<Map<String, Object?>> _runPort(
  Directory root,
  String armatureName,
  String skeletonPath,
  String texturePath,
  String animation,
  int playTimes,
  double fps,
  int totalFrames,
) {
  final events = <Map<String, Object?>>[];
  var frame = 0;

  final factory = HeadlessFactory(null, () => _CollectingProxy(events, () => frame));

  // The reference harness installs a collecting event manager, and it matters:
  // the runtime dispatches every *sound* event twice — once on the armature and
  // once on this app-level manager, which is where an engine would hook audio.
  // Without it the port would look like it drops half the sounds.
  factory.dragonBones = DragonBones(_CollectingProxy(events, () => frame));
  final data = factory.parseDragonBonesData(
    jsonDecode(File('${root.path}/$skeletonPath').readAsStringSync()),
  );
  if (data == null) {
    throw StateError('$skeletonPath did not parse');
  }
  if (texturePath != '-') {
    factory.parseTextureAtlasData(
      jsonDecode(File('${root.path}/$texturePath').readAsStringSync()),
      null,
      data.name,
    );
  }

  final armature = factory.buildArmature(armatureName, data.name);
  if (armature == null) {
    throw StateError('$armatureName did not build');
  }

  armature.animation.play(animation, playTimes);
  for (var f = 0; f <= totalFrames; f++) {
    frame = f;
    factory.dragonBones.advanceTime(1.0 / fps);
  }

  return events;
}

/// Maps a reference dump back to the source files it was produced from.
({String skeleton, String texture})? _resolve(Directory root, File golden, Map<String, dynamic> meta) {
  final fixture = meta['fixture'] as String? ?? '';

  if (golden.path.contains('events__unity__')) {
    final dir = Directory('${root.path}/test/fixtures/unity/$fixture');
    if (!dir.existsSync()) return null;
    final skeletons = dir.listSync().whereType<File>().where((f) => f.path.endsWith('_ske.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (skeletons.isEmpty) return null;
    final skeleton = skeletons.first;
    final texture = File('${skeleton.path.substring(0, skeleton.path.length - '_ske.json'.length)}_tex.json');
    return (
      skeleton: _relative(root, skeleton),
      texture: texture.existsSync() ? _relative(root, texture) : '-',
    );
  }

  switch (fixture) {
    case 'Dragon':
      return (skeleton: 'test/fixtures/Dragon_ske.json', texture: 'test/fixtures/Dragon_tex.json');
    case '龙':
      return (skeleton: 'test/fixtures/龙_ske.json', texture: 'test/fixtures/龙_tex.json');
    case 'mecha_1004d':
      return (skeleton: 'example/assets/mecha_1004d/ske.json', texture: 'example/assets/mecha_1004d/tex.json');
  }
  return null;
}

String _relative(Directory root, File file) =>
    file.path.startsWith('${root.path}/') ? file.path.substring(root.path.length + 1) : file.path;

/// Human-readable one-line rendering of an event, for mismatch reports.
String _show(Map<String, dynamic> event) {
  final bits = <String>['f${event['frame']}'];
  for (final field in _fields) {
    final value = event[field];
    if (value != null && '$value'.isNotEmpty) bits.add('$field=$value');
  }
  bits.add('time=${event['time']}');
  return bits.join(' ');
}

/// Compares one event stream. Returns the number of mismatches found, appending
/// up to [limit] reports to [reports].
int _diff(
  String label,
  List<dynamic> golden,
  List<Map<String, Object?>> port,
  List<String> reports, {
  int limit = 6,
}) {
  var mismatches = 0;

  void report(String message) {
    mismatches++;
    if (reports.length < limit) reports.add('$label: $message');
  }

  if (golden.length != port.length) {
    report('event count differs — reference ${golden.length}, port ${port.length}');
  }

  final count = golden.length < port.length ? golden.length : port.length;
  for (var i = 0; i < count; i++) {
    final g = golden[i] as Map<String, dynamic>;
    final p = port[i];

    if (g['frame'] != p['frame']) {
      report('#$i frame differs — reference ${_show(g)} | port ${_show(p)}');
      continue;
    }

    for (final field in _fields) {
      final gv = g[field];
      final pv = p[field];
      if ((gv ?? '') != (pv ?? '')) {
        report('#$i $field differs — reference ${_show(g)} | port ${_show(p)}');
        break;
      }
    }

    final gt = (g['time'] as num).toDouble();
    final pt = (p['time'] as num).toDouble();
    if ((gt - pt).abs() > _epsilon) {
      report('#$i time differs — reference $gt, port $pt');
    }
  }

  return mismatches;
}

void main(List<String> args) {
  final root = _repoRoot();
  final outDir = Directory('${root.path}/tool/ground_truth/out');

  // Optional: a substring to filter the dumps by, and `--dump` to print both
  // streams side by side. Debugging aid — the full run diffs all 47.
  final filters = args.where((a) => !a.startsWith('--')).toList();
  final showStreams = args.contains('--dump');

  var goldenFiles = outDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && f.path.contains('events__'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (filters.isNotEmpty) {
    goldenFiles = goldenFiles.where((f) => filters.any((filter) => f.uri.pathSegments.last.contains(filter))).toList();
  }

  if (goldenFiles.isEmpty) {
    stderr.writeln('no event reference dumps in ${outDir.path}');
    stderr.writeln('run tool/ground_truth/run_events.sh first');
    exit(2);
  }

  var fixtureCount = 0;
  var scenarioCount = 0;
  var eventCount = 0;
  var mismatches = 0;
  final skipped = <String>[];

  for (final file in goldenFiles) {
    final golden = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final resolved = _resolve(root, file, golden);
    final name = file.uri.pathSegments.last;

    if (resolved == null) {
      skipped.add(name);
      continue;
    }

    final reports = <String>[];
    var fixtureMismatches = 0;
    var scenarios = 0;

    for (final raw in golden['scenarios'] as List<dynamic>) {
      final scenario = raw as Map<String, dynamic>;
      scenarios++;

      final reference = (scenario['events'] as List<dynamic>?) ?? const <dynamic>[];
      List<Map<String, Object?>> port;
      try {
        port = _runPort(
          root,
          golden['armatureName'] as String,
          resolved.skeleton,
          resolved.texture,
          scenario['animation'] as String,
          (scenario['playTimes'] as num).toInt(),
          (golden['frameRate'] as num).toDouble(),
          (scenario['totalFrames'] as num).toInt(),
        );
      } on Object catch (error, stack) {
        fixtureMismatches++;
        if (reports.length < 6) {
          reports.add('$name ${scenario['animation']} playTimes=${scenario['playTimes']}: threw $error\n'
              '${stack.toString().split('\n').take(6).join('\n')}');
        }
        continue;
      }

      eventCount += reference.length;
      final before = fixtureMismatches;
      fixtureMismatches += _diff(
        '$name ${scenario['animation']} playTimes=${scenario['playTimes']}',
        reference,
        port,
        reports,
        limit: showStreams ? 1000 : 6,
      );

      if (showStreams && fixtureMismatches != before) {
        print('--- reference ${scenario['animation']} playTimes=${scenario['playTimes']}');
        for (final event in reference) {
          print('    R ${_show(event as Map<String, dynamic>)}');
        }
        print('--- port');
        for (final event in port) {
          print('    P ${_show(event)}');
        }
      }
    }

    fixtureCount++;
    scenarioCount += scenarios;
    mismatches += fixtureMismatches;

    if (fixtureMismatches > 0) {
      print('FAIL ${golden['fixture']} ($fixtureMismatches mismatches over $scenarios scenarios)');
      for (final report in reports) {
        print('     $report');
      }
    }
  }

  print('');
  print('$fixtureCount fixtures, $scenarioCount scenarios, $eventCount reference events '
      'compared');
  if (skipped.isNotEmpty) {
    print('skipped ${skipped.length} dump(s) with no resolvable source: ${skipped.join(', ')}');
  }
  print(mismatches > 0 ? 'RESULT: FAIL ($mismatches mismatches)' : 'RESULT: PASS');
  if (mismatches > 0) exit(1);
}
