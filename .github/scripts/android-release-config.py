#!/usr/bin/env python3
"""Resolve a configured Android package without ever handling credentials."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


parser = argparse.ArgumentParser(
    description="Resolve a configured Android application for the shared package workflow."
)
parser.add_argument("--app", required=True, help="Configured Android application key")
parser.add_argument("--github-output", help="GitHub Actions output file")
parser.add_argument(
    "--format",
    choices=("github-output", "json"),
    default="github-output",
    help="Output format (default: github-output)",
)
args = parser.parse_args()

repository_root = Path(__file__).resolve().parents[2]
config_path = repository_root / ".github" / "android-packages.json"
config = json.loads(config_path.read_text(encoding="utf-8"))
apps = config.get("apps")
if not isinstance(apps, dict):
    fail(f"Invalid Android package config: {config_path}")

app = apps.get(args.app)
if not isinstance(app, dict):
    fail(f"Unknown Android app {args.app!r}. Available: {', '.join(sorted(apps))}")

required_keys = ("display_name", "path", "secret_prefix", "application_id")
missing_keys = [key for key in required_keys if not isinstance(app.get(key), str) or not app[key]]
if missing_keys:
    fail(f"Android app {args.app!r} has missing fields: {', '.join(missing_keys)}")

app_path = repository_root / app["path"]
if not (app_path / "android").is_dir():
    fail(f"Configured Android directory does not exist: {app['path']}")
if not (app_path / "pubspec.yaml").is_file():
    fail(f"Configured Flutter pubspec does not exist: {app['path']}/pubspec.yaml")

outputs = {
    "app_key": args.app,
    "app_name": app["display_name"],
    "app_path": app["path"],
    "secret_prefix": app["secret_prefix"],
    "application_id": app["application_id"],
}

if args.format == "json":
    print(json.dumps(outputs, indent=2))
    raise SystemExit(0)

output_path = args.github_output or os.environ.get("GITHUB_OUTPUT")
if not output_path:
    fail("--github-output or GITHUB_OUTPUT is required for github-output format")

with Path(output_path).open("a", encoding="utf-8") as output_file:
    for key, value in outputs.items():
        output_file.write(f"{key}={value}\n")
