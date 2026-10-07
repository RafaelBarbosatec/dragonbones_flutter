// Compares the pure-Dart DragonBones port against the reference dumps produced
// by the OFFICIAL DragonBones runtime (see tool/ground_truth/).
//
// Per frame it checks:
//   1. every bone's global transform matrix,
//   2. every slot's draw data: world matrix, pivot, quad size, atlas region,
//      z-order, visibility, blend mode and colour,
//   3. every mesh slot's posed vertices, UVs and triangle indices,
//   4. slots holding a nested armature: the child's slots, with the parent slot's
//      matrix composed onto them.
//
// (2)-(4) are what make the renderer verifiable without a GPU: if the geometry
// matches the official runtime, drawing it on a canvas is a thin, low-risk step.
//
// The sweep covers the hand-picked ladder (`Dragon`, `龙`, `mecha_1004d`) plus
// every demo asset from the DragonBones Unity SDK, discovered from the dumps in
// tool/ground_truth/out. A target that crashes is reported and the sweep
// continues, so one unsupported asset cannot hide the state of the rest.
//
// Run from anywhere:
//   dart run packages/dragonbones/tool/check_against_oracle.dart
//   dart run packages/dragonbones/tool/check_against_oracle.dart --verbose
//
// Exits non-zero if anything drifts beyond the tolerance, crashes, or is
// missing a dump.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

const double tolerance = 1e-4;
const int maxReported = 25;

var verbose = false;

double _r(num v) => v.toDouble();

/// One oracle dump to check, and how to reproduce the state it captures.
class Target {
  const Target(this.dump, this.skeletonPath, this.texturePath, this.armature, this.animation, this.label);

  final String dump;

  /// Paths relative to the repository root (the fixtures and the example assets
  /// live in different layouts).
  final String skeletonPath;
  final String texturePath;

  /// Armature to build. `null` means "the first one the asset declares".
  final String? armature;

  /// Animation to play. `'auto'` means "the first one the asset declares",
  /// mirroring what `tool/ground_truth/dump.js auto` does.
  final String? animation;

  final String label;
}

const String _fixtures = 'test/fixtures';
const String _unity = '$_fixtures/unity';
const String _mecha = 'example/assets/mecha_1004d';

const List<Target> namedTargets = <Target>[
  Target('Dragon_rest', '$_fixtures/Dragon_ske.json', '$_fixtures/Dragon_tex.json', 'Dragon', null, 'rest'),
  Target('Dragon_stand', '$_fixtures/Dragon_ske.json', '$_fixtures/Dragon_tex.json', 'Dragon', 'stand', 'stand'),
  Target('Dragon_walk', '$_fixtures/Dragon_ske.json', '$_fixtures/Dragon_tex.json', 'Dragon', 'walk', 'walk'),
  Target('Dragon_jump', '$_fixtures/Dragon_ske.json', '$_fixtures/Dragon_tex.json', 'Dragon', 'jump', 'jump'),
  Target('Dragon_fall', '$_fixtures/Dragon_ske.json', '$_fixtures/Dragon_tex.json', 'Dragon', 'fall', 'fall'),
  // 60 bones, 5 deformable meshes (2 of them skinned), FFD timelines.
  Target('Long_stand', '$_fixtures/龙_ske.json', '$_fixtures/龙_tex.json', 'armatureName', 'stand', 'long'),
  // Four armatures in one file, three of them nested inside slots of the first —
  // this is what exercises the child-armature flattening.
  Target('Mecha_walk', '$_mecha/ske.json', '$_mecha/tex.json', 'mecha_1004d', 'walk', 'mecha'),
];

