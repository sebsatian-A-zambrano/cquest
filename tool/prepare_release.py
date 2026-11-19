"""Prepare Flutter's web build for offline use and GitHub Releases."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parent.parent


def prepare(build: Path, archive: Path | None):
    build = build.resolve()
    if not (build / "index.html").is_file():
        raise SystemExit("Build the game with flutter build web first.")
    (build / ".nojekyll").touch()
    files = sorted(
        path for path in build.rglob("*")
        if path.is_file()
        and path.stat().st_size
        and path.name not in {"offline-files.json", "cquest-sw.js"}
        and path.suffix != ".map"
    )
    digest = hashlib.sha256()
    entries = []
    for path in files:
        relative = path.relative_to(build).as_posix()
        data = path.read_bytes()
        digest.update(relative.encode())
        digest.update(hashlib.sha256(data).digest())
        entries.append(relative)
    # The service worker's own behavior is part of the cache version.
    worker_path = build / "cquest-sw.js"
    worker = re.sub(r"const BUILD_VERSION = '[^']+';", "const BUILD_VERSION = '__CQUEST_VERSION__';", worker_path.read_text(encoding="utf-8"))
    digest.update(worker.encode("utf-8"))
    manifest = {
        "version": digest.hexdigest()[:20],
        "bytes": sum(path.stat().st_size for path in files),
        "files": entries,
    }
    worker_path.write_text(worker.replace("__CQUEST_VERSION__", manifest["version"]), encoding="utf-8")
    (build / "offline-files.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if archive:
        archive = archive.resolve()
        if archive.is_relative_to(build):
            raise SystemExit("Write the ZIP outside the web build.")
        archive.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(archive, "w", ZIP_DEFLATED) as package:
            for path in sorted(build.rglob("*")):
                if path.is_file() and path.suffix != ".map":
                    package.write(path, "juego/" + path.relative_to(build).as_posix())
            package.write(ROOT / "tool" / "start_game.py", "start_game.py")
            package.write(ROOT / "tool" / "serve.py", "serve.py")
            package.writestr("JUGAR.txt", (
                "CQuest - El festival de los faros\n\n"
                "En computadora, instala Python 3 si hace falta y ejecuta:\n"
                "python start_game.py\n\n"
                "Se abre el juego en http://127.0.0.1:8765/.\n"
                "Mantén abierta la consola mientras juegas.\n"
                "En celular, usa el enlace del juego publicado en GitHub Pages\n"
                "y su opción Instalar para guardarlo en la pantalla de inicio.\n"
                "Este ZIP contiene la versión web. No es un APK de Android.\n"
            ))
        checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
        archive.with_suffix(".zip.sha256").write_text(
            f"{checksum}  {archive.name}\n", encoding="utf-8"
        )
        print(f"{archive.name}: {archive.stat().st_size / 1024**2:.1f} MiB")
    print(f"Offline bundle: {len(entries)} files, {manifest['bytes'] / 1024**2:.1f} MiB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=Path, default=ROOT / "build" / "web")
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    prepare(args.build, args.archive)
