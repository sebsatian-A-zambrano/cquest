"""Local CQuest server with a single SQLite save slot."""
import argparse
from contextlib import closing
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import sqlite3
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DB = Path(os.environ.get("LOCALAPPDATA", Path.home() / ".local" / "share")) / "CQuest" / "progress.sqlite3"
KEY = re.compile(r"(?:avatar|solved|campaign28\.solved|rpg\.(?:crossed|sound)|(?:draft\.|rpg\.world\.)(?:alg|c)-(?:[1-9]|1[0-4]))")
MAX_BODY = 512 * 1024


def connect(path):
    return sqlite3.connect(path, timeout=4)


def initialize(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with closing(connect(path)) as db, db:
        db.execute("CREATE TABLE IF NOT EXISTS progress (key TEXT PRIMARY KEY, value TEXT NOT NULL)")


class Handler(SimpleHTTPRequestHandler):
    def setup(self):
        self.request.settimeout(8)
        super().setup()

    def respond(self, status, data=None):
        body = json.dumps(data, ensure_ascii=True).encode() if data is not None else b""
        self.send_response(status)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Type", "application/json")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        path = urlsplit(self.path).path
        if path != "/api/progress":
            if path.startswith("/api/"):
                return self.respond(404)
            return super().do_GET()
        if not self.local_request():
            return self.respond(403)
        try:
            with closing(connect(self.server.db_path)) as db:
                self.respond(200, dict(db.execute("SELECT key, value FROM progress")))
        except sqlite3.Error:
            self.respond(503)

    def local_request(self):
        port = self.server.server_port
        hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
        host = self.headers.get("Host")
        origin = self.headers.get("Origin")
        return (
            host in hosts
            and self.headers.get("Sec-Fetch-Site") not in {"cross-site", "same-site"}
            and origin in {None, f"http://{host}"}
        )

    def do_PUT(self):
        if self.path != "/api/progress":
            return self.respond(404)
        if not self.local_request():
            return self.respond(403)
        if self.headers.get_content_type() != "application/json":
            return self.respond(415)
        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.respond(400)
        if not 0 < size <= MAX_BODY:
            return self.respond(413)
        try:
            data = json.loads(self.rfile.read(size))
            key, value = data["key"], data["value"]
            importing = data.get("import", False)
            if not (isinstance(key, str) and KEY.fullmatch(key)
                    and isinstance(value, str) and isinstance(importing, bool)):
                return self.respond(400)
            value.encode("utf-8")
        except (ValueError, KeyError, TypeError, AttributeError):
            return self.respond(400)
        try:
            with closing(connect(self.server.db_path)) as db, db:
                if importing:
                    db.execute("INSERT OR IGNORE INTO progress VALUES (?, ?)", (key, value))
                else:
                    db.execute(
                        "INSERT INTO progress VALUES (?, ?) "
                        "ON CONFLICT(key) DO UPDATE SET value=excluded.value", (key, value)
                    )
            self.respond(204)
        except sqlite3.Error:
            self.respond(503)


def server(port, db_path, directory):
    initialize(db_path)
    httpd = ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=str(directory)))
    httpd.db_path = db_path
    return httpd


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    options = parser.parse_args()
    directory = ROOT / "build" / "web"
    if not (directory / "index.html").is_file():
        parser.error("Primero compila la versión web de CQuest.")
    with server(options.port, options.db, directory) as httpd:
        print(f"CQuest en http://127.0.0.1:{httpd.server_port}/", flush=True)
        httpd.serve_forever()
