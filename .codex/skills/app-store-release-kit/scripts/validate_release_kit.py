#!/usr/bin/env python3
"""Validate one app's generated App Store release-material package."""

from __future__ import annotations

import argparse
import re
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

try:
    from PIL import Image
except ImportError as error:  # pragma: no cover - environment-specific
    raise SystemExit("Pillow is required: python3 -m pip install Pillow") from error


IPHONE_REQUIRED = {
    (1179, 2556),
    (2556, 1179),
    (1206, 2622),
    (2622, 1206),
}
IPAD_REQUIRED = {
    (2064, 2752),
    (2752, 2064),
    (2048, 2732),
    (2732, 2048),
}
IPHONE_ACCEPTED = IPHONE_REQUIRED | {
    (1260, 2736), (2736, 1260),
    (1290, 2796), (2796, 1290),
    (1320, 2868), (2868, 1320),
    (1284, 2778), (2778, 1284),
    (1242, 2688), (2688, 1242),
    (1170, 2532), (2532, 1170),
    (1125, 2436), (2436, 1125),
    (1080, 2340), (2340, 1080),
    (1242, 2208), (2208, 1242),
    (750, 1334), (1334, 750),
    (640, 1096), (1096, 640),
    (640, 1136), (1136, 640),
    (640, 920), (920, 640),
    (640, 960), (960, 640),
}
IPAD_ACCEPTED = IPAD_REQUIRED | {
    (1488, 2266), (2266, 1488),
    (1668, 2420), (2420, 1668),
    (1668, 2388), (2388, 1668),
    (1640, 2360), (2360, 1640),
    (1668, 2224), (2224, 1668),
    (1536, 2008), (2008, 1536),
    (1536, 2048), (2048, 1536),
    (768, 1004), (1004, 768),
    (768, 1024), (1024, 768),
}
PLACEHOLDER_PATTERN = re.compile(r"\[\[[A-Z0-9_]+\]\]|\{\{[^}]+\}\}|\bTODO\b|example\.com", re.IGNORECASE)
EMAIL_PATTERN = re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.IGNORECASE)
DESCRIPTION_CANDIDATES = (
    "artifacts/app-store-listing/description-en.txt",
    "docs/release/APP_STORE_DESCRIPTION_EN.txt",
    "app-store/description-en.txt",
)
KEYWORD_CANDIDATES = (
    "artifacts/app-store-listing/keywords-en.txt",
    "docs/release/APP_STORE_KEYWORDS_EN.txt",
    "app-store/keywords-en.txt",
)


@dataclass(frozen=True)
class Finding:
    level: str
    code: str
    message: str
    path: str | None = None


def add(findings: list[Finding], level: str, code: str, message: str, path: Path | None = None) -> None:
    findings.append(Finding(level, code, message, str(path) if path else None))


def first_existing(root: Path, candidates: tuple[str, ...]) -> Path | None:
    return next((root / candidate for candidate in candidates if (root / candidate).is_file()), None)


def read(path: Path) -> str:
    return path.read_text(errors="replace")


def validate_manifest(root: Path, findings: list[Finding]) -> tuple[bool | None, str | None]:
    path = root / "release-kit.yml"
    if not path.is_file():
        add(findings, "ERROR", "manifest.missing", "release-kit.yml is missing", path)
        return None, None
    text = read(path)
    for key in ("app_name", "operator", "support_email", "production_domain", "effective_date"):
        match = re.search(rf"(?m)^\s*{key}:\s*(.*)$", text)
        value = match.group(1).strip().strip("'\"") if match else ""
        if not value:
            add(findings, "ERROR", f"manifest.{key}", f"Manifest value {key} is missing", path)
    ipad_match = re.search(r"(?m)^\s*ipad:\s*([^#\n]+)", text)
    ipad_value = ipad_match.group(1).strip().strip("'\"").lower() if ipad_match else None
    ipad = True if ipad_value == "true" else False if ipad_value == "false" else None
    if ipad is None:
        add(findings, "WARN", "manifest.ipad_auto", "Resolve platforms.ipad from the Xcode target before completion", path)
    app_match = re.search(r"(?m)^\s*app_name:\s*([^#\n]+)", text)
    app_name = app_match.group(1).strip().strip("'\"") if app_match else None
    return ipad, app_name


