"""Validate that the exact packaged game also satisfies the no-op installer contract."""
from pathlib import Path
import argparse,sys,hashlib,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/'tools/v16'))
from assemble import payload,records,lua
from original_fixture import load
p=argparse.ArgumentParser(description=__doc__);p.add_argument('place',type=Path);args=p.parse_args()
base=(ROOT/'tools/v12/mock_prefix.luau').read_text()
base+='\nlocal ColorSequence={new=function(a,b)return {_kind="ColorSequence",A=a,B=b or a}end}\n'
base+='local originalRows='+lua(load(args.place,full_maps=True))+'\nlocal expectedEntries='+lua(records())+'\n'
fixture=(HERE/'installer_cases.luau.in').read_text().split('-- CASES_INSERT')[0].replace('__INSTALLER__',payload())
case='''
currentMode='packagedRerun';requireCount=0;warnings={};fixture(currentMode)
local before=capture()
local ok,why=pcall(install);assert(ok,'Packaged game fails installer no-op contract: '..tostring(why))
checkSame(before,'Packaged no-op rerun')
assert(workspace:GetAttribute('HABPolishVersion')==16,'Version marker')
assert(not services.ServerStorage:FindFirstChild('HABPolishV16Preflight'),'Leaked staging')
print('PACKAGED_NOOP_PASSED')
'''
with tempfile.TemporaryDirectory(prefix='hab-v16-packaged-')as temp:
 path=Path(temp)/'packaged.luau';path.write_text(base+fixture+case)
 result=subprocess.run(['/workspace/.cloud-tools/bin/luau',str(path)],capture_output=True,text=True,timeout=90)
 if result.returncode:raise SystemExit(result.stdout[-3000:]+result.stderr[-5000:])
 assert 'PACKAGED_NOOP_PASSED'in result.stdout
report={'passed':True,'place_sha256':hashlib.sha256(args.place.read_bytes()).hexdigest(),'installer_sha256':hashlib.sha256(payload().encode()).hexdigest(),'native_studio_tested':False,'scope':'Independent binary-derived complete live map/lobby graph passes full installer no-op preflight and remains unchanged in transaction adapter.'}
(ROOT/'PackagedRerunV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('Packaged binary passes installer no-op compatibility contract')
