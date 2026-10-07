// Quick headless inspector: loads a fixture, poses it, and prints what the
// draw list contains. Pure Dart — useful for eyeballing numbers before they
// reach a screen.
//
//   dart run packages/dragonbones/tool/inspect_fixture.dart <base> <armature>
//
// `<base>` is either a fixture stem (`test/fixtures/龙`) or an asset directory
// (`example/assets/mecha_1004d`). Defaults to the `龙` fixture, whose mesh
// slots are the interesting ones.
import 'dart:convert';
import 'dart:io';

import 'package:dragonbones/dragonbones.dart';

void main(List<String> args) {
  final base = args.isNotEmpty ? args[0] : 'test/fixtures/龙';
  final wanted = args.length > 1 ? args[1] : null;

  final dirStyle = File('$base/ske.json').existsSync();
  final skeFile = File(dirStyle ? '$base/ske.json' : '${base}_ske.json');
  final texFile = File(dirStyle ? '$base/tex.json' : '${base}_tex.json');

  final ske = jsonDecode(skeFile.readAsStringSync()) as Object;
  final tex = jsonDecode(texFile.readAsStringSync()) as Object;

  final factory = HeadlessFactory();
  final data = factory.parseDragonBonesData(ske)!;
  factory.parseTextureAtlasData(tex, null, data.name);

  for (final name in data.armatureNames) {
    if (wanted != null && name != wanted) continue;
    stdout.writeln('=== "$name" ===');
    final Armature? armature;
    try {
      armature = factory.buildArmature(name, data.name, '');
    } catch (error) {
      stdout.writeln('  build FAILED: $error');
      continue;
    }
    if (armature == null) {
      stdout.writeln('  null armature');
      continue;
    }

    final animations = armature.armatureData.animationNames;
    if (animations.isNotEmpty) {
      armature.animation.play(animations.first);
    }

    for (var frame = 0; frame < 3; ++frame) {
      armature.advanceTime(1 / 24);
      final list = armature.buildDrawList();
      var meshes = 0, sprites = 0, verts = 0, tris = 0;
      double minU = 1e9, maxU = -1e9, minV = 1e9, maxV = -1e9;

      for (final entry in list) {
        final mesh = entry.mesh;
        if (mesh == null) {
          sprites++;
          continue;
        }
        meshes++;
        verts += mesh.vertexCount;
        tris += mesh.triangleCount;
        for (var i = 0; i < mesh.uvs.length; i += 2) {
          minU = mesh.uvs[i] < minU ? mesh.uvs[i] : minU;
          maxU = mesh.uvs[i] > maxU ? mesh.uvs[i] : maxU;
          minV = mesh.uvs[i + 1] < minV ? mesh.uvs[i + 1] : minV;
          maxV = mesh.uvs[i + 1] > maxV ? mesh.uvs[i + 1] : maxV;
        }
      }

      stdout.writeln('  frame $frame: drawList=${list.length} '
          'sprites=$sprites meshes=$meshes (verts=$verts tris=$tris)');
      if (meshes > 0) {
        stdout.writeln('    uv range: u=[${minU.toStringAsFixed(4)}, '
            '${maxU.toStringAsFixed(4)}] v=[${minV.toStringAsFixed(4)}, '
            '${maxV.toStringAsFixed(4)}]');
      }
      for (final entry in list.where((e) => e.mesh != null)) {
        final v = entry.mesh!.vertices;
        stdout.writeln('    mesh ${entry.slotName}: ${entry.mesh} '
            'first=(${v[0].toStringAsFixed(2)}, ${v[1].toStringAsFixed(2)}) '
            'tex=${entry.texture?.name}');
      }
    }
  }
}
