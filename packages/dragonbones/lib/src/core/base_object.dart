part of dragonbones;

/// Base class for pooled objects in the upstream runtime.
///
/// The upstream uses a per-class object pool keyed on `static toString()`.
/// Dart's garbage collector makes that unnecessary, so this port simply
/// constructs objects directly and `_onClear` is only used to reset fields.
abstract class BaseObject {
  void _onClear();

  void returnToPool() => _onClear();
}
