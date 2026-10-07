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

/// One oracle dump to check, and how to reproduce the state it captures.
class Target {
  const Target(this.dump, this.skeletonPath, this.texturePath, this.armature,
      this.animation, this.label);

  final String dump;

  /// Paths relative to the repository root (the fixtures and the example assets
  /// live in different layouts).
  final String skeletonPath;
  final String texturePath;
  final String armature;
  final String? animation;
  final String label;
}

const String _fixtures = 'test/fixtures';
const String _mecha = 'example/assets/mecha_1004d';

const List<Target> targets = <Target>[
  Target('Dragon_rest', '$_fixtures/Dragon_ske.json',
      '$_fixtures/Dragon_tex.json', 'Dragon', null, 'rest'),
  Target('Dragon_stand', '$_fixtures/Dragon_ske.json',
      '$_fixtures/Dragon_tex.json', 'Dragon', 'stand', 'stand'),
  Target('Dragon_walk', '$_fixtures/Dragon_ske.json',
      '$_fixtures/Dragon_tex.json', 'Dragon', 'walk', 'walk'),
  Target('Dragon_jump', '$_fixtures/Dragon_ske.json',
      '$_fixtures/Dragon_tex.json', 'Dragon', 'jump', 'jump'),
  Target('Dragon_fall', '$_fixtures/Dragon_ske.json',
      '$_fixtures/Dragon_tex.json', 'Dragon', 'fall', 'fall'),
  // 60 bones, 5 deformable meshes (2 of them skinned), FFD timelines.
  Target('Long_stand', '$_fixtures/龙_ske.json', '$_fixtures/龙_tex.json',
      'armatureName', 'stand', 'long'),
  // Four armatures in one file, three of them nested inside slots of the first —
  // this is what exercises the child-armature flattening.
  Target('Mecha_walk', '$_mecha/ske.json', '$_mecha/tex.json', 'mecha_1004d',
      'walk', 'mecha'),
];

