import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:libmpv_dart/libmpv.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  PlayerPageState createState() => PlayerPageState();
}

class PlayerPageState extends State<PlayerPage> {
  late Player _player;
  // late MpvVideoController _controller;
  bool _loaded = false;

  bool _menuExpanded = false;
  double _seekingPos = 0;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    _player = Player(
      {
        'config': 'yes',
        'input-default-bindings': 'yes',
      },
      videoOutput: true,
    );
    _player.setPropertyString('keep-open', 'yes');

    setState(() {
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    late final colorScheme = Theme.of(context).colorScheme;
    late final backgroundColor = colorScheme.surface;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _buildPlayer(colorScheme),
                  ),
                ),
                _menuExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 300,
                          child: _buildSidePanel(colorScheme, backgroundColor),
                        ),
                      )
                    : const SizedBox(),
              ],
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width - 28,
            height: 30,
            child: Row(
              children: [
                Expanded(child: _buildSeekbar()),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: _buildControlbar(colorScheme),
          ),
          const SizedBox(
            height: 10,
          )
        ],
      ),
    );
  }

  Widget _buildPlayer(ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: _loaded
          ? Stack(
              children: [
                const ColoredBox(
                  color: Colors.black,
                  child: SizedBox.expand(),
                ),
                SizedBox.expand(
                  child: FittedBox(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _player.id,
                      builder: (context, id, _) {
                        return SizedBox(
                          width: _player.videoParams.value.dw.toDouble(),
                          height: _player.videoParams.value.dh.toDouble(),
                          child: Texture(textureId: id),
                        );
                      },
                    ),
                  ),
                ),
              ],
            )
          : Container(
              color: Colors.black,
              child: const SizedBox.expand(),
            ),
    );
  }

  Widget _buildSeekbar() {
    late final colorScheme = Theme.of(context).colorScheme;
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: colorScheme.secondaryContainer,
        thumbColor: colorScheme.onSecondaryContainer,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 6,
        ),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: ValueListenableBuilder(
        valueListenable: _player.duration,
        builder: (context, dur, _) {
          return ValueListenableBuilder(
            valueListenable: _player.position,
            builder: (constext, pos, _) {
              double p = _seeking ? _seekingPos : pos * 1.0;
              p = min(p, dur * 1.0);
              p = max(0, p);
              return Slider(
                max: dur * 1.0,
                value: p,
                onChanged: (value) {
                  setState(() {
                    _seekingPos = value;
                  });
                },
                onChangeStart: (value) {
                  setState(() {
                    _seeking = true;
                  });
                },
                onChangeEnd: (value) {
                  // _player.seek(value ~/ 1);
                  _player.command(['seek', value.toString(), 'absolute']);
                  setState(() {
                    _seeking = false;
                  });
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSidePanel(ColorScheme colorScheme, Color backgroundColor) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(18)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('panel'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ValueListenableBuilder(
              valueListenable: _player.duration,
              builder: (context, dur, _) {
                return ValueListenableBuilder(
                  valueListenable: _player.position,
                  builder: (constext, pos, _) {
                    return SizedBox(
                      height: 30,
                      child: Text('position - duration: $pos - $dur'),
                    );
                  },
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _player.volume,
              builder: (context, value, _) {
                return SizedBox(
                  height: 30,
                  child: Text('volume: $value'),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _player.speed,
              builder: (context, value, _) {
                return SizedBox(
                  height: 30,
                  child: Text('speed: $value'),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _player.videoParams,
              builder: (context, value, _) {
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Text(value.toString()),
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: _player.audioParams,
              builder: (context, value, _) {
                return Container(
                  height: 100,
                  alignment: Alignment.center,
                  child: Text(value.toString()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlbar(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  _player.setPropertyDouble('volume', 0);
                },
                icon: const Icon(Icons.volume_up),
              ),
              SizedBox(
                width: 100,
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: colorScheme.secondaryContainer,
                    thumbColor: colorScheme.onSecondaryContainer,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: _player.volume,
                    builder: (context, value, _) {
                      return Slider(
                        max: 100,
                        value: value,
                        onChanged: (value) {
                          _player.setPropertyDouble('volume', value);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'stop',
          onPressed: () {
            _player.command(['stop']);
          },
          icon: const Icon(
            Icons.stop_outlined,
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'openfile',
          icon: const Icon(Icons.file_open_outlined),
          onPressed: () async {
            var res =
                await FilePicker.platform.pickFiles(lockParentWindow: true);
            if (res != null) {
              String url = res.files.single.path!;
              _player.command(['loadfile', url]);
            }
          },
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          tooltip: 'play or pause',
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          iconSize: 28,
          onPressed: () {
            _player.command(['cycle', 'pause']);
          },
          icon: const Icon(Icons.sync),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: 'command',
          icon: const Icon(Icons.terminal),
          onPressed: () {
            _player.command(['show-text', 'custom command']);
          },
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'VO Info',
          onPressed: () {
            _player.command(['keypress', 'I']);
          },
          icon: const Icon(
            Icons.info_outline,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Custom UI panel',
                onPressed: () {
                  setState(() {
                    _menuExpanded = !_menuExpanded;
                  });
                },
                icon: const Icon(
                  Icons.menu,
                ),
              ),
              const SizedBox(
                width: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