def validate_description(root: Path, findings: list[Finding], explicit: Path | None) -> None:
    path = explicit or first_existing(root, DESCRIPTION_CANDIDATES)
    if not path or not path.is_file():
        add(findings, "ERROR", "description.missing", "English description file is missing", path)
        return
    value = read(path).rstrip("\n")
    count = len(value)
    if not value.strip():
        add(findings, "ERROR", "description.empty", "English description is empty", path)
    if count > 4000:
        add(findings, "ERROR", "description.limit", f"Description is {count} characters; maximum is 4000", path)
    else:
        add(findings, "PASS", "description.limit", f"Description is {count}/4000 characters", path)
    if "<" in value and re.search(r"<\/?[A-Za-z][^>]*>", value):
        add(findings, "ERROR", "description.html", "Description must be plain text, not HTML", path)


def validate_keywords(root: Path, findings: list[Finding], explicit: Path | None, app_name: str | None) -> None:
    path = explicit or first_existing(root, KEYWORD_CANDIDATES)
    if not path or not path.is_file():
        add(findings, "ERROR", "keywords.missing", "English keywords file is missing", path)
        return
    value = read(path).strip()
    byte_count = len(value.encode("utf-8"))
    if not value:
        add(findings, "ERROR", "keywords.empty", "English keywords are empty", path)
        return
    if byte_count > 100:
        add(findings, "ERROR", "keywords.limit", f"Keywords use {byte_count} UTF-8 bytes; maximum is 100", path)
    else:
        add(findings, "PASS", "keywords.limit", f"Keywords use {byte_count}/100 UTF-8 bytes", path)
    keywords = [item.strip() for item in value.replace("\n", ",").split(",") if item.strip()]
    normalized = [item.casefold() for item in keywords]
    duplicates = sorted(item for item, count in Counter(normalized).items() if count > 1)
    if duplicates:
        add(findings, "ERROR", "keywords.duplicates", f"Duplicate keywords: {', '.join(duplicates)}", path)
    too_short = [item for item in keywords if len(item) <= 2]
    if too_short:
        add(findings, "ERROR", "keywords.too_short", f"Keywords must be longer than two characters: {', '.join(too_short)}", path)
    if app_name:
        app_tokens = {token.casefold() for token in re.findall(r"[A-Za-z0-9]+", app_name) if len(token) > 2}
        repeated = sorted(set(normalized) & app_tokens)
        if repeated:
            add(findings, "WARN", "keywords.app_name", f"Keywords repeat app-name terms: {', '.join(repeated)}", path)


def validate_html(root: Path, findings: list[Finding], website: Path | None) -> None:
    website_root = website or root / "website"
    index = website_root / "index.html"
    privacy = website_root / "privacy.html"
    styles = website_root / "styles.css"
    for path in (index, privacy, styles):
        if not path.is_file():
            add(findings, "ERROR", "website.missing", f"Website file is missing: {path.name}", path)
    if not index.is_file() or not privacy.is_file():
        return

    index_text = read(index)
    privacy_text = read(privacy)
    for path, text in ((index, index_text), (privacy, privacy_text)):
        marker = PLACEHOLDER_PATTERN.search(text)
        if marker:
            add(findings, "ERROR", "website.placeholder", f"Unresolved template marker: {marker.group(0)}", path)
        structural_checks = (
            (re.compile(r"<title\b", re.IGNORECASE), "title"),
            (re.compile(r"<meta\b[^>]*\bname\s*=\s*['\"]viewport['\"]", re.IGNORECASE), "viewport meta"),
            (re.compile(r"<html\b[^>]*\blang\s*=", re.IGNORECASE), "html root with language"),
        )
        for pattern, label in structural_checks:
            if not pattern.search(text):
                add(findings, "ERROR", "website.structure", f"Missing {label}", path)
    if "privacy.html" not in index_text:
        add(findings, "ERROR", "website.privacy_link", "Product website does not link to privacy.html", index)
    index_emails = set(EMAIL_PATTERN.findall(index_text))
    privacy_emails = set(EMAIL_PATTERN.findall(privacy_text))
    if not index_emails:
        add(findings, "ERROR", "website.contact", "Product website has no support email", index)
    if not privacy_emails:
        add(findings, "ERROR", "privacy.contact", "Privacy policy has no contact email", privacy)
    if index_emails and privacy_emails and not (index_emails & privacy_emails):
        add(findings, "WARN", "website.contact_mismatch", "Website and privacy policy use different contact emails")
    if "privacy" not in privacy_text.casefold():
        add(findings, "ERROR", "privacy.heading", "Privacy policy does not identify itself as a privacy policy", privacy)


