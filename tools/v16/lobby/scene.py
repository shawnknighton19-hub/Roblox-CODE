"""Analytic original geometry fixture plus executed V16 builder, with exact rigid moves."""
from pathlib import Path
import argparse,copy,hashlib,json,sys
import numpy as np
HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'tools/v15/lobby'))
from common import output_dir
SOURCE_SHA='c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309'
ARCHIVES=['North terrace','Gardens and seating','Boundary','HABExpansionLobby/SpectatorOverlook','HABExpansionLobby/InvisibleLobbyBarrier']
def from_decoded(path):
 rows=json.loads(Path(path).read_text());out=[]
 enums=json.loads((REPO/'tools/v15/lobby/geometry-schema.json').read_text())['enums']
 materials={v:k for k,v in enums['Material'][1].items()}
 for row in rows:
  p=row['path'];v={k:x['value'] for k,x in row['properties'].items()}
  if row['class'] not in ('Part','WedgePart','SpawnLocation','MeshPart'):continue
  if any(p==f'Workspace/Lobby/{a}' or p.startswith(f'Workspace/Lobby/{a}/') for a in ARCHIVES):continue
  cf=v['CFrame'];props={'Name':p,'CFrame':{'_kind':'CFrame','p':dict(zip('XYZ',cf['position'].values())),'m':cf['rotation']},'Size':dict(zip('XYZ',v['size'].values()))}
  props['Color']={k.upper():n/255 for k,n in v['Color3uint8'].items()}
  for k in ('Anchored','CanCollide','CanTouch','CanQuery','CastShadow','Transparency'):props[k]=v[k]
  props['Shape']={'Name':{0:'Ball',1:'Block',2:'Cylinder'}[v.get('shape',1)]}
  props['Material']={'Name':materials[v['Material']]}
  node={'class':row['class'],'props':props,'children':[],'attributes':{}}
  guis=[r for r in rows if r['class']=='SurfaceGui' and r['path'].rsplit('/',1)[0]==p]
  if guis:
   gui=guis[0];labels=[r for r in rows if r['class']=='TextLabel' and r['path'].startswith(gui['path']+'/')]
   if labels:node['previewSign']={'text':labels[0]['properties']['Text']['value'],'face':{5:'Front',2:'Back'}.get(gui['properties']['Face']['value'],'Other')}
  out.append(node)
 return {'inputSHA256':SOURCE_SHA,'limits':'Geometry-only fixture decoded from the exact original HABWAS with independent rbxfile reader. Render labels approximate; no script data.','instances':[{'class':'Model','props':{'Name':'Lobby'},'children':out}]}
def scene(generated,original=None):
 d=json.loads((HERE/'retained-original.json').read_text());new=json.loads(Path(generated).read_text())
 if original:assert hashlib.sha256(Path(original).read_bytes()).hexdigest()==SOURCE_SHA,'Unexpected input place'
 for n in d['instances'][0]['children']:
  for move in new['layout']:
   if n['props']['Name'].startswith('Workspace/Lobby/'+move['Path']+'/'):
    cf=n['props']['CFrame'];delta=move['Delta'];rot=np.array(delta['m']).reshape(3,3)
    cf['p']=dict(zip('XYZ',(rot@np.array([cf['p'][c] for c in 'XYZ'])+np.array([delta['p'][c] for c in 'XYZ'])).tolist()))
    cf['m']=(rot@np.array(cf['m']).reshape(3,3)).ravel().tolist()
    break
  if 'Emotes kiosk/EMOTES' in n['props']['Name'] and 'previewSign' in n:n['previewSign']['text']='LOCKER'
 d['instances'][0]['children']+=new['instances'];d['providedOriginalVerified']=bool(original)
 return d
def add_spectator_map(document,map_export):
 active=copy.deepcopy(next(n for n in json.loads(Path(map_export).read_text())['instances'] if n['props']['Name']=='Maps'))
 document['instances'][0]['children'].append(active)
 def walk(node):
  yield node
  for c in node.get('children',[]):yield from walk(c)
 spawns=[n for n in walk(active) if n['props']['Name'].startswith('Spawn') and n['class']=='Part']
 for i,node in enumerate(spawns):
  pos=node['props']['CFrame']['p'];tone={'R':.12 if i%2 else 1,'G':.82 if i%2 else .4,'B':1 if i%2 else .2}
  for name,offset,size,color in [('Head',5,[1.5,1.5,1.5],{'R':1,'G':.8,'B':.57}),('Torso',3,[2,2,1],tone),('Legs',1,[1.8,2,1],{'R':.08,'G':.12,'B':.2})]:
   document['instances'][0]['children'].append({'class':'Part','props':{'Name':'Illustrative actor '+name,'CFrame':{'p':{'X':pos['X'],'Y':pos['Y']+offset,'Z':pos['Z']},'m':[1,0,0,0,1,0,0,0,1]},'Size':dict(zip('XYZ',size)),'Color':color,'CanCollide':False},'children':[]})
 document['previewAnnotations']='Illustrative block actor markers at actual active-map spawn points; these markers are not part of the delivered place.'
 return document
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--generated',required=True);p.add_argument('--original');p.add_argument('--out-dir');p.add_argument('--decoded-original');p.add_argument('--spectator-maps');a=p.parse_args();out=output_dir(a.out_dir)
 if a.decoded_original:(HERE/'retained-original.json').write_text(json.dumps(from_decoded(a.decoded_original),separators=(',',':'))+'\n')
 document=scene(a.generated,a.original)
 if a.spectator_maps:document=add_spectator_map(document,a.spectator_maps)
 (out/'combined.raw.json').write_text(json.dumps(document,separators=(',',':'))+'\n');print(out/'combined.raw.json')
