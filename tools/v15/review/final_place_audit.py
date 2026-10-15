#!/usr/bin/env python3
"""Independently compare the deliverable's scripts/settings with installer inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools/v15"))
from assemble import records
from place_binary import Place
from input_audit import attributes


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main(input_path, output_path):
    before, after = Place(input_path), Place(output_path)
    before_index = {before.path_of(ref): obj for ref, obj in before.instances.items()}
    index = {}
    for ref in after.instances:
        index.setdefault(after.path_of(ref), []).append(ref)
    rows = []
    for entry in records():
        refs = index.get(entry["path"], [])
        assert len(refs) == 1, (entry["path"], refs)
        obj = after.instances[refs[0]]
        assert obj["class"] == entry["class"], entry["path"]
        if entry.get("target"):
            expected = entry["target"].encode()
        else:
            expected = before_index[entry["path"]]["props"]["Source"]
            assert expected.decode().replace("\r\n", "\n").strip() == entry["old"].strip()
        assert obj["props"]["Source"] == expected, ("stale packaged source", entry["path"])
        if entry.get("disable"):
            assert obj["props"]["Disabled"] is True, entry["path"]
        elif entry.get("disabled") is not None:
            assert obj["props"]["Disabled"] == entry["disabled"], entry["path"]
        rows.append({"path": entry["path"], "source_sha256": sha(expected)})
    assert len(index.get("ServerScriptService/Services/ServerMain", [])) == 1
    assert len(index.get("Workspace/Lobby/LobbySpawn", [])) == 1
    assert len(index.get("Workspace/Lobby/HABPolishedLobbyV15", [])) == 1
    for root_name in ("StarterPlayer", "Workspace"):
        original_ref = next(r for r in before.instances if before.path_of(r) == root_name)
        final_ref = index[root_name][0]
        original = before.instances[original_ref]
        final = after.instances[final_ref]
        assert original_ref == final_ref
        if root_name == "Workspace":
            old_attrs = attributes(original["props"]["AttributesSerialize"])
            final_attrs = attributes(final["props"]["AttributesSerialize"])
            assert final_attrs.pop("HABPolishVersion") == 15
            assert final_attrs == old_attrs
        else:
            group = next(g for g, c in before.classes.items() if original_ref in c["refs"])
            old_chunk = next(c for c in before.chunks if c.get("class_id") == group and c.get("property") == "GameSettingsAvatar")
            final_chunk = next(c for c in after.chunks if c.get("class_id") == group and c.get("property") == "GameSettingsAvatar")
            assert old_chunk["bytes"] == final_chunk["bytes"]
    backups = [obj for ref, obj in after.instances.items() if after.path_of(ref).startswith("ServerStorage/HABPolishV15FileBackup/Scripts/")]
    for obj in backups:
        if obj["class"] in {"Script", "LocalScript"}:
            assert obj["props"]["Disabled"] is True
    report = {
        "passed": True, "input_sha256": sha(before.data), "output_sha256": sha(after.data),
        "input_instances": before.instance_count, "output_instances": after.instance_count,
        "verified_script_entries": len(rows), "script_entries": rows,
        "avatar_setting_preserved": "R6", "workspace_existing_attributes_preserved": True,
        "backup_script_entries": len(backups), "backup_executable_scripts_disabled": True,
        "limits": "Read-only binary/source consistency review. Native Studio opening, rendering, network replication and purchases are not simulated.",
    }
    (REPO / "V15-FinalPlaceReview.validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "script_entries"}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    main(args.input, args.output)