def preview_files(root: Path) -> list[Path]:
    bases = (
        root / "artifacts" / "app-store-previews" / "final",
        root / "docs" / "release" / "app_store_previews",
    )
    ignored_parts = {"background", "backgrounds", "qa", "source", "sources", "evidence"}
    found: set[Path] = set()
    for base in bases:
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
                continue
            relative_parts = {part.casefold() for part in path.relative_to(base).parts[:-1]}
            if relative_parts & ignored_parts:
                continue
            found.add(path)
    return sorted(found)


def has_alpha(image: Image.Image) -> bool:
    return image.mode in {"RGBA", "LA"} or (image.mode == "P" and "transparency" in image.info)


def infer_ipad_support(root: Path) -> bool | None:
    project_files = (
        [path for path in (root / "ios").rglob("project.pbxproj") if "Pods" not in path.parts]
        if (root / "ios").is_dir()
        else []
    )
    if not project_files:
        return None
    values: list[str] = []
    for path in project_files:
        values.extend(re.findall(r"TARGETED_DEVICE_FAMILY\s*=\s*([^;]+);", read(path)))
    normalized = {value.replace('"', "").replace(" ", "") for value in values}
    if any("2" in value.split(",") for value in normalized):
        return True
    if normalized and all(value == "1" for value in normalized):
        return False
    return None


def validate_previews(root: Path, findings: list[Finding], manifest_ipad: bool | None) -> None:
    paths = preview_files(root)
    if not paths:
        add(findings, "ERROR", "screenshots.missing", "No final App Store screenshots were found")
        return

    sizes: list[tuple[int, int]] = []
    iphone_count = 0
    ipad_count = 0
    for path in paths:
        try:
            with Image.open(path) as image:
                size = image.size
                sizes.append(size)
                if has_alpha(image):
                    add(findings, "ERROR", "screenshots.alpha", f"Image has alpha/transparency; mode={image.mode}", path)
                if size in IPHONE_ACCEPTED:
                    iphone_count += 1
                elif size in IPAD_ACCEPTED:
                    ipad_count += 1
                else:
                    add(findings, "ERROR", "screenshots.dimensions", f"Unrecognized App Store screenshot size: {size[0]}x{size[1]}", path)
        except Exception as error:
            add(findings, "ERROR", "screenshots.read", f"Cannot read image: {error}", path)

    if iphone_count == 0:
        add(findings, "ERROR", "screenshots.iphone", "No accepted iPhone screenshot was found")
    elif not any(size in IPHONE_REQUIRED for size in sizes):
        add(findings, "ERROR", "screenshots.iphone_required", "Missing current iPhone Dynamic Island medium-display screenshot")
    else:
        add(findings, "PASS", "screenshots.iphone_required", f"Found {iphone_count} accepted iPhone screenshot(s)")

    inferred_ipad = infer_ipad_support(root)
    supports_ipad = manifest_ipad if manifest_ipad is not None else inferred_ipad
    if supports_ipad is True:
        if not any(size in IPAD_REQUIRED for size in sizes):
            add(findings, "ERROR", "screenshots.ipad_required", "App supports iPad but has no current 13-inch iPad screenshot")
        else:
            add(findings, "PASS", "screenshots.ipad_required", f"Found {ipad_count} accepted iPad screenshot(s)")
    elif supports_ipad is None:
        add(findings, "WARN", "screenshots.ipad_unknown", "Could not determine whether the app supports iPad")

    counts = Counter(sizes)
    for size, count in sorted(counts.items()):
        if count > 10:
            add(findings, "ERROR", "screenshots.count", f"{count} screenshots use {size[0]}x{size[1]}; maximum per size is 10")
        else:
            add(findings, "PASS", "screenshots.group", f"{count} screenshot(s) at {size[0]}x{size[1]}")


