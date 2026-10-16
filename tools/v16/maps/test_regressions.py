"""Mutation checks proving the geometry checks reject broken map contracts."""
from pathlib import Path
import argparse,copy,hashlib,json
from check_routes import inspect

def walk(n):
 yield n
 for c in n.get('children',[]):yield from walk(c)
def run(path):
 doc=json.loads(Path(path).read_text());base=next(n for n in doc['instances'] if n['props']['Name']=='MapLibrary')['children'][0]
 cases=[]
 def reject(name,change,expected):
  m=copy.deepcopy(base);change(m)
  try:inspect(m)
  except AssertionError as exc:
   assert expected in str(exc),(name,'wrong failure',str(exc));cases.append({'case':name,'rejected':True,'reason':expected})
  else:raise AssertionError('Broken geometry was accepted: '+name)
 def ramps(m):return [n for n in walk(m) if n.get('attributes',{}).get('HABRampV16')]
 def flipped(m):
  p=ramps(m)[0]['props'];p['CFrame']['m']=[-v if i%3 in (0,2) else v for i,v in enumerate(p['CFrame']['m'])]
 reject('Ramp points downhill at deck connection',flipped,'reversed or discontinuous ramp')
 reject('One of two ramps has no collision',lambda m:ramps(m)[0]['props'].__setitem__('CanCollide',False),'ramp endpoint unreachable')
 def duplicate(m):
  f=next(n for n in m['children'] if n['props']['Name']=='Spawns');f['children'][1]['props']['CFrame']=copy.deepcopy(f['children'][0]['props']['CFrame'])
 # Pair spacing deliberately fails before a graph test can mask a duplicate.
 m=copy.deepcopy(base);duplicate(m)
 try:inspect(m)
 except AssertionError:cases.append({'case':'Duplicate spawn centers','rejected':True,'reason':'Minimum pair spacing'})
 else:raise AssertionError('Duplicate spawns accepted')
 def paint(m):
  roads=[n for n in walk(m) if n['props'].get('Name')=='Flush route surface'];roads[1]['props']['CFrame']['p']['Y']=roads[0]['props']['CFrame']['p']['Y']
 reject('Coplanar intersecting road paint',paint,'coplanar road paint')
 def shell(m):
  for n in walk(m):
   if n['props'].get('Name')=='Bold foundation':n['props']['CFrame']['p']['Y']+=.18
 reject('Ink shell overlaps top floor',shell,'floor shell z-fighting')
 return {'geometryRawSHA256':hashlib.sha256(Path(path).read_bytes()).hexdigest(),'rejectedBrokenFixtures':len(cases),'cases':cases}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('--out',required=True);a=p.parse_args();r=run(a.source);Path(a.out).write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
