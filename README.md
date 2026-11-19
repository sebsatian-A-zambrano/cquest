# CQuest · El festival de los faros

RPG de exploración y programación en español, con dos campañas independientes: **14 mundos de Algoritmos** y **14 mundos de C**. Explora una noche de faros apagados, conversa, toma decisiones y escribe código para reparar cada lugar y abrir el siguiente mundo.

**[Jugar](https://sebsatian-a-zambrano.github.io/cquest/)** · **[Instalar en el celular](https://sebsatian-a-zambrano.github.io/cquest/instalar.html)** · **[Descargar para PC](https://github.com/sebsatian-A-zambrano/cquest/releases/latest)**

## Jugar e instalar

Escoge un avatar y abre una campaña. Usa **WASD o las flechas** para caminar y **E** para interactuar. En el celular puedes tocar el mapa, los objetos y los botones de dirección. La luz dorada señala el próximo objetivo.

Habla con el habitante, elige una ruta y lleva el suministro a la consola. Allí encontrarás una explicación, un ejemplo, pistas, un editor y pruebas que ejecutan tu código. Al reparar el faro aparecen el puente y la salida al siguiente mundo. Los ecos opcionales, decisiones y logros se recogen en la crónica final.

En **Android**, abre el juego en Chrome y elige **Instalar** o **Añadir a pantalla de inicio**. En **iPhone**, abre el enlace en Safari y usa **Compartir → Añadir a pantalla de inicio**. En la página de instalación, espera la confirmación de que la descarga terminó antes de jugar sin conexión: incluye el compilador y ocupa aproximadamente 70 MB. La aplicación se instala desde el navegador; la descarga de GitHub es un ZIP para PC, no un APK.

## Tu partida es local

Se guardan la posición, decisiones, suministros, recuerdos, mundos completados y borradores. **No se necesita cuenta y las partidas no se envían a GitHub ni a una base de datos en la nube.**

- En el juego publicado y la aplicación instalada, la base de datos está en el navegador del dispositivo (IndexedDB, con una copia local).
- En el PC, si usas el servidor incluido, también se guarda en SQLite: %LOCALAPPDATA%\CQuest\progress.sqlite3 en Windows. Se comparte entre los navegadores que usen ese servidor local.
- Abre **Mi partida** desde el indicador de guardado para descargar una copia e importarla en otro dispositivo. La importación conserva los capítulos ya completados.
- Guarda una copia antes de borrar datos del navegador, cambiar de navegador o reinstalar la aplicación. Cada navegador y cada dirección del juego tienen su propia partida.

## Descargar y abrir en PC

Descarga **cquest-web.zip** desde [Releases](https://github.com/sebsatian-A-zambrano/cquest/releases/latest), extráelo por completo y, con Python 3 instalado, ejecuta:

~~~text
python start_game.py
~~~

Se abrirá http://127.0.0.1:8765/. Mantén la ventana abierta mientras juegas. El servidor solo acepta conexiones desde este equipo. El ZIP incluye el juego, los recursos y el compilador; no necesitas Flutter para jugar.

## Construir desde el código

Requiere Flutter 3.47.7 y Python 3.10 o posterior. El juego está escrito en **Dart y Flutter**; el compilador y la instalación usan JavaScript.

~~~text
flutter pub get
flutter analyze --fatal-infos
flutter test
node --test test/save_merge.test.mjs
python -m unittest discover -s test -p test_progress.py
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
python tool/prepare_release.py --archive dist/cquest-web.zip
python tool/serve.py
~~~

Con el servidor local abierto, visita http://127.0.0.1:8765/. Las partidas quedan fuera de la carpeta pública. No publiques archivos de base de datos ni copias personales.

Las pruebas de navegador requieren Playwright para Python y Chrome o Chromium:

~~~text
python test/compiler_smoke.py
python test/save_browser_smoke.py
python test/rpg_browser_smoke.py
~~~

La primera comprueba las soluciones y los programas iniciales de los 28 desafíos, los errores del compilador y la recuperación tras un bucle infinito. La segunda comprueba guardado, recuperación desde SQLite en un navegador nuevo, exportación e importación, y ejecución de C sin conexión. La tercera recorre el primer capítulo completo.

## Publicación

Al subir cambios a main, GitHub Actions comprueba y construye el juego para GitHub Pages. Al subir una etiqueta v*, genera la descarga de la versión y su comprobante SHA-256.

Las campañas se basan en los temas de Algoritmos e Lógica de Programação y Linguagem e Técnicas de Programação de Unicesumar. Los libros PDF no forman parte de este repositorio. El código se compila con Clang en un Web Worker y se ejecuta en WebAssembly con entradas y archivos virtuales. Se incluyen las licencias de [@live-codes/clang-wasm](https://github.com/live-codes/clang-wasm) y [browser_wasi_shim](https://github.com/bjorn3/browser_wasi_shim) en web/compiler. El arte de portada, los retratos y el icono son recursos originales generados con ImageGen.
