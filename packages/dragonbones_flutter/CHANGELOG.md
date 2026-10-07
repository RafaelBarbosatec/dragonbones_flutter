# Changelog

## 0.1.0

First release. Draws DragonBones skeletal animations on a Flutter `Canvas`
through two methods, `update(dt)` and `render(canvas)` — with no dependency on
Flame or any other engine, so the same code drops into a plain Flutter app, a
Flame `Component`, a Bonfire `GameComponent`, or a `CustomPainter`.

- Sprites and deformable meshes (`drawVertices` + `ImageShader`), including
  skinned meshes with bone weights and animated FFD.
- Nested child armatures flattened into the draw list, with the parent slot's
  transform composed onto them.
- `DragonBonesWidget` with `DragonBonesFit`, and `computeBounds()` for placement.
