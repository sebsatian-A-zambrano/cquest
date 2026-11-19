import json
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from tool.serve import server


class ProgressTest(unittest.TestCase):
    def test_writes_survive_restart_and_import_does_not_replace_them(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            db = root / "private" / "progress.sqlite3"
            public = root / "public"
            public.mkdir()
            initial = '{"choice":1,"memory":true,"repaired":true}'
            draft = '{"main.c":"/* qué tal */"}'

            def run(check):
                with server(0, db, public) as httpd:
                    thread = Thread(target=httpd.serve_forever, daemon=True)
                    thread.start()
                    origin = f"http://127.0.0.1:{httpd.server_port}"

                    def get(path="/api/progress"):
                        with urlopen(origin + path, timeout=5) as response:
                            return json.load(response)

                    def save(key, value, **headers):
                        mode = headers.pop("importing", False)
                        req = Request(origin + "/api/progress", method="PUT",
                                      data=json.dumps({"key": key, "value": value, "import": mode}).encode(),
                                      headers={"Content-Type": "application/json", **headers})
                        with urlopen(req, timeout=5) as response:
                            self.assertEqual(response.status, 204)
                    try:
                        check(get, save)
                    finally:
                        httpd.shutdown()
                        thread.join()

            def write(get, save):
                self.assertEqual(get(), {})
                save("rpg.world.alg-1", initial, importing=True)
                save("draft.c-3", draft)

            def check(get, save):
                save("rpg.world.alg-1", "stale", importing=True)
                self.assertEqual(get(), {"rpg.world.alg-1": initial, "draft.c-3": draft})
                for key, headers, status in [
                    ("unknown", {}, 400),
                    ("avatar", {"Origin": "https://example.org"}, 403),
                ]:
                    with self.assertRaises(HTTPError) as failure:
                        save(key, "1", **headers)
                    self.assertEqual(failure.exception.code, status)
                with self.assertRaises(HTTPError) as failure:
                    get("/progress.sqlite3")
                self.assertEqual(failure.exception.code, 404)
                save("rpg.world.alg-1", "updated")
                self.assertEqual(get()["rpg.world.alg-1"], "updated")

            run(write)
            run(check)
