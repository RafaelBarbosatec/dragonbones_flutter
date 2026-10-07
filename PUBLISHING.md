# Publishing

Both packages are **not** publishable as they stand: their pubspecs carry
`publish_to: none`, which is deliberate. Nothing is published until someone
removes that line on purpose, because a pub.dev release cannot be deleted — only
retracted.

Check the current state at any time with:

```bash
cd packages/dragonbones        && dart pub publish --dry-run
cd packages/dragonbones_flutter && flutter pub publish --dry-run
```

## Why there is an order

`dragonbones_flutter` depends on `dragonbones` through a **path** dependency:

```yaml
dependencies:
  dragonbones:
    path: ../dragonbones
```

That works in this repo and must be changed before publishing — a published
package cannot depend on a path. So `dragonbones` has to go out first, and only
then can the renderer point at a version range. Doing it the other way around
leaves a window where CI is red for no reason, which is why it is not done in
advance.

## Steps

```bash
# 1. runtime first
cd packages/dragonbones
#    - set `version: 0.1.0` (it is 0.0.1-dev.1 today)
#    - delete the `publish_to: none` line
dart pub publish --dry-run     # must be clean before the real thing
dart pub publish               # <- irreversible

# 2. then the renderer
cd ../dragonbones_flutter
#    - set `version: 0.1.0`
#    - delete the `publish_to: none` line
#    - replace the path dependency:
#         dragonbones:
#           path: ../dragonbones
#      with:
#         dragonbones: ^0.1.0
flutter pub get && flutter test
flutter pub publish --dry-run
flutter pub publish
```

## Checklist

| Item | dragonbones | dragonbones_flutter |
| --- | --- | --- |
| `LICENSE` in the package root | ✅ | ✅ |
| `CHANGELOG.md` | ✅ | ✅ |
| `README.md` | ✅ | ✅ |
| `publish_to: none` removed | ⬜ on publish | ⬜ on publish |
| Version bumped off `0.0.1-dev.1` | ⬜ | ⬜ |
| No `path:` dependency | ✅ (no deps at all) | ⬜ after step 1 |
| `--dry-run` clean | ⬜ | ⬜ |

## Name availability

Checked 2026-10 and free on pub.dev: `dragonbones`, `dragonbones_flutter`,
`flame_dragonbones`. If `dragonbones` is taken by the time you publish, the
fallback worth considering is `flame_dragonbones` for the renderer and whatever
the runtime ends up as.

## What is deliberately not in the archive

`packages/dragonbones/.pubignore` drops the `tool/` directory. Those scripts
(`check_against_oracle.dart`, `parse_check.dart`, `inspect_fixture.dart`) read the
reference dumps and fixtures from the repository root, which is outside the
package — shipping them would ship something that cannot run. They live in the
repository, where they work.

## Still open before a 1.0

Not blockers for a first release, but worth knowing:

- **`PathConstraint`, `Surface` bones, animation events (`EventObject`),
  `SlotZIndex` / `SlotAlpha` timelines** are not ported. No asset in the test set
  needs them; a project that does would hit a wall.
- **Appearance is only eyeballed.** CI proves pixels are produced, not that the
  result looks right.
- The example app is a demo, not documentation.
