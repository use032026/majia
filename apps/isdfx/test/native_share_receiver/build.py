#!/usr/bin/env python3
"""Offline QA-only Android receiver build; never installs or controls a device."""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import zipfile

SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[1]
EVIDENCE = PROJECT / "artifacts/native-share-receiver"
SDK = Path(os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
           or Path.home() / "Library/Android/sdk")
BUILD_TOOLS = SDK / "build-tools/35.0.0"
ANDROID_JAR = SDK / "platforms/android-36/android.jar"
JAVA = Path(os.environ.get("JAVA_HOME")
            or "/Applications/Android Studio.app/Contents/jbr/Contents/Home")
KEYSTORE = Path.home() / ".android/debug.keystore"


def main() -> None:
    for required in [ANDROID_JAR, KEYSTORE, JAVA / "bin/javac"] + [
        BUILD_TOOLS / name for name in ["aapt2", "d8", "zipalign", "apksigner"]
    ]:
        if not required.is_file():
            raise SystemExit(f"Existing tool/input missing: {required}")
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S")
    build = PROJECT / ".codex-build/share-receiver-build" / f"run-{stamp}-{os.getpid()}"
    classes, dex = build / "classes", build / "dex"
    classes.mkdir(parents=True)
    dex.mkdir()
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    log_path = EVIDENCE / "build.log"
    env = os.environ.copy()
    env["JAVA_HOME"] = str(JAVA)
    env["ID_FIXTURE_QA_STORE_PASS"] = "android"
    env["ID_FIXTURE_QA_KEY_PASS"] = "android"
    tools = {name: str(BUILD_TOOLS / name) for name in ["aapt2", "d8", "zipalign", "apksigner"]}
    manifest_apk = build / "manifest.apk"
    unsigned = build / "unsigned.apk"
    aligned = build / "aligned.apk"
    output = EVIDENCE / "QA.apk"
    with log_path.open("w", encoding="utf-8") as log:
        def run(args: list[str]) -> str:
            log.write("$ " + " ".join(args) + "\n")
            log.flush()
            result = subprocess.run(args, cwd=SOURCE, env=env,
                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log.write(result.stdout + "\n")
            log.flush()
            if result.returncode:
                raise RuntimeError(f"Command failed ({result.returncode}); inspect {log_path}")
            return result.stdout

        run([str(JAVA / "bin/javac"), "-source", "8", "-target", "8", "-classpath",
            str(ANDROID_JAR), "-d", str(classes)] + [str(p) for p in SOURCE.glob("src/**/*.java")])
        run([tools["d8"], "--min-api", "29", "--lib", str(ANDROID_JAR),
            "--output", str(dex)] + [str(p) for p in classes.rglob("*.class")])
        run([tools["aapt2"], "link", "-o", str(manifest_apk), "-I", str(ANDROID_JAR),
            "--manifest", str(SOURCE / "AndroidManifest.xml"),
            "--min-sdk-version", "29", "--target-sdk-version", "35",
            "--version-code", "1", "--version-name", "1.0-qa"])
        unsigned.write_bytes(manifest_apk.read_bytes())
        with zipfile.ZipFile(unsigned, "a", compression=zipfile.ZIP_DEFLATED) as apk:
            apk.write(dex / "classes.dex", "classes.dex")
        run([tools["zipalign"], "-f", "4", str(unsigned), str(aligned)])
        run([tools["apksigner"], "sign", "--ks", str(KEYSTORE),
            "--ks-key-alias", "androiddebugkey", "--ks-pass", "env:ID_FIXTURE_QA_STORE_PASS",
            "--key-pass", "env:ID_FIXTURE_QA_KEY_PASS", "--out", str(output), str(aligned)])
        signature = run([tools["apksigner"], "verify", "--verbose", "--print-certs", str(output)])
        run([tools["zipalign"], "-c", "4", str(output)])
        permissions = run([tools["aapt2"], "dump", "permissions", str(output)])
        manifest = run([tools["aapt2"], "dump", "xmltree", str(output), "--file", "AndroidManifest.xml"])
        badging = run([tools["aapt2"], "dump", "badging", str(output)])
        if "uses-permission" in permissions:
            raise RuntimeError("Unexpected uses-permission in QA APK")
        if "dev.idfixture.qa.share_receiver" not in badging or "minSdkVersion:'29'" not in badging:
            raise RuntimeError("Unexpected package/minimum SDK")
        if "application-debuggable" in badging:
            raise RuntimeError("QA APK must remain non-debuggable")
        if not re.search(r"android:debuggable\([^)]*\)=false\b", manifest) or not re.search(r"android:testOnly\([^)]*\)=true\b", manifest):
            raise RuntimeError("Missing explicit QA application flags")
    report = {
        "package": "dev.idfixture.qa.share_receiver", "min_sdk": 29, "target_sdk": 35,
        "test_only": True, "debuggable": False, "requested_permissions": [],
        "expected_source_authority": "dev.idfixture.id_fixture.flutter.share_provider",
        "artifact": str(output), "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "bytes": output.stat().st_size, "build_directory": str(build),
        "offline_build": True, "device_installed_or_operated": False,
        "signer": "Existing Android debug keystore; no certificate created",
        "verification": "apksigner verify, zipalign check, compiled manifest/permissions/badging inspected",
        "runtime": "not_run; Coordinator owns device validation",
        "cleanup": "Coordinator will remove exact task-local regenerable build tree after evidence retention",
    }
    (EVIDENCE / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"apk": str(output), "sha256": report["sha256"], "bytes": report["bytes"], "log": str(log_path)}))


if __name__ == "__main__":
    main()