/// One entry per `out/unity__*.json`, resolved back to its source files.
///
/// The dump records the fixture id (its path under `test/fixtures/unity`); the
/// skeleton file inside is found by glob, because some assets are named
/// differently from their directory (`mecha_1002_101d_light` ships
/// `mecha_1002_101d_show_ske.json`).
List<Target> discoverUnityTargets(String repoRoot) {
  final outDir = Directory('$repoRoot/tool/ground_truth/out');
  if (!outDir.existsSync()) return const <Target>[];

  final dumps = outDir.listSync().whereType<File>().where((f) => f.uri.pathSegments.last.startsWith('unity__')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final targets = <Target>[];
  for (final dump in dumps) {
    final stem = dump.uri.pathSegments.last.replaceAll('.json', '');
    final Map<String, dynamic> meta;
    try {
      meta = jsonDecode(dump.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }

    final fixture = meta['fixture'] as String? ?? stem.substring('unity__'.length);
    final dir = Directory('$repoRoot/$_unity/$fixture');
    if (!dir.existsSync()) continue;

    final skeletons = dir.listSync().whereType<File>().where((f) => f.path.endsWith('_ske.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (skeletons.isEmpty) continue;

    final skeleton = skeletons.first;
    final texture = File('${skeleton.path.substring(0, skeleton.path.length - '_ske.json'.length)}_tex.json');

    targets.add(Target(
      stem,
      _relative(repoRoot, skeleton.path),
      texture.existsSync() ? _relative(repoRoot, texture.path) : '-',
      null,
      'auto',
      fixture,
    ));
  }
  return targets;
}

String _relative(String repoRoot, String path) {
  final prefix = repoRoot.endsWith('/') ? repoRoot : '$repoRoot/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

/// Samples the same frames the dump does: frame 0 is the state right after
/// `buildArmature`, and each later frame advances by exactly one frame.
List<Map<String, dynamic>> sampleFrames(
  HeadlessFactory factory,
  String dataName,
  Target target,
) {
  // `null` armature means "the first one the asset declares", matching dump.js.
  final armatureName = target.armature ?? factory.getDragonBonesData(dataName)!.armatureNames.first;
  final built = factory.buildArmature(armatureName, dataName, '')!;

  final animationNames = built.armatureData.animationNames;
  var animation = target.animation;
  if (animation == 'auto') {
    animation = animationNames.isEmpty ? null : animationNames.first;
  }
  if (animation != null) {
    built.animation.play(animation);
  }

  final frameRate = built.armatureData.frameRate;
  final state = built.animation.lastAnimationState;
  final duration = state != null ? state.totalTime : 0.0;
  final lastFrame = (duration * frameRate).round();
  final frames = <Map<String, dynamic>>[];

  for (var f = 0; f <= (lastFrame < 1 ? 1 : lastFrame); f++) {
    if (f > 0) {
      built.advanceTime(1.0 / frameRate);
    }

    final drawList = built.buildDrawList();
    final drawBySlot = <String, List<SlotDrawData>>{};
    for (final d in drawList) {
      drawBySlot.putIfAbsent(d.slotName, () => <SlotDrawData>[]).add(d);
    }

    final slots = <Map<String, dynamic>>[];
    for (final slot in built.getSlots()) {
      final entries = drawBySlot[slot.name] ?? const <SlotDrawData>[];
      final d = entries.isEmpty ? null : entries.first;
      slots.add(<String, dynamic>{
        'name': slot.name,
        'displayIndex': slot.displayIndex,
        if (d != null)
          'matrix': <double>[
            d.matrix.a,
            d.matrix.b,
            d.matrix.c,
            d.matrix.d,
            d.matrix.tx,
            d.matrix.ty,
          ],
        if (d != null) 'pivot': <double>[d.pivotX, d.pivotY],
        if (d != null) 'quadSize': <double>[d.quadWidth, d.quadHeight],
        if (d != null) 'region': d.region,
        if (d != null) 'zOrder': d.zOrder,
        if (d != null) 'visible': d.visible,
        if (d != null) 'blendMode': d.blendMode,
        if (d != null) 'color': d.color,
        if (d != null && d.mesh != null)
          'mesh': <String, dynamic>{
            'vertexCount': d.mesh!.vertexCount,
            'triangleCount': d.mesh!.triangleCount,
            'vertices': d.mesh!.vertices,
            'uvs': d.mesh!.uvs,
            'indices': d.mesh!.triangles,
          },
      });
    }

    frames.add(<String, dynamic>{
      'bones': <Map<String, dynamic>>[
        for (final bone in built.getBones())
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
      'drawBySlot': drawBySlot,
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
  if (got.length != want.length) {
    out.add(Mismatch(label, frame, '$what length', want.length.toDouble(), got.length.toDouble()));
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

/// Compares triangle indices, which must match exactly — a wrong index means a
/// hole in the mesh, not a rounding difference.
void compareIndices(
  List<Mismatch> out,
  String label,
  int frame,
  String what,
  List<dynamic>? got,
  List<dynamic>? want,
  void Function(double error) track,
) {
  if (want == null) return;
  if (got == null || got.length != want.length) {
    out.add(Mismatch(label, frame, '$what length', want.length.toDouble(), (got?.length ?? 0).toDouble()));
    return;
  }
  for (var i = 0; i < want.length; i++) {
    final wv = _r(want[i] as num);
    final gv = _r(got[i] as num);
    track((gv - wv).abs());
    if (gv != wv && out.length < maxReported) {
      out.add(Mismatch(label, frame, '$what[$i]', wv, gv));
    }
  }
}

/// `first ∘ second` in the runtime's own convention: apply [second], then
/// [first]. Written out longhand on purpose — using the port's `Matrix` here
/// would just re-run the code under test.
///
/// A matrix is `[a, b, c, d, tx, ty]` mapping `x' = a*x + c*y + tx`,
/// `y' = b*x + d*y + ty`.
List<double> compose(List<double> first, List<double> second) {
  final pa = first[0], pb = first[1], pc = first[2], pd = first[3];
  final ptx = first[4], pty = first[5];
  final la = second[0], lb = second[1], lc = second[2], ld = second[3];
  final ltx = second[4], lty = second[5];

  return <double>[
    pa * la + pc * lb,
    pb * la + pd * lb,
    pa * lc + pc * ld,
    pb * lc + pd * ld,
    pa * ltx + pc * lty + ptx,
    pb * ltx + pd * lty + pty,
  ];
}

class TargetResult {
  TargetResult(this.label);

  final String label;
  var frames = 0;
  var bones = 0;
  var slotFields = 0;
  var meshValues = 0;
  var childSlots = 0;
  var maxError = 0.0;
  var comparisons = 0;
  final List<Mismatch> mismatches = <Mismatch>[];
  String? crash;

  bool get ok => crash == null && mismatches.isEmpty;
}

void printResult(TargetResult r) {
  final meshNote = r.meshValues > 0 ? ', ${r.meshValues} mesh values' : '';
  final childNote = r.childSlots > 0 ? ', ${r.childSlots} child slots' : '';

  if (r.crash != null) {
    stdout.writeln('  ${r.label.padRight(28)} CRASHED: ${r.crash}');
  } else if (r.mismatches.isNotEmpty) {
    stdout.writeln('  ${r.label.padRight(28)} '
        '${r.frames.toString().padLeft(3)} frames, ${r.bones} bones$meshNote$childNote, '
        'max err ${r.maxError.toStringAsExponential(3)}  <-- FAIL');
  } else {
    stdout.writeln('  ${r.label.padRight(28)} '
        '${r.frames.toString().padLeft(3)} frames, ${r.bones} bones, '
        '${r.slotFields} slot draw-data$meshNote$childNote, '
        'max err ${r.maxError.toStringAsExponential(3)}  OK');
  }
}

void main(List<String> args) {
  verbose = args.contains('--verbose');

  final scriptPath = Platform.script.toFilePath();
  final repoRoot = Directory(scriptPath).parent.parent.parent.parent.path;
  final outDir = Directory('$repoRoot/tool/ground_truth/out');

  if (!outDir.existsSync()) {
    stderr.writeln('Oracle dumps not found at ${outDir.path}.'
        '\nRun tool/ground_truth/fetch_runtime.sh && tool/ground_truth/run_all.sh');
    exit(2);
  }

  final targets = <Target>[
    ...namedTargets,
    ...discoverUnityTargets(repoRoot),
  ];

  final results = <TargetResult>[];

  for (final target in targets) {
    final result = TargetResult(target.label);
    results.add(result);

    final oracleFile = File('${outDir.path}/${target.dump}.json');
    if (!oracleFile.existsSync()) {
      result.crash = 'missing oracle ${oracleFile.path}';
      continue;
    }

    try {
      final oracle = jsonDecode(oracleFile.readAsStringSync()) as Map<String, dynamic>;
      final oracleFrames = (oracle['frames'] as List).cast<Map<String, dynamic>>();

      final factory = HeadlessFactory();
      final data = factory.parseDragonBonesData(
        jsonDecode(File('$repoRoot/${target.skeletonPath}').readAsStringSync()),
      )!;
      if (target.texturePath != '-') {
        factory.parseTextureAtlasData(
          jsonDecode(File('$repoRoot/${target.texturePath}').readAsStringSync()),
          null,
          data.name,
        );
      }

      void track(double e) {
        result.comparisons++;
        if (e > result.maxError) result.maxError = e;
      }

      // Any drift found beyond the report cap is still surfaced via maxError, but
      // for a PASS/FAIL verdict a single unrecorded mismatch must not slip by.
      var anyMismatch = false;

      final frames = sampleFrames(factory, data.name, target);
      result.frames = frames.length;
      if (frames.length != oracleFrames.length) {
        result.crash = 'frame count: port ${frames.length}, oracle ${oracleFrames.length}';
        continue;
      }

      for (var f = 0; f < frames.length; f++) {
        final got = frames[f];
        final want = oracleFrames[f]['state'] as Map<String, dynamic>;

        final gotBones = (got['bones'] as List).cast<Map<String, dynamic>>();
        final wantBones = (want['bones'] as List).cast<Map<String, dynamic>>();
        result.bones = gotBones.length;
        if (gotBones.length != wantBones.length) {
          result.crash = 'bone count ${gotBones.length} vs ${wantBones.length}';
          break;
        }

        for (var b = 0; b < gotBones.length; b++) {
          if (gotBones[b]['name'] != wantBones[b]['name']) {
            result.crash = 'bone $b name ${gotBones[b]['name']} vs ${wantBones[b]['name']}';
            break;
          }
          compareNumbers(result.mismatches, target.label, f, 'bone ${gotBones[b]['name']}',
              gotBones[b]['matrix'] as List<dynamic>, wantBones[b]['matrix'] as List<dynamic>, track);
        }
        if (result.crash != null) break;

        final gotSlots = (got['slots'] as List).cast<Map<String, dynamic>>();
        final wantSlots = (want['slots'] as List).cast<Map<String, dynamic>>();
        if (gotSlots.length != wantSlots.length) {
          result.crash = 'slot count ${gotSlots.length} vs ${wantSlots.length}';
          break;
        }
        final drawBySlot = got['drawBySlot'] as Map<String, List<SlotDrawData>>;

        for (var s = 0; s < gotSlots.length; s++) {
          final g = gotSlots[s], w = wantSlots[s];
          if (g['name'] != w['name']) {
            result.crash = 'slot $s name ${g['name']} vs ${w['name']}';
            break;
          }
          final prefix = 'slot ${g['name']}';

          // displayIndex lives on the runtime slot, not on the draw entry, so it
          // is checked even for a slot that draws nothing at all.
          if (g['displayIndex'] != w['displayIndex']) {
            anyMismatch = true;
            result.mismatches.add(Mismatch(
                target.label, f, '$prefix.displayIndex', _r(w['displayIndex'] as num), _r(g['displayIndex'] as num)));
          }

          // ---- nested armature ------------------------------------------
          // A slot holding a nested armature draws nothing itself: it contributes
          // the child's slots instead, with its own matrix composed onto theirs.
          final wChildren = w['childSlots'] as List<dynamic>?;
          if (wChildren != null) {
            final parentMatrix = <double>[for (final v in (w['matrix'] as List<dynamic>)) _r(v as num)];

            for (final child in wChildren.cast<Map<String, dynamic>>()) {
              final childName = child['name'] as String;
              final childMatrix = <double>[for (final v in (child['matrix'] as List<dynamic>)) _r(v as num)];
              // `parent ∘ child`, composed longhand — see [compose].
              final expected = compose(parentMatrix, childMatrix);

              // The same child armature can be mounted on more than one slot (and
              // its slot names repeat), so the entry is identified by the composed
              // matrix, not by name alone.
              final entries = drawBySlot[childName] ?? const <SlotDrawData>[];
              SlotDrawData? entry;
              for (final candidate in entries) {
                final c = <double>[
                  candidate.matrix.a,
                  candidate.matrix.b,
                  candidate.matrix.c,
                  candidate.matrix.d,
                  candidate.matrix.tx,
                  candidate.matrix.ty,
                ];
                var matches = true;
                for (var i = 0; i < 6; i++) {
                  if ((c[i] - expected[i]).abs() > 1e-3) {
                    matches = false;
                    break;
                  }
                }
                if (matches) {
                  entry = candidate;
                  break;
                }
              }
              if (entry == null) {
                anyMismatch = true;
                result.mismatches.add(Mismatch(target.label, f, 'child slot $childName missing', 0, 0));
                continue;
              }
              compareNumbers(
                  result.mismatches,
                  target.label,
                  f,
                  'child $childName.matrix',
                  <double>[
                    entry.matrix.a,
                    entry.matrix.b,
                    entry.matrix.c,
                    entry.matrix.d,
                    entry.matrix.tx,
                    entry.matrix.ty,
                  ],
                  expected,
                  track);
              // The child draws in its parent slot's place in the order.
              if (entry.zOrder != w['zOrder']) {
                anyMismatch = true;
                result.mismatches.add(Mismatch(
                    target.label, f, 'child $childName.zOrder', _r(w['zOrder'] as num), _r(entry.zOrder as num)));
              }
              result.childSlots++;
            }
            continue;
          }

          // ---- sprite / mesh draw data -----------------------------------
          final gMatrix = g['matrix'] as List<dynamic>?;
          if (gMatrix == null) {
            // The port omits the slot entirely. That is correct only when the
            // oracle agrees there is no drawable display there either (a slot
            // whose display index is -1, for instance).
            if (w['textureName'] != null || w['mesh'] != null) {
              anyMismatch = true;
              result.mismatches.add(Mismatch(target.label, f, '$prefix missing in port', 0, 0));
            }
            continue;
          }

          compareNumbers(
              result.mismatches, target.label, f, '$prefix.player', gMatrix, w['matrix'] as List<dynamic>?, track);
          compareNumbers(result.mismatches, target.label, f, '$prefix.pivot', g['pivot'] as List<dynamic>?,
              w['pivot'] as List<dynamic>?, track);
          // A mesh has no quad: its extent comes from the posed triangle list,
          // not from the atlas region. The port reports 0 there on purpose, so
          // only sprites are compared on this field.
          if (w['mesh'] == null) {
            compareNumbers(result.mismatches, target.label, f, '$prefix.quadSize', g['quadSize'] as List<dynamic>?,
                w['quadSize'] as List<dynamic>?, track);
          }
          compareNumbers(result.mismatches, target.label, f, '$prefix.region', g['region'] as List<dynamic>?,
              w['region'] as List<dynamic>?, track);
          compareNumbers(result.mismatches, target.label, f, '$prefix.color', g['color'] as List<dynamic>?,
              w['color'] as List<dynamic>?, track);
          result.slotFields++;
          if (g['zOrder'] != w['zOrder']) {
            anyMismatch = true;
            result.mismatches
                .add(Mismatch(target.label, f, '$prefix.zOrder', _r(w['zOrder'] as num), _r(g['zOrder'] as num)));
          }
          if (g['visible'] != w['visible']) {
            anyMismatch = true;
            result.mismatches.add(Mismatch(
                target.label, f, '$prefix.visible', (w['visible'] as bool) ? 1 : 0, (g['visible'] as bool) ? 1 : 0));
          }
          if (g['blendMode'] != w['blendMode']) {
            anyMismatch = true;
            result.mismatches.add(
                Mismatch(target.label, f, '$prefix.blendMode', _r(w['blendMode'] as num), _r(g['blendMode'] as num)));
          }

          // ---- mesh geometry --------------------------------------------
          final wMesh = w['mesh'] as Map<String, dynamic>?;
          if (wMesh != null) {
            final gMesh = g['mesh'] as Map<String, dynamic>?;
            if (gMesh == null) {
              anyMismatch = true;
              result.mismatches.add(Mismatch(target.label, f, '$prefix.mesh missing', 0, 0));
            } else {
              if (wMesh['vertexCount'] != gMesh['vertexCount']) {
                anyMismatch = true;
                result.mismatches.add(Mismatch(target.label, f, '$prefix.mesh.vertexCount',
                    _r(wMesh['vertexCount'] as num), _r(gMesh['vertexCount'] as num)));
              }
              if (wMesh['triangleCount'] != gMesh['triangleCount']) {
                anyMismatch = true;
                result.mismatches.add(Mismatch(target.label, f, '$prefix.mesh.triangleCount',
                    _r(wMesh['triangleCount'] as num), _r(gMesh['triangleCount'] as num)));
              }
              compareNumbers(result.mismatches, target.label, f, '$prefix.mesh.vertices',
                  gMesh['vertices'] as List<dynamic>?, wMesh['vertices'] as List<dynamic>?, track);
              compareNumbers(result.mismatches, target.label, f, '$prefix.mesh.uvs', gMesh['uvs'] as List<dynamic>?,
                  wMesh['uvs'] as List<dynamic>?, track);
              compareIndices(result.mismatches, target.label, f, '$prefix.mesh.indices',
                  gMesh['indices'] as List<dynamic>?, wMesh['indices'] as List<dynamic>?, track);
              result.meshValues += (wMesh['vertices'] as List).length + 1;
            }
          }
        }
        if (result.crash != null) break;
      }

      if (anyMismatch && result.mismatches.isEmpty) {
        // Beyond the report cap: still a failure, just not itemised.
        result.mismatches.add(Mismatch(target.label, 0, 'more mismatches than reported', 0, 0));
      }
    } catch (error, stack) {
      result.crash = '$error';
      if (verbose) stdout.writeln(stack);
    }

    // Printed as we go: a sweep this wide must stream, or a single slow asset
    // looks exactly like a hang.
    printResult(result);
  }

  // ------------------------------------------------------------------ report
  var totalComparisons = 0;
  var totalMeshValues = 0;
  var totalChildSlots = 0;
  final failures = <TargetResult>[];

  for (final r in results) {
    totalComparisons += r.comparisons;
    totalMeshValues += r.meshValues;
    totalChildSlots += r.childSlots;
    if (!r.ok) failures.add(r);
  }

  stdout.writeln('');
  stdout.writeln('$totalComparisons numeric comparisons over ${results.length} assets '
      '(${results.length - failures.length} clean, ${failures.length} failing)');
  stdout.writeln('$totalMeshValues mesh values, $totalChildSlots nested-armature slots');

  if (failures.isNotEmpty) {
    stdout.writeln('\nFailing assets: ${failures.map((f) => f.label).join(', ')}');
    stdout.writeln('\nFirst mismatches:');
    for (final f in failures) {
      if (f.crash != null) continue;
      for (final m in f.mismatches) {
        stdout.writeln(m);
      }
    }
    stdout.writeln('\nRESULT: FAIL');
    exit(1);
  }

  stdout.writeln('RESULT: PASS');
}
