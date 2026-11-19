import 'dart:math';

import 'package:flutter/material.dart';

import 'expedition.dart';

const tileSize = 32.0;
const palettes = [
  [
    Color(0xff233e3d),
    Color(0xff243534),
    Color(0xff275850),
    Color(0xff4f927a),
    Color(0xff183052),
    Color(0xff4588a4),
    Color(0xffffd394),
  ],
  [
    Color(0xff372e4b),
    Color(0xff27263e),
    Color(0xff493b62),
    Color(0xff986b98),
    Color(0xff253659),
    Color(0xff6379aa),
    Color(0xfff6bdad),
  ],
  [
    Color(0xff223b4d),
    Color(0xff1b2e43),
    Color(0xff2a5364),
    Color(0xff71a69d),
    Color(0xff182f52),
    Color(0xff488c9e),
    Color(0xffaff4da),
  ],
  [
    Color(0xff483745),
    Color(0xff352836),
    Color(0xff694558),
    Color(0xffb18282),
    Color(0xff242d51),
    Color(0xff677ba6),
    Color(0xffffb87c),
  ],
  [
    Color(0xff293c54),
    Color(0xff20304b),
    Color(0xff3c5c70),
    Color(0xff9cbbc9),
    Color(0xff1b2e4e),
    Color(0xff6091b8),
    Color(0xffd3e8ff),
  ],
];

class MoonTerrain extends CustomPainter {
  MoonTerrain(this.map, this.palette);
  final ExpeditionMap map;
  final List<Color> palette;

  late final Set<Point<int>> footpaths = _markTrails();

