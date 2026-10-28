#!/usr/bin/env python3
"""Create or reuse the Developer ID provisioning profile for a local-only Mac build.

A Developer ID app may claim its Keychain access group only when an embedded
provisioning profile grants it; without one, macOS refuses to launch it. This
registers the Mac bundle ID in your Apple Developer account when missing,
finds the Developer ID Application certificate that matches your signing
identity, creates (or reuses) a "Developer ID" profile for that pair, and
writes it to --output.

Authenticates with an App Store Connect API key: ASC_API_KEY_ID,
ASC_API_ISSUER_ID and ASC_API_KEY_PATH (the .p8 file). Called by
scripts/build-local-only-mac.sh; it reads these from .env-local.
"""

import argparse
import base64
import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "ios", "scripts"))
from asc_download_profile import API_BASE, _token  # noqa: E402


def request(token, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API_BASE + path, method=method, data=data)
    req.add_header("Authorization", "Bearer " + token)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as err:
        try:
            payload = json.loads(err.read() or b"{}")
        except Exception:
            payload = {}
        return err.code, payload


def fail(message, payload=None):
    detail = ""
    if payload:
        errors = payload.get("errors") or []
        detail = "; ".join(f"{e.get('code')}: {e.get('detail')}" for e in errors)
    sys.exit(f"error: {message}{' (' + detail + ')' if detail else ''}")


def bundle_id(token, identifier, name):
    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": "200"})
    status, body = request(token, "GET", f"/v1/bundleIds?{query}")
    if status != 200:
        fail("could not list bundle IDs", body)
    # The identifier filter matches prefixes; keep the exact Mac-capable one.
    for item in body.get("data", []):
        attrs = item["attributes"]
        if attrs["identifier"] == identifier and attrs["platform"] in ("MAC_OS", "UNIVERSAL"):
            print(f"==> App ID {identifier} already registered")
            return item["id"]
    status, body = request(token, "POST", "/v1/bundleIds", {
        "data": {
            "type": "bundleIds",
            "attributes": {"identifier": identifier, "name": name, "platform": "MAC_OS"},
        }
    })
    if status != 201:
        fail(f"could not register App ID {identifier}", body)
    print(f"==> Registered App ID {identifier}")
    return body["data"]["id"]


def certificate(token, identity_sha1):
    query = urllib.parse.urlencode({
        "filter[certificateType]": "DEVELOPER_ID_APPLICATION,DEVELOPER_ID_APPLICATION_G2",
        "fields[certificates]": "name,certificateContent,expirationDate",
        "limit": "200",
    })
    status, body = request(token, "GET", f"/v1/certificates?{query}")
    if status != 200:
        fail("could not list certificates", body)
    for item in body.get("data", []):
        der = base64.b64decode(item["attributes"]["certificateContent"])
        if hashlib.sha1(der).hexdigest().upper() == identity_sha1.upper():
            return item["id"]
    fail(f"no Developer ID Application certificate in the account matches {identity_sha1}")


def profile(token, name, bundle_resource_id, certificate_id):
    query = urllib.parse.urlencode({
        "filter[name]": name,
        "include": "bundleId,certificates",
        "fields[profiles]": "name,profileState,profileContent,bundleId,certificates",
        "limit": "10",
    })
    status, body = request(token, "GET", f"/v1/profiles?{query}")
    if status != 200:
        fail("could not list profiles", body)
    for item in body.get("data", []):
        rel = item.get("relationships", {})
        same_bundle = (rel.get("bundleId", {}).get("data") or {}).get("id") == bundle_resource_id
        certs = {c["id"] for c in (rel.get("certificates", {}).get("data") or [])}
        if (item["attributes"]["name"] == name and item["attributes"]["profileState"] == "ACTIVE"
                and same_bundle and certificate_id in certs):
            print(f"==> Reusing profile {name}")
            return item["attributes"]["profileContent"]
    status, body = request(token, "POST", "/v1/profiles", {
        "data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "MAC_APP_DIRECT"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
                "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
            },
        }
    })
    if status != 201:
        fail(f"could not create profile {name}", body)
    print(f"==> Created profile {name}")
    return body["data"]["attributes"]["profileContent"]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--app-name", required=True)
    parser.add_argument("--identity-sha1", required=True, help="SHA-1 of the Developer ID Application certificate")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    token = _token()
    bundle_resource_id = bundle_id(token, args.bundle_id, args.app_name)
    certificate_id = certificate(token, args.identity_sha1)
    # The bundle ID keeps the name unique when an app name moves to a new ID.
    content = profile(token, f"{args.app_name} {args.bundle_id} Developer ID", bundle_resource_id, certificate_id)
    with open(args.output, "wb") as out:
        out.write(base64.b64decode(content))
    print(f"==> Wrote {args.output}")


if __name__ == "__main__":
    main()
