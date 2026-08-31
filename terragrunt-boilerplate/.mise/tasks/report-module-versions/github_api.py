import json
import os
import re
import urllib.request
from typing import Any

GITHUB_API = "https://api.github.com"
API_TIMEOUT_SECONDS = 10

GITHUB_REPO = re.compile(r"github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\.git)?$")


def github_repo(url: str) -> str:
    match = GITHUB_REPO.search(url)
    return f"{match['owner']}/{match['repo']}" if match else ""


def _github_json(path: str) -> Any:
    request = urllib.request.Request(
        f"{GITHUB_API}/{path}",
        headers={"Accept": "application/vnd.github+json"},
    )
    if token := os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN"):
        request.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(request, timeout=API_TIMEOUT_SECONDS) as response:
            return json.loads(response.read())
    except (OSError, json.JSONDecodeError):
        return None


def latest_github_version(repo: str, fallback: str) -> str:
    release = _github_json(f"repos/{repo}/releases/latest")
    if isinstance(release, dict) and (tag := release.get("tag_name")):
        return tag

    tags = _github_json(f"repos/{repo}/tags?per_page=1")
    if isinstance(tags, list) and tags and (name := tags[0].get("name")):
        return name

    return fallback
