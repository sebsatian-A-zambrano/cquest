import 'dart:js_interop';

@JS('cquestFx')
external void _play(JSString event);

void playSound(String event) {
  try {
    _play(event.toJS);
  } on Object {
    // The expedition still works when audio is not available.
  }
}
