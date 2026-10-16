"""Execute real MapBuilderV16 and encode four staged replacement folders.

Uses the existing pinned Roblox serializer, never rewrites an uploaded source
place. The root installer is responsible for original-instance backups/swaps.
"""
from pathlib import Path
import argparse, copy, hashlib, json, os, re, shutil, subprocess, sys
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'tools/v15/lobby'))
import convert_geometry as converter
SCHEMA=json.loads((HERE/'geometry-schema.json').read_text())
converter.CLASSES,converter.ENUMS=SCHEMA['classes'],SCHEMA['enums']
convert=converter.convert

def export(out,luau,encoder=None):
 out=Path(out);out.mkdir(parents=True,exist_ok=True)
 source=(REPO/'MapBuilderV16.luau').read_text()
 mock=(REPO/'tools/v12/mock_prefix.luau').read_text()
 script=mock+'\nlocal Builder=(function()\n'+source+'\nend)()\nlocal built=Builder.BuildArchive()\nlocal roots={}\nfor _,f in ipairs(built:GetChildren()) do table.insert(roots,exportNode(f)) end\nprint(json({instances=roots}))\n'
 (out/'export.luau').write_text(script)
 result=subprocess.run([luau,str(out/'export.luau')],capture_output=True,text=True,check=True)
 raw=json.loads(result.stdout)
 def clean(n):
  assert n['props'].pop('Archivable',True) is True
  for c in n.get('children',[]):clean(c)
 for n in raw['instances']:clean(n)
 (out/'generated.raw.json').write_text(json.dumps(raw,separators=(',',':'))+'\n')
 typed=convert(copy.deepcopy(raw))
 (out/'generated.typed.json').write_text(json.dumps(typed,separators=(',',':'))+'\n')
 if not encoder:
  encoder=out/'geometry-encoder'
  env=dict(os.environ);env.setdefault('GOCACHE',str(out/'go-cache'));env.setdefault('GOMODCACHE',str(out/'go-modules'));env.setdefault('GOPATH',str(out/'go-work'))
  subprocess.run(['go','build','-o',str(encoder),'.'],cwd=REPO/'tools/v15/lobby/encoder',env=env,check=True)
 encoded=subprocess.run([str(encoder),str(out/'generated.typed.json'),str(out/'generated.rbxl')],check=True,capture_output=True,text=True)
 print(encoded.stdout,end='');counts=re.search(r'decoded (\d+) new instances; (\d+) property values match',encoded.stdout);assert counts,'Missing encoder roundtrip verification'
 sourcehash=hashlib.sha256(source.encode()).hexdigest();geohash=hashlib.sha256((out/'generated.rbxl').read_bytes()).hexdigest()
 report={'builderSHA256':sourcehash,'geometrySHA256':geohash,'geometryRawSHA256':hashlib.sha256((out/'generated.raw.json').read_bytes()).hexdigest(),'geometryRoundTrip':{'instances':int(counts[1]),'propertyValues':int(counts[2]),'encoder':'rbxfile encoder and decoder property comparison'},'basePlaceSHA256':'c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309','mapCount':15,'activeName':'Sky Garden','activeDisplayName':'Sunset Docks','activeAnchor':[0,-27,-190]}
 (out/'export-validation.json').write_text(json.dumps(report,indent=2)+'\n')
 return report

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--out-dir',default=str(HERE));p.add_argument('--luau',default=str(REPO.parent/'.cloud-tools/bin/luau'));p.add_argument('--encoder');a=p.parse_args()
 try: print(json.dumps(export(a.out_dir,a.luau,a.encoder),indent=2))
 except subprocess.CalledProcessError as exc:
  print(exc.stdout or '',file=sys.stderr);print(exc.stderr or '',file=sys.stderr);raise