  Set<Point<int>> _markTrails() {
    final night = ExpeditionProgress(repaired: true);
    final paths = <Point<int>>{map.spawn};
    for (final (from, to, stopNear) in [
      ('S', 'N', true),
      ('S', 'A', false),
      ('S', 'D', false),
      ('A', 'O', false),
      ('D', 'O', false),
      ('O', 'G', false),
    ]) {
      paths.addAll(
        map.findPath(map.at(from), map.at(to), night, nearby: stopNear) ?? [],
      );
    }
    return paths;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / (map.width * tileSize),
      size.height / (map.height * tileSize),
    );
    final art = _Art(canvas);
    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        final tile = map.tile(Point(x, y));
        final l = x * tileSize, t = y * tileSize;
        final seed = (x * 97 + y * 197 + x * y * 37) % 101;
        if ('~B'.contains(tile)) {
          art.pixels(l, t, palette[4], [
            [0, 0, 32, 32],
          ]);
          art.pixels(l, t, palette[5].withValues(alpha: .55), [
            [3 + seed % 9, 8, 12, 1],
            [16, 19 + seed % 6, 10, 2],
            [7, 28, 5, 1],
          ]);
          for (final (dx, dy, bx, by, w, h) in [
            (-1, 0, 0, 0, 2, 32),
            (1, 0, 30, 0, 2, 32),
            (0, -1, 0, 0, 32, 2),
            (0, 1, 0, 30, 32, 2),
          ]) {
            final p = Point(x + dx, y + dy);
            if (map.contains(p) && !'~B'.contains(map.tile(p))) {
              art.pixels(l, t, palette[3].withValues(alpha: .55), [
                [bx, by, w, h],
              ]);
            }
          }
        } else {
          art.pixels(
            l,
            t,
            Color.lerp(palette[1], palette[0], .68 + (seed % 11) / 35)!,
            [
              [0, 0, 32, 32],
            ],
          );
          if (footpaths.contains(Point(x, y))) {
            final paving = Color.lerp(
              palette[0],
              const Color(0xffb49b86),
              .18,
            )!;
            art.pixels(l, t, paving, [
              [9, 9, 14, 14],
              [6, 12, 20, 8],
            ]);
            for (final (dx, dy, bx, by, w, h) in [
              (-1, 0, 0, 11, 13, 10),
              (1, 0, 20, 11, 12, 10),
              (0, -1, 11, 0, 10, 13),
              (0, 1, 11, 20, 10, 12),
            ]) {
              if (footpaths.contains(Point(x + dx, y + dy))) {
                art.pixels(l, t, paving, [
                  [bx, by, w, h],
                ]);
              }
            }
            art.pixels(l, t, palette[6].withValues(alpha: .19), [
              [11 + seed % 6, 11, 3, 1],
              [14, 18 + seed % 3, 2, 1],
            ]);
          }
          for (int i = 0; i < 7; i++) {
            art.pixels(l, t, palette[3].withValues(alpha: .24), [
              [
                (seed * 3 + i * 13) % 28 + 2,
                (seed * 7 + i * 17) % 28 + 2,
                i.isEven ? 1 : 3,
                1,
              ],
            ]);
          }
          if (seed % 5 == 0 && tile != '#') {
            art.pixels(l, t, palette[3], [
              [7, 24, 1, 5],
              [6, 26, 2, 1],
              [9, 22, 1, 5],
            ]);
            art.pixels(l, t, palette[6].withValues(alpha: .62), [
              [6, 24, 3, 1],
              [9, 22, 2, 1],
            ]);
          }
          if ('SNADEOG'.contains(tile)) {
            art.pixels(l, t, palette[3].withValues(alpha: .16), [
              [3, 18, 26, 10],
              [6, 27, 20, 2],
            ]);
          }
        }
      }
    }
    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        if (map.tile(Point(x, y)) != '#') continue;
        final l = x * tileSize + ((x * 7 + y * 3) % 4), t = y * tileSize;
        if ((x * 3 + y * 7) % 9 == 0) {
          final cliff = Color.lerp(palette[2], const Color(0xff8b809b), .28)!;
          art.pixels(l, t, palette[1], [
            [1, 20, 28, 8],
          ]);
          art.pixels(l, t, cliff, [
            [4, 14, 23, 11],
            [7, 9, 15, 6],
            [11, 6, 8, 5],
          ]);
          art.pixels(l, t, palette[3].withValues(alpha: .78), [
            [8, 10, 8, 2],
            [5, 16, 8, 2],
            [22, 17, 3, 2],
          ]);
          continue;
        }
        art.pixels(l, t, const Color(0xff3e373c), [
          [12, 16, 6, 15],
        ]);
        art.pixels(l, t, palette[2], [
          [11, 0, 7, 3],
          [7, 3, 15, 5],
          [4, 8, 20, 6],
          [1, 14, 26, 8],
          [3, 22, 22, 3],
        ]);
        art.pixels(l, t, palette[3].withValues(alpha: .76), [
          [11, 3, 5, 1],
          [7, 8, 6, 2],
          [3, 15, 9, 2],
          [11, 19, 7, 1],
        ]);
        art.pixels(l, t, palette[6].withValues(alpha: .28), [
          [18, 10, 3, 2],
          [19, 17, 4, 1],
        ]);
      }
    }
    final bounds = Rect.fromLTWH(
      0,
      0,
      map.width * tileSize,
      map.height * tileSize,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          radius: .73,
          colors: [Colors.transparent, Color(0x5526284a), Color(0xc309101e)],
          stops: [.42, .83, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(MoonTerrain old) =>
      old.map != map || old.palette != palette;
}

class MoonFigures extends CustomPainter {
  MoonFigures({
    required this.map,
    required this.palette,
    required this.avatar,
    required this.npc,
    required this.player,
    required this.elapsed,
    required this.target,
    required this.charge,
    required this.memory,
    required this.repaired,
    required this.facingLeft,
    required this.walking,
  });
  final ExpeditionMap map;
  final List<Color> palette;
  final int avatar, npc;
  final Offset player;
  final double elapsed;
  final Point<int> target;
  final String? charge;
  final bool memory, repaired, facingLeft, walking;

  Offset centre(Point<int> p) =>
      Offset((p.x + .5) * tileSize, (p.y + .5) * tileSize);
  Offset loc(String id) => centre(map.at(id));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(
      size.width / (map.width * tileSize),
      size.height / (map.height * tileSize),
    );
    final art = _Art(canvas);
    final time = elapsed * 2 * pi;
    final light = palette[6];
    for (int i = 0; i < 20; i++) {
      final x = 14 + (i * 71) % (map.width * 32 - 28) + sin(time + i * .6) * 6;
      final y = 14 + (i * 43) % (map.height * 32 - 28) + cos(time + i) * 4;
      art.pixels(
        x,
        y,
        light.withValues(alpha: .15 + (sin(time * 2 + i) + 1) * .22),
        [
          [0, 0, i % 3 == 0 ? 2 : 1, 1],
        ],
      );
    }
    if (!memory) {
      final p = loc('E') + Offset(0, sin(time * 2) * 1.5);
      art.glow(p, const Color(0xffabdfff), 13, .48);
      art.gem(p, const Color(0xffb5e3ff), 5);
    }
    for (final id in ['A', 'D']) {
      if (charge == 'gone') break;
      final p = loc(id);
      if (charge == id) art.glow(p, light, 17, .42);
      art.pixels(p.dx, p.dy, const Color(0xff152034), [
        [-9, 4, 18, 6],
      ]);
      art.pixels(
        p.dx,
        p.dy,
        charge == id ? const Color(0xffb67b59) : const Color(0xff56516f),
        [
          [-8, 0, 16, 8],
        ],
      );
      art.pixels(p.dx, p.dy, charge == id ? light : const Color(0xff9085a3), [
        [-7, -2, 14, 3],
        [-1, 2, 2, 4],
      ]);
    }
    final b = loc('B');
    if (repaired) {
      final horizontal =
          map.tile(Point(map.at('B').x, map.at('B').y - 1)) == '~';
      canvas.save();
      canvas.translate(b.dx, b.dy);
      if (!horizontal) canvas.rotate(pi / 2);
      art.pixels(0, 0, const Color(0xff805a56), [
        [-16, -11, 32, 22],
      ]);
      for (int i = 0; i < 6; i++) {
        art.pixels(0, 0, const Color(0xffc99167), [
          [-15 + i * 5, -8, 4, 16],
        ]);
      }
      art.pixels(0, 0, light, [
        [-16, -11, 32, 2],
        [-16, 9, 32, 2],
      ]);
      canvas.restore();
      art.glow(b, light, 24, .37);
    }
    final o = loc('O');
    final towerLight = repaired ? const Color(0xffffd493) : palette[3];
    final masonry = Color.lerp(palette[2], const Color(0xff807496), .54)!;
    art.pixels(o.dx, o.dy, const Color(0xff172038), [
      [-18, -5, 36, 11],
    ]);
    art.pixels(o.dx, o.dy, masonry, [
      [-14, -23, 28, 25],
      [-10, -28, 20, 8],
      [-6, -34, 12, 7],
    ]);
    art.pixels(o.dx, o.dy, const Color(0xff45536d), [
      [-16, -19, 32, 3],
      [-13, -8, 26, 2],
      [-10, -26, 20, 3],
    ]);
    art.pixels(o.dx, o.dy, const Color(0xff252a47), [
      [-7, -23, 14, 11],
      [-10, -3, 4, 7],
      [6, -3, 4, 7],
    ]);
    art.pixels(o.dx, o.dy, towerLight, [
      [-5, -21, 10, 6],
      [-3, -23, 6, 2],
      [-12, -11, 3, 3],
      [9, -11, 3, 3],
    ]);
    art.pixels(o.dx, o.dy, const Color(0xff696185), [
      [0, -23, 1, 9],
      [-5, -17, 10, 1],
    ]);
    if (repaired) {
      art.glow(o + const Offset(0, -20), towerLight, 47, .56);
      art.pixels(o.dx, o.dy, towerLight.withValues(alpha: .47), [
        [-21, -26, 7, 2],
        [14, -25, 8, 2],
        [-2, -43, 3, 6],
      ]);
    }
    final screen = repaired ? const Color(0xffa0f4ce) : light;
    art.glow(o, screen, 22, .27);
    art.pixels(o.dx, o.dy, const Color(0xff605b82), [
      [-9, -10, 18, 20],
      [-12, 8, 24, 3],
      [-5, -13, 10, 3],
    ]);
    art.pixels(o.dx, o.dy, const Color(0xff212b46), [
      [-6, -8, 12, 10],
    ]);
    art.pixels(o.dx, o.dy, screen, [
      [-4, -6, 8, 1],
      [-4, -3, 5, 1],
      [-2, 5, 4, 2],
      [7, -14, 2, 4],
    ]);
    final g = loc('G');
    if (repaired) art.glow(g, light, 26, .57);
    art.pixels(g.dx, g.dy, const Color(0xff856e91), [
      [-10, -9, 4, 19],
      [6, -9, 4, 19],
      [-8, -13, 16, 5],
      [-5, -16, 10, 3],
    ]);
    if (repaired) {
      art.pixels(g.dx, g.dy, light.withValues(alpha: .63), [
        [-5, -7, 10, 17],
        [-2, -9, 4, 14],
      ]);
    }
    final hero = player * tileSize + const Offset(16, 16);
    final villager = loc('N');
    void drawHero() => art.sprite(
      hero,
      avatar,
      facingLeft,
      walking ? sin(time * 19) * 1.4 : 0,
    );
    if (hero.dy <= villager.dy) drawHero();
    art.sprite(villager, npc, false, 0);
    if (hero.dy > villager.dy) drawHero();
    final q = centre(target) + Offset(0, -18 + sin(time * 3) * 2);
    art.glow(q, light, 12, .55);
    art.gem(q, const Color(0xffffe9a8), 3.7);
  }

  @override
  bool shouldRepaint(MoonFigures old) => true;
}

