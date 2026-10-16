"""Derive audited original-place lobby transforms from the real V16 builder.

Only CFrame, present WorldPivotData, and CFrame-valued attributes change. Every
other attribute record is preserved byte-for-byte. The complete input place is
SHA-pinned; the packaging layer verifies each original singleton property hash.
"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE.parent))
from package_place import Place, Reader, entries, encode_entries, f32, read_array

BASE_SHA = 'c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309'
ARCHIVES = {6872: 'North terrace', 7021: 'Gardens and seating', 7169: 'Boundary',
            8071: 'HABExpansionLobby/SpectatorOverlook',
            8341: 'HABExpansionLobby/InvisibleLobbyBarrier'}


def sha(value):
    return hashlib.sha256(value).hexdigest()


def get_layout(luau):
    source = (REPO / 'LobbyBuilderV16.luau').read_text()
    mock = (REPO / 'tools/v12/mock_prefix.luau').read_text()
    suffix = '''
local Builder=(function()\n%s\nend)()
local result={}
for _,entry in ipairs(Builder.GetLayout()) do
 table.insert(result,{path=entry.Path,anchor=entry.Anchor,old={entry.Old:GetComponents()},new={entry.New:GetComponents()},delta={entry.Delta:GetComponents()}})
end
print(json(result))
''' % source
    with tempfile.TemporaryDirectory(prefix='hab-v16-layout-') as temporary:
        script = Path(temporary) / 'layout.luau'
        script.write_text(mock + suffix)
        return json.loads(subprocess.check_output([luau, str(script)], text=True))


def rotation(code):
    assert 1 <= code <= 36, ('Invalid basic CFrame rotation', code)
    normals = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]
    right, up = normals[(code - 1) // 6], normals[(code - 1) % 6]
    assert sum(a * b for a, b in zip(right, up)) == 0
    back = (right[1]*up[2]-right[2]*up[1], right[2]*up[0]-right[0]*up[2], right[0]*up[1]-right[1]*up[0])
    return [v for row in zip(right, up, back) for v in row]


def unf32(raw):
    bits = int.from_bytes(raw, 'big')
    bits = ((bits >> 1) | (bits << 31)) & 0xffffffff
    return struct.unpack('<f', struct.pack('<I', bits))[0]


def decode_cf(raw):
    matrix = list(struct.unpack('<9f', raw[1:37])) if raw[0] == 0 else rotation(raw[0])
    return [unf32(raw[i:i+4]) for i in range(len(raw)-12, len(raw), 4)] + matrix


def encode_cf(value):
    return b'\0' + struct.pack('<9f', *value[3:]) + b''.join(f32(v) for v in value[:3])


def multiply(a, b):
    position = [a[i] + sum(a[3+i*3+j] * b[j] for j in range(3)) for i in range(3)]
    matrix = [sum(a[3+r*3+j] * b[3+j*3+c] for j in range(3)) for r in range(3) for c in range(3)]
    return position + matrix


def inverse(a):
    matrix = [a[3+c*3+r] for r in range(3) for c in range(3)]
    return [-sum(matrix[r*3+j] * a[j] for j in range(3)) for r in range(3)] + matrix


def close(a, b, tolerance=.002):
    return len(a) == len(b) and max(abs(x-y) for x, y in zip(a, b)) <= tolerance


def attribute_records(raw):
    if not raw:
        return []
    reader, result = Reader(raw), []
    for _ in range(reader.u32()):
        start = reader.off
        name, kind = reader.string().decode(), reader.byte()
        payload_start = reader.off
        if kind == 2:
            reader.string()
        elif kind == 20:
            reader.read(12)
            mode = reader.byte()
            if mode == 0:
                reader.read(36)
            else:
                rotation(mode)
        else:
            # Refuse unknown records before writing, rather than guessing lengths.
            assert kind in {3, 4, 5, 6}, ('Unreviewed attribute type', name, kind)
            reader.read({3: 1, 4: 4, 5: 4, 6: 8}[kind])
        result.append({'name': name, 'kind': kind, 'raw': raw[start:reader.off],
                       'prefix': raw[start:payload_start], 'payload': raw[payload_start:reader.off]})
    assert reader.off == len(raw)
    return result


def attribute_cframe(payload):
    position = list(struct.unpack('<3f', payload[:12]))
    matrix = list(struct.unpack('<9f', payload[13:])) if payload[12] == 0 else rotation(payload[12])
    return position + matrix


def update_cframe_attributes(raw, delta):
    records, transformed = attribute_records(raw), []
    if not records:
        return raw, transformed
    encoded = []
    for record in records:
        if record['kind'] != 20:
            encoded.append(record['raw'])
            continue
        original = attribute_cframe(record['payload'])
        target = multiply(delta, original)
        payload = struct.pack('<3f', *target[:3]) + b'\0' + struct.pack('<9f', *target[3:])
        assert close(attribute_cframe(payload), target, .00003)
        encoded.append(record['prefix'] + payload)
        transformed.append({'name': record['name'], 'old': original, 'new': attribute_cframe(payload)})
    updated = struct.pack('<I', len(encoded)) + b''.join(encoded)
    reread = attribute_records(updated)
    for before, after in zip(records, reread):
        if before['kind'] != 20:
            assert before['raw'] == after['raw'], 'Non-CFrame attribute changed'
    return updated, transformed


def generate(base, luau):
    place = Place(base)
    assert sha(place.data) == BASE_SHA, 'Only the reviewed original HABWAS.rbxl is supported'
    layout = get_layout(luau)
    path_refs = collections.defaultdict(list)
    for ref in place.instances:
        path_refs[place.path_of(ref)].append(ref)
    props = {}
    for chunk in place.chunks:
        if chunk['type'] == b'PROP' and chunk['property'] in {'CFrame', 'WorldPivotData', 'AttributesSerialize'}:
            refs = place.classes[chunk['class_id']]['refs']
            for ref, value in zip(refs, entries(chunk, len(refs))):
                props[(ref, chunk['property'])] = chunk['dtype'], value

    changes, audit, stats = [], [], collections.Counter()
    def change(ref, prop, replacement):
        dtype, original = props[(ref, prop)]
        old_raw = encode_entries(dtype, [original])
        new_raw = encode_entries(dtype, [replacement])
        parsed = read_array(Reader(new_raw), dtype, 1)[0]
        assert parsed == replacement
        if old_raw == new_raw:
            return
        changes.append({'ref': ref, 'path': place.path_of(ref), 'property': prop,
                        'original_sha256': sha(old_raw), 'value_hex': new_raw.hex()})
        stats[prop] += 1

    selected = set()
    for move in layout:
        path = 'Workspace/Lobby/' + move['path']
        assert len(path_refs[path]) == 1
        model_ref = path_refs[path][0]
        assert place.instances[model_ref]['class'] == 'Model'
        anchor_path = path + '/' + move['anchor']
        assert len(path_refs[anchor_path]) == 1
        anchor_ref = path_refs[anchor_path][0]
        anchor_original = decode_cf(props[(anchor_ref, 'CFrame')][1])
        assert close(anchor_original, move['old']), ('Unexpected original booth anchor', path)
        # Apply computes Delta against the actual source anchor, not its rounded
        # expected pose; mirror that operation for published binary geometry.
        delta = multiply(move['new'], inverse(anchor_original))
        assert close(delta, move['delta'])
        affected = [ref for ref in place.instances if place.path_of(ref) == path or place.path_of(ref).startswith(path + '/')]
        assert not selected.intersection(affected), 'Overlapping original transform roots'
        selected.update(affected)
        record = {'ref': model_ref, 'path': path, 'anchorRef': anchor_ref,
                  'old': anchor_original, 'new': move['new'], 'delta': delta,
                  'descendantCountIncludingRoot': len(affected), 'cframeAttributes': []}
        for ref in affected:
            for prop in ('CFrame', 'WorldPivotData'):
                if (ref, prop) not in props:
                    continue
                dtype, value = props[(ref, prop)]
                if prop == 'WorldPivotData':
                    assert dtype == 30
                    if not value[1]:
                        continue
                    original = value[0]
                else:
                    assert dtype == 16
                    original = value
                target = multiply(delta, decode_cf(original))
                encoded = encode_cf(target)
                assert close(decode_cf(encoded), target, .00003), ('Float precision loss', ref, prop)
                assert close(multiply(inverse(delta), decode_cf(encoded)), decode_cf(original), .00004)
                change(ref, prop, (encoded, value[1]) if prop == 'WorldPivotData' else encoded)
            if (ref, 'AttributesSerialize') in props:
                dtype, value = props[(ref, 'AttributesSerialize')]
                assert dtype == 1
                updated, transformed = update_cframe_attributes(value, delta)
                if transformed:
                    change(ref, 'AttributesSerialize', updated)
                    record['cframeAttributes'].append({'ref': ref, 'path': place.path_of(ref), 'attributes': transformed})
                    stats['CFrameAttributes'] += len(transformed)
        proposed_anchor = decode_cf(next(read_array(Reader(bytes.fromhex(c['value_hex'])), 16, 1)[0] for c in changes if c['ref'] == anchor_ref and c['property'] == 'CFrame'))
        assert close(proposed_anchor, move['new'], .00002)
        audit.append(record)

    arena_ref = 6793
    assert place.path_of(arena_ref) == 'Workspace/ActiveArenaAnchor'
    arena_before = decode_cf(props[(arena_ref, 'CFrame')][1])
    assert close(arena_before, [0, -27, -245, 1, 0, 0, 0, 1, 0, 0, 0, 1])
    change(arena_ref, 'CFrame', encode_cf([0, -27, -190, 1, 0, 0, 0, 1, 0, 0, 0, 1]))
    for ref, path in ARCHIVES.items():
        assert place.path_of(ref) == 'Workspace/Lobby/' + path
    assert stats['CFrameAttributes'] == 4, 'Expected four spinning bundle display origins'
    assert len({(c['ref'], c['property']) for c in changes}) == len(changes)
    # Four reviewed visible labels change, while original model identity, anchor,
    # collection tag and browse hint remain available to the existing clients.
    labels = [{'ref': ref, 'path': place.path_of(ref), 'text': obj['props']['Text'].decode()}
              for ref, obj in place.instances.items() if place.path_of(ref).startswith('Workspace/Lobby/V11 Bomb Exchange/Emotes kiosk/') and 'Text' in obj['props']]
    text_targets = {'EMOTES': 'LOCKER', 'SHOW YOUR STYLE': 'YOUR EFFECTS COLLECTION',
                    'EMOTES EXCHANGE': 'YOUR LOCKER', 'CELEBRATE EVERY CLOSE CALL': 'BROWSE YOUR OWNED EFFECTS'}
    text_changes = [{'ref': row['ref'], 'path': row['path'], 'original': row['text'], 'new': text_targets[row['text']]}
                    for row in labels if row['text'] in text_targets]
    assert len(text_changes) == len(text_targets) == 4
    return {'baseSHA256': BASE_SHA, 'builder': 'LobbyBuilderV16.luau',
            'sourceSHA256': sha((REPO/'LobbyBuilderV16.luau').read_bytes()),
            'archiveOriginal': {str(ref): 'Workspace/Lobby/'+path for ref, path in ARCHIVES.items()},
            'propertyChanges': changes, 'transforms': audit, 'counts': dict(stats),
            'textChanges': text_changes,
            'verification': {'sourceSHA256Checked': True, 'actualBuilderLayoutExecuted': True,
                             'allAnchorPosesVerified': True, 'inverseTransformsVerified': True,
                             'allOtherAttributeRecordsByteIdentical': True,
                             'allPropertySingletonsCodecRoundTripped': True}}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', required=True)
    parser.add_argument('--luau', default=os.environ.get('LUAU_BINARY') or shutil.which('luau'))
    parser.add_argument('--out', default=str(HERE/'property-manifest.json'))
    args = parser.parse_args()
    assert args.luau, 'Pass --luau /path/to/luau'
    result = generate(args.base, args.luau)
    Path(args.out).write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'output': str(args.out), 'changes': len(result['propertyChanges']), 'counts': result['counts'], 'verification': result['verification']}, indent=2))
