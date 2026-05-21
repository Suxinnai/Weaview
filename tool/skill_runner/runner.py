from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

VERSION = "0.1.0"
ROOT = Path(__file__).resolve().parent
SKILLS_DIR = ROOT / ".skills"


def _json_response(handler: BaseHTTPRequestHandler, status: int, payload: dict[str, Any]) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def _read_json(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length = int(handler.headers.get("Content-Length") or "0")
    if length <= 0:
        return {}
    return json.loads(handler.rfile.read(length).decode("utf-8"))


def _skill_id_from_url(url: str) -> str:
    parsed = urlparse(url)
    source = parsed.path if parsed.scheme else url
    name = Path(source.rstrip("/")).name.replace(".git", "")
    slug = re.sub(r"[^a-zA-Z0-9_-]+", "-", name).strip("-").lower()
    return slug or "skill"


def _clone_or_copy(url: str, target: Path) -> None:
    SKILLS_DIR.mkdir(parents=True, exist_ok=True)
    local = Path(url).expanduser()
    if local.exists():
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(local, target, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        return
    if target.exists() and (target / ".git").exists():
        subprocess.run(["git", "pull", "--ff-only"], cwd=target, check=True, capture_output=True, text=True)
        return
    if target.exists():
        shutil.rmtree(target)
    subprocess.run(["git", "clone", "--depth", "1", url, str(target)], check=True, capture_output=True, text=True)


def _parse_skill_markdown(path: Path, fallback_id: str, source_url: str) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = [line.strip() for line in text.splitlines()]
    title = next((line.lstrip("#").strip() for line in lines if line.startswith("#")), fallback_id)
    description = next(
        (line for line in lines if line and not line.startswith("#") and not line.startswith("```")),
        "",
    )
    entrypoints = [{"id": "default", "label": "默认入口", "description": "Run the skill default command."}]
    lower = f"{fallback_id} {title} {description} {source_url}".lower()
    if "tweet" in lower or "twitter" in lower or "x-tweet" in lower:
        entrypoints = [
            {
                "id": "fetch_tweet",
                "label": "抓取推文",
                "description": "Fetch a tweet-like URL through scripts/fetch_tweet.py.",
            }
        ]
    return {
        "id": fallback_id,
        "name": title,
        "description": description,
        "sourceUrl": source_url,
        "localPath": str(path.parent),
        "entrypoints": entrypoints,
    }


def install_skill(url: str) -> dict[str, Any]:
    if not url.strip():
        raise ValueError("Missing skill URL.")
    skill_id = _skill_id_from_url(url)
    target = SKILLS_DIR / skill_id
    _clone_or_copy(url, target)
    skill_md = target / "SKILL.md"
    if not skill_md.exists():
        raise ValueError("Skill repository does not contain SKILL.md.")
    manifest = _parse_skill_markdown(skill_md, skill_id, url)
    (target / "skill.runner.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return manifest


def _load_skill(skill_id: str) -> dict[str, Any]:
    path = SKILLS_DIR / skill_id / "skill.runner.json"
    if not path.exists():
        raise ValueError(f"Skill is not installed: {skill_id}")
    return json.loads(path.read_text(encoding="utf-8"))


def _extract_url(text: str) -> str:
    match = re.search(r"https?://\S+", text)
    if not match:
        raise ValueError("No URL found in skill input.")
    return match.group(0).rstrip("。。，,)")


def run_skill(skill_id: str, input_text: str, entrypoint: str) -> dict[str, Any]:
    manifest = _load_skill(skill_id)
    source = f"{manifest.get('id', '')} {manifest.get('name', '')} {manifest.get('sourceUrl', '')}".lower()
    if not ("tweet" in source or "twitter" in source or "x-tweet" in source):
        raise ValueError("This runner only allows the x-tweet-fetcher compatible command in v0.1.0.")
    if entrypoint not in ("default", "fetch_tweet", ""):
        raise ValueError(f"Entrypoint is not allowlisted: {entrypoint}")
    repo = Path(manifest["localPath"])
    script = repo / "scripts" / "fetch_tweet.py"
    if not script.exists():
        raise ValueError("Missing scripts/fetch_tweet.py for this skill.")
    url = _extract_url(input_text)
    completed = subprocess.run(
        [sys.executable, str(script), "--url", url],
        cwd=repo,
        capture_output=True,
        text=True,
        timeout=90,
    )
    if completed.returncode != 0:
        error = completed.stderr.strip() or completed.stdout.strip() or "Skill command failed."
        return {"ok": False, "error": error}
    stdout = completed.stdout.strip()
    parsed: Any = None
    if stdout:
        try:
            parsed = json.loads(stdout)
        except json.JSONDecodeError:
            parsed = None
    if isinstance(parsed, dict):
        text = parsed.get("text") or parsed.get("content") or json.dumps(parsed, ensure_ascii=False, indent=2)
        return {"ok": True, "text": str(text), "json": parsed}
    return {"ok": True, "text": stdout}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            _json_response(self, 200, {"ok": True, "version": VERSION})
            return
        _json_response(self, 404, {"ok": False, "error": "Not found."})

    def do_POST(self) -> None:  # noqa: N802
        try:
            payload = _read_json(self)
            if self.path == "/skills/install":
                _json_response(self, 200, install_skill(str(payload.get("url", ""))))
                return
            if self.path == "/skills/run":
                result = run_skill(
                    str(payload.get("skillId", "")),
                    str(payload.get("input", "")),
                    str(payload.get("entrypoint", "default")),
                )
                _json_response(self, 200 if result.get("ok") else 400, result)
                return
            _json_response(self, 404, {"ok": False, "error": "Not found."})
        except Exception as exc:  # noqa: BLE001
            _json_response(self, 400, {"ok": False, "error": str(exc)})

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))


def main() -> None:
    parser = argparse.ArgumentParser(description="Weaview skill runner")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Weaview skill runner {VERSION} on http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
