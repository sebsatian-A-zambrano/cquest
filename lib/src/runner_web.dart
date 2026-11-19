import 'dart:convert';
import 'dart:js_interop';

@JS('cquestGrade')
external JSPromise<JSString> _grade(JSString json, JSFunction status);

Future<Map<String, dynamic>> runCode(
  Map<String, Object> request,
  void Function(String) onStatus,
) async {
  try {
    final result = await _grade(
      jsonEncode(request).toJS,
      ((JSString value) => onStatus(value.toDart)).toJS,
    ).toDart;
    return jsonDecode(result.toDart) as Map<String, dynamic>;
  } on Object {
    return {
      'diagnostics': 'No se pudo iniciar el laboratorio. Recarga la página.',
    };
  }
}
