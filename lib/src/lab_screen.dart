import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'campaign.dart';
import 'progress.dart';
import 'runner.dart';
import 'style.dart';

typedef Runner = Future<Map<String, dynamic>> Function(
  Map<String, Object> request,
  void Function(String) onStatus,
);

class LabScreen extends StatefulWidget {
  const LabScreen({
    required this.lab,
    required this.number,
    required this.avatar,
    required this.passed,
    required this.onPass,
    required this.onNext,
    this.runner = runCode,
    this.expedition = false,
    super.key,
  });
  final Lab lab;
  final int number;
  final int avatar;
  final bool passed;
  final VoidCallback onPass;
  final VoidCallback? onNext;
  final Runner runner;
  final bool expedition;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  final _editorKey = GlobalKey();
  final _resultKey = GlobalKey();
  final _rewardKey = GlobalKey();
  final _stdin = TextEditingController();
  late final Map<String, TextEditingController> _files;
  late String _current;
  late bool _passed = widget.passed;
  String? _working;
  Map<String, dynamic>? _result;
  bool _isCustom = false;
  int _hints = 0;
  int _selectedCase = 0;

  Lab get lab => widget.lab;
  Color get accent => lab.language == 'alg' ? mint : lilac;
  String get draftKey => 'draft.${lab.id}';

  @override
  void initState() {
    super.initState();
    Map<String, dynamic> saved = {};
    final raw = readProgress(draftKey);
    if (raw != null) {
      try {
        saved = jsonDecode(raw) as Map<String, dynamic>;
      } on Object {
        // If stored data is invalid, reopen the original starter.
      }
    }
    _files = {
      for (final entry in lab.files.entries)
        entry.key: TextEditingController(
          text: lab.editable.contains(entry.key) && saved[entry.key] is String
              ? saved[entry.key] as String
              : entry.value,
        ),
    };
    _current = lab.editable.first;
    for (final name in lab.editable) {
      _files[name]!.addListener(_save);
    }
  }

  @override
  void dispose() {
    for (final controller in _files.values) {
      controller.dispose();
    }
    _stdin.dispose();
    super.dispose();
  }

