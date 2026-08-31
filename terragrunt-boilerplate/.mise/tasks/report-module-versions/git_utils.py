import os
import subprocess
from pathlib import Path

from github_api import github_repo


def _git(*args: str) -> str:
    try:
        return subprocess.run(
            ["git", *args],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def repository_name() -> str:
    repo = github_repo(_git("remote", "get-url", "origin"))
    return repo.split("/")[-1] if repo else Path.cwd().name


def chdir_to_repo_root() -> None:
    if root := _git("rev-parse", "--show-toplevel"):
        os.chdir(root)
