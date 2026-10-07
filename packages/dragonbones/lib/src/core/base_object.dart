part of '../../dragonbones.dart';

/// Base class for pooled objects in the upstream runtime.
///
/// The upstream draws every runtime object through `BaseObject.borrowObject`,
/// which guarantees `_onClear()` runs exactly once at the start of an object's
/// life:
///
/// ```ts
/// const object = new objectConstructor();
/// object._onClear();          // always, even on a fresh object
/// return object;
/// ```
///
/// Dart's garbage collector makes the *pool* unnecessary, but not the
/// `_onClear()` call: `_onClear()` is not merely "reset a recycled object", it
/// is where a class establishes its default state — most notably
/// `DisplayType.Armature` / `Mesh` / `Path` / `BoundingBox`, which the subclasses
/// set there and *nowhere else*. Dropping the call left every subclass holding
/// the base default (`DisplayType.Image`), which is why nested-armature slots
/// crashed on load and mesh slots were silently treated as sprites.
///
/// So the constructor calls it, mirroring `borrowObject`. This is safe in Dart:
/// a subclass's field initializers run *before* the superclass constructor body
/// (verified empirically), so by the time `_onClear()` is reached every field in
/// the chain is initialised. It also dispatches virtually, so the most-derived
/// `_onClear()` is the one that runs — which is exactly what upstream relies on.
abstract class BaseObject {
  BaseObject() {
    _onClear();
  }

  void _onClear();

  void returnToPool() => _onClear();
}
