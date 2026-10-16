"""Analytic no-jump arena checks against exported, executed builder geometry.

This reconstructs solid wedges/boxes/ellipsoids/cylinders. It verifies grounded
R6-sized clearance and connected spawn/ramp/deck routes on a 2-stud lattice. It
does not claim to simulate Roblox Humanoid physics, latency or live bot AI.
"""
from pathlib import Path
import argparse,collections,hashlib,json,math,sys
import numpy as np
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[2]
sys.path.insert(0,str(REPO/'tools/v15/lobby'))
from geometry import parts,vec,walk as hierarchy

def vertical(p,x,z,top=90,bottom=-10):
 """Vectorized exact vertical ray/solid entry; NaN means no intersection."""
 o=np.stack((x-p.pos[0],np.full_like(x,top-p.pos[1]),z-p.pos[2]),axis=-1)@p.rot
 d=np.array([0.,-1.,0.])@p.rot
 lo=np.zeros_like(x);hi=np.full_like(x,top-bottom)
 if p.kind in ('Ball','Cylinder'):
  if p.kind=='Cylinder':
   if abs(d[0])<1e-10:hi=np.where(abs(o[...,0])<=p.half[0]+1e-7,hi,-1)
   else:
    a=(-p.half[0]-o[...,0])/d[0];b=(p.half[0]-o[...,0])/d[0]
    lo=np.maximum(lo,np.minimum(a,b));hi=np.minimum(hi,np.maximum(a,b))
   oo=o[...,1:]/p.half[1:];dd=d[1:]/p.half[1:]
  else:oo=o/p.half;dd=d/p.half
  a=dd@dd;b=2*np.sum(oo*dd,axis=-1);c=np.sum(oo*oo,axis=-1)-1
  if a<1e-12:hi=np.where(c<=1e-7,hi,-1)
  else:
   disc=b*b-4*a*c;root=np.sqrt(np.maximum(0,disc));lo=np.maximum(lo,(-b-root)/(2*a));hi=np.minimum(hi,(-b+root)/(2*a));hi=np.where(disc>=0,hi,-1)
 else:
  for normal,distance in p.planes():
   denominator=normal@d;numerator=distance-o@normal
   if abs(denominator)<1e-10:hi=np.where(numerator>=-1e-7,hi,-1)
   elif denominator<0:lo=np.maximum(lo,numerator/denominator)
   else:hi=np.minimum(hi,numerator/denominator)
 return np.where((lo<=hi+1e-7)&(hi>=0)&(lo<=top-bottom),top-lo,np.nan)

