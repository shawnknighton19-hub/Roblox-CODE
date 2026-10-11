"""Exercise V13's real transaction against a source-exact V12 instance fixture."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from assemble import ROOT, REPO, SOURCES, PRESERVED, literal, payload, compiler


def main():
    output=Path(os.environ.get('V13_TEST_OUTPUT', str(Path(tempfile.gettempdir())/'huss-v13-installer-tests')))
    output.mkdir(parents=True,exist_ok=True)
    prefix=(ROOT.parent/'v12/mock_prefix.luau').read_text()
    prefix+='\nlocal ColorSequence={new=function(a,b) return {_kind="ColorSequence",A=a,B=b or a} end}\n'
    manifest=json.loads((ROOT.parent/'v12/fixtures/manifest.json').read_text())
    prefix+='\nlocal dependencyFixture={\n'+''.join('{path='+literal(e['path'])+',class='+literal(e['class'])+',source='+literal((ROOT.parent/'v12/fixtures'/e['file']).read_text())+',disabled='+('true' if e['disabled'] else 'false')+'},\n' for e in manifest)+'}\n'
    prefix+='\nlocal source={\n'+''.join('[ '+literal(k)+' ]='+literal(p.read_text())+',\n' for k,p in SOURCES.items())+'}\n'
    prefix+='\nlocal preserved={\n'+''.join('[ '+literal(k)+' ]='+literal(p.read_text())+',\n' for k,p in PRESERVED.items())+'}\n'
    prefix+='\nlocal oldAnimate='+literal((ROOT/'fixtures/Animate-uploaded.luau').read_text())+'\n'
    prefix+='\nlocal v5Animate='+literal((ROOT/'fixtures/Animate-V5.luau').read_text())+'\n'
    case=(ROOT/'tests/installer_cases.luau.in').read_text().replace('__SHOP_BUILDER__',(REPO/'ShopStandsV12.luau').read_text()).replace('__INSTALLER__',payload())
    target=output/'installer-cases.luau';target.write_text(prefix+case)
    runner=os.environ.get('LUAU') or shutil.which('luau') or '/workspace/.cloud-tools/bin/luau'
    result=subprocess.run([runner,str(target)],text=True,capture_output=True)
    (output/'installer-cases.output').write_text(result.stdout+result.stderr)
    if result.returncode: raise SystemExit(result.stdout[-3000:]+result.stderr)
    report=json.loads(next(line.split(' ',1)[1] for line in result.stdout.splitlines() if line.startswith('INSTALL_REPORT ')))
    for path in set(SOURCES.values()) | set(PRESERVED.values()):
        subprocess.run([compiler(),'--binary',str(path)],stdout=subprocess.DEVNULL,check=True)
    report['compiled_component_files']=len(set(SOURCES.values()) | set(PRESERVED.values()))
    report['scope']='Actual V13 payload, source-exact V12 scripts, real shop validation, deterministic Instance transaction fixture. Native Studio runtime/rendering not simulated.'
    report['installer_sha256']=hashlib.sha256(payload().encode()).hexdigest()
    (REPO/'Install-R6-Trails-V13.validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='results'}))


if __name__=='__main__': main()
