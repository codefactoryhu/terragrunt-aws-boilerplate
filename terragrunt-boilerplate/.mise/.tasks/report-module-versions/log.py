import sys
from typing import Any


def _log(level: str, message: str, stream: Any = sys.stdout) -> None:
    print(f"[{level}]".ljust(10) + message, file=stream)


def info(message: str) -> None:
    _log("INFO", message)


def error(message: str) -> None:
    _log("ERROR", message, sys.stderr)


def success(message: str) -> None:
    _log("SUCCESS", message)
