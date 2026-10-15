"""Validate and copy the frozen packaging manifest to a chosen output directory."""
from pathlib import Path
import argparse,json,hashlib,sys
from common import HERE,REPO,output_dir
p=argparse.ArgumentParser();p.add_argument('--original');p.add_argument('--out-dir');a=p.parse_args()
manifest=json.loads((HERE/'world-manifest.json').read_text())
assert hashlib.sha256((REPO/manifest['geometry']).read_bytes()).hexdigest()==manifest['geometry_sha256']
assert hashlib.sha256((REPO/manifest['builder']).read_bytes()).hexdigest()==manifest['sourceSHA256']
if a.original:
 fixture=json.loads((HERE/'original-lobby-fixture.json').read_text());assert hashlib.sha256(Path(a.original).read_bytes()).hexdigest()==fixture['inputSHA256'],'Different original place; refuse reuse of refs.'
 sys.path.insert(0,str(HERE.parent));from place_binary import Place
 place=Place(a.original)
 for ref,path in manifest['archiveOriginal'].items():assert place.path_of(int(ref))==path
 for row in manifest['textChanges']:
  assert place.path_of(row['ref'])==row['path'];assert place.instances[row['ref']]['props']['Text'].decode()==row['original']
out=output_dir(a.out_dir);(out/'world-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(out/'world-manifest.json')
