from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

from git_utils import repository_name
from github_api import github_repo, latest_github_version
from terragrunt import parse_git_source

REPORT_TIMEZONE = timezone(timedelta(hours=1))

GIT, LOCAL, UNKNOWN = "git", "local", "unknown"
UP_TO_DATE, OUTDATED = "up-to-date", "outdated"


@dataclass(frozen=True)
class ModuleReport:
    unit_name: str
    module_name: str
    module_type: str
    current_version: str
    latest_version: str
    status: str
    note: str = ""

    @property
    def needs_update(self) -> bool:
        return self.status == OUTDATED

    @property
    def log_line(self) -> str:
        if self.note:
            return f"{self.unit_name}: {self.note}"
        return f"{self.unit_name}: {self.current_version} -> {self.latest_version} ({self.status})"


def build_report(unit_name: str, source: str) -> ModuleReport:
    if source.startswith("git::"):
        return _git_report(unit_name, source)

    if source.startswith("../"):
        return ModuleReport(
            unit_name,
            Path(source).name,
            LOCAL,
            LOCAL,
            LOCAL,
            UP_TO_DATE,
            note="local module, up-to-date",
        )

    return ModuleReport(
        unit_name,
        source,
        UNKNOWN,
        UNKNOWN,
        UNKNOWN,
        UNKNOWN,
        note="unknown module type",
    )


def _git_report(unit_name: str, source: str) -> ModuleReport:
    url, current, subpath = parse_git_source(source)
    repo = github_repo(url)

    if not repo:
        return ModuleReport(
            unit_name,
            url,
            GIT,
            current,
            current,
            UP_TO_DATE,
            note="non-GitHub git source, marked up-to-date",
        )

    latest = latest_github_version(repo, fallback=current)
    return ModuleReport(
        unit_name=unit_name,
        module_name=f"{repo}//{subpath}" if subpath else repo,
        module_type=GIT,
        current_version=current,
        latest_version=latest,
        status=UP_TO_DATE if current == latest else OUTDATED,
    )


def render_yaml(reports: list[ModuleReport], env_dir: Path, outdated_only: bool) -> str:
    lines = [
        f"# Generated: {datetime.now(REPORT_TIMEZONE):%Y-%m-%d %H:%M:%S CET}",
        f"# Repository: {repository_name()}",
        f"# Environment: {env_dir}",
        f"# Report Type: {'Outdated' if outdated_only else 'Full'}",
        "",
        "terraform_modules:",
    ]

    for report in reports:
        fields = [
            ("unit_name", f'"{report.unit_name}"'),
            ("module_name", f'"{report.module_name}"'),
            ("module_type", f'"{report.module_type}"'),
            ("current_version", f'"{report.current_version}"'),
            ("latest_version", f'"{report.latest_version}"'),
            ("status", f'"{report.status}"'),
            ("needs_update", "true" if report.needs_update else "false"),
        ]
        (first_key, first_value), *rest = fields
        lines.append(f"  - {first_key}: {first_value}")
        lines.extend(f"    {key}: {value}" for key, value in rest)
        lines.append("")

    return "\n".join(lines) + "\n"