def inspect(model):
 name=model['props']['Name'];a=model['attributes'];ps=parts(model);solids=[p for p in ps if p.collide]
 assert len(ps)==a['BasePartCount']<=400,(name,'part budget')
 assert all(p.props.get('Anchored') for p in ps),(name,'unanchored')
 assert all(node['class'] in {'Model','Folder','Part','WedgePart','SurfaceGui','Frame','TextLabel'} for node,_ in hierarchy(model)),(name,'unexpected active code or imported visual effect')
 assert not any(p.props.get('Material',{}).get('Name')=='Neon' for p in ps),(name,'unnecessary glow')
 floor=next(n for n in model['children'] if n['props']['Name']=='Floor');assert floor['class']=='Part'
 assert abs(floor['props']['CFrame']['p']['Y']+floor['props']['Size']['Y']/2)<1e-7
 spawnfolder=next(n for n in model['children'] if n['props']['Name']=='Spawns')
 spawns=[vec(n['props']['CFrame']['p']) for n in spawnfolder['children']]
 assert len(spawns)==16 and len({n['props']['Name'] for n in spawnfolder['children']})==16
 assert all(not n['props']['CanCollide'] and n['props']['Transparency']==1 for n in spawnfolder['children'])
 assert min(np.linalg.norm(x[[0,2]]-z[[0,2]]) for i,x in enumerate(spawns) for z in spawns[i+1:])>=13-1e-7
 ramps=[p for p in ps if p.attrs.get('HABRampV16')]
 assert len(ramps)==2
 for p in ramps:
  assert p.attrs['Width']>=22 and p.attrs['Run']>=p.attrs['Rise']*4
  start,end=vec(p.attrs['Start']),vec(p.attrs['End'])
  for t in np.linspace(.01,.99,31):
   q=start+(end-start)*t;hit=vertical(p,np.array([q[0]]),np.array([q[2]]))[0]
   assert abs(hit-q[1])<1e-5,(name,'reversed or discontinuous ramp',t,hit,q[1])
 # Includes only intended walkable tops; collision-cover rooftops aren't routes.
 walk=[p for p in solids if p.attrs.get('HABGroundV16') or p.attrs.get('HABWalkableV16') or p.attrs.get('HABRampV16')]
 # Check the exact authored spawn centers, not only their nearest grid cell.
 sx=np.array([q[0] for q in spawns]);sz=np.array([q[2] for q in spawns])
 for dx,dz in [(0,0),(2,0),(-2,0),(0,2),(0,-2),(1.42,1.42),(-1.42,1.42),(1.42,-1.42),(-1.42,-1.42)]:
  ground=np.full(16,-np.inf)
  for p in walk:ground=np.maximum(ground,np.nan_to_num(vertical(p,sx+dx,sz+dz),nan=-np.inf))
  assert np.all(np.abs(ground)<.01),(name,'spawn lacks level continuous floor')
  for p in solids:
   if p.attrs.get('HABGroundV16'):continue
   top=vertical(p,sx+dx,sz+dz)
   assert not np.any(np.isfinite(top)&(top>.8)&(p.minimum[1]<5.5)),(name,'exact spawn overlaps solid',p.name)
 # The first render found coplanar lower shells and crossing road paint. Keep
 # these real visual regressions checked on the exported authoring geometry.
 roads=[p for p in ps if p.name=='Flush route surface']
 assert len({round(p.pos[1]+p.size[1]/2,5) for p in roads})==len(roads),(name,'coplanar road paint')
 assert all(p.maximum[1]<-.1 for p in ps if p.name=='Bold foundation'),(name,'floor shell z-fighting')
 groundparts=[p for p in solids if p.attrs.get('HABGroundV16')]
 for road in roads:
  rx=np.array([road.pos[0]+dx*road.size[0]/2 for dx in (-1,0,1) for dz in (-1,0,1)])
  rz=np.array([road.pos[2]+dz*road.size[2]/2 for dx in (-1,0,1) for dz in (-1,0,1)])
  grounded=np.full(9,-np.inf)
  for p in groundparts:grounded=np.maximum(grounded,np.nan_to_num(vertical(p,rx,rz),nan=-np.inf))
  assert np.all(np.isfinite(grounded)),(name,'paint floats outside floor footprint')
 x=np.arange(-a['MapWidth']/2,a['MapWidth']/2+.1,2.0);z=np.arange(-a['MapDepth']/2,a['MapDepth']/2+.1,2.0)
 X,Z=np.meshgrid(x,z);heights=np.full(X.shape,-np.inf)
 for p in walk:heights=np.maximum(heights,np.nan_to_num(vertical(p,X,Z),nan=-np.inf))
 valid=np.isfinite(heights);heights=np.where(valid,heights,-10)
 # Full-height clearance at center and a 2-stud-radius footprint. Supporting
 # slopes may rise <0.5stud across the footprint; the body begins0.8stud above.
 for dx,dz in [(0,0),(2,0),(-2,0),(0,2),(0,-2),(1.42,1.42),(-1.42,1.42),(1.42,-1.42),(-1.42,-1.42)]:
  support=np.full(X.shape,-np.inf)
  for p in walk:support=np.maximum(support,np.nan_to_num(vertical(p,X+dx,Z+dz),nan=-np.inf))
  valid&=np.isfinite(support)&(np.abs(support-heights)<.8)
  for p in solids:
   if p.attrs.get('HABGroundV16'):continue
   top=vertical(p,X+dx,Z+dz)
   # vertical intersection through body, using per-cell translated rays.
   # For these authored solids only walkable ramps/decks intersect below feet;
   # all other colliders begin at or below the body and are fully blocked.
   if p.attrs.get('HABRampV16') or p.attrs.get('HABWalkableV16'):
    valid&=~(np.isfinite(top)&(top>heights+.8))
   else:valid&=~(np.isfinite(top)&(top>heights+.8)&(p.minimum[1]<heights+5.5))
 def cell(q):
  ix=int(round((q[0]-x[0])/2));iz=int(round((q[2]-z[0])/2));return iz,ix
 spawncells=[cell(q) for q in spawns]
 assert all(valid[c] for c in spawncells),(name,'spawn clearance',[(i+1,c) for i,c in enumerate(spawncells) if not valid[c]])
 start=spawncells[0];seen={start};queue=collections.deque([start]);routes={start:None}
 while queue:
  zz,xx=queue.popleft()
  for dz,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
   c=zz+dz,xx+dx
   if 0<=c[0]<len(z) and 0<=c[1]<len(x) and c not in seen and valid[c] and abs(heights[c]-heights[zz,xx])<=.65:
    seen.add(c);routes[c]=(zz,xx);queue.append(c)
 assert all(c in seen for c in spawncells),(name,'disconnected spawn',[i+1 for i,c in enumerate(spawncells) if c not in seen])
 deck=cell(vec(a['DeckCenter']));assert deck in seen,(name,'deck unreachable',deck)
 for p in ramps:
  for attr in ['Start','End']:
   c=cell(vec(p.attrs[attr]));assert c in seen,(name,'ramp endpoint unreachable',attr,c)
 # Both ramps must independently allow entry from the spawn-connected ground.
 # Remove one ramp's footprint and require the deck accessible via the other.
 independent=[]
 for blocked in ramps:
  blockedcells=np.isfinite(vertical(blocked,X,Z));vv=valid&~blockedcells
  seen2={start};queue=collections.deque([start])
  while queue:
   zz,xx=queue.popleft()
   for dz,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
    c=zz+dz,xx+dx
    if 0<=c[0]<len(z) and 0<=c[1]<len(x) and c not in seen2 and vv[c] and abs(heights[c]-heights[zz,xx])<=.65:seen2.add(c);queue.append(c)
  assert deck in seen2,(name,'only one functional ramp',blocked.attrs['Start'])
  independent.append(True)
 reachable=sum(1 for c in seen if heights[c]<.5)
 return {'name':name,'parts':len(ps),'size':[a['MapWidth'],a['MapDepth']],'spawns':16,'spawnPairChecks':120,'ramps':2,'rampSampleChecks':62,'rampWidths':[p.attrs['Width'] for p in ramps],'maximumRampDegrees':round(max(math.degrees(math.atan(p.attrs['Rise']/p.attrs['Run'])) for p in ramps),2),'connectedWalkableCells':len(seen),'groundedRouteAreaApprox':reachable*4,'independentDeckEntrances':2,'gridStuds':2,'avatarClearanceRadius':2,'limitations':'Analytic authored geometry only; Roblox Studio playtest still required.'}

