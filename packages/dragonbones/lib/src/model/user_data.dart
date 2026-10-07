part of '../../dragonbones.dart';

/// @private
class ActionData extends BaseObject {
  int type = ActionType.Play;
  String name = '';
  BoneData? bone;
  SlotData? slot;
  UserData? data;

  @override
  void _onClear() {
    this.type = ActionType.Play;
    this.name = '';
    this.bone = null;
    this.slot = null;
    this.data = null;
  }
}

/// @private
class UserData extends BaseObject {
  String name = '';
  final List<num> ints = <num>[];
  final List<num> floats = <num>[];
  final List<String> strings = <String>[];

  @override
  void _onClear() {
    this.name = '';
    this.ints.length = 0;
    this.floats.length = 0;
    this.strings.length = 0;
  }

  void addInt(num value) => this.ints.add(value);
  void addFloat(num value) => this.floats.add(value);
  void addString(String value) => this.strings.add(value);
}
