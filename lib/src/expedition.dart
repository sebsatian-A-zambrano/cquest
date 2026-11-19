import 'dart:collection';
import 'dart:convert';
import 'dart:math';

const directions = <Point<int>>[
  Point(0, -1),
  Point(-1, 0),
  Point(0, 1),
  Point(1, 0),
];

int tileDistance(Point<int> a, Point<int> b) =>
    (a.x - b.x).abs() + (a.y - b.y).abs();

class ExpeditionProgress {
  ExpeditionProgress({
    this.choice,
    this.charged = false,
    this.memory = false,
    this.repaired = false,
    this.finished = false,
    this.position,
  });

  int? choice;
  bool charged, memory, repaired, finished;
  Point<int>? position;

  int get xp =>
      (choice == null ? 0 : 10) +
      (charged ? 15 : 0) +
      (memory ? 20 : 0) +
      (repaired ? 50 : 0) +
      (finished ? 25 : 0);

  static String keyFor(String id) => 'rpg.world.$id';

  factory ExpeditionProgress.decode(String? raw) {
    try {
      final data = jsonDecode(raw ?? '') as Map;
      final choice = data['choice'];
      final x = data['x'];
      final y = data['y'];
      return ExpeditionProgress(
        choice: choice == 0 || choice == 1 ? choice as int : null,
        charged: data['charged'] == true,
        memory: data['memory'] == true,
        repaired: data['repaired'] == true,
        finished: data['finished'] == true,
        position: x is int && y is int ? Point(x, y) : null,
      );
    } on Object {
      return ExpeditionProgress();
    }
  }

  String encode(Point<int> location) => jsonEncode({
    'choice': choice,
    'charged': charged,
    'memory': memory,
    'repaired': repaired,
    'finished': finished,
    'x': location.x,
    'y': location.y,
  });
}

class ExpeditionMap {
  ExpeditionMap(this.tiles);
  final List<String> tiles;
  late final markers = <String, Point<int>>{
    for (int y = 0; y < tiles.length; y++)
      for (int x = 0; x < tiles[y].length; x++)
        if ('SNADEOBG'.contains(tiles[y][x])) tiles[y][x]: Point(x, y),
  };
  int get width => tiles.first.length;
  int get height => tiles.length;
  Point<int> at(String marker) => markers[marker]!;
  Point<int> get spawn => at('S');

  bool contains(Point<int> p) =>
      p.x >= 0 && p.y >= 0 && p.x < width && p.y < height;
  String tile(Point<int> p) => tiles[p.y][p.x];

  bool walkable(Point<int> p, ExpeditionProgress progress) {
    if (!contains(p)) return false;
    return switch (tile(p)) {
      '#' || '~' || 'N' => false,
      'B' || 'G' => progress.repaired,
      _ => true,
    };
  }

  List<Point<int>>? findPath(
    Point<int> from,
    Point<int> to,
    ExpeditionProgress progress, {
    bool nearby = false,
  }) {
    final queue = Queue<Point<int>>()..add(from);
    final previous = <Point<int>, Point<int>?>{from: null};
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (tileDistance(current, to) <= (nearby ? 1 : 0)) {
        final path = <Point<int>>[];
        Point<int>? step = current;
        while (step != null && step != from) {
          path.add(step);
          step = previous[step];
        }
        return path.reversed.toList();
      }
      for (final d in directions) {
        final next = Point(current.x + d.x, current.y + d.y);
        if (!previous.containsKey(next) && walkable(next, progress)) {
          previous[next] = current;
          queue.add(next);
        }
      }
    }
    return null;
  }
}

final expeditionMaps = [
  ExpeditionMap(const [
    '###############',
    '#....#....~...#',
    '#..E.#....~.G.#',
    '#....#....~...#',
    '#........O~...#',
    '#N........B...#',
    '#..##.....~...#',
    '#..A.....D~...#',
    '#S........~...#',
    '###############',
  ]),
  ExpeditionMap(const [
    '###############',
    '#A..#.....~..G#',
    '#...#..D..~...#',
    '#...#.....~...#',
    '#S.......OB...#',
    '#.N.......~...#',
    '#.....##..~...#',
    '#..E......~...#',
    '#.........~...#',
    '###############',
  ]),
  ExpeditionMap(const [
    '###############',
    '#G...~.....D..#',
    '#....~..E.....#',
    '#....~....##..#',
    '#....BO.......#',
    '#....~..##.N..#',
    '#....~.....##.#',
    '#....~.A......#',
    '#....~.......S#',
    '###############',
  ]),
  ExpeditionMap(const [
    '###############',
    '#..S..........#',
    '#N..##........#',
    '#......E...A..#',
    '#..##.........#',
    '#..D...#.O....#',
    '#~~~~~~~B~~~~~#',
    '#.............#',
    '#...G.........#',
    '###############',
  ]),
  ExpeditionMap(const [
    '###############',
    '#......~.....G#',
    '#..A...~......#',
    '#......~......#',
    '#.###..~..##..#',
    '#....O.B......#',
    '#S.N...~......#',
    '#......~......#',
    '#D..E..~......#',
    '###############',
  ]),
  ExpeditionMap(const [
    '###############',
    '#....G........#',
    '#.............#',
    '#~~~~B~~~~~~~~#',
    '#....O........#',
    '#E.....####...#',
    '#..D.......A..#',
    '#......N......#',
    '#.........S...#',
    '###############',
  ]),
  ExpeditionMap(const [
    '###############',
    '#..D.#....~...#',
    '#....#....~.G.#',
    '#..E......~...#',
    '#.##.....OB...#',
    '#.....#...~...#',
    '#..A..#...~...#',
    '#.....#N..~...#',
    '#..S......~...#',
    '###############',
  ]),
];

ExpeditionMap expeditionMap(int index, bool isC) {
  final original = expeditionMaps[index % expeditionMaps.length];
  if ((index >= expeditionMaps.length) != isC) {
    return ExpeditionMap(
      original.tiles.map((row) => row.split('').reversed.join()).toList(),
    );
  }
  return original;
}
