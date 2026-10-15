#!/usr/bin/env python3
"""Execute actual V15 clips/client/native effects against deterministic Roblox math/signals."""
from pathlib import Path
import hashlib,json,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
FILES=['HABActionAnimationsV15.luau','HABAbilityEffectsV15.luau','HABActionClientV15.client.luau','CarrierPanicV15.client.luau']
def main():
    compiler='/workspace/.cloud-tools/bin/luau-compile';luau='/workspace/.cloud-tools/bin/luau'
    for n in FILES:subprocess.run([compiler,str(ROOT/n)],check=True,stdout=subprocess.DEVNULL)
    prefix=(ROOT/'tools/v12/tests/panic_fixture.luau.in').read_text().split('local panicExports')[0]
    body=(HERE/'fixture.luau.in').read_text()
    for key,name in zip(['ANIMATION','FX','CLIENT','PANIC'],FILES):body=body.replace('{{'+key+'}}',(ROOT/name).read_text())
    body=body.replace('{{REGRESSIONS}}',(HERE/'regressions.luau').read_text())
    with tempfile.TemporaryDirectory(prefix='hab-action-v15-') as d:
        p=Path(d)/'suite.luau';p.write_text(prefix+body)
        proc=subprocess.run([luau,str(p)],capture_output=True,text=True)
        print(proc.stdout,end='');print(proc.stderr,end='')
        if proc.returncode:raise SystemExit(proc.returncode)
        m=re.search(r'V15 actions: (\d+) assertions passed',proc.stdout);assert m
        report={'passed':True,'assertions':int(m.group(1)),'run_command':'python tools/v15/animation-tests/test_actions.py','checks':['Actual clip finite transforms, neutral entry/recovery, all9ability signatures, mirrored strikes, authoritativecontact timing.','Actual actionclient prediction/rejection, hits/blocks, dodge priority, panic ownership, freshAnimatorbaseline, ragdoll, respawn, destruction.','All9nativeability effects, sanitized decoys, partgroupcaps, ReducedMotion, shutdown and zero-perframe allocations.','R6 canonical rotated joints and R15Motor6D/AnimationConstraint role coverage.'],'limitations':'Offline deterministic Roblox API/math/signals adapter. Native Studio rendering, server/client replication, and uploaded asset permissions still require Studio playtest.','sha256':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in FILES}}
        (ROOT/'ActionsV15.validation.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
