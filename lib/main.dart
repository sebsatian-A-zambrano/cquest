import 'package:flutter/material.dart';

import 'src/campaign.dart';
import 'src/chronicle.dart';
import 'src/expedition.dart';
import 'src/progress.dart';
import 'src/install.dart';
import 'src/save_badge.dart';
import 'src/rpg_screen.dart';
import 'src/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeProgress();
  runApp(const CQuest());
}

class CQuest extends StatelessWidget {
  const CQuest({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CQuest · La noche sin faros',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: night,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: mint,
        surface: panel,
        onSurface: ink,
      ),
    ),
    home: const ExpeditionHome(),
  );
}

class ExpeditionHome extends StatefulWidget {
  const ExpeditionHome({super.key});
  @override
  State<ExpeditionHome> createState() => _ExpeditionHomeState();
}

class _ExpeditionHomeState extends State<ExpeditionHome> {
  late Future<List<Lab>> campaign = loadCampaign();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Lab>>(
    future: campaign,
    builder: (context, data) {
      if (data.hasData) return MoonRefuge(labs: data.requireData);
      return Scaffold(
        body: Center(
          child: data.hasError
              ? FilledButton(
                  onPressed: () => setState(() => campaign = loadCampaign()),
                  child: const Text('Cargar la partida'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}

class MoonRefuge extends StatefulWidget {
  const MoonRefuge({required this.labs, super.key});
  final List<Lab> labs;

  @override
  State<MoonRefuge> createState() => _MoonRefugeState();
}

class _MoonRefugeState extends State<MoonRefuge> {
  late int avatar;
  late Set<int> crossed;

  @override
  void initState() {
    super.initState();
    final stored = int.tryParse(readProgress('avatar') ?? '');
    avatar = stored != null && stored >= 0 && stored < explorers.length
        ? stored
        : 0;
    crossed = (readProgress('rpg.crossed') ?? '')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((i) => i >= 0 && i < campaignSize)
        .toSet();
  }

  int next(int first) {
    for (int i = first; i < first + worldsPerCampaign; i++) {
      if (!crossed.contains(i)) return i;
    }
    return first;
  }

  List<ExpeditionProgress> get journey => [
    for (final lab in widget.labs)
      ExpeditionProgress.decode(
        readProgress(ExpeditionProgress.keyFor(lab.id)),
      ),
  ];

  int xpBefore(int current) => journey.indexed
      .where((entry) => entry.$1 != current)
      .fold(0, (total, entry) => total + entry.$2.xp);

  Route<void> chapter(int i) => MaterialPageRoute<void>(
    builder: (route) => RpgScreen(
      lab: widget.labs[i],
      index: i % worldsPerCampaign,
      avatar: avatar,
      previousXp: xpBefore(i),
      onCross: () {
        if (crossed.add(i)) {
          setState(() {});
          saveProgress('rpg.crossed', crossed.join(','));
        }
        final navigator = Navigator.of(route);
        if ((i + 1) % worldsPerCampaign == 0) {
          navigator.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La expedición se guardó en tu crónica.'),
            ),
          );
        } else {
          navigator.pushReplacement(chapter(i + 1));
        }
      },
    ),
  );

  Future<void> start(int i) async {
    await Navigator.of(context).push(chapter(i));
    if (mounted) setState(() {});
  }

  void chronology() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .76,
          maxChildSize: .95,
          minChildSize: .4,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            children: [
              const Text(
                'Crónica de CQuest',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const Text(
                'Aquí puedes continuar o regresar a un lugar visitado.',
              ),
              const SizedBox(height: 9),
              Text(
                '${xpBefore(-1)} XP',
                style: const TextStyle(
                  color: peach,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (journey.any((stage) => stage.repaired))
                const Text('✦ Primera luz · Reparaste tu primer faro.'),
              if (journey.where((stage) => stage.memory).length >= 3)
                const Text('✧ Cronista de la niebla · Recuperaste tres ecos.'),
              if (crossed.contains(13) || crossed.contains(27))
                const Text(
                  '✦ Arquitectura de la luz · Terminaste un proyecto de la red.',
                ),
              for (final (first, name, scenes) in [
                (0, 'La noche sin faros', algorithmChronicle),
                (14, 'La red de latón', cChronicle),
              ]) ...[
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    color: peach,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (int i = 0; i < scenes.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      crossed.contains(first + i)
                          ? Icons.auto_awesome
                          : worldUnlocked(first + i, crossed)
                          ? Icons.near_me
                          : Icons.lock_outline,
                      color: worldUnlocked(first + i, crossed) ? mint : muted,
                      size: 19,
                    ),
                    title: Text('${i + 1}. ${scenes[i].place}'),
                    subtitle: Text(
                      widget.labs[first + i].topic,
                      style: const TextStyle(color: muted),
                    ),
                    onTap: worldUnlocked(first + i, crossed)
                        ? () {
                            Navigator.of(sheet).pop();
                            start(first + i);
                          }
                        : null,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/moon-title.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(.38, .72),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xf1091323), Color(0xbc10172b), Color(0x150c1526)],
              stops: [0, .51, 1],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x110e1524),
                Color(0xe20b1321),
              ],
              stops: [0, .67, 1],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final small = box.maxWidth < 650;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Align(
                    alignment: small ? Alignment.center : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        small ? 21 : box.maxWidth * .075,
                        small ? 30 : 45,
                        21,
                        30,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 530),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: peach,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'DIARIO DE UNA EXPEDICIÓN',
                                  style: TextStyle(
                                    color: peach,
                                    letterSpacing: small ? 2 : 3.4,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'CQuest',
                              style: TextStyle(
                                fontSize: small ? 61 : 86,
                                height: .98,
                                letterSpacing: -3.3,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 11),
                            const Text(
                              'El festival de los faros',
                              style: TextStyle(
                                color: peach,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'El último faro acaba de apagarse. Elige quién llevará la luz al otro lado de la niebla.',
                              style: TextStyle(
                                color: ink,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: [
                                for (int i = 0; i < explorers.length; i++)
                                  Semantics(
                                    selected: avatar == i,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(74, 75),
                                        backgroundColor: avatar == i
                                            ? const Color(0xff264b4c)
                                            : const Color(0xc81c233a),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 7,
                                        ),
                                        side: BorderSide(
                                          color: avatar == i ? mint : line,
                                        ),
                                        foregroundColor: avatar == i
                                            ? mint
                                            : ink,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() => avatar = i);
                                        saveProgress(
                                          'avatar',
                                          avatar.toString(),
                                        );
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 23,
                                            backgroundImage: AssetImage(
                                              'assets/avatar-$i.jpg',
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(explorers[i]),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 23),
                            _saveSlot(
                              0,
                              'La noche sin faros',
                              'Algoritmos y lógica',
                              Icons.hiking_rounded,
                              mint,
                            ),
                            const SizedBox(height: 9),
                            _saveSlot(
                              14,
                              'La red de latón',
                              'Programación en C',
                              Icons.precision_manufacturing_outlined,
                              peach,
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: chronology,
                              icon: const Icon(Icons.menu_book_outlined),
                              label: const Text('Abrir crónica'),
                            ),
                            const SaveBadge(),
                            TextButton.icon(onPressed: openInstall, icon: const Icon(Icons.install_mobile), label: const Text('Instalar / descargar')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _saveSlot(
    int first,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final done = crossed
        .where((i) => i >= first && i < first + worldsPerCampaign)
        .length;
    return OutlinedButton(
      onPressed: () => start(next(first)),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: ink,
        backgroundColor: const Color(0xe8202a42),
        padding: const EdgeInsets.fromLTRB(14, 9, 12, 10),
        side: BorderSide(color: color.withValues(alpha: .62)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$subtitle · $done/14',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }
}
