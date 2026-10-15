"""Analytic no-jump access checks against new geometry and retained real booth parts."""
from pathlib import Path
import json,hashlib,sys,math,argparse
from common import HERE,REPO as ROOT,output_dir
from inspect_geometry import scene
import numpy as np
parser=argparse.ArgumentParser();parser.add_argument('--out-dir');parser.add_argument('--scene');parser.add_argument('--generated');parser.add_argument('--original');parser.add_argument('--luau');parser.add_argument('--report')
args=parser.parse_args();OUT=output_dir(args.out_dir)
from route_math import parts,ground_grid,components,nearest_label,vertical_hit,circle_offsets
if args.scene:
 D=json.loads(Path(args.scene).read_text());new={'instances':[next(n for n in D['instances'][0]['children'] if n['props']['Name']=='HABPolishedLobbyV15')]}
else:D,new=scene(OUT,args.generated,args.original,args.luau)
pp=parts(D['instances'][0]);coll=[p for p in pp if p.collide]
z0=86.66000366210938;floor=1.5;checks=0
errors=[]
def check(ok,text):
 global checks
 checks+=1
 if not ok:errors.append(text)
points=[('Spawn',0,64),('Bombs',-74,-17),('Trails',-74,20),('Titles',74,-17),('Emotes',74,20),('Cyber',-28,73),('Glacier',28,73),('Solar',52,-3),('Phantom',-52,-3),('Crates',68,40),('Abilities',-54,59),('Passes',54,59),('West ramp',-54,-20),('East ramp',54,-20)]
grid,xx,zz=ground_grid(coll,2,step=1,level=floor);labels,sizes=components(grid)
ids=[nearest_label(labels,xx,zz,x,z0+z,1.8) for _,x,z in points]
check(None not in ids,'Ground access point does not fit the 4-stud wide standing envelope: '+str(list(zip(points,ids))))
check(len(set(ids))==1,'Ground access points are disconnected: '+str(list(zip(points,ids))))
for name,x,z in points:
 for dx,dz in circle_offsets(2):
  support=vertical_hit(coll,x+dx,z0+z+dz,floor+.3,floor-.5,False)
  blocked=vertical_hit(coll,x+dx,z0+z+dz,floor+6.4,floor+.4,False)
  check(support is not None and abs(support[0]-floor)<.2,name+' lacks floor support')
  check(blocked is None,name+' approach blocked: '+str(blocked and blocked[1].name))
# Both inclines join the flat plaza to the same five-stud terrace without a step.
for x in (-54,54):
 for t in np.linspace(.01,.99,31):
  height=floor+5*t;z=z0-22-24*t
  for offset in (-10,-5,0,5,10):
   hit=vertical_hit(coll,x+offset,z,height+6.4,height-.4,False)
   check(hit is not None and abs(hit[0]-height)<.05,'Ramp blocked/discontinuous at '+str((x,offset,t,hit and (hit[0],hit[1].name))))
 for z,h in ((z0-21.4,floor),(z0-46.6,floor+5)):
  for offset in (-10,-5,0,5,10):
   hit=vertical_hit(coll,x+offset,z,h+6.4,h-.4,False)
   check(hit is not None and abs(hit[0]-h)<.05,'Ramp endpoint blocked')
boardpoints=[('West ramp',-54,-49),('East ramp',54,-49),('Wins',-54,-65),('Kills',-18,-65),('Final stands',18,-65),('Global wins',54,-65),('Overlook entry',0,-86),('Overlook',0,-108)]
grid,xx,zz=ground_grid(coll,2,step=1,level=floor+5);labels,sizes=components(grid)
ids=[nearest_label(labels,xx,zz,x,z0+z,1.8) for _,x,z in boardpoints]
check(None not in ids,'Terrace approach blocked: '+str(list(zip(boardpoints,ids))))
check(len(set(ids))==1,'Terrace/overlook route disconnected: '+str(list(zip(boardpoints,ids))))
newparts=parts(new['instances'][0])
for p in newparts:
 check(np.isfinite(p.pos).all() and np.isfinite(p.size).all() and (p.size>0).all(),'Invalid geometry '+p.name)
 check(p.minimum[0]>=-102.0001 and p.maximum[0]<=102.0001 and p.minimum[2]>=z0-94.0001 and p.maximum[2]<=z0+94.0001,'New lobby extends outside current playable footprint: '+p.name)
 check(p.props.get('Anchored') is True,'Unanchored lobby part '+p.name)
 check(p.props.get('CanTouch') is False,'Unexpected touch emitter '+p.name)
report={'version':15,'checks':checks,'passed':not errors,'errors':errors,'groundAccessPoints':len(points),'terraceAccessPoints':len(boardpoints),'standingClearanceRadius':2,'standingEnvelopeHeight':6.4,'rampWidth':28,'rampRise':5,'rampRun':24,'rampSlopeDegrees':math.degrees(math.atan(5/24)),'newParts':len(newparts),'archivedArchitectureParts':233,'retainedExistingParts':len(pp)-len(newparts),'newFootprintInsideOldFootprint':True,'sourceSHA256':{'LobbyBuilderV15.luau':hashlib.sha256((ROOT/'LobbyBuilderV15.luau').read_bytes()).hexdigest()},'inputSHA256':D['inputSHA256'],'providedOriginalVerified':D.get('providedOriginalVerified',False),'limits':'Analytic geometry with decoded input booth collision; not Roblox Humanoid/PathfindingService playtesting.'}
(Path(args.report) if args.report else OUT/'LobbyV15.validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));assert not errors,errors