def validate(
    root: Path,
    description: Path | None = None,
    keywords: Path | None = None,
    website: Path | None = None,
) -> list[Finding]:
    findings: list[Finding] = []
    manifest_ipad, app_name = validate_manifest(root, findings)
    validate_description(root, findings, description)
    validate_keywords(root, findings, keywords, app_name)
    validate_html(root, findings, website)
    validate_previews(root, findings, manifest_ipad)
    return findings


def report(findings: list[Finding], root: Path) -> str:
    errors = sum(finding.level == "ERROR" for finding in findings)
    warnings = sum(finding.level == "WARN" for finding in findings)
    passes = sum(finding.level == "PASS" for finding in findings)
    lines = [
        "# App Store Release Kit QA",
        "",
        f"Target: `{root}`",
        "",
        f"Result: {'FAIL' if errors else 'PASS'} — {errors} error(s), {warnings} warning(s), {passes} passed check(s)",
        "",
        "## Findings",
        "",
    ]
    for finding in findings:
        location = f" — `{finding.path}`" if finding.path else ""
        lines.append(f"- **{finding.level}** `{finding.code}`: {finding.message}{location}")
    lines.extend(
        [
            "",
            "Passing this report does not prove runtime capture authenticity, visual quality, public hosting, legal review, App Store upload, processing, TestFlight availability, submission, review, or device behavior.",
            "",
        ]
    )
    return "\n".join(lines)


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="release-kit-validate-") as temporary:
        root = Path(temporary)
        (root / "artifacts/app-store-listing").mkdir(parents=True)
        (root / "artifacts/app-store-listing/description-en.txt").write_text("A focused planner for projects, notes, and daily progress.")
        (root / "artifacts/app-store-listing/keywords-en.txt").write_text("planning,projects,offline,organizer,progress")
        (root / "release-kit.yml").write_text(
            "identity:\n  app_name: Fixture\n  operator: Fixture Studio\n"
            "contact:\n  support_email: support@fixture.test\n  production_domain: https://fixture.test\n"
            "platforms:\n  iphone: true\n  ipad: true\n"
            "privacy:\n  effective_date: 2026-10-08\n"
        )
        website = root / "website"
        website.mkdir()
        (website / "styles.css").write_text("body { color: #17312e; }")
        shared_head = '<html lang="en"><head><meta name="viewport" content="width=device-width"><title>Fixture</title></head>'
        (website / "index.html").write_text(shared_head + '<body><a href="privacy.html">Privacy</a><a href="mailto:support@fixture.test">Support</a></body></html>')
        (website / "privacy.html").write_text(shared_head + '<body><h1>Privacy Policy</h1><a href="mailto:support@fixture.test">Contact</a></body></html>')
        final = root / "artifacts/app-store-previews/final"
        final.mkdir(parents=True)
        Image.new("RGB", (1206, 2622), "#0B6B63").save(final / "iphone.png")
        Image.new("RGB", (2752, 2064), "#17312E").save(final / "ipad.png")
        findings = validate(root)
        errors = [finding for finding in findings if finding.level == "ERROR"]
        if errors:
            raise AssertionError("\n".join(f"{finding.code}: {finding.message}" for finding in errors))
    print("validate_release_kit self-test passed")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app_root", type=Path, nargs="?")
    parser.add_argument("--description", type=Path)
    parser.add_argument("--keywords", type=Path)
    parser.add_argument("--website", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.app_root:
        parser.error("app_root is required unless --self-test is used")
    root = args.app_root.resolve()
    findings = validate(root, args.description, args.keywords, args.website)
    rendered = report(findings, root)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered)
        print(args.report)
    else:
        print(rendered, end="")
    raise SystemExit(1 if any(finding.level == "ERROR" for finding in findings) else 0)


if __name__ == "__main__":
    main()
