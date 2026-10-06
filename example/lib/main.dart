// Minimal example: draw a DragonBones animation on a plain Flutter Canvas.
//
// No Flame, no game engine — just `update(dt)` + `render(canvas)` driven by the
// provided widget. See example/README.md for how to run it.
import 'package:dragonbones_flutter/dragonbones_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  DragonBonesPlayer? _player;
  List<String> _animations = const <String>[];
  String? _animation;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final assets = await DragonBonesAssets.loadAsset(
        bundle: rootBundle,
        skeleton: 'assets/Dragon_ske.json',
        texture: 'assets/Dragon_tex.json',
        image: 'assets/Dragon_tex.png',
      );

      final armature = assets.buildArmature('Dragon');
      if (armature == null) {
        throw StateError('armature "Dragon" not found in the asset');
      }

      final player = DragonBonesPlayer(armature, resolveImage: assets.imageFor);
      final animations = armature.armatureData.animationNames;
      player.play(animations.first);

      if (!mounted) return;
      setState(() {
        _player = player;
        _animations = animations;
        _animation = animations.first;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;

    return Scaffold(
      appBar: AppBar(title: const Text('DragonBones on a Flutter Canvas')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: const Color(0xFF102030),
              child: _error != null
                  ? Center(child: Text('$_error', textAlign: TextAlign.center))
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
            child: Row(
              children: <Widget>[
                const Text('Animation '),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _animation,
                    items: <DropdownMenuItem<String>>[
                      for (final name in _animations)
                        DropdownMenuItem<String>(value: name, child: Text(name)),
                    ],
                    onChanged: _animations.isEmpty
                        ? null
                        : (String? value) {
                            if (value == null || value == _animation) return;
                            setState(() => _animation = value);
                          },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text(
              'update(dt) + render(canvas) — no game engine involved.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
