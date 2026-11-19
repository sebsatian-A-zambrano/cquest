import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'campaign.dart';
import 'chronicle.dart';
import 'expedition.dart';
import 'effects.dart';
import 'lab_screen.dart';
import 'moon_art.dart';
import 'progress.dart';
import 'runner.dart';
import 'style.dart';
import 'save_badge.dart';

class RpgScreen extends StatefulWidget {
  const RpgScreen({
    required this.lab,
    required this.index,
    required this.avatar,
    required this.onCross,
    this.runner = runCode,
    this.previousXp = 0,
    super.key,
  });

  final Lab lab;
  final int index, avatar, previousXp;
  final VoidCallback onCross;
  final Runner runner;

  @override
  State<RpgScreen> createState() => _RpgScreenState();
}

class _RpgScreenState extends State<RpgScreen>
    with SingleTickerProviderStateMixin {
  late final bool isC = widget.lab.language == 'c';
  late final Chronicle scene = (isC
      ? cChronicle
      : algorithmChronicle)[widget.index];
  late final ExpeditionMap map = expeditionMap(widget.index, isC);
  late final List<Color> palette =
      palettes[(widget.index + (isC ? 2 : 0)) % palettes.length];
  late final ExpeditionProgress state = ExpeditionProgress.decode(
    readProgress(ExpeditionProgress.keyFor(widget.lab.id)),
  );
  late Point<int> position;
  late Point<int> previous;
  late final AnimationController ambience;
  final keyboard = FocusNode(debugLabel: 'Escenario');
  final time = Stopwatch()..start();
  int movedAt = -1000;
  int travel = 0;
  bool left = false;
  bool inDialog = false;
  late bool sound = readProgress('rpg.sound') != 'off';
  void _fx(String event) {
    if (sound) playSound(event);
  }

  String? note;

  String get target => state.finished || state.repaired
      ? 'G'
      : state.choice == null
      ? 'N'
      : state.charged
      ? 'O'
      : state.choice == 0
      ? 'A'
      : 'D';
  String? get chosenItem =>
      state.choice == null ? null : scene.items[state.choice!];

  @override
  void initState() {
    super.initState();
    final saved = state.position;
    position = saved != null && map.walkable(saved, state) ? saved : map.spawn;
    previous = position;
    ambience = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    ambience.dispose();
    keyboard.dispose();
    time.stop();
    super.dispose();
  }

  void _checkpoint() => saveProgress(
    ExpeditionProgress.keyFor(widget.lab.id),
    state.encode(position),
  );
  void _focus() {
    if (mounted) keyboard.requestFocus();
  }

  void _notice(String message) {
    if (mounted) setState(() => note = message);
  }

  void _step(Point<int> tile) {
    if (!map.walkable(tile, state)) {
      if (map.contains(tile) &&
          'BG'.contains(map.tile(tile)) &&
          !state.repaired) {
        _notice('El puente sigue roto. Repara la consola para cruzar.');
      }
      return;
    }
    setState(() {
      if (tile.x != position.x) left = tile.x < position.x;
      previous = position;
      position = tile;
      movedAt = time.elapsedMilliseconds;
      note = null;
    });
    _checkpoint();
  }

  void _move(int dx, int dy) {
    travel++;
    _step(Point(position.x + dx, position.y + dy));
  }

  Future<void> _go(Point<int> tile, {String? interact}) async {
    if (inDialog) return;
    _focus();
    final attempt = ++travel;
    final path = map.findPath(position, tile, state, nearby: interact != null);
    if (path == null) {
      _notice('No hay paso por ahí. Busca un camino iluminado.');
      return;
    }
    for (final next in path) {
      if (travel != attempt || !mounted) return;
      _step(next);
      await Future<void>.delayed(const Duration(milliseconds: 109));
    }
    if (mounted && travel == attempt && interact != null) {
      await _interact(interact);
    }
  }

  String? _nearby() {
    const candidates = ['N', 'A', 'D', 'E', 'O', 'G'];
    bool near(String id) => tileDistance(position, map.at(id)) <= 1;
    if (near(target)) return target;
    for (final id in candidates) {
      if (near(id) &&
          (id != 'E' || !state.memory) &&
          (!(id == 'A' || id == 'D') || !state.charged)) {
        return id;
      }
    }
    return null;
  }

  void _useAction() {
    travel++;
    final neighbor = _nearby();
    if (neighbor != null) {
      _interact(neighbor);
    } else {
      _notice('Acércate a un personaje u objeto antes de interactuar.');
    }
  }

  KeyEventResult _keys(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (inDialog) return KeyEventResult.ignored;
    final move = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.keyW => const Point(0, -1),
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => const Point(0, 1),
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => const Point(-1, 0),
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => const Point(1, 0),
      _ => null,
    };
    if (move != null) {
      _move(move.x, move.y);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        [
          LogicalKeyboardKey.keyE,
          LogicalKeyboardKey.space,
        ].contains(event.logicalKey)) {
      _useAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _interact(String id) async {
    if (!mounted || inDialog || tileDistance(position, map.at(id)) > 1) return;
    switch (id) {
      case 'N':
        _fx('talk');
        if (state.choice == null) {
          final option = await _say(
            speaker: scene.npc,
            body: scene.problem,
            portrait: _npcPortrait,
            options: scene.choices,
          );
          if (option == null || !mounted) return;
          setState(() => state.choice = option);
          _checkpoint();
          await _say(
            speaker: scene.npc,
            portrait: _npcPortrait,
            body:
                '${scene.reactions[option]}\n\nRecoge «${scene.items[option]}» donde brilla el marcador.',
            options: const ['Voy en camino'],
          );
        } else {
          final text = state.repaired
              ? scene.repair
              : state.charged
              ? 'Trajiste «$chosenItem». Conéctalo a la consola. Allí tienes el plano y el código que falta.'
              : '${scene.reactions[state.choice!]} Busca «$chosenItem» y tráelo a la consola.';
          await _say(speaker: scene.npc, portrait: _npcPortrait, body: text);
        }
      case 'A' || 'D':
        if (state.choice == null) {
          _notice('Habla con ${scene.npc} antes de recoger un suministro.');
        } else if (state.charged) {
          _notice('Tu mochila ya lleva el suministro de este faro.');
        } else if (id != target) {
          _notice('Esta reserva se queda para la otra ruta.');
        } else {
          setState(() => state.charged = true);
          _fx('pickup');
          _checkpoint();
          await _say(
            speaker: 'Mochila',
            body:
                'Recogiste «$chosenItem».\n\nCon el suministro puedes abrir la consola del faro.',
            options: const ['Ir a la consola'],
          );
        }
      case 'E':
        if (state.memory) return;
        setState(() => state.memory = true);
        _fx('memory');
        _checkpoint();
        await _say(
          speaker: 'Eco de la noche',
          body: scene.memory,
          options: const ['Guardar en la bitácora'],
        );
      case 'O':
        if (state.repaired) {
          _notice('La consola está operativa. El puente ya se puede cruzar.');
        } else if (!state.charged) {
          _notice(
            'La consola necesita el suministro que te indicó ${scene.npc}.',
          );
        } else {
          await _terminal();
        }
      case 'G':
        if (!state.repaired) {
          _notice('El arco está apagado. Repara el faro antes de cruzar.');
        } else {
          final last = widget.index == worldsPerCampaign - 1;
          final choice = await _say(
            speaker: last ? 'El último faro' : 'El arco de luz',
            body: last ? '${scene.repair}\n\n${_ending()}' : scene.repair,
            options: [
              last ? 'Cerrar el capítulo' : 'Cruzar al siguiente mundo',
            ],
          );
          if (choice == 0 && mounted) {
            setState(() => state.finished = true);
            _fx('cross');
            _checkpoint();
            widget.onCross();
          }
        }
    }
  }

  String _ending() {
    final prefix = isC ? 'c' : 'alg';
    int care = 0, observed = 0;
    for (int i = 1; i <= worldsPerCampaign; i++) {
      final entry = ExpeditionProgress.decode(
        readProgress(ExpeditionProgress.keyFor('$prefix-$i')),
      );
      if (entry.choice == 0) care++;
      if (entry.memory) observed++;
    }
    final epilogue = care >= 8
        ? 'En los barrios te recuerdan como Guardián del Festival. Los vecinos organizan la próxima patrulla juntos.'
        : 'Los vigías te llaman Explorador de la Noche. Copian tus rutas para que otras expediciones puedan llegar más lejos.';
    return '$epilogue\n\nEcos conservados en tu bitácora: $observed de $worldsPerCampaign.';
  }

  int? get _npcPortrait => switch (scene.npc) {
    'Lúa' => 0,
    'Nico' => 1,
    'Mimo' => 2,
    _ => null,
  };

  Future<void> _terminal() async {
    setState(() => inDialog = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (route) => LabScreen(
          lab: widget.lab,
          number: widget.index + 1,
          avatar: widget.avatar,
          passed: state.repaired,
          expedition: true,
          runner: widget.runner,
          onPass: () {
            if (!mounted) return;
            setState(() => state.repaired = true);
            _fx('repair');
            _checkpoint();
          },
          onNext: () => Navigator.of(route).pop(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => inDialog = false);
    _focus();
    if (state.repaired) {
      await _say(
        speaker: scene.npc,
        portrait: _npcPortrait,
        body:
            '¡Funciona! +50 XP. ${scene.repair}\n\nCruza el puente y acércate al arco iluminado.',
        options: const ['Volver al camino'],
      );
    }
  }

  Future<int?> _say({
    required String speaker,
    required String body,
    int? portrait,
    List<String> options = const ['Continuar'],
  }) async {
    if (inDialog) return null;
    setState(() => inDialog = true);
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: MissionCard(
                border: palette[6],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (portrait != null) ...[
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: AssetImage(
                              'assets/avatar-$portrait.jpg',
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          Icon(Icons.auto_awesome, color: palette[6]),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Text(
                            speaker,
                            style: TextStyle(
                              color: palette[6],
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: const TextStyle(height: 1.55, fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    for (int i = 0; i < options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ink,
                            alignment: Alignment.centerLeft,
                            side: BorderSide(
                              color: palette[6].withValues(alpha: .60),
                            ),
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: () => Navigator.of(sheet).pop(i),
                          child: Text(options[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) {
      setState(() => inDialog = false);
      _focus();
    }
    return result;
  }

  String get objective => switch (target) {
    'N' => 'Habla con ${scene.npc}.',
    'A' || 'D' => 'Recoge «$chosenItem».',
    'O' => 'Conecta el suministro a la consola y repara el faro.',
    _ => 'Cruza el puente y acércate al arco de luz.',
  };

  String _markerName(String id) => switch (id) {
    'N' => 'Hablar con ${scene.npc}',
    'A' => 'Abrir cofre de ${scene.items[0]}',
    'D' => 'Abrir cofre de ${scene.items[1]}',
    'E' => 'Escuchar eco de la noche',
    'O' => 'Usar consola del faro',
    'G' => 'Cruzar arco de luz',
    _ => 'Interactuar',
  };

  void _journal() {
    final selected = state.choice;
    _say(
      speaker: 'Bitácora de ${explorers[widget.avatar]}',
      body: [
        'MISIÓN · $objective',
        if (selected != null)
          'DECISIÓN · ${scene.choices[selected]}\n${scene.reactions[selected]}',
        'MOCHILA · ${state.charged ? chosenItem : 'Vacía'}',
        'EXPERIENCIA · ${widget.previousXp + state.xp} XP',
        if (state.memory) 'ECO · ${scene.memory}',
        if (state.repaired) 'FARO · Activo. El puente está abierto.',
      ].join('\n\n'),
      options: const ['Cerrar bitácora'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: keyboard,
      autofocus: true,
      onKeyEvent: _keys,
      child: Scaffold(
        backgroundColor: const Color(0xff101526),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1390),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hud(),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxWidth < 940;
                        return compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _board(),
                                  const SizedBox(height: 8),
                                  _controls(compact: true),
                                  const SizedBox(height: 10),
                                  _questPanel(),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _board(),
                                        const SizedBox(height: 8),
                                        _controls(compact: false),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(width: 252, child: _questPanel()),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud() => Row(
    children: [
      IconButton(
        tooltip: 'Volver al refugio',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      const SizedBox(width: 3),
      CircleAvatar(
        radius: 20,
        backgroundImage: AssetImage('assets/avatar-${widget.avatar}.jpg'),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isC ? 'LA RED DE LATÓN' : 'LA NOCHE SIN FAROS'} · ${widget.index + 1}/14',
              style: TextStyle(
                color: palette[6],
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              scene.place,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: palette[6].withValues(alpha: .11),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${widget.previousXp + state.xp} XP',
          style: TextStyle(
            color: palette[6],
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SaveBadge(compact: true),
      IconButton(
        tooltip: sound ? 'Silenciar sonidos' : 'Activar sonidos',
        onPressed: () {
          setState(() => sound = !sound);
          saveProgress('rpg.sound', sound ? 'on' : 'off');
          _fx('talk');
        },
        icon: Icon(
          sound ? Icons.volume_up_outlined : Icons.volume_off_outlined,
          size: 20,
        ),
      ),
      IconButton(
        tooltip: 'Abrir bitácora',
        onPressed: _journal,
        icon: Icon(Icons.menu_book_rounded, color: palette[6]),
      ),
    ],
  );

  Widget _board() => Semantics(
    label: 'Escenario de ${scene.place}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: palette[6].withValues(alpha: .48), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: AspectRatio(
            aspectRatio: map.width / map.height,
            child: LayoutBuilder(
              builder: (context, box) {
                final cellW = box.maxWidth / map.width,
                    cellH = box.maxHeight / map.height;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(painter: MoonTerrain(map, palette)),
                    ),
                    AnimatedBuilder(
                      animation: ambience,
                      builder: (context, _) {
                        final phase =
                            ((time.elapsedMilliseconds - movedAt) / 108)
                                .clamp(0.0, 1.0)
                                .toDouble();
                        final start = Offset(
                          previous.x.toDouble(),
                          previous.y.toDouble(),
                        );
                        final end = Offset(
                          position.x.toDouble(),
                          position.y.toDouble(),
                        );
                        return CustomPaint(
                          painter: MoonFigures(
                            map: map,
                            palette: palette,
                            avatar: widget.avatar,
                            npc: _npcPortrait ?? 3,
                            player: Offset.lerp(start, end, phase)!,
                            elapsed: ambience.value,
                            target: map.at(target),
                            charge: state.charged
                                ? 'gone'
                                : state.choice == null
                                ? null
                                : target,
                            memory: state.memory,
                            repaired: state.repaired,
                            facingLeft: left,
                            walking: phase < 1,
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTapUp: (detail) {
                        final p = Point(
                          (detail.localPosition.dx / cellW).floor(),
                          (detail.localPosition.dy / cellH).floor(),
                        );
                        if (map.contains(p)) _go(p);
                      },
                    ),
                    for (final id in ['N', 'A', 'D', 'E', 'O', 'G'])
                      if (!(id == 'E' && state.memory) &&
                          !(['A', 'D'].contains(id) && state.charged))
                        Positioned(
                          left: map.at(id).x * cellW,
                          top: map.at(id).y * cellH,
                          width: cellW,
                          height: cellH,
                          child: Semantics(
                            label: _markerName(id),
                            button: true,
                            onTap: () => _go(map.at(id), interact: id),
                            child: GestureDetector(
                              excludeFromSemantics: true,
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _go(map.at(id), interact: id),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                    if (note != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: Align(
                            child: Container(
                              color: const Color(0xe1101526),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  note!,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _controls({required bool compact}) {
    final nearby = _nearby();
    final action = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: palette[6],
        foregroundColor: night,
      ),
      onPressed: _useAction,
      icon: const Icon(Icons.touch_app_outlined, size: 17),
      label: Text(nearby == null ? 'Interactuar' : _markerName(nearby)),
    );
    if (!compact) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'WASD / flechas para caminar · E para interactuar · también puedes tocar el escenario',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 5,
          children: [
            for (final (dx, dy, icon, label) in [
              (-1, 0, Icons.keyboard_arrow_left, 'Izquierda'),
              (0, -1, Icons.keyboard_arrow_up, 'Arriba'),
              (0, 1, Icons.keyboard_arrow_down, 'Abajo'),
              (1, 0, Icons.keyboard_arrow_right, 'Derecha'),
            ])
              IconButton.filledTonal(
                tooltip: label,
                onPressed: () => _move(dx, dy),
                icon: Icon(icon),
              ),
            action,
          ],
        ),
        const SizedBox(height: 3),
        const Text(
          'Toca un punto para caminar o un objeto para acercarte.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _questPanel() => MissionCard(
    border: palette[6].withValues(alpha: .36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: palette[6], size: 18),
            const SizedBox(width: 7),
            Text(
              'MISIÓN ACTUAL',
              style: TextStyle(
                color: palette[6],
                letterSpacing: 1.4,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            objective,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          widget.lab.topic,
          style: const TextStyle(color: muted, height: 1.35, fontSize: 13),
        ),
        const Divider(height: 30, color: line),
        _check('Elegir una ruta', state.choice != null),
        _check('Recoger el suministro', state.charged),
        _check('Reparar el faro con código', state.repaired),
        _check('Cruzar el arco', state.finished),
        const Divider(height: 30, color: line),
        Text(
          'MOCHILA',
          style: TextStyle(
            color: palette[6],
            letterSpacing: 1.3,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          state.charged ? chosenItem! : 'Sin suministros',
          style: const TextStyle(color: muted),
        ),
        if (state.memory) ...[
          const SizedBox(height: 8),
          const Text(
            '✦ Eco recuperado',
            style: TextStyle(color: Color(0xffabdfff)),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _journal,
          icon: const Icon(Icons.menu_book_rounded, size: 17),
          label: const Text('Bitácora'),
        ),
      ],
    ),
  );

  Widget _check(String label, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 14,
          color: done ? palette[6] : muted,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: done ? ink : muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
