// Minimal example: draw DragonBones animations on a plain Flutter Canvas.
//
// The character list comes from `asset_catalog.dart`, generated from the
// directories under `assets/` — every character in the repository's fixture
// set, so the app doubles as a viewer for all of them. See example/README.md.
import 'package:dragonbones_example/game/game.dart';
import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'asset_catalog.dart';
import 'head_follow_page.dart';

void main() {
  runApp(const DragonBonesExampleApp());
}

class DragonBonesExampleApp extends StatelessWidget {
  const DragonBonesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DragonBones + Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  /// Opens on a character with several animations and a mesh-free rig.
  static const String _initial = 'mecha_1004d_show';

  DragonBonesAssets? _bones;
  DragonBonesPlayer? _player;
  List<String> _armatures = const <String>[];
  List<String> _animations = const <String>[];
  String _character = _initial;
  String? _armature;
  String? _animation;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the selected character and shows its first armature.
  Future<void> _load() async {
    try {
      final bones = await DragonBonesAssets.loadAsset(
        bundle: rootBundle,
        skeleton: 'assets/$_character/ske.json',
        texture: 'assets/$_character/tex.json',
        image: 'assets/$_character/tex.png',
      );

      final names = bones.factory.getDragonBonesData(bones.name)?.armatureNames;
      final armatures = names ?? const <String>[];
      if (armatures.isEmpty) {
        throw StateError('no armature in assets/$_character');
      }

      if (!mounted) return;
      _bones = bones;
      _armatures = armatures;
      _show(armatures.first);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _bones = null;
        _player = null;
        _armatures = const <String>[];
        _animations = const <String>[];
        _error = error;
      });
    }
  }

  /// Builds [armature] from the loaded character and plays its first animation.
  void _show(String armature) {
    final bones = _bones;
    if (bones == null) {
      return;
    }

    final built = bones.buildArmature(armature);
    if (built == null) {
      setState(() => _error = StateError('armature "$armature" not found'));
      return;
    }

    final player = DragonBonesPlayer(built, resolveImage: bones.imageFor);
    final animations = built.armatureData.animationNames;
    if (animations.isNotEmpty) {
      player.play(animations.first);
    }

    setState(() {
      _player = player;
      _armature = armature;
      _animations = animations;
      _animation = animations.isEmpty ? null : animations.first;
      _error = null;
    });
  }

  /// Switches character: drop everything, then load the new one.
  void _select(String character) {
    setState(() {
      _character = character;
      _bones = null;
      _player = null;
      _armatures = const <String>[];
      _animations = const <String>[];
      _armature = null;
      _animation = null;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DragonBones on a Flutter Canvas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Bonfire platformer (keyboard + on-screen controls)',
            icon: const Icon(Icons.sports_esports),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GameExample(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Head follows the pointer (mouse / touch)',
            icon: const Icon(Icons.mouse),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HeadFollowPage(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: const Color(0xFF102030),
              child: _error != null
                  ? Center(
                      child: Text(
                      '$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ))
                  : player == null
                      ? const Center(child: CircularProgressIndicator())
                      : DragonBonesWidget(
                          player: player,
                          animation: _animation,
                          fit: DragonBonesFit.contain,
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _picker<String>(
                  label: 'Character',
                  value: _character,
                  values: kExampleAssets,
                  onChanged: (value) {
                    if (value != null && value != _character) {
                      _select(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _picker<String>(
                  label: 'Armature',
                  value: _armature,
                  values: _armatures,
                  onChanged: (value) {
                    if (value != null && value != _armature) {
                      _show(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _picker<String>(
                  label: 'Animation',
                  value: _animation,
                  values: _animations,
                  onChanged: (value) {
                    if (value != null && value != _animation) {
                      setState(() => _animation = value);
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              '${kExampleAssets.length} characters, the repository fixtures — '
              'update(dt) + render(canvas), no game engine involved.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker<T>({
    required String label,
    required T? value,
    required List<T> values,
    required void Function(T?) onChanged,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            items: <DropdownMenuItem<T>>[
              for (final item in values)
                DropdownMenuItem<T>(value: item, child: Text('$item')),
            ],
            onChanged: values.isEmpty ? null : onChanged,
          ),
        ),
      ],
    );
  }
}
