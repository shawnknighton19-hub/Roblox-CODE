"""Combine freshly executed builder geometry with the recorded HABWAS booth fixture.

--original optionally verifies the supplied place is the exact fixture input and
checks its retained hierarchy using the tracked binary reader. Unknown inputs stop.
"""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess,sys
from common import HERE,REPO,output_dir,luau_binary

def scene(out,generated=None,original=None,luau=None):
 fixture=json.loads((HERE/'original-lobby-fixture.json').read_text())
 if original:
  path=Path(original);assert hashlib.sha256(path.read_bytes()).hexdigest()==fixture['inputSHA256'],'This fixture belongs to a different input place; decode/review the new place first.'
  sys.path.insert(0,str(HERE.parent));from place_binary import Place
  place=Place(path);paths={place.path_of(ref):ref for ref in place.instances}
  for p in json.loads((HERE/'world-manifest.json').read_text())['preservePaths']:assert p in paths,p
 if generated:
  fresh=json.loads(Path(generated).read_text())
 else:
  script=(REPO/'tools/v12/mock_prefix.luau').read_text()+'\nlocal B=(function()\n'+(REPO/'LobbyBuilderV15.luau').read_text()+'\nend)()\nprint(json({instances={exportNode(B.Build(nil))}}))\n'
  (out/'scene-export.luau').write_text(script)
  fresh=json.loads(subprocess.check_output([luau_binary(luau),str(out/'scene-export.luau')],text=True))
  (out/'generated.raw.json').write_text(json.dumps(fresh,separators=(',',':'))+'\n')
 combined=copy.deepcopy(fixture);combined['instances'][0]['children']+=fresh['instances'];combined['providedOriginalVerified']=bool(original)
 (out/'combined.raw.json').write_text(json.dumps(combined,separators=(',',':'))+'\n')
 return combined,fresh

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--out-dir');p.add_argument('--generated');p.add_argument('--original');p.add_argument('--luau');a=p.parse_args();out=output_dir(a.out_dir);scene(out,a.generated,a.original,a.luau);print(out/'combined.raw.json')