def run(source,out):
 doc=json.loads(Path(source).read_text());folders={n['props']['Name']:n for n in doc['instances']}
 assert set(folders)=={'MapLibrary','BombTagV6Previews','BombTagPreviewGalleryV5','Maps'}
 assert all(n['attributes']['HABWorldVersion']==16 for n in folders.values())
 models=folders['MapLibrary']['children'];assert len(models)==15
 results=[]
 for m in models:
  result=inspect(m);results.append(result);print('PASS',result['name'],result['parts'],'parts',result['connectedWalkableCells'],'connected cells',flush=True)
 assert {n['props']['Name'] for n in models}=={n['props']['Name'] for n in folders['BombTagV6Previews']['children']}
 active=folders['Maps']['children'][0];assert active['props']['Name']=='Sky Garden' and active['attributes']['DisplayName']=='Sunset Docks'
 floor=next(n for n in active['children'] if n['props']['Name']=='Floor');assert np.allclose(vec(floor['props']['CFrame']['p'])+np.array([0,2,0]),[0,-27,-190])
 report={'geometryRawSHA256':hashlib.sha256(Path(source).read_bytes()).hexdigest(),'maps':results,'mapCount':15,'allSpawnPairsConnected':1800,'allRampsIndependentlyReachable':30,'rampHeightSamples':930,'geometryOnly':True}
 Path(out).write_text(json.dumps(report,indent=2)+'\n');return report
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('--out',default=str(HERE/'route-validation.json'));a=p.parse_args();run(a.source,a.out)
