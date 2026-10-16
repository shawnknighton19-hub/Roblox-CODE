"""Assemble a fresh-HABWAS polish installer. No archived V15 runtime is installed."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]
FIXTURES=json.loads((REPO/'tools/v15/fixtures/scripts.json').read_text())
BYREF={e['ref']:e for e in FIXTURES}
BASE_SHA='c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309'
STATIC={8437:'DodgeWeaveV16.client.luau',8448:'HABActionClientV16.client.luau',27181:'EconomyServiceV16.luau'}
ADDITIONS=[('ReplicatedStorage/HABWeaveAnimationsV16','HABWeaveAnimationsV16.luau'),
 ('ReplicatedStorage/HABExpansion/HABActionAnimationsV16','HABActionAnimationsV16.luau')]
# Keep all actual live controllers and runtime modules source-verified. Exclude
# inactive imported tool/animation-pack modules and unrelated editor utilities.
PRESERVE=[8417,8427,8428,8431,8432,8433,8438,8439,8440,8441,8442,8452,8481,8482,
8523,8524,8525,8527,8679,27143,27145,27146,27147,27151,27152,27153,27154,27155,
27156,27157,27158,27159,27160,27161,27162,27163,27164,27165,27167,27168,27172,
27176,27177,27178,27179,27180,27181,27182,27183,27184,27185,27186,27187,27188,
27189,27190,27191,27217,27219,27221,8443,8444,8445,8446,8447,8448,8449,8450,8437]

def replacements():
 out=dict(STATIC)
 for e in json.loads((ROOT/'effect_patch_manifest.json').read_text())['edits']:
  assert e['ref'] not in out,e['ref'];out[e['ref']]=e['source']
 return out

def literal(s):
 for n in range(2,30):
  end=']'+'='*n+']'
  if end not in s:return '['+'='*n+'['+s+end
 raise ValueError('Cannot quote source')
def lua(v):
 if v is None:return 'nil'
 if v is True:return 'true'
 if v is False:return 'false'
 if isinstance(v,str):return literal(v)
 if isinstance(v,(int,float)):return repr(v)
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 if isinstance(v,dict):return '{'+','.join('[ '+lua(k)+' ]='+lua(x) for k,x in v.items())+'}'
 raise TypeError(type(v))
def compiler():return os.environ.get('LUAU_COMPILE') or shutil.which('luau-compile') or '/workspace/.cloud-tools/bin/luau-compile'
def records():
 out=[];changed=replacements()
 for ref in sorted(set(PRESERVE)|set(changed)):
  e=BYREF[ref];assert hashlib.sha256((REPO/e['source']).read_bytes()).hexdigest()==e['sha256']
  item={'path':e['path'],'class':e['class'],'old':(REPO/e['source']).read_text(),'disabled':e['disabled']}
  if ref in changed:item['target']=(REPO/changed[ref]).read_text()
  out.append(item)
 for path,source in ADDITIONS:out.append({'path':path,'class':'ModuleScript','target':(REPO/source).read_text(),'add':True})
 return out

def payload():
 text=(ROOT/'installer_head.luau').read_text()+'\nlocal entries='+lua(records())+'\n'
 for name,file in [('Maps','MapBuilderV16.luau'),('Lobby','LobbyBuilderV16.luau')]:
  text+='local '+name+'=(function()\n'+(REPO/file).read_text()+'\nend)()\n'
 text+='local World=(function()\n'+(ROOT/'world_installer.luau').read_text()+'\nend)()\n'
 return text+(ROOT/'installer_tail.luau').read_text()

def manifest():
 data={'input_sha256':BASE_SHA,'edits':[], 'additions':[], 'disables':[],
 'workspace_attributes':{'HABPolishVersion':16},'backup_path':'ServerStorage/HABPolishV16FileBackup',
 'world_manifests':['tools/v16/maps/world-manifest.json','tools/v16/lobby/world-manifest.json']}
 for ref,source in replacements().items():
  e=BYREF[ref];data['edits'].append({'path':e['path'],'source':source,'original_sha256':e['sha256'],'source_sha256':hashlib.sha256((REPO/source).read_bytes()).hexdigest()})
 for path,source in ADDITIONS:data['additions'].append({'path':path,'class':'ModuleScript','source':source})
 (ROOT/'place_patch.json').write_text(json.dumps(data,indent=2)+'\n')
 return data

def assemble():
 text=payload();file=REPO/'Install-HABWAS-Polish-V16.command.luau';file.write_text(text)
 subprocess.run([compiler(),'--binary',str(file)],stdout=subprocess.DEVNULL,check=True)
 (REPO/'HABWAS-Polish-V16.txt').write_bytes(text.replace('\n','\r\n').encode())
 manifest()
 files=list(replacements().values())+[s for _,s in ADDITIONS]+['MapBuilderV16.luau','LobbyBuilderV16.luau']
 for f in files:subprocess.run([compiler(),'--binary',str(REPO/f)],stdout=subprocess.DEVNULL,check=True)
 report={'status':'passed','installer_sha256':hashlib.sha256(text.encode()).hexdigest(),'installer_bytes':len(text.encode()),
 'source_sha256':{f:hashlib.sha256((REPO/f).read_bytes()).hexdigest() for f in files},
 'syntax':'All proposed runtime sources and complete installer compiled; native Studio execution not claimed.'}
 (ROOT/'assembly.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='source_sha256'}))
if __name__=='__main__':assemble()
