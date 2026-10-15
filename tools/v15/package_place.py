"""Preserve the uploaded binary place while installing reviewed V15 sources/lobby.

Existing class groups are extended, never duplicated. Unknown original chunks
remain byte-identical; every entry in each rewritten property array is compared
after writing. Newly added instances use the pinned Roblox reflection defaults.
The output is published only after a second, independent decoder accepts it.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import uuid

import zstandard
from place_binary import Place, Reader

ROOT = Path(__file__).resolve().parents[2]
DEFAULTS = json.loads(Path(__file__).with_name('property_defaults.json').read_text())
WIDTHS = {2: 1, 3: 4, 4: 4, 6: 8, 7: 16, 12: 12, 13: 8, 14: 12,
          18: 4, 26: 3, 27: 8, 28: 4, 31: 16, 33: 8}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def string(value):
    if isinstance(value, str):
        value = value.encode()
    return struct.pack('<I', len(value)) + value


def interleave(values):
    return bytes(value[column] for column in range(len(values[0])) for value in values) if values else b''


def refs(values):
    encoded, previous = [], 0
    for value in values:
        delta = value - previous
        previous = value
        encoded.append(((delta << 1) ^ (delta >> 31)).to_bytes(4, 'big'))
    return interleave(encoded)


def read_array(reader, dtype, count):
    if dtype == 1:
        return [reader.string() for _ in range(count)]
    if dtype == 19:
        return reader.refs(count)
    if dtype == 16:
        rotations = []
        for _ in range(count):
            mode = reader.read(1)
            rotations.append(mode + (reader.read(36) if mode == b'\0' else b''))
        positions = read_array(reader, 14, count)
        return [r + p for r, p in zip(rotations, positions)]
    if dtype == 25:
        values = []
        for _ in range(count):
            mode = reader.read(1)
            assert mode[0] <= 3, 'Unrecognized physical property layout'
            values.append(mode + reader.read({0: 0, 1: 20, 2: 0, 3: 24}[mode[0]]))
        return values
    if dtype == 30:
        assert reader.byte() == 16, 'Only OptionalCFrame is supported'
        values = read_array(reader, 16, count)
        assert reader.byte() == 2
        presence = reader.read(count)
        return [(value, present) for value, present in zip(values, presence)]
    if dtype == 32:
        values = []
        for _ in range(count):
            start = reader.off
            reader.string()
            reader.read(3)
            reader.string()
            values.append(reader.data[start:reader.off])
        return values
    assert dtype in WIDTHS, f'Unsupported property layout {dtype}; refusing modification'
    width = WIDTHS[dtype]
    raw = reader.read(count * width)
    return [bytes(raw[column * count + row] for column in range(width)) for row in range(count)]


def encode_entries(dtype, values):
    if dtype == 1:
        return b''.join(string(v) for v in values)
    if dtype == 19:
        return refs(values)
    if dtype == 16:
        return b''.join(v[:-12] for v in values) + interleave([v[-12:] for v in values])
    if dtype in (25, 32):
        return b''.join(values)
    if dtype == 30:
        return b'\x10' + encode_entries(16, [v[0] for v in values]) + b'\x02' + bytes(v[1] for v in values)
    assert dtype in WIDTHS
    return interleave(values)


def entries(chunk, count):
    raw = chunk['raw'][chunk['payload_offset']:]
    reader = Reader(raw)
    values = read_array(reader, chunk['dtype'], count)
    assert reader.off == len(raw), (chunk['property'], chunk['dtype'], reader.off, len(raw))
    assert encode_entries(chunk['dtype'], values) == raw, 'Property codec must round-trip byte-identically'
    return values


def chunk_bytes(chunk, raw):
    data = zstandard.ZstdCompressor(level=3).compress(raw)
    return struct.pack('<4sIII', chunk['type'], len(data), len(raw), chunk['reserved']) + data


def attributes(values):
    encoded = []
    for name, value in values.items():
        if isinstance(value, bool):
            payload = b'\x03' + bytes([value])
        elif isinstance(value, (int, float)):
            payload = b'\x06' + struct.pack('<d', value)
        else:
            payload = b'\x02' + string(value)
        encoded.append(string(name) + payload)
    return struct.pack('<I', len(encoded)) + b''.join(encoded)


def attribute_records(raw):
    if not raw:
        return {}
    reader, result = Reader(raw), {}
    for _ in range(reader.u32()):
        start = reader.off
        name, dtype = reader.string().decode(), reader.byte()
        if dtype == 2:
            reader.string()
        else:
            assert dtype in {3, 4, 5, 6}, f'Unsupported edited attribute type {dtype}; preserve input and stop'
            reader.read({3: 1, 4: 4, 5: 4, 6: 8}[dtype])
        assert name not in result
        result[name] = raw[start:reader.off]
    assert reader.off == len(raw)
    return result


def update_attributes(raw, changes):
    records = attribute_records(raw)
    records.update(attribute_records(attributes(changes)))
    return struct.pack('<I', len(records)) + b''.join(records.values())


def f32(value):
    bits = struct.unpack('<I', struct.pack('<f', value))[0]
    return (((bits << 1) | (bits >> 31)) & 0xffffffff).to_bytes(4, 'big')


def integer(value, width=4):
    return ((value << 1) ^ (value >> (width * 8 - 1))).to_bytes(width, 'big')


def default_value(cls, prop, dtype, empty_shared):
    aliases = {'AttributesSerialize': 'Attributes', 'Color3uint8': 'Color', 'shape': 'Shape',
               'size': 'Size', 'formFactorRaw': 'FormFactor', 'MaterialVariantSerialized': 'MaterialVariant',
               'ScaleFactor': 'Scale', 'DefinesCapabilities': 'Sandboxed'}
    definition = DEFAULTS['classes'][cls].get(aliases.get(prop, prop))
    # These hidden serialized fields are empty on a newly created Instance.
    if definition is None and prop in {'SerializedOverrides', 'Name'}:
        definition = {'String': ''}
    if dtype == 19:
        return -1
    assert definition is not None, f'Missing reviewed default {cls}.{prop}'
    kind, value = next(iter(definition.items()))
    if dtype == 1:
        if kind == 'Attributes':
            assert not value
            return attributes({})
        assert kind in {'String', 'ContentId'}, (cls, prop, kind)
        return value.encode()
    if dtype == 2:
        assert kind == 'Bool'
        return bytes([value])
    if dtype == 3:
        return integer(value)
    if dtype == 4:
        return f32(value)
    if dtype == 6:
        return f32(value[0]) + integer(value[1])
    if dtype == 7:
        return f32(value[0][0]) + f32(value[1][0]) + integer(value[0][1]) + integer(value[1][1])
    if dtype in (12, 13, 14):
        return b''.join(f32(v) for v in value)
    if dtype == 16:
        position, matrix = value
        return b'\0' + struct.pack('<9f', *(x for row in matrix for x in row)) + b''.join(f32(v) for v in position)
    if dtype == 18:
        return value.to_bytes(4, 'big')
    if dtype == 25:
        assert value == 'Default'
        return b'\0'
    if dtype == 26:
        return bytes(value)
    if dtype == 27:
        return integer(value, 8)
    if dtype == 28:
        assert kind in {'SharedString', 'Tags'} and not value
        return empty_shared.to_bytes(4, 'big')
    if dtype == 30:
        assert kind == 'OptionalCFrame' and value is None
        return (b'\x02' + bytes(12), 0)  # identity CFrame, optional is absent
    if dtype == 31:
        return bytes.fromhex(value['binary_hex'])
    if dtype == 32:
        family, weight, style, cache = value
        weights = {'Thin': 100, 'ExtraLight': 200, 'Light': 300, 'Regular': 400, 'Medium': 500,
                   'SemiBold': 600, 'Bold': 700, 'ExtraBold': 800, 'Heavy': 900}
        return string(family) + struct.pack('<HB', weights[weight], int(style == 'Italic')) + string(cache)
    if dtype == 33:
        return value.to_bytes(8, 'big')
    raise AssertionError((cls, prop, dtype, kind))


def independent_decode(place, executable):
    # Pass the untouched encoded bytes to a modern independent decoder. Do not
    # strip properties, normalize modern PhysicalProperties, or reserialize.
    with tempfile.TemporaryDirectory(prefix='hab-v15-decode-') as temporary:
        path = Path(temporary) / 'place.rbxl'
        path.write_bytes(place.data)
        return json.loads(subprocess.check_output([executable, str(path)], text=True))


def _package(base, output, manifest, verifier):
    base, output = Path(base), Path(output)
    assert base.resolve() != output.resolve() and not output.exists()
    source = Place(base)
    assert sha(source.data) == manifest['input_sha256'], 'Manifest does not match the reviewed upload'
    assert not any(c['type'] == b'SIGN' for c in source.chunks), 'Signed payloads are unsupported'
    path_refs = {}
    for ref in source.instances:
        path_refs.setdefault(source.path_of(ref), []).append(ref)

    def one(path):
        matches = path_refs.get(path, [])
        assert len(matches) == 1, (path, matches)
        return matches[0]

    edits, expected_sources, nodes, moved, frozen_sources = {}, {}, [], {}, {}
    backup_path = manifest.get('backup_path', 'ServerStorage/HABPolishV15FileBackup')
    assert backup_path not in path_refs, 'Already patched input; choose the original reviewed upload'
    nodes.append({'path': backup_path, 'class': 'Folder', 'attributes': {
        'Installer': 'HAB V15 verified file update', 'OriginalUploadSHA256': sha(source.data)}})
    restore = ['HAB V15 backup. The original upload was not modified.',
               'Disabled source copies store OriginalPath and OriginalDisabled.',
               'Original architecture is archived below OriginalLobby; restore its OriginalPath from this manifest.', '']
    backed_up = set()

    def backup(ref):
        if ref in backed_up:
            return
        backed_up.add(ref)
        obj = source.instances[ref]
        nodes.append({'path': backup_path + '/Scripts/' + str(ref) + '_' + obj['name'],
                      'class': obj['class'], 'Source': obj['props']['Source'], 'Disabled': True,
                      'attributes': {'OriginalPath': source.path_of(ref),
                                     'OriginalDisabled': obj['props'].get('Disabled', False)}})
        restore.append('RESTORE SCRIPT: ' + source.path_of(ref))

    nodes.append({'path': backup_path + '/Scripts', 'class': 'Folder'})
    for entry in manifest.get('edits', []):
        ref = one(entry['path'])
        original = source.instances[ref]['props']['Source']
        assert sha(original) == entry['original_sha256'], f'Unreviewed source: {entry["path"]}'
        data = (ROOT / entry['source']).read_bytes()
        frozen_sources[entry['source']] = data
        if entry.get('source_sha256'):
            assert sha(data) == entry['source_sha256']
        assert (ref, 'Source') not in edits
        edits[(ref, 'Source')] = data
        expected_sources[entry['path']] = data
        backup(ref)
    for entry in manifest.get('disables', []):
        ref = one(entry['path'])
        obj = source.instances[ref]
        assert obj['class'] in {'Script', 'LocalScript'}
        assert sha(obj['props']['Source']) == entry['original_sha256']
        assert obj['props']['Disabled'] == entry.get('original_disabled', False)
        edits[(ref, 'Disabled')] = b'\x01'
        backup(ref)
    for entry in manifest.get('additions', []):
        assert entry['path'] not in path_refs, f'Existing system: {entry["path"]}'
        data = (ROOT / entry['source']).read_bytes()
        frozen_sources[entry['source']] = data
        nodes.append({'path': entry['path'], 'class': entry['class'], 'Source': data, 'Disabled': bool(entry.get('disabled', False))})
        expected_sources[entry['path']] = data
        restore.append('ADDED: ' + entry['path'])
    if manifest.get('workspace_attributes'):
        ref = one('Workspace')
        edits[(ref, 'AttributesSerialize')] = update_attributes(
            source.instances[ref]['props']['AttributesSerialize'], manifest['workspace_attributes'])
    if 'avatar_enum' in manifest:
        assert manifest['avatar_enum'] in {0, 1, 2}
        edits[(one('StarterPlayer'), 'GameSettingsAvatar')] = manifest['avatar_enum'].to_bytes(4, 'big')

    geometry = None
    geometry_refs, geometry_values = {}, {}
    lobby = manifest.get('lobby_manifest')
    if lobby:
        if isinstance(lobby, str):
            lobby = json.loads((ROOT / lobby).read_text())
        geometry_path = ROOT / lobby['geometry']
        geometry = Place(geometry_path)
        if lobby.get('geometry_sha256'):
            assert sha(geometry.data) == lobby['geometry_sha256']
        if lobby.get('sourceSHA256'):
            assert sha((ROOT / lobby['builder']).read_bytes()) == lobby['sourceSHA256'], 'Lobby export uses a stale builder'
        assert all(c['type'] in {b'INST', b'PROP', b'PRNT', b'END\0'} for c in geometry.chunks)
        assert not geometry.source_chunks, 'Lobby export must contain geometry only'
        for name, parent in lobby['newRoots'].items():
            assert parent + '/' + name not in path_refs, 'Generated lobby root already exists'
        nodes.append({'path': backup_path + '/OriginalLobby', 'class': 'Folder'})
        for old_ref, path in lobby['archiveOriginal'].items():
            ref = int(old_ref)
            assert one(path) == ref and source.instances[ref]['class'] == 'Model'
            assert not any(source.path_of(script_ref).startswith(path + '/') for script_ref in source.source_chunks), 'Never archive an active system as decoration'
            moved[ref] = backup_path + '/OriginalLobby'
            restore.append('RESTORE LOBBY: ' + source.instances[ref]['name'] + ' -> ' + path)
        for path in lobby.get('preservePaths', []):
            one(path)
        for change in lobby.get('textChanges', []):
            ref = one(change['path'])
            assert ref == change['ref'] and source.instances[ref]['class'] in {'TextLabel', 'TextButton'}
            original = source.instances[ref]['props']['Text'].decode()
            assert original == change['original'], 'Unreviewed booth sign text'
            edits[(ref, 'Text')] = change['new'].encode()
            restore.append('RESTORE TEXT: ' + json.dumps({'path': change['path'], 'Text': original}, ensure_ascii=False))
        for ref, obj in geometry.instances.items():
            old_path = geometry.path_of(ref)
            root_name = old_path.split('/')[0]
            assert root_name in lobby['newRoots'], f'Unapproved generated root {root_name}'
            path = lobby['newRoots'][root_name] + '/' + old_path
            node = {'path': path, 'class': obj['class'], 'geometry_ref': ref,
                    'geometry_parent': obj['parent'], 'root_parent_path': lobby['newRoots'][root_name]}
            nodes.append(node)
            geometry_refs[ref] = node
        for c in geometry.chunks:
            if c['type'] == b'PROP':
                for ref, value in zip(geometry.classes[c['class_id']]['refs'], entries(c, len(geometry.classes[c['class_id']]['refs']))):
                    geometry_values[(ref, c['property'])] = (c['dtype'], value)
        restore.append('ADDED LOBBY: ' + ', '.join(lobby['newRoots']))
    nodes.append({'path': backup_path + '/RestoreManifest', 'class': 'StringValue', 'Value': '\n'.join(restore)})

    groups = {}
    for group, record in source.classes.items():
        assert record['name'] not in groups, 'Duplicate class group in input'
        groups[record['name']] = group
    new_by_group = {}
    for index, node in enumerate(nodes):
        assert node['class'] in groups, f'Missing existing class {node["class"]}; refuse duplicate/new class guesses'
        node['ref'] = max(source.instances) + 1 + index
        node['uuid'] = uuid.uuid5(uuid.NAMESPACE_URL, 'hab-v15:' + sha(source.data) + ':' + node['path'] + ':' + str(index))
        if 'geometry_ref' not in node:
            assert node['path'] not in path_refs, f'Duplicate added system path {node["path"]}'
        path_refs.setdefault(node['path'], []).append(node['ref'])
        new_by_group.setdefault(groups[node['class']], []).append(node)
    moved = {ref: one(path) for ref, path in moved.items()}

    empty_shared = None
    for c in source.chunks:
        if c['type'] == b'SSTR':
            reader = Reader(c['raw'])
            assert reader.u32() == 0
            for index in range(reader.u32()):
                reader.read(16)
                if reader.string() == b'':
                    empty_shared = index
            assert reader.off == len(c['raw'])
    assert empty_shared is not None

    def new_value(node, prop, dtype):
        if 'geometry_ref' in node and (node['geometry_ref'], prop) in geometry_values:
            original_type, value = geometry_values[(node['geometry_ref'], prop)]
            assert original_type == dtype, (node['class'], prop, original_type, dtype)
            if dtype == 19 and value >= 0:
                return geometry_refs[value]['ref']
            assert dtype != 28, 'Generated shared strings require explicit remapping'
            return value
        if prop == 'Name':
            return node['path'].rsplit('/', 1)[-1].encode()
        if prop == 'AttributesSerialize':
            return attributes(node.get('attributes', {}))
        if prop == 'ScriptGuid':
            return ('{' + str(node['uuid']).upper() + '}').encode()
        if prop == 'UniqueId':
            return node['uuid'].bytes
        if prop in node:
            value = node[prop]
            if dtype == 1:
                return value.encode() if isinstance(value, str) else value
            if dtype == 2:
                return bytes([value])
            raise AssertionError('Unsupported explicit new property ' + prop)
        return default_value(node['class'], prop, dtype, empty_shared)

    property_keys = {(source.classes[c['class_id']]['name'], c['property']) for c in source.chunks if c['type'] == b'PROP'}
    if geometry:
        assert all((geometry.instances[ref]['class'], prop) in property_keys for ref, prop in geometry_values), 'Generated property absent from original class; refuse to discard it'
    assert all(any(c.get('property') == prop and ref in source.classes[c['class_id']]['refs']
                   for c in source.chunks if c['type'] == b'PROP') for ref, prop in edits)
    replacements, original_entries = {}, {}
    parent_index = None
    for index, c in enumerate(source.chunks):
        if c['type'] == b'INST':
            reader = Reader(c['raw'])
            group = reader.u32()
            if group not in new_by_group:
                continue
            name, fmt, count = reader.string(), reader.byte(), reader.u32()
            old_refs = reader.refs(count)
            assert fmt == 0 and reader.off == len(c['raw']), 'Only ordinary instance groups may be extended'
            new_refs = [n['ref'] for n in new_by_group[group]]
            raw = struct.pack('<I', group) + string(name) + bytes([fmt]) + struct.pack('<I', count + len(new_refs)) + refs(old_refs + new_refs)
            replacements[index] = chunk_bytes(c, raw)
        elif c['type'] == b'PROP':
            group, prop, dtype = c['class_id'], c['property'], c['dtype']
            old_refs = source.classes[group]['refs']
            if group not in new_by_group and not any((ref, prop) in edits for ref in old_refs):
                continue
            values = entries(c, len(old_refs))
            original_entries[index] = values
            revised_values = [edits.get((ref, prop), value) for ref, value in zip(old_refs, values)]
            revised_values.extend(new_value(node, prop, dtype) for node in new_by_group.get(group, []))
            replacements[index] = chunk_bytes(c, c['raw'][:c['payload_offset']] + encode_entries(dtype, revised_values))
        elif c['type'] == b'PRNT':
            assert parent_index is None
            parent_index = index
            reader = Reader(c['raw'])
            assert reader.byte() == 0
            count = reader.u32()
            old_refs, old_parents = reader.refs(count), reader.refs(count)
            assert reader.off == len(c['raw']) and set(old_refs) == set(source.instances)
            parents = [moved.get(ref, parent) for ref, parent in zip(old_refs, old_parents)]
            for node in nodes:
                if 'geometry_ref' in node:
                    old_parent = node['geometry_parent']
                    parents.append(geometry_refs[old_parent]['ref'] if old_parent in geometry_refs else one(node['root_parent_path']))
                else:
                    parents.append(one(node['path'].rsplit('/', 1)[0]))
            raw = b'\0' + struct.pack('<I', count + len(nodes)) + refs(old_refs + [n['ref'] for n in nodes]) + refs(parents)
            replacements[index] = chunk_bytes(c, raw)
    assert parent_index is not None
    header = bytearray(source.data[:32])
    struct.pack_into('<I', header, 20, source.instance_count + len(nodes))
    output.write_bytes(bytes(header) + b''.join(replacements.get(i, c['bytes']) for i, c in enumerate(source.chunks)))
    revised = Place(output)
    assert len(revised.chunks) == len(source.chunks) and revised.class_count == source.class_count
    assert revised.instance_count == source.instance_count + len(nodes)
    checked_entries = 0
    for index, (before, after) in enumerate(zip(source.chunks, revised.chunks)):
        if index not in replacements:
            assert before['bytes'] == after['bytes'], f'Unrelated chunk changed: {index}'
        if index in original_entries:
            old_refs = source.classes[before['class_id']]['refs']
            values = entries(after, len(revised.classes[after['class_id']]['refs']))
            for offset, ref in enumerate(old_refs):
                assert values[offset] == edits.get((ref, before['property']), original_entries[index][offset]), (ref, before['property'])
                checked_entries += 1
            for offset, node in enumerate(new_by_group.get(before['class_id'], []), len(old_refs)):
                assert values[offset] == new_value(node, before['property'], before['dtype'])
    for ref, obj in source.instances.items():
        actual = revised.instances[ref]
        assert obj['class'] == actual['class'] and obj['name'] == actual['name']
        assert actual['parent'] == moved.get(ref, obj['parent'])
    for node in nodes:
        assert revised.path_of(node['ref']) == node['path']
    assert sha(base.read_bytes()) == sha(source.data), 'Original upload changed'
    baseline, final = independent_decode(source, verifier), independent_decode(revised, verifier)
    assert baseline['warnings'] == final['warnings'], ('Independent decoder warnings changed',
                                                       baseline['warnings'], final['warnings'])
    assert final['instance_count'] == revised.instance_count
    old_scripts = {x['path']: x for x in baseline['scripts']}
    new_scripts = {x['path']: x for x in final['scripts']}
    for path, entry in old_scripts.items():
        if path not in expected_sources:
            assert new_scripts[path] == entry, f'Unrelated script changed: {path}'
    for path, data in expected_sources.items():
        assert new_scripts[path]['source_sha256'] == sha(data), f'Decoded source mismatch: {path}'
    for node in nodes:
        if 'Source' in node:
            assert new_scripts[node['path']]['source_sha256'] == sha(node['Source'])
    for name, data in frozen_sources.items():
        assert (ROOT / name).read_bytes() == data, f'Source changed during packaging: {name}'
    if geometry:
        assert geometry.path.read_bytes() == geometry.data, 'Lobby export changed during packaging'
    return {'status': 'passed', 'input_sha256': sha(source.data), 'output_sha256': sha(revised.data),
            'input_instances': source.instance_count, 'output_instances': revised.instance_count,
            'updated_sources': list(expected_sources), 'disabled_paths': [e['path'] for e in manifest.get('disables', [])],
            'added_instances': len(nodes), 'imported_geometry_instances': len(geometry_refs),
            'archived_original_models': {str(ref): source.path_of(ref) for ref in moved},
            'original_chunks_preserved': len(source.chunks) - len(replacements),
            'rewritten_original_property_entries_verified': checked_entries,
            'same_class_groups': True, 'all_original_property_entries_verified': True,
            'independent_decoder': final.get('decoder', 'external modern RBXL decoder'),
            'independent_decoder_input': 'Original encoded RBXL bytes, without compatibility projection',
            'independent_decoder_no_new_warnings': True, 'backup': backup_path,
            'defaults_source_sha256': DEFAULTS['source_sha256'],
            'limits': 'Native Studio opening, rendering, animation playback and published multiplayer require playtesting.'}


def package(base, output, manifest, verifier):
    output = Path(output)
    assert Path(base).resolve() != output.resolve(), 'Never overwrite the uploaded place'
    assert not output.exists(), 'Choose a new output path; existing file preserved'
    with tempfile.TemporaryDirectory(prefix='.hab-v15-package-', dir=output.parent) as temporary:
        staged = Path(temporary) / output.name
        result = _package(base, staged, manifest, verifier)
        os.link(staged, output)
    output.with_suffix('.validation.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input')
    parser.add_argument('output')
    parser.add_argument('--manifest', default=str(Path(__file__).with_name('place_patch.json')))
    parser.add_argument('--verifier', default=os.environ.get('RBXL_VERIFY'), help='Modern independent RBXL decoder executable (or RBXL_VERIFY env var)')
    args = parser.parse_args()
    parser.error('--verifier or RBXL_VERIFY is required') if not args.verifier else None
    package(args.input, args.output, json.loads(Path(args.manifest).read_text()), args.verifier)
