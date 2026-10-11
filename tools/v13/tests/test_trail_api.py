#!/usr/bin/env python3
"""Check actual trail writes against a small recorded Roblox API allowlist.

Uses deterministic Instance/math doubles; this is not a native Studio playtest.
The full upstream API dump is not required to reproduce the test.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile

root=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--luau',default=shutil.which('luau') or '/workspace/.cloud-tools/bin/luau')
parser.add_argument('--report',action='store_true')
args=parser.parse_args()
allowlist=json.loads((here/'trail_api_allowlist.json').read_text())
api,enums=allowlist['classes'],allowlist['enums']
def lua(x):
 if x is True:return 'true'
 if x is False:return 'false'
 if isinstance(x,str):return json.dumps(x)
 if isinstance(x,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in x.items())+'}'
 return str(x)
source=(root/'tools/v12/tests/skins_math_instance_fixture.luau').read_text()
source+='\nlocal realProperties='+lua(api)+'\nlocal realEnums='+lua({k:enums[k] for k in ['Material','PartType']})+'\n'
source+='''
local propertyWrites=0
local oldWrite=mt.__newindex
mt.__newindex=function(t,k,v)
 local properties=realProperties[t.ClassName]
 if properties then
  assert(properties[k],t.ClassName..'.'..k..' is not a real Roblox property')
  assert(not properties[k].readonly,t.ClassName..'.'..k..' is read-only')
  propertyWrites+=1
 end
 return oldWrite(t,k,v)
end
for group,values in pairs(realEnums) do
 Enum[group]=setmetatable({},{__index=function(t,name)
  assert(values[name],'Unknown Roblox Enum.'..group..'.'..name)
  local value={_kind='EnumItem',EnumType=group,Name=name};rawset(t,name,value);return value
 end})
end
local Builder=(function()
'''+(root/'TrailDesignsV13.luau').read_text()+'''
end)()
local Catalog=(function()
'''+(root/'HussCatalogV13.luau').read_text()+'''
end)()
local cases=0
for _,item in ipairs(Catalog.Items) do if item.category=='Trails' then
 local handle=assert(Builder.Create(workspace,item,{Preview=false}))
 handle:SetEnabled(true)
 for frameIndex=1,120 do
  handle:Step(CFrame.new(frameIndex*.55,4,0),Vector3.new(33,0,0),frameIndex/60,1/60)
 end
 handle:SetEnabled(false)
 for frameIndex=121,155 do handle:Step(CFrame.new(66,4,0),Vector3.zero,frameIndex/60,1/60) end
 handle:Destroy()
 local model=assert(Builder.Preview(workspace,item))
 assert(model:IsA('Model'));model:Destroy()
 cases+=1
end end
assert(cases==25)
print('STRICT_REAL_API_TRAILS '..cases..' designs / '..propertyWrites..' property writes passed')
'''
with tempfile.TemporaryDirectory(prefix='huss-trail-api-v13-') as directory:
 p=Path(directory)/'strict_builder_api.luau';p.write_text(source)
 r=subprocess.run([args.luau,str(p)],capture_output=True,text=True)
print(r.stdout,end='');print(r.stderr,end='')
if r.returncode: raise SystemExit(r.returncode)
if args.report:
 result=re.search(r'STRICT_REAL_API_TRAILS (\d+) designs / (\d+) property writes passed',r.stdout)
 assert result,'Missing strict API test result'
 report={'status':'passed','designs':int(result.group(1)),'property_writes_checked':int(result.group(2)),
 'sourceSha256':{n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in ['TrailDesignsV13.luau','HussCatalogV13.luau']},
 'api_provenance':allowlist['provenance'],
 'checks':['Actual builder execution for every catalog trail','120 moving frames and 35 stationary frames per trail','All preview models created and destroyed','Every Model, Part and WedgePart write names an existing writable API property','Material and PartType enum names verified against Roblox API metadata'],
 'limits':['Roblox-compatible math/Instance test doubles; native rendering, networking, replication and physics were not executed.','Property write count is repeated runtime coverage, not that many distinct behavior tests.']}
 (root/'TrailApiV13.validation.json').write_text(json.dumps(report,indent=2)+'\n')
