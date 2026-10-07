# Changelog

## 0.1.0

First release. Pure-Dart runtime for the DragonBones 5.x skeletal animation
format, with **zero dependencies** — it runs on a bare Dart SDK, including on the
web.

Runs armatures, bone/translate/rotate/scale/all timelines, slot display and colour
timelines, deform (FFD) timelines, FFD and skinned deformable meshes, IK
constraints and nested child armatures, and exposes the posed result as a
framework-agnostic draw list (`Armature.buildDrawList()`).

Verification is the point of this package: the whole thing is diffed frame by frame
against the official DragonBones runtime, across three hand-picked fixtures and all
44 demo assets from the DragonBones Unity SDK — 757,701 numeric comparisons, 0
mismatches. See the repository for the harness (`tool/ground_truth/`) and the
results.
