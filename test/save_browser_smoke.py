"""Verify local save recovery, backup merging, and the complete offline bundle."""
import json
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from tool.serve import server

CHROME = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")

def ready(page, url):
    page.goto(url)
    page.evaluate("async () => { await cquestProgressReady; }")

with TemporaryDirectory() as folder, sync_playwright() as pw:
    httpd = server(0, Path(folder) / "progress.sqlite3", ROOT / "build" / "web")
    thread = Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    origin = f"http://127.0.0.1:{httpd.server_port}"
    browser = pw.chromium.launch(executable_path=str(CHROME) if CHROME.exists() else None)
    context = browser.new_context()
    page = context.new_page()
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    ready(page, origin + "/partida.html")
    values = {
        "avatar": "1",
        "rpg.crossed": "0,1",
        "rpg.world.alg-1": json.dumps({"x": 6, "y": 4, "choice": 0, "charged": True, "memory": True, "repaired": True, "finished": True}),
        "draft.alg-1": json.dumps({"faro.algo": "inicio { mostrar(7); }"}),
    }
    page.evaluate("""async values => {
      for (const [key,value] of Object.entries(values)) cquestSaveProgress(key,value);
      await cquestFlushProgress();
    }""", values)
    page.wait_for_function("""async () => {
      const values = await (await fetch('/api/progress')).json();
      return values['rpg.crossed'] === '0,1' && Boolean(values['draft.alg-1']);
    }""")
    backup = page.evaluate("cquestExportProgress()")
    page.reload()
    page.evaluate("async () => { await cquestProgressReady; }")
    assert page.evaluate("cquestReadProgress('draft.alg-1')") == values["draft.alg-1"]
    page.evaluate("async () => {cquestSaveProgress('rpg.crossed','0,1,2');await cquestFlushProgress();}")
    page.evaluate("data => cquestImportProgress(data)", backup)
    assert page.evaluate("cquestReadProgress('rpg.crossed')") == "0,1,2"
    before = page.evaluate("cquestExportProgress()")
    broken = json.loads(backup)
    broken["saves"].append({"key": "unrelated-private-key", "value": "bad", "modifiedAt": 1})
    try:
        page.evaluate("data => cquestImportProgress(data)", json.dumps(broken))
        raise AssertionError("Invalid backup was accepted")
    except Exception as failure:
        assert "datos inválidos" in str(failure), failure
    assert json.loads(before)["saves"] == json.loads(page.evaluate("cquestExportProgress()"))["saves"]
    with page.expect_download() as download:
        page.get_by_role("button", name="Descargar copia").click()
    assert download.value.suggested_filename.startswith("cquest-partida-")
    page.wait_for_function("async () => (await (await fetch('/api/progress')).json())['rpg.crossed'] === '0,1,2'")
    context.close()
    fresh = browser.new_context()
    page = fresh.new_page()
    ready(page, origin + "/partida.html")
    assert page.evaluate("cquestReadProgress('rpg.crossed')") == "0,1,2", "SQLite did not recover into a clean browser"
    assert json.loads(page.evaluate("cquestReadProgress('rpg.world.alg-1')"))["finished"]
    fresh.close()
    httpd.shutdown()
    thread.join()
    httpd.server_close()
    print("Browser database, SQLite recovery, backup download, and safe import: passed.", flush=True)

    class Quiet(SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass

    static = ThreadingHTTPServer(("127.0.0.1", 0), partial(Quiet, directory=ROOT / "build" / "web"))
    thread = Thread(target=static.serve_forever, daemon=True)
    thread.start()
    origin = f"http://127.0.0.1:{static.server_port}"
    context = browser.new_context(viewport={"width": 390, "height": 844}, is_mobile=True, has_touch=True)
    page = context.new_page()
    page.on("pageerror", lambda error: errors.append(str(error)))
    ready(page, origin + "/partida.html")
    page.evaluate("data => cquestImportProgress(data)", backup)
    page.goto(origin + "/instalar.html")
    page.evaluate("async () => { await cquestOfflineReady; }")
    page.wait_for_function("navigator.serviceWorker.controller !== null", timeout=120000)
    context.set_offline(True)
    page.goto(origin + "/partida.html")
    page.evaluate("async () => { await cquestProgressReady; }")
    assert page.evaluate("cquestReadProgress('rpg.crossed')") == "0,1"
    page.goto(origin + "/")
    page.wait_for_selector("flutter-view", timeout=60000)
    labs = json.loads((ROOT / "assets/campaign.json").read_text(encoding="utf-8"))
    solutions = json.loads((ROOT / "test/verified_solutions.json").read_text(encoding="utf-8"))
    result = page.evaluate("async data => JSON.parse(await cquestGrade(JSON.stringify(data), () => {}))", {
        "lang": "c", "tests": [{k: v for k, v in t.items() if k != "label"} for t in labs[14]["tests"]], "files": solutions[14],
    })
    assert result.get("cases") and all(case["ok"] for case in result["cases"]), result
    assert not errors, errors
    context.close()
    browser.close()
    static.shutdown()
    thread.join()
    static.server_close()
    print("Mobile layout, static hosting, offline reload, saved progress, and offline C compiler: passed.")
