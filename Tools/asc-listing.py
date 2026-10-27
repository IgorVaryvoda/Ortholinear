#!/usr/bin/env python3
"""Uploads the localized listings in docs/listing/*.json to App Store Connect.

Usage: Tools/asc-listing.py [--apply] [--iap] [--screenshots] [locale ...]
Without --apply it only checks the files against Apple's limits and prints what it would change.
--apply writes the name and subtitle to the app info being edited, and the description, keywords,
promotional text and What's New to the version in Prepare for Submission; create that version first.
--iap also writes the Ortholinear Pro display name and description.
--screenshots replaces each locale's 6.9-inch iPhone screenshots, en-US included, with goldie's framed
PNGs from goldie/out/screenshots/iphone-6.9/<locale>/, in file-name order.
Needs PyJWT and ASC_KEY_ID, ASC_ISSUER_ID, and optionally ASC_KEY_PATH
(default ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8).
"""
import glob, hashlib, json, os, sys, time, urllib.error, urllib.request

APP = "6808996711"
IAP = "6819696774"
REPO = "https://github.com/IgorVaryvoda/Ortholinear"
LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promotionalText": 170, "description": 4000,
          "whatsNew": 4000, "iapName": 30, "iapDescription": 55}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
args = [a for a in sys.argv[1:] if not a.startswith("--")]
apply, iap, screenshots = "--apply" in sys.argv, "--iap" in sys.argv, "--screenshots" in sys.argv

listings = {}
for path in sorted(glob.glob(os.path.join(root, "docs/listing/*.json"))):
    locale = os.path.basename(path)[:-5]
    if args and locale not in args: continue
    listing = json.load(open(path, encoding="utf-8"))
    problems = [f"missing {k}" for k in LIMITS if not listing.get(k)]
    problems += [f"{k} is {len(v)} > {LIMITS[k]}" for k, v in listing.items() if k in LIMITS and len(v) > LIMITS[k]]
    keywords = listing.get("keywords", "")
    if ", " in keywords: problems.append("keywords have spaces after commas")
    if problems: sys.exit(f"{locale}: " + "; ".join(problems))
    listings[locale] = listing
print(f"{len(listings)} listings within limits: {' '.join(listings)}")
if not apply: sys.exit()

import jwt  # PyJWT, only needed to upload.

key_id, issuer = os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"]
key = open(os.path.expanduser(os.environ.get("ASC_KEY_PATH", f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"))).read()

def request(method, path, body=None, url=None):
    now = int(time.time())
    token = jwt.encode({"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}, key,
                       algorithm="ES256", headers={"kid": key_id})
    req = urllib.request.Request(url or "https://api.appstoreconnect.apple.com" + path, method=method,
                                 data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path}: {error.code} {error.read().decode()}")

def upsert(kind, existing, parent, parent_type, parent_id, locale, attributes):
    """Updates the localization for `locale`, or creates it under its parent."""
    if locale in existing:
        request("PATCH", f"/v1/{kind}/{existing[locale]}",
                {"data": {"type": kind, "id": existing[locale], "attributes": attributes}})
        return "updated"
    request("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": {"locale": locale, **attributes},
                                             "relationships": {parent: {"data": {"type": parent_type, "id": parent_id}}}}})
    return "created"

versions = request("GET", f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
version = next((v for v in versions if v["attributes"]["appStoreState"] in EDITABLE), None)
if not version: sys.exit("No version is in Prepare for Submission; create the next version first.")
infos = request("GET", f"/v1/apps/{APP}/appInfos")["data"]
info = next(i for i in infos if i["attributes"]["state"] != "READY_FOR_DISTRIBUTION")
print(f"Version {version['attributes']['versionString']}, app info {info['id']}")

def by_locale(path):
    return {item["attributes"]["locale"]: item["id"] for item in request("GET", path + "?limit=200")["data"]}

info_locs = by_locale(f"/v1/appInfos/{info['id']}/appInfoLocalizations")
version_locs = by_locale(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
iap_locs = by_locale(f"/v2/inAppPurchases/{IAP}/inAppPurchaseLocalizations") if iap else {}

for locale, listing in listings.items():
    done = [upsert("appInfoLocalizations", info_locs, "appInfo", "appInfos", info["id"], locale, {
        "name": listing["name"], "subtitle": listing["subtitle"], "privacyPolicyUrl": f"{REPO}/blob/main/PRIVACY.md"})]
    # A new app info localization brings the version's along with it.
    version_locs = by_locale(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    done.append(upsert("appStoreVersionLocalizations", version_locs, "appStoreVersion", "appStoreVersions", version["id"], locale, {
        "description": listing["description"], "keywords": listing["keywords"],
        "promotionalText": listing["promotionalText"], "whatsNew": listing["whatsNew"],
        "supportUrl": f"{REPO}/blob/main/SUPPORT.md", "marketingUrl": REPO}))
    # A live purchase's existing localizations can't be edited; only missing ones are added.
    if iap and locale not in iap_locs:
        done.append(upsert("inAppPurchaseLocalizations", iap_locs, "inAppPurchaseV2", "inAppPurchases", IAP, locale, {
            "name": listing["iapName"], "description": listing["iapDescription"]}))
    print(f"  {locale}: {', '.join(done)}")

def upload_screenshots(locale, localization):
    files = sorted(glob.glob(os.path.join(root, "goldie/out/screenshots/iphone-6.9", locale, "*.png")))
    if not files: return f"no screenshots in goldie/out/screenshots/iphone-6.9/{locale}"
    sets = request("GET", f"/v1/appStoreVersionLocalizations/{localization}/appScreenshotSets")["data"]
    shot_set = next((x["id"] for x in sets if x["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
    if shot_set:
        for old in request("GET", f"/v1/appScreenshotSets/{shot_set}/appScreenshots")["data"]:
            request("DELETE", f"/v1/appScreenshots/{old['id']}")
    else:
        shot_set = request("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": localization}}}}})["data"]["id"]
    for file in files:
        data = open(file, "rb").read()
        shot = request("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
            "attributes": {"fileName": os.path.basename(file), "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": shot_set}}}}})["data"]
        for part in shot["attributes"]["uploadOperations"]:
            chunk = data[part["offset"]:part["offset"] + part["length"]]
            req = urllib.request.Request(part["url"], method=part["method"], data=chunk,
                                         headers={h["name"]: h["value"] for h in part["requestHeaders"]})
            urllib.request.urlopen(req).read()
        request("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return f"{len(files)} screenshots"

if screenshots:
    version_locs = by_locale(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    for locale in ["en-US", *listings] if not args or "en-US" in args else listings:
        print(f"  {locale}: {upload_screenshots(locale, version_locs[locale])}")