/// Samples the same frames the dump does: frame 0 is the state right after
/// `buildArmature`, and each later frame advances by exactly one frame.
List<Map<String, dynamic>> sampleFrames(
  HeadlessFactory factory,
  String dataName,
  String armatureName,
  String? animation,
) {
  final built = factory.buildArmature(armatureName, dataName, '')!;
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
      out.add(Mismatch(
          label, frame, '$what missing', _r(want[i] as num), double.nan));
    }
    return;
  }
  if (got.length != want.length) {
    out.add(Mismatch(label, frame, '$what length', want.length.toDouble(),
        got.length.toDouble()));
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
      out.add(Mismatch(
          label, frame, '$what[$i] missing in port', _r(wv), double.nan));
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
    out.add(Mismatch(label, frame, '$what length', want.length.toDouble(),
        (got?.length ?? 0).toDouble()));
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

void main() {
  final scriptPath = Platform.script.toFilePath();
  final repoRoot = Directory(scriptPath).parent.parent.parent.parent.path;
  final outDir = Directory('$repoRoot/tool/ground_truth/out');

  if (!outDir.existsSync()) {
    stderr.writeln('Oracle dumps not found at ${outDir.path}.'
        '\nRun tool/ground_truth/fetch_runtime.sh && tool/ground_truth/run_all.sh');
    exit(2);
  }

  final mismatches = <Mismatch>[];
  var comparisons = 0;
  var meshComparisonCount = 0;
  var childComparisonCount = 0;

  for (final target in targets) {
    final oracleFile = File('${outDir.path}/${target.dump}.json');
    if (!oracleFile.existsSync()) {
      stderr.writeln('missing oracle: ${oracleFile.path}');
      exit(2);
    }
    final oracle =
        jsonDecode(oracleFile.readAsStringSync()) as Map<String, dynamic>;
    final oracleFrames =
        (oracle['frames'] as List).cast<Map<String, dynamic>>();
    final label = target.label;

    final skeRaw =
        jsonDecode(File('$repoRoot/${target.skeletonPath}').readAsStringSync());
    final texRaw =
        jsonDecode(File('$repoRoot/${target.texturePath}').readAsStringSync());

    final factory = HeadlessFactory();
    final data = factory.parseDragonBonesData(skeRaw)!;
    factory.parseTextureAtlasData(texRaw, null, data.name);

    final frames =
        sampleFrames(factory, data.name, target.armature, target.animation);
    if (frames.length != oracleFrames.length) {
      stderr.writeln('$label: FRAME COUNT MISMATCH — port ${frames.length}, '
          'oracle ${oracleFrames.length}');
      exit(1);
    }

    var maxError = 0.0;
    var slotFieldsCompared = 0;
    var meshValuesHere = 0;
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
        stderr.writeln(
            '$label f$f: bone count ${gotBones.length} vs ${wantBones.length}');
        exit(1);
      }
      for (var b = 0; b < gotBones.length; b++) {
        if (gotBones[b]['name'] != wantBones[b]['name']) {
          stderr.writeln('$label f$f bone $b: name ${gotBones[b]['name']} '
              'vs ${wantBones[b]['name']}');
          exit(1);
        }
        compareNumbers(
            mismatches,
            label,
            f,
            'bone ${gotBones[b]['name']}',
            gotBones[b]['matrix'] as List<dynamic>,
            wantBones[b]['matrix'] as List<dynamic>,
            track);
      }

      final gotSlots = (got['slots'] as List).cast<Map<String, dynamic>>();
      final wantSlots = (want['slots'] as List).cast<Map<String, dynamic>>();
      if (gotSlots.length != wantSlots.length) {
        stderr.writeln(
            '$label f$f: slot count ${gotSlots.length} vs ${wantSlots.length}');
        exit(1);
      }
      final drawBySlot = got['drawBySlot'] as Map<String, List<SlotDrawData>>;

      for (var s = 0; s < gotSlots.length; s++) {
        final g = gotSlots[s], w = wantSlots[s];
        if (g['name'] != w['name']) {
          stderr
              .writeln('$label f$f slot $s: name ${g['name']} vs ${w['name']}');
          exit(1);
        }
        final prefix = 'slot ${g['name']}';

        // displayIndex lives on the runtime slot, not on the draw entry, so it is
        // checked even for a slot that draws nothing at all.
        if (g['displayIndex'] != w['displayIndex']) {
          mismatches.add(Mismatch(label, f, '$prefix.displayIndex',
              _r(w['displayIndex'] as num), _r(g['displayIndex'] as num)));
        }

        // ---- nested armature ----------------------------------------------
        // A slot holding a nested armature draws nothing itself: it contributes
        // the child's slots instead, with its own matrix composed onto theirs.
        final wChildren = w['childSlots'] as List<dynamic>?;
        if (wChildren != null) {
          final parentMatrix = <double>[
            for (final v in (w['matrix'] as List<dynamic>)) _r(v as num)
          ];

          for (final child in wChildren.cast<Map<String, dynamic>>()) {
            final childName = child['name'] as String;
            final childMatrix = <double>[
              for (final v in (child['matrix'] as List<dynamic>)) _r(v as num)
            ];
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
              mismatches.add(
                  Mismatch(label, f, 'child slot $childName missing', 0, 0));
              continue;
            }
            compareNumbers(
                mismatches,
                label,
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
              mismatches.add(Mismatch(label, f, 'child $childName.zOrder',
                  _r(w['zOrder'] as num), _r(entry.zOrder as num)));
            }
            childComparisonCount++;
          }
          continue;
        }

        // ---- sprite / mesh draw data ---------------------------------------
        final gMatrix = g['matrix'] as List<dynamic>?;
        if (gMatrix == null) {
          // The port omits the slot entirely. That is correct only when the
          // oracle agrees there is no drawable display there either (a slot whose
          // display index is -1, for instance).
          final oracleDraws = w['textureName'] != null || w['mesh'] != null;
          if (oracleDraws) {
            mismatches.add(Mismatch(label, f, '$prefix missing in port', 0, 0));
          }
          continue;
        }

        compareNumbers(mismatches, label, f, '$prefix.player', gMatrix,
            w['matrix'] as List<dynamic>?, track);
        compareNumbers(mismatches, label, f, '$prefix.pivot',
            g['pivot'] as List<dynamic>?, w['pivot'] as List<dynamic>?, track);
        // A mesh has no quad: its extent comes from the posed triangle list, not
        // from the atlas region. The port reports 0 there on purpose, so only
        // sprites are compared on this field. The mesh check below covers the
        // real geometry.
        if (w['mesh'] == null) {
          compareNumbers(
              mismatches,
              label,
              f,
              '$prefix.quadSize',
              g['quadSize'] as List<dynamic>?,
              w['quadSize'] as List<dynamic>?,
              track);
        }
        compareNumbers(
            mismatches,
            label,
            f,
            '$prefix.region',
            g['region'] as List<dynamic>?,
            w['region'] as List<dynamic>?,
            track);
        compareNumbers(mismatches, label, f, '$prefix.color',
            g['color'] as List<dynamic>?, w['color'] as List<dynamic>?, track);
        slotFieldsCompared++;
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

        // ---- mesh geometry ------------------------------------------------
        final wMesh = w['mesh'] as Map<String, dynamic>?;
        if (wMesh != null) {
          final gMesh = g['mesh'] as Map<String, dynamic>?;
          if (gMesh == null) {
            mismatches.add(Mismatch(label, f, '$prefix.mesh missing', 0, 0));
          } else {
            if (wMesh['vertexCount'] != gMesh['vertexCount']) {
              mismatches.add(Mismatch(
                  label,
                  f,
                  '$prefix.mesh.vertexCount',
                  _r(wMesh['vertexCount'] as num),
                  _r(gMesh['vertexCount'] as num)));
            }
            if (wMesh['triangleCount'] != gMesh['triangleCount']) {
              mismatches.add(Mismatch(
                  label,
                  f,
                  '$prefix.mesh.triangleCount',
                  _r(wMesh['triangleCount'] as num),
                  _r(gMesh['triangleCount'] as num)));
            }
            compareNumbers(
                mismatches,
                label,
                f,
                '$prefix.mesh.vertices',
                gMesh['vertices'] as List<dynamic>?,
                wMesh['vertices'] as List<dynamic>?,
                track);
            compareNumbers(
                mismatches,
                label,
                f,
                '$prefix.mesh.uvs',
                gMesh['uvs'] as List<dynamic>?,
                wMesh['uvs'] as List<dynamic>?,
                track);
            compareIndices(
                mismatches,
                label,
                f,
                '$prefix.mesh.indices',
                gMesh['indices'] as List<dynamic>?,
                wMesh['indices'] as List<dynamic>?,
                track);
            meshValuesHere += (wMesh['vertices'] as List).length + 1;
            meshComparisonCount += (wMesh['vertices'] as List).length + 1;
          }
        }
      }
    }

    final meshNote = meshValuesHere > 0 ? ', $meshValuesHere mesh values' : '';
    stdout.writeln(
        '  ${label.padRight(6)} ${frames.length.toString().padLeft(3)} frames, '
        '${(frames.first['bones'] as List).length} bones, $slotFieldsCompared slot draw-data'
        '$meshNote, max err ${maxError.toStringAsExponential(3)}'
        '${maxError <= tolerance ? '  OK' : '  <-- FAIL'}');
  }

  stdout.writeln('');
  stdout.writeln(
      '$comparisons numeric comparisons, ${mismatches.length} mismatches '
      '(tolerance $tolerance)');
  stdout.writeln(
      '$meshComparisonCount mesh values, $childComparisonCount nested-armature slots');
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
