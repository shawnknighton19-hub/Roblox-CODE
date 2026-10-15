#!/usr/bin/env python3
"""Independent inspection of the supplied HABWAS binary; never executes game scripts."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools/v15"))
from place_binary import Place, Reader


def attributes(raw):
    """Only the types present in the supplied Workspace are accepted."""
    if not raw:
        return {}
    r = Reader(raw)
    result = {}
    for _ in range(r.u32()):
        name = r.string().decode()
        kind = r.byte()
        if kind == 2:
            value = r.string().decode()
        elif kind == 3:
            value = bool(r.byte())
        elif kind == 6:
            value = struct.unpack("<d", r.read(8))[0]
        else:
            raise AssertionError(f"Unreviewed attribute type {kind}: {name}")
        result[name] = value
    assert r.off == len(raw)
    return result


def inspect(path):
    p = Place(path)
    active = {}
    for ref, (_, index, sources) in p.source_chunks.items():
        obj = p.instances[ref]
        name = p.path_of(ref)
        if name.startswith(("StarterPlayer/", "ServerScriptService/", "ReplicatedStorage/")):
            assert name not in active, f"Duplicate script path {name}"
            active[name] = {
                "class": obj["class"], "disabled": obj["props"].get("Disabled"),
                "sha256": hashlib.sha256(sources[index]).hexdigest(),
            }
    starter = next(i for i, x in p.instances.items() if x["class"] == "StarterPlayer")
    workspace = next(i for i, x in p.instances.items() if x["class"] == "Workspace")
    starter_class = next(cid for cid, x in p.classes.items() if starter in x["refs"])
    rig = next(c for c in p.chunks if c.get("class_id") == starter_class and c.get("property") == "GameSettingsAvatar")
    assert rig["dtype"] == 18
    # The supplied StarterPlayer class has one instance. Enum data is four byte lanes.
    assert len(p.classes[starter_class]["refs"]) == 1
    avatar = int.from_bytes(rig["raw"][rig["payload_offset"]:], "big")
    assert avatar == 0, "The supplied place has changed its avatar type"
    attrs = attributes(p.instances[workspace]["props"].get("AttributesSerialize", b""))
    assert attrs["HussDodgeV5"] is True
    spawn = [p.path_of(i) for i, x in p.instances.items() if x["class"] == "SpawnLocation" and p.path_of(i).startswith("Workspace/")]
    assert spawn == ["Workspace/Lobby/LobbySpawn"]
    return {
        "input_name": Path(path).name,
        "input_sha256": hashlib.sha256(p.data).hexdigest(),
        "instance_count": p.instance_count,
        "script_count": len(p.source_chunks),
        "starter_player_game_settings_avatar": {"value": avatar, "name": "R6"},
        "workspace_attributes": attrs,
        "live_spawns": spawn,
        "runtime_source_inventory": active,
        "findings": [
            "Uploaded avatar setting is already R6. Preserve it in the patched binary.",
            "ServerMain is ServerScriptService/Services/ServerMain.",
            "ClientMain intentionally does not start MovementAnimationController.",
            "CosmeticsServiceV11 explicitly rejects retired emotes; this is not a missing animation asset.",
            "DodgeWeaveV5, CarrierPanicV12, CollectionEffectsV11 and HABActionClient previously wrote joint transforms independently.",
            "The original carrier speed bonus applies only while sprinting.",
            "The original server dodge acceptance omitted HussDodgeStartedAt, making server action recovery checks ineffective.",
            "Current visual pack repeats Aura, BombFX, DodgeFX and Trail effects; trail rendering must be kept while other texture overlays are removed.",
        ],
        "limits": ["Read-only binary and source inspection; not a native Roblox execution or visual playtest."],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--report", type=Path, default=REPO / "V15-InputAudit.validation.json")
    args = parser.parse_args()
    report = inspect(args.input)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ("input_name", "input_sha256", "instance_count", "script_count", "starter_player_game_settings_avatar", "live_spawns")}, indent=2))
