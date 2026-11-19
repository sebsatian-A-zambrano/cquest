"""Start the downloaded CQuest web game on this computer."""
from serve import DEFAULT_DB, server
from pathlib import Path
import webbrowser

game = Path(__file__).resolve().parent / "juego"
if not (game / "index.html").is_file():
    raise SystemExit("Extrae todo el ZIP antes de ejecutar este archivo.")
address = "http://127.0.0.1:8765/"
try:
    httpd = server(8765, DEFAULT_DB, game)
except OSError:
    raise SystemExit("El puerto 8765 está ocupado. Cierra el otro servidor antes de abrir esta copia.")
print(f"CQuest: {address}\nMantén esta ventana abierta. Ctrl+C para cerrar.")
webbrowser.open(address)
try:
    httpd.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    httpd.server_close()
