"""No-jump access and spectator sightline samples against executed/retained geometry."""
from pathlib import Path
import argparse,json,hashlib,math,sys
import numpy as np
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'tools/v15/lobby'))
from route_math import parts,ground_grid,components,nearest_label,vertical_hit,circle_offsets
from geometry import walk,Part
p=argparse.ArgumentParser();p.add_argument('--scene',required=True);p.add_argument('--generated',required=True);p.add_argument('--maps');p.add_argument('--report',required=True);a=p.parse_args()
doc=json.loads(Path(a.scene).read_text());new=json.loads(Path(a.generated).read_text());pp=parts(doc['instances'][0]);coll=[p for p in pp if p.collide];errors=[];checks=0
def check(ok,message):
 global checks
 checks+=1
 if not ok:errors.append(message)
points=[('Spawn',0,150.66),('Bombs',-73,44),('Trails',-73,79),('Titles',-73,114),('Locker',-73,149),('Cyber',75,44),('Solar',75,72),('Glacier',75,100),('Phantom',75,128),('Crates',26,144),('Abilities',48,144),('Passes',70,144),('West ramp',-54,67),('East ramp',54,67)]
points += [('Board '+str(x),x,167) for x in (-54,-18,18,54)]
grid,xx,zz=ground_grid(coll,2,step=1,level=1.5);labels,sizes=components(grid)
ids=[nearest_label(labels,xx,zz,float(x),float(z),1.8) for _,x,z in points]
check(None not in ids,'Ground approach blocked '+str(list(zip(points,ids))));check(len(set(ids))==1,'Ground approaches disconnected '+str(list(zip(points,ids))))
for name,x,z in points:
 for dx,dz in circle_offsets(2):
  hit=vertical_hit(coll,x+dx,z+dz,1.8,1,False);blocked=vertical_hit(coll,x+dx,z+dz,7.9,1.9,False)
  check(hit is not None and abs(hit[0]-1.5)<.2,name+' missing support');check(blocked is None,name+' blocked '+str(blocked and blocked[1].name))
for x in (-54,54):
 for t in np.linspace(.01,.99,31):
  height=1.5+5*t;z=64-24*t
  for offset in (-10,-5,0,5,10):
   hit=vertical_hit(coll,x+offset,z,height+6.4,height-.4,False)
   check(hit is not None and abs(hit[0]-height)<.05,'Ramp blocked/discontinuous '+str((x,offset,t,hit and (hit[0],hit[1].name))))
 for z,h in ((64.6,1.5),(39.4,6.5)):
  for offset in (-10,-5,0,5,10):
   hit=vertical_hit(coll,x+offset,z,h+6.4,h-.4,False);check(hit is not None and abs(hit[0]-h)<.05,'Ramp endpoint blocked')
terrace=[(-54,36),(54,36),(-54,-34),(0,-34),(54,-34)]
grid,xx,zz=ground_grid(coll,2,step=1,level=6.5);labels,sizes=components(grid);ids=[nearest_label(labels,xx,zz,float(x),float(z),1.8) for x,z in terrace]
check(None not in ids,'Terrace approach blocked '+str(ids));check(len(set(ids))==1,'Terrace disconnected '+str(ids))
np_new=parts(new['instances'][0])
for p in np_new:
 check(np.isfinite(p.pos).all() and np.isfinite(p.size).all() and (p.size>0).all(),'Invalid dimensions '+p.name)
 check(p.props.get('Anchored') is True,'Unanchored '+p.name)
 check(p.props.get('CanTouch') is False,'Unexpected touch '+p.name)
 if 'Invisible' in p.name or 'invisible' in p.name:check(p.transparency==1 and not p.query,'Safety boundary obstructs camera '+p.name)
# Check a 4-stud standing/sprint envelope cannot exit the northern edge through a rail gap.
barriers=[p for p in np_new if p.name=='Invisible safety boundary']
for x in np.linspace(-63,63,64):
 check(any(p.ray(np.array([x,9.5,-35]),np.array([0,0,-1]),15) is not None for p in barriers),'Front safety gap '+str(x))
