// Compares the pure-Dart DragonBones port against the reference dumps produced
// by the OFFICIAL DragonBones runtime (see tool/ground_truth/).
//
// Two things are checked, per frame:
//   1. every bone's global transform matrix,
//   2. every slot's draw data: world matrix, pivot, quad size, atlas region,
//      z-order, visibility, blend mode and colour.
//
// (2) is what makes the renderer verifiable without a GPU: if the geometry
// matches the official runtime, drawing it on a canvas is a thin, low-risk step.
//
// Run from anywhere:
//   dart run packages/dragonbones/tool/check_against_oracle.dart
//
// Exits non-zero if anything drifts beyond the tolerance.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

const double tolerance = 1e-4;
const int maxReported = 25;

double _r(num v) => v.toDouble();

List<Map<String, dynamic>> sampleFrames(HeadlessFactory factory, String? animation) {
  final armature = factory.buildArmature('Dragon', 'Dragon')!;
  if (animation != null) {
    armature.animation.play(animation);
  }

  final frameRate = armature.armatureData.frameRate;
  final state = armature.animation.lastAnimationState;
  final duration = state != null ? state.totalTime : 0.0;
  final lastFrame = (duration * frameRate).round();
  final frames = <Map<String, dynamic>>[];

  for (var f = 0; f <= (lastFrame < 1 ? 1 : lastFrame); f++) {
    if (f > 0) {
      armature.advanceTime(1.0 / frameRate);
    }

    final drawList = armature.buildDrawList();
    final drawBySlot = <String, SlotDrawData>{
      for (final d in drawList) d.slotName: d,
    };

    final slots = <Map<String, dynamic>>[];
    for (final slot in armature.getSlots()) {
      final d = drawBySlot[slot.name];
      slots.add(<String, dynamic>{
        'name': slot.name,
        'displayIndex': slot.displayIndex,
        if (d != null) 'matrix': <double>[
          d.matrix.a, d.matrix.b, d.matrix.c, d.matrix.d, d.matrix.tx, d.matrix.ty,
        ],
        if (d != null) 'pivot': <double>[d.pivotX, d.pivotY],
        if (d != null) 'quadSize': <double>[d.quadWidth, d.quadHeight],
        if (d != null) 'region': d.region,
        if (d != null) 'zOrder': d.zOrder,
        if (d != null) 'visible': d.visible,
        if (d != null) 'blendMode': d.blendMode,
        if (d != null) 'color': d.color,
      });
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
      'slots': slots,
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
  String toString() => '  $animation f$frame $what: expected $expected, '
      'got $actual (err ${error.toStringAsExponential(3)})';
}

/// Compares a numeric list field, reporting per-component mismatches.
void compareNumbers(
  List<Mismatch> out,
  String label,
  int frame,
  String what,
  List<dynamic>? got,
  List<dynamic>? want,
  void Function(double error) track,
) {
  if (want == null) return;
  if (got == null) {
    for (var i = 0; i < want.length; i++) {
      out.add(Mismatch(label, frame, '$what missing', _r(want[i] as num), double.nan));
    }
    return;
  }
  for (var i = 0; i < want.length; i++) {
    final wv = want[i];
    final gv = got[i];
    // A NaN on the oracle side means the harness could not read the field
    // (JSON.stringify turns NaN into null) — surface it instead of crashing.
    if (wv is! num) {
      out.add(Mismatch(label, frame, '$what[$i] unusable in oracle', 0, 0));
      continue;
    }
    if (gv is! num) {
      out.add(Mismatch(label, frame, '$what[$i] missing in port', _r(wv), double.nan));
      continue;
    }
    final err = (_r(gv) - _r(wv)).abs();
    track(err);
    if (err > tolerance && out.length < maxReported) {
      out.add(Mismatch(label, frame, '$what[$i]', _r(wv), _r(gv)));
    }
  }
}

void main() {
  final scriptPath = Platform.script.toFilePath();
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
  var comparisons = 0;

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

    final factory = HeadlessFactory();
    factory.parseDragonBonesData(skeRaw, 'Dragon');
    factory.parseTextureAtlasData(texRaw, null, 'Dragon');

    final frames = sampleFrames(factory, entry.value);
    if (frames.length != oracleFrames.length) {
      stderr.writeln('$label: FRAME COUNT MISMATCH — port ${frames.length}, '
          'oracle ${oracleFrames.length}');
      exit(1);
    }

    var maxError = 0.0;
    var slotFieldsCompared = 0;
    void track(double e) {
      comparisons++;
      if (e > maxError) maxError = e;
    }

    for (var f = 0; f < frames.length; f++) {
      final got = frames[f];
      final want = oracleFrames[f]['state'] as Map<String, dynamic>;

      final gotBones = (got['bones'] as List).cast<Map<String, dynamic>>();
      final wantBones = (want['bones'] as List).cast<Map<String, dynamic>>();
      if (gotBones.length != wantBones.length) {
        stderr.writeln('$label f$f: bone count ${gotBones.length} vs ${wantBones.length}');
        exit(1);
      }
      for (var b = 0; b < gotBones.length; b++) {
        if (gotBones[b]['name'] != wantBones[b]['name']) {
          stderr.writeln('$label f$f bone $b: name ${gotBones[b]['name']} '
              'vs ${wantBones[b]['name']}');
          exit(1);
        }
        compareNumbers(mismatches, label, f, 'bone ${gotBones[b]['name']}',
            gotBones[b]['matrix'] as List<dynamic>, wantBones[b]['matrix'] as List<dynamic>, track);
      }

      final gotSlots = (got['slots'] as List).cast<Map<String, dynamic>>();
      final wantSlots = (want['slots'] as List).cast<Map<String, dynamic>>();
      if (gotSlots.length != wantSlots.length) {
        stderr.writeln('$label f$f: slot count ${gotSlots.length} vs ${wantSlots.length}');
        exit(1);
      }
      for (var s = 0; s < gotSlots.length; s++) {
        final g = gotSlots[s], w = wantSlots[s];
        if (g['name'] != w['name']) {
          stderr.writeln('$label f$f slot $s: name ${g['name']} vs ${w['name']}');
          exit(1);
        }
        final prefix = 'slot ${g['name']}';
        compareNumbers(mismatches, label, f, '$prefix.player',
            g['matrix'] as List<dynamic>?, w['matrix'] as List<dynamic>?, track);
        compareNumbers(mismatches, label, f, '$prefix.pivot',
            g['pivot'] as List<dynamic>?, w['pivot'] as List<dynamic>?, track);
        compareNumbers(mismatches, label, f, '$prefix.quadSize',
            g['quadSize'] as List<dynamic>?, w['quadSize'] as List<dynamic>?, track);
        compareNumbers(mismatches, label, f, '$prefix.region',
            g['region'] as List<dynamic>?, w['region'] as List<dynamic>?, track);
        compareNumbers(mismatches, label, f, '$prefix.color',
            g['color'] as List<dynamic>?, w['color'] as List<dynamic>?, track);
        if (w['matrix'] != null) slotFieldsCompared++;
        if (g['zOrder'] != w['zOrder']) {
          mismatches.add(Mismatch(label, f, '$prefix.zOrder',
              _r(w['zOrder'] as num), _r(g['zOrder'] as num)));
        }
        if (g['visible'] != w['visible']) {
          mismatches.add(Mismatch(label, f, '$prefix.visible',
              (w['visible'] as bool) ? 1 : 0, (g['visible'] as bool) ? 1 : 0));
        }
        if (g['blendMode'] != w['blendMode']) {
          mismatches.add(Mismatch(label, f, '$prefix.blendMode',
              _r(w['blendMode'] as num), _r(g['blendMode'] as num)));
        }
        if (g['displayIndex'] != w['displayIndex']) {
          mismatches.add(Mismatch(label, f, '$prefix.displayIndex',
              _r(w['displayIndex'] as num), _r(g['displayIndex'] as num)));
        }
      }
    }

    stdout.writeln('  ${label.padRight(6)} ${frames.length.toString().padLeft(3)} frames, '
        '${(frames.first['bones'] as List).length} bones, $slotFieldsCompared slot draw-data, '
        'max err ${maxError.toStringAsExponential(3)}'
        '${maxError <= tolerance ? '  OK' : '  <-- FAIL'}');
  }

  stdout.writeln('');
  stdout.writeln('$comparisons numeric comparisons, ${mismatches.length} mismatches '
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
