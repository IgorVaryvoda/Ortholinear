#!/usr/bin/env python3
"""Raw App Store captures for goldie, driven by XCUITest instead of argent flows.

Usage: Tools/store-capture.py <iPhone 17 Pro Max simulator udid> [locale ...]
For each App Store locale (default: every one in LOCALES) writes
goldie/out/raw/iphone-6.9/<locale>/{<scene>.png, manifest.json}, plus preview-<segment>.mp4 for en-US;
then run `goldie frame`, `goldie preview --locale en-US`, `goldie manifest` with GOLDIE_CONFIG set.
Each locale starts from a new install with the app in that language, after English, so the keyboard
starts in its own layout, as it does on a phone in that language.
"""
import datetime, json, os, re, signal, subprocess, sys, time

# App Store locale: (language the app launches in, words the typing scene types). None keeps the
# simulator's English and the test's own Ukrainian words.
LOCALES = {
    "en-US": (None, None),
    "uk": ("uk-UA", None),
    "pl": ("pl-PL", "Do zobaczenia jutro"),
    "cs": ("cs-CZ", "Ahoj jak se vede"),
    "sk": ("sk-SK", "Ahoj ako to ide"),
    "hr": ("hr-HR", "Bok vidimo se sutra"),
    "de-DE": ("de-DE", "Hallo bis morgen"),
    "nl-NL": ("nl-NL", "Hoi tot morgen"),
    "da": ("da-DK", "Hej vi ses i morgen"),
    "sv": ("sv-SE", "Hej vi ses imorgon"),
    "no": ("nb-NO", "Hei vi ses i morgen"),
    "fr-FR": ("fr-FR", "Bonjour tout le monde"),
    "fr-CA": ("fr-CA", "Bonjour tout le monde"),
    "es-ES": ("es-ES", "Hola nos vemos mañana"),
    "es-MX": ("es-MX", "Hola nos vemos mañana"),
}

udid = sys.argv[1]
locales = sys.argv[2:] or list(LOCALES)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
derived = os.path.join(root, "build/dd-store-capture")
scenes = ["type", "suggest", "languages", "settings", "private", "themes"]
segments = ["type", "glide", "theme"]

def sh(*args, **kw):
    return subprocess.run(args, check=True, **kw)

def keys(words):
    """Key identifiers: automatic capitals put Shift on for the first letter."""
    return ",".join("Space" if c == " " else (c.upper() if i == 0 else c) for i, c in enumerate(words))

sh("xcrun", "simctl", "bootstatus", udid, "-b")
sh("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--dataNetwork", "wifi",
   "--wifiMode", "active", "--wifiBars", "3", "--cellularMode", "active", "--cellularBars", "4",
   "--batteryState", "charged", "--batteryLevel", "100")
base = ["xcodebuild", "-project", os.path.join(root, "Ortholinear.xcodeproj"), "-scheme", "Ortholinear",
        "-configuration", "Release", "-destination", f"id={udid}", "-derivedDataPath", derived]
sh(*base, "build-for-testing", "ENABLE_TESTABILITY=YES", stdout=subprocess.DEVNULL)

for locale in locales:
    language, words = LOCALES[locale]
    raw = os.path.join(root, "goldie/out/raw/iphone-6.9", locale)
    os.makedirs(raw, exist_ok=True)
    print(f"{locale}:")
    # A new install, so the app picks its starting languages again.
    subprocess.run(["xcrun", "simctl", "uninstall", udid, "com.varyvoda.Ortholinear"])
    env = dict(os.environ, TEST_RUNNER_STORE_CAPTURE_DIR=raw)
    if language: env["TEST_RUNNER_STORE_LANGUAGE"] = language
    if words: env["TEST_RUNNER_STORE_TYPE"] = keys(words)

    def test(name):
        return subprocess.run(base + ["test-without-building", f"-only-testing:OrtholinearUITests/StoreCaptureTests/{name}"],
                              env=env, capture_output=True, text=True)

    for index, scene in enumerate(scenes, 1):
        result = test(f"test{index}{scene.capitalize()}")
        ok = result.returncode == 0 and os.path.exists(os.path.join(raw, f"{scene}.png"))
        print(f"  screenshot {scene}: {'ok' if ok else 'FAILED'}")
        if not ok:
            sys.exit(result.stdout[-3000:])

    preview = None
    if locale == "en-US":
        recording = os.path.join(derived, "preview-take.mp4")
        recorder = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264", "--force", recording],
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        # recordVideo prints "Recording started" once frames flow; the take starts then.
        while "Recording started" not in (recorder.stdout.readline() or "Recording started"):
            pass
        started = time.time()
        result = test("test7Preview")
        time.sleep(1)
        recorder.send_signal(signal.SIGINT)
        recorder.wait()
        marks = {m.group(1): float(m.group(2)) - started for m in re.finditer(r"STORE_MARK (\w+) ([\d.]+)", result.stdout)}
        if result.returncode != 0 or len(marks) < len(segments) + 1:
            sys.exit(f"preview take failed: {marks}\n{result.stdout[-3000:]}")
        clips = []
        for segment, following in zip(segments, segments[1:] + ["end"]):
            out = os.path.join(raw, f"preview-{segment}.mp4")
            start, end = marks[segment], marks[following]
            sh("ffmpeg", "-y", "-loglevel", "error", "-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", recording,
               "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", "30", "-an", out)
            clips.append({"segmentId": segment, "file": out, "durationSeconds": round(end - start, 3)})
            print(f"  preview {segment}: {end - start:.1f}s")
        preview = {"sceneId": "preview", "clips": clips}
    manifest = {"device": "iphone-6.9", "udid": udid, "capturedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "screenshots": [{"sceneId": s, "file": os.path.join(raw, f"{s}.png")} for s in scenes],
                "preview": preview}
    json.dump(manifest, open(os.path.join(raw, "manifest.json"), "w"), indent=2)
    print("  wrote", os.path.join(raw, "manifest.json"))
