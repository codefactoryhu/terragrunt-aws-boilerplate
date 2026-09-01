from __future__ import annotations

import re
from pathlib import Path

SOURCE_LINE = re.compile(r'^\s*source\s*=\s*"([^"]+)"')
GIT_SOURCE = re.compile(r"^git::(?P<url>[^?]+)(?:\?ref=(?P<ref>.+))?$")
SUBPATH_SEPARATOR = re.compile(r"(?<!:)//")


def extract_source(terragrunt_file: Path) -> str | None:
    for line in terragrunt_file.read_text().splitlines():
        if match := SOURCE_LINE.match(line):
            return match.group(1)
    return None


def parse_git_source(source: str) -> tuple[str, str, str]:
    match = GIT_SOURCE.match(source)
    if not match:
        return "", "", ""

    url, ref = match["url"], match["ref"] or "main"
    if separator := SUBPATH_SEPARATOR.search(url):
        return url[: separator.start()], ref, url[separator.end() :]
    return url, ref, ""


def find_units(env_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in env_dir.rglob("terragrunt.hcl")
        if not any(part.startswith(".") for part in path.relative_to(env_dir).parts)
    )
