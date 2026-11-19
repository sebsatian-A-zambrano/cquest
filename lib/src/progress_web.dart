import 'dart:js_interop';

@JS('cquestProgressReady')
external JSPromise<JSAny?> get _ready;
@JS('cquestReadProgress')
external JSString? _read(JSString key);
@JS('cquestSaveProgress')
external void _save(JSString key, JSString value);
@JS('cquestProgressStatus')
external JSString _status();
@JS('cquestOpenSaves')
external void _openSaves();

Future<void> initializeProgress() async {
  try {
    await _ready.toDart;
  } on Object {
    // The save indicator reports unavailable storage while the game stays usable.
  }
}

String? readProgress(String key) {
  try {
    return _read(key.toJS)?.toDart;
  } on Object {
    return null;
  }
}

void saveProgress(String key, String value) => _save(key.toJS, value.toJS);
String progressStatus() {
  try {
    return _status().toDart;
  } on Object {
    return '{"phase":"error","message":"No se pudo comprobar el guardado"}';
  }
}

void openSaves() => _openSaves();
