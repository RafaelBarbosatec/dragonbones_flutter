/*
 * Pure-Dart port of the DragonBones 2D skeletal-animation runtime.
 *
 * Covers the DragonBones 5.5 text/JSON format: bone timelines
 * (translate/rotate/scale/all), slot display/colour timelines, deform (FFD)
 * timelines, sprites, deformable meshes (including skinned ones) and nested
 * child armatures.
 *
 * The port follows the upstream TypeScript sources closely (same class and
 * member names, including the `_`-prefixed fields the upstream keeps public)
 * so it can be diffed against `.ref/dragonBones-ts/`.
 *
 * Two deliberate deviations from the upstream, both documented where they
 * appear: the object pool is gone (Dart's GC handles it — but `BaseObject`'s
 * constructor still calls `_onClear()`, because upstream's `borrowObject` always
 * does and several classes set their default state there), and JS array growth
 * (`.length = n`) is replaced with explicit sizing.
 *
 * Only `dart:math` and `dart:typed_data` are used; there are no third-party or
 * `package:` dependencies.
 */
library dragonbones;

import 'dart:math' as math;
import 'dart:typed_data';

part 'src/core/base_object.dart';
part 'src/core/dragon_bones.dart';
part 'src/geom/point.dart';
part 'src/geom/rectangle.dart';
part 'src/geom/color_transform.dart';
part 'src/geom/matrix.dart';
part 'src/geom/transform.dart';
part 'src/model/user_data.dart';
part 'src/model/dragon_bones_data.dart';
part 'src/model/armature_data.dart';
part 'src/model/display_data.dart';
part 'src/model/skin_data.dart';
part 'src/model/animation_data.dart';
part 'src/model/animation_config.dart';
part 'src/model/texture_atlas_data.dart';
part 'src/parser/object_data_parser.dart';
part 'src/armature/transform_object.dart';
part 'src/armature/bone.dart';
part 'src/armature/slot.dart';
part 'src/armature/armature.dart';
part 'src/animation/base_timeline_state.dart';
part 'src/animation/timeline_state.dart';
part 'src/animation/animation_state.dart';
part 'src/animation/animation.dart';
part 'src/factory/base_factory.dart';
part 'src/factory/headless_factory.dart';
part 'src/render/draw_data.dart';
part 'src/render/mesh_geometry.dart';

/// JavaScript-compatible remainder (`a % b` truncates towards zero).
double _jsMod(double a, double b) => a - b * (a / b).truncateToDouble();

/// JavaScript-compatible `Math.round` (rounds .5 towards +Infinity).
double _jsRound(double value) => (value + 0.5).floorToDouble();

/// JavaScript `||` style numeric coercion used by the object data parser.
double _number(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) {
    if (value == 'NaN') return defaultValue;
    final parsed = double.tryParse(value);
    return parsed ?? defaultValue;
  }
  if (value is bool) return value ? 1.0 : 0.0;
  return defaultValue;
}
