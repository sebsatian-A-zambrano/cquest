"""Checks authored solutions, failing starters, diagnostics and loop isolation in real Chrome."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
labs = json.loads((ROOT / "assets/campaign.json").read_text(encoding="utf-8"))
solutions = json.loads((ROOT / "test/verified_solutions.json").read_text(encoding="utf-8"))
CHROME = Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe")

class QuietHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/harness":
            return super().do_GET()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(b'<!doctype html><meta charset="utf-8"><script src="/cquest-bridge.js"></script>')

    def log_message(self, *args):
        pass

def request(lab, files):
    return {
        "lang": lab["id"].split("-")[0],
        "tests": [{k: v for k, v in t.items() if k != "label"} for t in lab["tests"]],
        "files": files,
    }

with ThreadingHTTPServer(
    ("127.0.0.1", 0), partial(QuietHandler, directory=ROOT / "web")
) as server, sync_playwright() as playwright:
    Thread(target=server.serve_forever, daemon=True).start()
    browser = playwright.chromium.launch(executable_path=str(CHROME) if CHROME.exists() else None)
    page = browser.new_page()
    page.goto(f"http://127.0.0.1:{server.server_port}/harness")

    def grade(payload):
        return page.evaluate("async data => JSON.parse(await cquestGrade(JSON.stringify(data), () => {}))", payload)

    for lab, solution in zip(labs, solutions, strict=True):
        result = grade(request(lab, solution))
        assert len(result.get("cases", [])) == len(lab["tests"]) and all(
            case["ok"] for case in result["cases"]
        ), (lab["id"], result)
        starter = grade(request(lab, lab["files"]))
        assert starter.get("diagnostics") or any(
            not case["ok"] for case in starter.get("cases", [])
        ), (lab["id"], starter)
        print(f"{lab['id']}: passed {len(lab['tests'])} authored cases", flush=True)

    invalid = grade(request(labs[14], {"main.c": "int main(void) { return ; }"}))
    assert "error" in invalid.get("diagnostics", ""), invalid
    infinite = grade(request(labs[14], {"main.c": "int main(void) { volatile int x=0; for (;;) x=1; }"}))
    assert "excedió el tiempo" in infinite.get("diagnostics", ""), infinite
    recovered = grade(request(labs[14], solutions[14]))
    assert recovered["cases"][0]["ok"], recovered
    print("Compiler diagnostics, infinite loop timeout, and recovery verified.")
    browser.close()
    server.shutdown()
