#!/usr/bin/env python3
"""Check literal Instance constructors and enum references against recorded engine API.

This is deliberately a limited source API check, not an engine execution claim.
The input API is the Roblox Client Tracker's current API-Dump.json.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

REPO = Path(__file__).resolve().parents[3]
SNAPSHOT = Path(__file__).with_name("api_reference.json")
SOURCE = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
REQUIRED_MEMBERS = {
    "AnimationConstraint": ["Part0", "Part1", "C0", "C1", "Transform", "Enabled", "Attachment0", "Attachment1"],
    "Motor6D": ["Part0", "Part1", "C0", "C1", "Transform", "Enabled"],
    "RunService": ["PreAnimation", "PreSimulation", "Heartbeat", "RenderStepped"],
    "MarketplaceService": ["ProcessReceipt", "GetProductInfo", "UserOwnsGamePassAsync", "PromptGamePassPurchaseFinished"],
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    return sorted(REPO.glob("*V15*.luau"))


def references(files):
    classes, enums = set(), set()
    for path in files:
        text = path.read_text()
        classes.update(re.findall(r"Instance\.new\(\s*['\"]([^'\"]+)['\"]", text))
        enums.update(re.findall(r"\bEnum\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)", text))
    return classes, enums


def refresh(api_path):
    doc = json.loads(api_path.read_text())
    classes = {c["Name"] for c in doc["Classes"]}
    by_class = {c["Name"]: c for c in doc["Classes"]}
    enums = {e["Name"]: sorted(i["Name"] for i in e["Items"]) for e in doc["Enums"]}
    members = {}
    for name, required in REQUIRED_MEMBERS.items():
        for member_name in required:
            current = by_class[name]
            while current:
                found = next((m for m in current["Members"] if m["Name"] == member_name), None)
                if found:
                    members[name + "." + member_name] = {
                        "owner": current["Name"], "type": found["MemberType"],
                        "security": found.get("Security"),
                    }
                    break
                current = by_class.get(current.get("Superclass"))
            else:
                raise AssertionError(f"Missing engine API {name}.{member_name}")
    # Name metadata only; no source code or whole raw dump needs to be vendored.
    SNAPSHOT.write_text(json.dumps({
        "source": SOURCE, "sourceSha256": digest(api_path),
        "classes": sorted(classes), "enums": enums, "reviewed_members": members,
    }, indent=2) + "\n")


def check():
    api = json.loads(SNAPSHOT.read_text())
    files = sources()
    assert files, "No V15 production sources exist"
    constructors, enums = references(files)
    for name in sorted(constructors):
        assert name in api["classes"], f"Unknown Instance class {name}"
    for category, value in sorted(enums):
        assert category in api["enums"], f"Unknown enum {category}"
        assert value in api["enums"][category], f"Unknown enum member {category}.{value}"
    for name, entry in api["reviewed_members"].items():
        security = entry["security"]
        if isinstance(security, dict):
            assert all(v == "None" for v in security.values()), f"Protected member {name}"
        else:
            assert security == "None", f"Protected member {name}"
    report = {
        "verified": True,
        "sourceSha256": {str(p.relative_to(REPO)): digest(p) for p in files},
        "api_reference_sha256": digest(SNAPSHOT),
        "literal_instance_classes": sorted(constructors),
        "literal_enum_members": [".".join(e) for e in sorted(enums)],
        "reviewed_public_members": api["reviewed_members"],
        "file_count": len(files),
        "limits": [
            "Checks literal class constructors and enum member references only.",
            "Does not validate dynamic properties, engine execution, event ordering, physics, rendering, or asset permissions.",
        ],
    }
    (REPO / "V15-APIReview.validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"API references: {len(files)} sources, {len(constructors)} classes, {len(enums)} enum members passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh-api", type=Path)
    args = parser.parse_args()
    if args.refresh_api:
        refresh(args.refresh_api)
    check()
