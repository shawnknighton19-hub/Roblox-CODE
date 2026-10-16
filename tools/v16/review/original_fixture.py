"""Read exact source/parent and transactional world properties from tracked HABWAS.
The fixture excludes irrelevant native VFX asset descendants and arena decoration.
It preserves the complete original Lobby subtree, including duplicate names.
"""
from pathlib import Path
import sys,struct,json,hashlib
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'tools/v15'))
from place_binary import Place,Reader
from package_place import entries

def floating(b):
 n=int.from_bytes(b,'big');n=(n>>1)|((n&1)<<31)
 return struct.unpack('>f',n.to_bytes(4,'big'))[0]
def orientation(mode,raw=b''):
 if mode==0:return list(struct.unpack('<9f',raw))
 normals=[(1,0,0),(0,1,0),(0,0,1),(-1,0,0),(0,-1,0),(0,0,-1)]
 right=normals[(mode-1)//6];up=normals[(mode-1)%6]
 back=(right[1]*up[2]-right[2]*up[1],right[2]*up[0]-right[0]*up[2],right[0]*up[1]-right[1]*up[0])
 return [right[i//3]if i%3==0 else up[i//3]if i%3==1 else back[i//3]for i in range(9)]
def cf(b):return {'kind':'CFrame','value':[floating(b[-12:][i:i+4])for i in (0,4,8)]+orientation(b[0],b[1:-12])}
def attrs(raw):
 if not raw:return {}
 r=Reader(raw);out={}
 for _ in range(r.u32()):
  name,typ=r.string().decode(),r.byte()
  if typ==2:value=r.string().decode()
  elif typ==3:value=bool(r.byte())
  elif typ==4:value=struct.unpack('<i',r.read(4))[0]
  elif typ==5:value=struct.unpack('<f',r.read(4))[0]
  elif typ==6:value=struct.unpack('<d',r.read(8))[0]
  elif typ==17:value={'kind':'Vector3','value':list(struct.unpack('<3f',r.read(12)))}
  elif typ==20:
   pos=list(struct.unpack('<3f',r.read(12)));mode=r.byte();value={'kind':'CFrame','value':pos+orientation(mode,r.read(36)if mode==0 else b'')}
  else:raise AssertionError(f'Unreviewed fixture attribute {name} type {typ}')
  out[name]=value
 assert r.off==len(raw)
 return out

def load(path=None,full_maps=False):
 p=Place(path or ROOT/'HABWAS.rbxl')
 if path is None:assert hashlib.sha256(p.data).hexdigest()=='c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309'
 chosen=set()
 for ref,o in p.instances.items():
  path=p.path_of(ref);components=path.split('/')
  keep=ref in p.source_chunks or path.startswith('Workspace/Lobby') or path=='Workspace/ActiveArenaAnchor'
  if path.startswith(('ServerStorage/MapLibrary','Workspace/Maps','ReplicatedStorage/BombTagV6Previews','ReplicatedStorage/BombTagPreviewGalleryV5')):
   keep=keep or full_maps or len(components)<=3 or components[-1] in ('Floor','Spawns') or '/Spawns/' in path
  if path.startswith('ReplicatedStorage/') and o['class'] in ('Folder','RemoteEvent','RemoteFunction'):keep=True
  if path.count('/')==0:keep=True
  if keep:chosen.add(ref)
 for ref in list(chosen):
  parent=p.instances[ref]['parent']
  while parent in p.instances:chosen.add(parent);parent=p.instances[parent]['parent']
 shared=[]
 for chunk in p.chunks:
  if chunk['type']==b'SSTR':
   reader=Reader(chunk['raw']);assert reader.u32()==0
   for _ in range(reader.u32()):reader.read(16);shared.append(reader.string())
 rows={}
 for ref in chosen:
  o=p.instances[ref];props={}
  for name in ('Source','Disabled','Text','Archivable','Enabled','Anchored','CanCollide','CanQuery','CanTouch','Tags'):
   if name in o['props']:
    val=o['props'][name];props[name]=val.decode() if isinstance(val,bytes)else val
  rows[ref]={'ref':ref,'parent':o['parent'],'name':o['name'],'class':o['class'],'path':p.path_of(ref),'props':props,
             'attrs':attrs(o['props'].get('AttributesSerialize',b''))}
 for chunk in p.chunks:
  name=chunk.get('property')
  if name not in ('CFrame','size','PrimaryPart','WorldPivotData','Tags'):continue
  refs=p.classes[chunk['class_id']]['refs']
  if not any(r in chosen for r in refs):continue
  for ref,b in zip(refs,entries(chunk,len(refs))):
   if ref not in chosen:continue
   if name=='Tags':value=shared[int.from_bytes(b,'big')].decode();key='Tags'
   elif name=='CFrame':value=cf(b);key=name
   elif name=='size':value={'kind':'Vector3','value':[floating(b[i:i+4])for i in (0,4,8)]};key='Size'
   elif name=='PrimaryPart':
    if b not in chosen:continue
    value={'kind':'Ref','value':b};key=name
   elif name=='WorldPivotData':
    if not b[1]:continue
    value=cf(b[0]);key='WorldPivot'
   rows[ref]['props'][key]=value
 return sorted(rows.values(),key=lambda r:(r['path'].count('/'),r['ref']))
if __name__=='__main__':
 data=load();print(json.dumps({'instances':len(data),'sources':sum('Source'in r['props']for r in data),'lobby':sum(r['path'].startswith('Workspace/Lobby')for r in data)}))
