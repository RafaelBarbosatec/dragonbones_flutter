part of '../../dragonbones.dart';

/// @private
class SkinData extends BaseObject {
  String name = '';
  final Map<String, List<DisplayData?>> displays = <String, List<DisplayData?>>{};
  ArmatureData? parent;

  @override
  void _onClear() {
    this.displays.clear();
    this.name = '';
    this.parent = null;
  }

  void addDisplay(String slotName, DisplayData? value) {
    if (!this.displays.containsKey(slotName)) {
      this.displays[slotName] = <DisplayData?>[];
    }

    if (value != null) {
      value.parent = this;
    }

    this.displays[slotName]!.add(value);
  }

  DisplayData? getDisplay(String slotName, String displayName) {
    final slotDisplays = this.getDisplays(slotName);
    if (slotDisplays != null) {
      for (final display in slotDisplays) {
        if (display != null && display.name == displayName) {
          return display;
        }
      }
    }
    return null;
  }

  List<DisplayData?>? getDisplays(String slotName) {
    if (!this.displays.containsKey(slotName)) {
      return null;
    }
    return this.displays[slotName];
  }
}
