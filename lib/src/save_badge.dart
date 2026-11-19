import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'progress.dart';
import 'style.dart';

class SaveBadge extends StatefulWidget {
  const SaveBadge({this.compact = false, super.key});
  final bool compact;
  @override
  State<SaveBadge> createState() => _SaveBadgeState();
}

class _SaveBadgeState extends State<SaveBadge> {
  Timer? timer;
  String value = progressStatus();
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final next = progressStatus();
      if (next != value && mounted) setState(() => value = next);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> state;
    try {
      state = jsonDecode(value) as Map<String, dynamic>;
    } on Object {
      state = {'phase': 'error', 'message': 'No se pudo comprobar el guardado'};
    }
    final phase = state['phase'];
    final icon = phase == 'saved'
        ? Icons.save_outlined
        : phase == 'error'
        ? Icons.warning_amber_rounded
        : Icons.save_outlined;
    final message = state['message'] as String;
    if (widget.compact) {
      return IconButton(
        onPressed: openSaves,
        tooltip: message,
        icon: Icon(icon, size: 21, color: phase == 'error' ? peach : mint),
      );
    }
    return TextButton.icon(
      onPressed: openSaves,
      icon: Icon(icon, size: 18),
      label: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}
