import 'package:flutter/material.dart';

const night = Color(0xff0e1327);
const panel = Color(0xff171e35);
const line = Color(0xff323d5b);
const ink = Color(0xfff7f2ff);
const muted = Color(0xffb8c2da);
const mint = Color(0xff9de7cb);
const lilac = Color(0xffc9b4fa);
const peach = Color(0xffffcb99);
const explorers = ['Lúa', 'Nico', 'Mimo'];
const roles = ['Exploradora', 'Inventor', 'Robot guía'];

class MissionCard extends StatelessWidget {
  const MissionCard({required this.child, this.border = line, super.key});
  final Widget child;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: border),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
