// Compares the pure-Dart DragonBones port against the reference dumps produced
// by the OFFICIAL DragonBones runtime (see tool/ground_truth/).
//
// Run from anywhere:
//   dart run packages/dragonbones/tool/check_against_oracle.dart
//
// Exits non-zero if any animation drifts beyond the tolerance.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

const double tolerance = 1e-4;

/// Frame 0 is the state right after `buildArmature` + `play(name)`, with no time
/// advance; each following frame advances by exactly 1/frameRate.
List<Map<String, dynamic>> sampleFrames(
  HeadlessFactory factory,
  String fixtureSke,
  String? animation,
) {
  final armature = factory.buildArmature('Dragon', 'Dragon')!;
  if (animation != null) {
    armature.animation.play(animation);
  }

  final frameRate = armature.armatureData.frameRate;
  final state = armature.animation.lastAnimationState;
  final duration = state != null ? state.totalTime : 0.0;
  final totalFrames = duration * frameRate;
  final frameCount = totalFrames.round();
  final frames = <Map<String, dynamic>>[];

  for (var f = 0; f <= (frameCount < 1 ? 1 : frameCount); f++) {
    if (f > 0) {
      armature.advanceTime(1.0 / frameRate);
    }
    frames.add(<String, dynamic>{
      'bones': <Map<String, dynamic>>[
        for (final bone in armature.getBones())
          <String, dynamic>{
            'name': bone.name,
            'matrix': <double>[
              bone.globalTransformMatrix.a,
              bone.globalTransformMatrix.b,
              bone.globalTransformMatrix.c,
              bone.globalTransformMatrix.d,
              bone.globalTransformMatrix.tx,
              bone.globalTransformMatrix.ty,
            ],
          },
      ],
      'slots': <Map<String, dynamic>>[
        for (final slot in armature.getSlots())
          <String, dynamic>{
            'name': slot.name,
            'displayIndex': slot.displayIndex,
          },
      ],
    });
  }

  return frames;
}

class Mismatch {
  Mismatch(this.animation, this.frame, this.what, this.expected, this.actual);
  final String animation;
  final int frame;
  final String what;
  final double expected;
  final double actual;

  double get error => (expected - actual).abs();

  @override
  String toString() =>
      '  $animation f$frame $what: expected $expected, got $actual '
      '(err ${error.toStringAsExponential(3)})';
}

void main() {
  final scriptPath = Platform.script.toFilePath();
  // <repo>/packages/dragonbones/tool/check_against_oracle.dart
  final repoRoot = Directory(scriptPath).parent.parent.parent.parent.path;
  final outDir = Directory('$repoRoot/tool/ground_truth/out');
  final fixtures = Directory('$repoRoot/test/fixtures');

  if (!outDir.existsSync()) {
    stderr.writeln('Oracle dumps not found at ${outDir.path}.'
        '\nRun tool/ground_truth/fetch_runtime.sh && tool/ground_truth/run_all.sh');
    exit(2);
  }

  final skeRaw = jsonDecode(File('${fixtures.path}/Dragon_ske.json').readAsStringSync());
  final texRaw = jsonDecode(File('${fixtures.path}/Dragon_tex.json').readAsStringSync());

  final mismatches = <Mismatch>[];
  var totalComparisons = 0;

  // null => the rest pose (no play()).
  const targets = <String, String?>{
    'Dragon_rest': null,
    'Dragon_stand': 'stand',
    'Dragon_walk': 'walk',
    'Dragon_jump': 'jump',
    'Dragon_fall': 'fall',
  };

  for (final entry in targets.entries) {
    final oracleFile = File('${outDir.path}/${entry.key}.json');
    if (!oracleFile.existsSync()) {
      stderr.writeln('missing oracle: ${oracleFile.path}');
      exit(2);
    }
    final oracle = jsonDecode(oracleFile.readAsStringSync()) as Map<String, dynamic>;
    final oracleFrames = (oracle['frames'] as List).cast<Map<String, dynamic>>();
    final label = entry.value ?? 'rest';

    // Fresh factory per target, mirroring the harness.
    final factory = HeadlessFactory();
    factory.parseDragonBonesData(skeRaw, 'Dragon');
    factory.parseTextureAtlasData(texRaw, null, 'Dragon');

    final frames = sampleFrames(factory, 'Dragon_ske.json', entry.value);

    if (frames.length != oracleFrames.length) {
      stderr.writeln(
          '$label: FRAME COUNT MISMATCH — port ${frames.length}, oracle ${oracleFrames.length}');
      exit(1);
    }

    var maxError = 0.0;
    for (var f = 0; f < frames.length; f++) {
      final got = frames[f];
      final want = oracleFrames[f]['state'] as Map<String, dynamic>;
      final wantBones = (want['bones'] as List).cast<Map<String, dynamic>>();
      final wantSlots = (want['slots'] as List).cast<Map<String, dynamic>>();

      final gotBones = (got['bones'] as List).cast<Map<String, dynamic>>();
      final gotSlots = (got['slots'] as List).cast<Map<String, dynamic>>();

      if (gotBones.length != wantBones.length) {
        stderr.writeln('$label f$f: bone count ${gotBones.length} vs ${wantBones.length}');
        exit(1);
      }

      for (var b = 0; b < gotBones.length; b++) {
        final g = gotBones[b], w = wantBones[b];
        if (g['name'] != w['name']) {
          stderr.writeln('$label f$f bone $b: name ${g['name']} vs ${w['name']}');
          exit(1);
        }
        final gm = (g['matrix'] as List).cast<num>();
        final wm = (w['matrix'] as List).cast<num>();
        for (var i = 0; i < 6; i++) {
          totalComparisons++;
          final err = (gm[i].toDouble() - wm[i].toDouble()).abs();
          if (err > maxError) maxError = err;
          if (err > tolerance && mismatches.length < 40) {
            mismatches.add(Mismatch(label, f, '${g['name']}.m$i',
                wm[i].toDouble(), gm[i].toDouble()));
          }
        }
      }

      for (var s = 0; s < gotSlots.length; s++) {
        final g = gotSlots[s], w = wantSlots[s];
        if (g['name'] != w['name']) {
          stderr.writeln('$label f$f slot $s: name ${g['name']} vs ${w['name']}');
          exit(1);
        }
        totalComparisons++;
        if (g['displayIndex'] != w['displayIndex']) {
          mismatches.add(Mismatch(label, f, '${g['name']}.displayIndex',
              (w['displayIndex'] as num).toDouble(), (g['displayIndex'] as num).toDouble()));
        }
      }
    }

    stdout.writeln('  ${label.padRight(6)} ${frames.length.toString().padLeft(3)} frames, '
        '${frames.first['bones'] is List ? (frames.first['bones'] as List).length : 0} bones, '
        'max error ${maxError.toStringAsExponential(3)}'
        '${maxError <= tolerance ? '  OK' : '  <-- FAIL'}');
  }

  stdout.writeln('');
  stdout.writeln('$totalComparisons comparisons, ${mismatches.length} mismatches '
      '(tolerance $tolerance)');
  if (mismatches.isNotEmpty) {
    stdout.writeln('\nFirst mismatches:');
    for (final m in mismatches) {
      stdout.writeln(m);
    }
    stdout.writeln('\nRESULT: FAIL');
    exit(1);
  }
  stdout.writeln('RESULT: PASS');
}
