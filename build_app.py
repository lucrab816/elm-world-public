from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import json
import argparse

root = Path(__file__).resolve().parent
engine = root / "tools/Godot.app/Contents/MacOS/Godot"
if not engine.exists():
    raise SystemExit("缺少项目专用 Godot，请先完成工具准备。")
native = root / "project/native/libcozy_lifecycle.dylib"
subprocess.run(["xcrun", "clang", "-dynamiclib", "-fobjc-arc", "-arch", "arm64",
                "-mmacosx-version-min=12.0", "-framework", "Cocoa",
                str(root / "native/cozy_lifecycle.m"), "-o", str(native)], check=True)
subprocess.run(["codesign", "--force", "--sign", "-", str(native)], check=True)
subprocess.run([str(engine), "--headless", "--path", str(root / "project"), "--editor", "--import", "--quit"], check=True)
parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", type=Path, default=root / "build")
args = parser.parse_args()
app = args.output_dir.expanduser().resolve() / "Elm World Public Preview.app"
macos = app / "Contents/MacOS"
resources = app / "Contents/Resources"
macos.mkdir(parents=True, exist_ok=True)
resources.mkdir(parents=True, exist_ok=True)
shutil.copy2(root / "GODOT-LICENSES.txt", resources / "GODOT-LICENSES.txt")
engine_copy = macos / "Godot.new"
shutil.copy2(engine, engine_copy)
engine_copy.replace(macos / "Godot")
shutil.copytree(root / "project", resources / "world", dirs_exist_ok=True,
                ignore=shutil.ignore_patterns("editor", "shader_cache", "*.tmp", "tests", "previews"))
bridge = resources / "world/bridge"
bridge.mkdir(exist_ok=True)
for name in ["subscription_probe.py","chat_worker.py","decision.schema.json"]:
    shutil.copy2(root / "bridge" / name,bridge / name)
(bridge / "runtime.json").write_text(json.dumps({"python":sys.executable,"codex":""}))
launcher = macos / "CozyWorld"
launcher.write_text('''#!/bin/sh
APP_CONTENTS=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec "$APP_CONTENTS/MacOS/Godot" --path "$APP_CONTENTS/Resources/world" "$@"
''')
launcher.chmod(0o755)
with (app / "Contents/Info.plist").open("wb") as f:
    plistlib.dump({
        "CFBundleName": "Elm World Public Preview", "CFBundleDisplayName": "Elm World Public Preview",
        "CFBundleIdentifier": "local.elmworld.publicpreview",
        "CFBundleExecutable": "CozyWorld", "CFBundlePackageType": "APPL",
        "CFBundleVersion": "153", "CFBundleShortVersionString": "0.1.53",
        "LSMinimumSystemVersion": "12.0", "NSHighResolutionCapable": True,
        "NSHumanReadableCopyright": "Prototype; Godot Engine MIT license included."
    }, f)
subprocess.run(["codesign", "--force", "--sign", "-", str(macos / "Godot")], check=True)
# Finder/file-provider metadata on the generated bundle can invalidate signing.
# Remove only FinderInfo; retain quarantine and other security attributes.
subprocess.run(["xattr", "-d", "com.apple.FinderInfo", str(app)], capture_output=True)
subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
print(app)
