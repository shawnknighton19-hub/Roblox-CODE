"""Execute the real builder and export new geometry with pinned serializer metadata.

The output directory defaults to a fresh temporary directory. Luau and Go are
external development tools; all adapters, schema, and encoder source are tracked.
"""
from pathlib import Path
import argparse,copy,hashlib,json,os,shutil,subprocess
from common import HERE,REPO,output_dir,luau_binary
from convert_geometry import convert

def export(out,luau,encoder=None,go=None):
 source=(REPO/'LobbyBuilderV15.luau').read_text()
 mock=(REPO/'tools/v12/mock_prefix.luau').read_text()
 script=mock+'\nlocal Builder=(function()\n'+source+'\nend)()\nlocal built=Builder.Build(nil)\nprint(json({instances={exportNode(built)}}))\n'
 (out/'export.luau').write_text(script)
 raw=json.loads(subprocess.check_output([luau,str(out/'export.luau')],text=True))
 def clean(n):
  # This adapter supplies Archivable=true by default; the frozen geometry omitted
  # that engine-default property. All values authored by Build remain present.
  assert n['props'].pop('Archivable',True) is True
  for c in n.get('children',[]):clean(c)
 for n in raw['instances']:clean(n)
 (out/'generated.raw.json').write_text(json.dumps(raw,separators=(',',':'))+'\n')
 typed=copy.deepcopy(raw)
 def migrate(n):
  if n['class']=='UICorner' and 'CornerRadius' in n['props']:
   value=n['props'].pop('CornerRadius')
   for key in ('BottomLeftRadius','BottomRightRadius','TopLeftRadius','TopRightRadius'):n['props'][key]=value
  for child in n.get('children',[]):migrate(child)
 for n in typed['instances']:migrate(n)
 (out/'generated.typed.json').write_text(json.dumps(convert(typed),separators=(',',':'))+'\n')
 if not encoder:
  go=go or os.environ.get('GO_BINARY') or shutil.which('go')
  if not go:raise RuntimeError('Go 1.23+ not found. Pass --go /path/to/go or --encoder /path/to/built/encoder.')
  version=subprocess.run([go,'version'],text=True,capture_output=True)
  if version.returncode or not version.stdout.startswith('go version go'):
   raise RuntimeError('The selected go command is not a Go compiler. Pass --go /path/to/Go/bin/go.')
  encoder=out/('geometry-encoder.exe' if os.name=='nt' else 'geometry-encoder')
  env=dict(os.environ);env.setdefault('GOCACHE',str(out/'go-cache'));env.setdefault('GOMODCACHE',str(out/'go-modules'));env.setdefault('GOPATH',str(out/'go-work'))
  subprocess.run([go,'build','-o',str(encoder),'.'],cwd=HERE/'encoder',env=env,check=True)
 subprocess.run([str(encoder),str(out/'generated.typed.json'),str(out/'generated.rbxl')],check=True)
 report={'builderSHA256':hashlib.sha256(source.encode()).hexdigest(),'geometrySHA256':hashlib.sha256((out/'generated.rbxl').read_bytes()).hexdigest(),'encoder':'github.com/robloxapi/rbxfile@37f4b3f11ff694d24160b9d7b948174fd384d596','output':str(out)}
 (out/'export-validation.json').write_text(json.dumps(report,indent=2)+'\n');return report

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--out-dir');parser.add_argument('--luau');parser.add_argument('--go');parser.add_argument('--encoder')
 args=parser.parse_args();print(json.dumps(export(output_dir(args.out_dir),luau_binary(args.luau),args.encoder,args.go),indent=2))