  void _save() => saveProgress(
    draftKey,
    jsonEncode({for (final name in lab.editable) name: _files[name]!.text}),
  );

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 260),
        alignment: .02,
      );
    }
  }

  Future<void> _run({bool custom = false}) async {
    if (_working != null) return;
    FocusScope.of(context).unfocus();
    final sample = lab.tests[_selectedCase];
    final tests = custom
        ? [LabCase('Tu prueba', _stdin.text, '', sample.provided)]
        : lab.tests;
    setState(() {
      _working = 'Abriendo el laboratorio…';
      _result = null;
      _isCustom = custom;
    });
    Map<String, dynamic> result;
    try {
      result = await widget.runner(
        {
          'lang': lab.language,
          'files': {
            for (final entry in _files.entries) entry.key: entry.value.text,
          },
          'tests': tests.map((test) => test.toJson()).toList(),
        },
        (stage) {
          if (mounted) setState(() => _working = stage);
        },
      );
    } on Object {
      result = {'diagnostics': 'No se pudo ejecutar. Vuelve a intentarlo.'};
    }
    if (!mounted) return;
    final cases = (result['cases'] as List?) ?? [];
    final passed =
        !custom &&
        cases.length == lab.tests.length &&
        cases.every((test) => test['ok'] == true);
    if (passed && !_passed) widget.onPass();
    setState(() {
      _working = null;
      _result = result;
      _passed = _passed || passed;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollTo(passed ? _rewardKey : _resultKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final course = lab.language == 'alg'
        ? 'Algoritmos y lógica'
        : 'Programación en C';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: night,
        title: Text(
          widget.expedition
              ? 'Consola del faro'
              : 'Mundo ${widget.number} / $worldsPerCampaign',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 46),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1276),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(course),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, box) {
                      if (box.maxWidth < 850) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _lesson(),
                            const SizedBox(height: 14),
                            _workbench(),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _lesson()),
                          const SizedBox(width: 14),
                          Expanded(flex: 6, child: _workbench()),
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
    );
  }

  Widget _hero(String course) => MissionCard(
    border: accent.withValues(alpha: .52),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.asset(
            'assets/avatar-${widget.avatar}.jpg',
            width: 66,
            height: 76,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                lab.title,
                style: const TextStyle(
                  fontSize: 29,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                lab.story,
                style: const TextStyle(color: muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _lesson() => MissionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Aprende · ${lab.topic}', Icons.auto_stories_outlined),
        const SizedBox(height: 10),
        for (final paragraph in lab.lesson) ...[
          Text(paragraph, style: const TextStyle(height: 1.55, color: muted)),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 6),
        const Text(
          'Ejemplo resuelto',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _console(lab.example, color: accent),
        const SizedBox(height: 8),
        Text(lab.trace, style: const TextStyle(height: 1.45, color: muted)),
        const SizedBox(height: 16),
        const Divider(color: line),
        const SizedBox(height: 4),
        _heading('Tu misión', Icons.flag_outlined),
        const SizedBox(height: 7),
        Text(lab.goal, style: const TextStyle(height: 1.5)),
        if (lab.blueprint.isNotEmpty) ...[
          const SizedBox(height: 12),
          _heading('Plano del programa', Icons.account_tree_outlined),
          const SizedBox(height: 7),
          for (final (index, part) in lab.blueprint.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}.',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      part,
                      style: const TextStyle(color: muted, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => _scrollTo(_editorKey),
            icon: const Icon(Icons.code),
            label: const Text('Ir al editor'),
          ),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < _hints; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              '${i + 1}. ${lab.hints[i]}',
              style: const TextStyle(color: peach, height: 1.45),
            ),
          ),
        if (_hints < lab.hints.length)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _hints++),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(_hints == 0 ? 'Pedir una pista' : 'Otra pista'),
            ),
          ),
      ],
    ),
  );

  Widget _heading(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: accent, size: 21),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
    ],
  );

  Widget _workbench() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MissionCard(
        key: _editorKey,
        border: accent.withValues(alpha: .45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('Laboratorio de código', Icons.terminal),
            const SizedBox(height: 7),
            Text(
              lab.language == 'alg' ? 'Pseudocódigo de CQuest' : 'C17 · Clang',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: [
                for (final name in _files.keys)
                  ChoiceChip(
                    selected: _current == name,
                    showCheckmark: false,
                    label: Text(
                      name,
                      style: TextStyle(color: _current == name ? night : ink),
                    ),
                    selectedColor: accent,
                    avatar: lab.editable.contains(name)
                        ? null
                        : Icon(
                            Icons.lock_outline,
                            color: _current == name ? night : muted,
                            size: 15,
                          ),
                    onSelected: (_) => setState(() => _current = name),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): () =>
                    _run(),
              },
              child: TextField(
                key: ValueKey(_current),
                controller: _files[_current],
                readOnly: !lab.editable.contains(_current) || _working != null,
                minLines: 10,
                maxLines: 19,
                maxLength: 16000,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  height: 1.55,
                  fontSize: 14,
                  color: ink,
                ),
                decoration: _input('Código de $_current')
                    .copyWith(counterText: ''),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _working == null ? () => _run() : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Ejecutar y comprobar'),
                ),
                Text(
                  '${lab.tests.length} ${lab.tests.length == 1 ? 'caso' : 'casos'}',
                  style: const TextStyle(color: muted),
                ),
              ],
            ),
            if (_working case final stage?) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(stage, style: const TextStyle(color: mint)),
              ),
            ],
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Banco de pruebas'),
              subtitle: const Text('Consulta entradas o ensaya una propia.'),
              children: [_testBench()],
            ),
          ],
        ),
      ),
      if (_passed) ...[
        const SizedBox(height: 14),
        MissionCard(
          key: _rewardKey,
          border: peach,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: peach, size: 31),
              const SizedBox(height: 5),
              Text(
                widget.expedition
                    ? '¡Faro encendido!'
                    : widget.onNext == null
                    ? '¡Campaña completada!'
                    : '¡Mundo iluminado!',
                style: const TextStyle(
                  fontSize: 23,
                  color: peach,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text('Tu programa superó las pruebas de la misión.'),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.onNext != null)
                    FilledButton.icon(
                      onPressed: _working == null ? widget.onNext : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        widget.expedition
                            ? 'Volver al escenario'
                            : 'Siguiente mundo',
                      ),
                    ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver al atlas'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      if (_result != null) ...[const SizedBox(height: 14), _results()],
    ],
  );

  Widget _testBench() {
    final sample = lab.tests[_selectedCase];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 3,
          children: [
            for (int i = 0; i < lab.tests.length; i++)
              ChoiceChip(
                label: Text('Caso ${i + 1}'),
                selected: _selectedCase == i,
                showCheckmark: false,
                onSelected: (_) => setState(() => _selectedCase = i),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(sample.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(
          'Entrada: ${sample.input.isEmpty ? '(vacía)' : sample.input}',
          style: const TextStyle(color: muted),
        ),
        for (final entry in sample.provided.entries) ...[
          const SizedBox(height: 6),
          Text(entry.key, style: const TextStyle(color: muted)),
          _console(entry.value.isEmpty ? '(archivo vacío)' : entry.value),
        ],
        const SizedBox(height: 5),
        const Text('Salida esperada', style: TextStyle(color: muted)),
        _console(sample.expected),
        const SizedBox(height: 12),
        TextField(
          controller: _stdin,
          maxLength: 8000,
          minLines: 1,
          maxLines: 3,
          decoration: _input('Tu entrada (opcional)'),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _working == null ? () => _run(custom: true) : null,
            child: const Text('Probar mi entrada'),
          ),
        ),
      ],
    );
  }

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    alignLabelWithHint: true,
    filled: true,
    fillColor: night,
    border: const OutlineInputBorder(),
  );

  Widget _console(String code, {Color color = ink}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: night,
      borderRadius: BorderRadius.circular(8),
    ),
    child: SelectableText(
      code,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: color,
        height: 1.5,
      ),
    ),
  );

  Widget _results() {
    final result = _result!;
    final cases = (result['cases'] as List?) ?? [];
    final count = cases.where((value) => value['ok'] == true).length;
    final testIndex = result['testIndex'] as int?;
    return MissionCard(
      key: _resultKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            _isCustom ? 'Tu ejecución' : 'Resultados de las pruebas',
            Icons.fact_check_outlined,
          ),
          const SizedBox(height: 8),
          if (result['diagnostics'] case final String error) ...[
            if (testIndex != null && !_isCustom)
              Text('Caso ${testIndex + 1} · ${lab.tests[testIndex].label}'),
            if (_diagnosticTip(error) case final tip?) ...[
              Text(tip, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 8),
            ],
            _console(error, color: peach),
          ] else if (!_isCustom)
            Text(
              '$count de ${lab.tests.length} aprobados',
              style: TextStyle(
                color: count == lab.tests.length ? mint : peach,
                fontWeight: FontWeight.w800,
              ),
            ),
          for (var i = 0; i < cases.length; i++) ...[
            const SizedBox(height: 9),
            if (_isCustom) ...[
              const Text('Salida'),
              _console(_output(cases[i])),
            ] else
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: cases[i]['ok'] != true,
                leading: Icon(
                  cases[i]['ok'] == true
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: cases[i]['ok'] == true ? mint : peach,
                ),
                title: Text(lab.tests[i].label),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Entrada: ${lab.tests[i].input.isEmpty ? '(vacía)' : lab.tests[i].input}',
                      style: const TextStyle(color: muted),
                    ),
                  ),
                  _console(
                    'Esperado\n${lab.tests[i].expected}\n\nObtenido\n${_output(cases[i])}',
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String? _diagnosticTip(String diagnostic) {
    if (diagnostic.contains("expected ';'")) {
      return 'Busca un punto y coma al final de la instrucción señalada o en la línea anterior.';
    }
    if (diagnostic.contains('undeclared identifier') ||
        diagnostic.contains('undeclared function')) {
      return 'El compilador no encuentra ese nombre. Revisa cómo lo escribiste, dónde lo declaraste y qué cabeceras incluiste.';
    }
    if (diagnostic.contains("expected '}'")) {
      return 'Comprueba que cada llave de apertura tenga una llave de cierre.';
    }
    if (diagnostic.contains('non-void function')) {
      return 'La función promete devolver un valor. Asegúrate de que cada camino llegue a un retorno con un valor del tipo correcto.';
    }
    if (diagnostic.contains('undefined symbol')) {
      return 'Hay una declaración o llamada sin una implementación enlazada. Comprueba el nombre de la función en cada archivo.';
    }
    return null;
  }

  String _output(dynamic test) {
    if (test['error'] case final String error) return error;
    final output = (test['output'] as String).trimRight();
    final exit = test['exit'];
    final stderr = (test['stderr'] as String?)?.trimRight() ?? '';
    return [
      output.isEmpty ? '(sin salida)' : output,
      if (stderr.isNotEmpty) stderr,
      if (exit != 0) 'Estado de salida: $exit',
    ].join('\n');
  }
}