visibility=[]
if a.maps:
 export_report=Path(a.maps).with_name('export-validation.json')
 if export_report.exists():assert json.loads(export_report.read_text())['builderSHA256']==hashlib.sha256((REPO/'MapBuilderV16.luau').read_bytes()).hexdigest(),'Map export does not match current builder; regenerate before checking.'
 maps=json.loads(Path(a.maps).read_text());root=next(n for n in maps['instances'] if n['props']['Name']=='MapLibrary')
 eyes=[np.array([x,12,-35]) for x in (-58,-29,0,29,58)]
 lobby_occluders=[p for p in pp if p.transparency<.5 and p.name not in ('Floor',)]
 for model in root['children']:
  if model['class']!='Model':continue
  map_parts=parts(model);offset=np.array([0,-27,-190]);targets=[]
  for node,path in walk(model):
   if node['class'] in ('Part','SpawnLocation') and '/Spawns/Spawn' in path:
    obj=Part(node,path);targets.append((path,obj.pos+offset+np.array([0,5,0])))
  # Real spawn/head samples establish actors, not merely the floor, are visible.
  seen=0;details=[]
  occluders=[p for p in map_parts if p.transparency<.5 and p.name not in ('Spawn','SpawnLocation')]
  for name,target in targets:
   visible=False
   for eye in eyes:
    direction=target-eye;length=np.linalg.norm(direction);direction/=length
    blocked=any(p.ray(eye,direction,length-.2) is not None for p in lobby_occluders)
    if not blocked:blocked=any(p.ray(eye-offset,direction,length-.2) is not None for p in occluders)
    if not blocked:visible=True;break
   seen+=visible;details.append({'sample':name,'visible':visible})
  check(len(targets)>0,'No player spawn samples '+model['props']['Name'])
  # Spawn lanes may deliberately sit behind useful cover. Check ordinary central
  # movement lanes separately, using only 4-stud-wide standing-clear ground.
  map_coll=[p for p in map_parts if p.collide];lane_details=[];lane_candidates=[]
  for x in (-60,-30,0,30,60):
   for z in (-50,-25,0,25,50):lane_candidates.append((x,0,z,'Ground lane'))
  for deck in map_parts:
   if deck.attrs.get('HABWalkableV16') and deck.name=='Walkable deck':
    for dx,dz in ((0,0),(-deck.size[0]/4,0),(deck.size[0]/4,0),(0,-deck.size[2]/4),(0,deck.size[2]/4)):
     surface=deck.pos+deck.rot@np.array([dx,deck.size[1]/2,dz]);lane_candidates.append((*surface.tolist(),deck.path))
  for x,height,z,surface_name in lane_candidates:
   clear=True
   for dx,dz in circle_offsets(2):
    support=vertical_hit(map_coll,x+dx,z+dz,height+.3,height-.5,False)
    obstacle=vertical_hit(map_coll,x+dx,z+dz,height+6.4,height+.4,False)
    if support is None or abs(support[0]-height)>.2 or obstacle is not None:clear=False;break
   if not clear:continue
   target=np.array([x,height+5,z],dtype=float)+offset;visible=False;lobby_clear=False
   for eye in eyes:
    direction=target-eye;length=np.linalg.norm(direction);direction/=length
    blocked=any(p.ray(eye,direction,length-.2) is not None for p in lobby_occluders)
    if not blocked:
     lobby_clear=True
     if not any(p.ray(eye-offset,direction,length-.2) is not None for p in occluders):visible=True;break
   lane_details.append({'localPosition':[x,height+5,z],'surface':surface_name,'visible':visible,'unobstructedByLobby':lobby_clear})
  lane_seen=sum(r['visible'] for r in lane_details)
  check(len(lane_details)>=5,'Insufficient standing-clear central lane samples '+model['props']['Name'])
  check(lane_seen>=math.ceil(len(lane_details)*.7),'Main movement lanes obscured '+model['props']['Name']+f' {lane_seen}/{len(lane_details)}')
  check(all(r['unobstructedByLobby'] for r in lane_details),'Lobby geometry obscures central map lanes '+model['props']['Name'])
  visibility.append({'map':model['props']['Name'],'spawnHeadSamples':len(targets),'spawnHeadsVisibleFromAtLeastOneViewingPosition':seen,'spawnSamples':details,'centralLaneSamples':len(lane_details),'centralLanesVisible':lane_seen,'laneSamples':lane_details})
report={'version':16,'checks':checks,'passed':not errors,'errors':errors,'groundAccessPoints':len(points),'terraceAccessPoints':len(terrace),'standingClearanceRadius':2,'standingEnvelopeHeight':6.4,'rampWidth':28,'rampRise':5,'rampRun':24,'rampSlopeDegrees':math.degrees(math.atan(5/24)),'newParts':len(np_new),'retainedExistingParts':len(pp)-len(np_new),'arenaAnchor':[0,-27,-190],'viewingEdgeZ':-39.7,'nearestMapEdgeZ':-70,'spectatorSeparationStuds':30.3,'spectatorViewpoints':[[-58,12,-35],[-29,12,-35],[0,12,-35],[29,12,-35],[58,12,-35]],'spectatorActorSightlines':visibility,'builderSHA256':hashlib.sha256((REPO/'LobbyBuilderV16.luau').read_bytes()).hexdigest(),'inputSHA256':doc['inputSHA256'],'providedOriginalVerified':doc.get('providedOriginalVerified',False),'mapBuilderSHA256':hashlib.sha256((REPO/'MapBuilderV16.luau').read_bytes()).hexdigest() if a.maps else None,'mapExportSHA256':hashlib.sha256(Path(a.maps).read_bytes()).hexdigest() if a.maps else None,'limits':'Analytic solid geometry and sampled actor-head rays. Map cover deliberately can occlude individual players. Not Roblox Humanoid/PathfindingService playtesting or engine screenshots.'}
Path(a.report).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='spectatorActorSightlines'},indent=2));assert not errors,errors
