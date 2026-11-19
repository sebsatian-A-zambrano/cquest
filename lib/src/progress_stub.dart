final _saved = <String,String>{};
Future<void> initializeProgress() async {}
String? readProgress(String key) => _saved[key];
void saveProgress(String key,String value) { _saved[key] = value; }
String progressStatus() => '{"phase":"local","message":"Guardado en esta sesión"}';
void openSaves() {}