class _Art {
  _Art(this.canvas);
  final Canvas canvas;
  final Paint brush = Paint()..isAntiAlias = false;

  void pixels(double x, double y, Color c, List<List<int>> shapes) {
    brush.color = c;
    for (final r in shapes) {
      canvas.drawRect(
        Rect.fromLTWH(x + r[0], y + r[1], r[2].toDouble(), r[3].toDouble()),
        brush,
      );
    }
  }

  void glow(Offset c, Color color, double r, double alpha) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void gem(Offset p, Color c, double r) {
    brush.color = c;
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r, p.dy)
        ..lineTo(p.dx, p.dy + r)
        ..lineTo(p.dx - r, p.dy)
        ..close(),
      brush,
    );
  }

  void sprite(Offset p, int kind, bool left, double stride) {
    final coat = [
      const Color(0xff4aab8c),
      const Color(0xff9c718d),
      const Color(0xffedf0f4),
      const Color(0xff7d86bf),
    ][kind];
    final detail = [
      const Color(0xffa0e7ba),
      const Color(0xffffb680),
      const Color(0xffb6a8fa),
      const Color(0xffdca4e3),
    ][kind];
    final skin = kind == 3 ? const Color(0xffad7664) : const Color(0xffffd9bf);
    final hair = kind == 0 ? coat : const Color(0xffa3665a);
    final x = p.dx, y = p.dy;
    pixels(x, y, const Color(0xff0f1b2d), [
      [-9, 8, 18, 4],
    ]);
    if (kind == 2) {
      glow(p, detail, 14, .31);
      pixels(x, y, coat, [
        [-7, -9, 14, 12],
        [-5, -11, 10, 2],
      ]);
      pixels(x, y, const Color(0xff29344e), [
        [-4, -6, 8, 5],
      ]);
      pixels(x, y, detail, [
        [-3, -5, 2, 2],
        [1, -5, 2, 2],
        [-2, -15, 2, 5],
      ]);
      pixels(x, y, const Color(0xfff3ae74), [
        [-5, 3, 10, 2],
        [2, 5, 4, 2],
      ]);
    } else {
      pixels(x, y + stride, const Color(0xff302940), [
        [-5, 6, 4, 4],
      ]);
      pixels(x, y - stride, const Color(0xff302940), [
        [1, 6, 4, 4],
      ]);
      pixels(x, y, coat, [
        [-6, -1, 12, 9],
        [-8, 2, 2, 4],
        [6, 1, 2, 4],
      ]);
      pixels(x, y, hair, [
        [-5, -13, 10, 3],
        [-7, -10, 14, 9],
      ]);
      pixels(x, y, skin, [
        [-4, -9, 9, 7],
      ]);
      pixels(x, y, const Color(0xff38253b), [
        [left ? -3 : 1, -7, 2, 2],
      ]);
      pixels(x, y, detail, [
        [-5, -12, 5, 2],
        [-5, -2, 10, 2],
        [2, 1, 3, 5],
      ]);
      pixels(x, y, const Color(0xffffc988), [
        [-2, 3, 3, 2],
      ]);
    }
  }
}
