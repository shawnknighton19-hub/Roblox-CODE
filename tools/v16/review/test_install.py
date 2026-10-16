"""Execute complete V16 installer with source-exact, original-HABWAS transaction fixtures.
Only newly generated inert syntax wrappers are required. No gameplay body runs here;
separate test_boot.py executes actual game startup/round bodies.
"""
from pathlib import Path
import hashlib,json,os,subprocess,sys,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/'tools/v16'))
from assemble import payload,records,lua
from original_fixture import load

def main():
 installer=payload()
 prefix=(ROOT/'tools/v12/mock_prefix.luau').read_text()
 prefix+='\nlocal ColorSequence={new=function(a,b)return {_kind="ColorSequence",A=a,B=b or a}end}\n'
 prefix+='local originalRows='+lua(load())+'\nlocal expectedEntries='+lua(records())+'\n'
 script=prefix+(HERE/'installer_cases.luau.in').read_text().replace('__INSTALLER__',installer)
 with tempfile.TemporaryDirectory(prefix='hab-v16-install-')as temp:
  path=Path(temp)/'cases.luau';path.write_text(script)
  result=subprocess.run(['/workspace/.cloud-tools/bin/luau',str(path)],capture_output=True,text=True,timeout=180)
  if result.returncode:
   Path('/tmp/hab-v16-installer-failed.luau').write_text(script)
   raise SystemExit(result.stdout[-4000:]+result.stderr[-7000:])
 report=json.loads(next(x[len('INSTALL_REPORT '):]for x in result.stdout.splitlines()if x.startswith('INSTALL_REPORT ')))
 report['installer_sha256']=hashlib.sha256(installer.encode()).hexdigest()
 report['source_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'tools/v16/world_installer.luau',ROOT/'tools/v16/installer_tail.luau',ROOT/'LobbyBuilderV16.luau',ROOT/'MapBuilderV16.luau']}
 report['original_place_sha256']=hashlib.sha256((ROOT/'HABWAS.rbxl').read_bytes()).hexdigest()
 report['native_studio_tested']=False
 report['scope']='Exact complete installer with original 179 sources, original parent graph and complete 1576-object original lobby fixture; deterministic Instance/service adapter and inert syntax wrappers. No native Studio execution claim.'
 (ROOT/'InstallerV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
 print('Installer transactions passed: '+str(len(report['scenarios']))+' scenarios')
if __name__=='__main__':main()
