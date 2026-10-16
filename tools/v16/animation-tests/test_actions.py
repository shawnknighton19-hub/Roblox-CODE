#!/usr/bin/env python3
"""Execute V16 action poses against the original HABWAS server packet contract."""
from pathlib import Path
import hashlib,json,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
FILES=['HABActionAnimationsV16.luau','HABActionClientV16.client.luau']
def main():
    luau='/workspace/.cloud-tools/bin/luau';compiler='/workspace/.cloud-tools/bin/luau-compile'
    for name in FILES:subprocess.run([compiler,str(ROOT/name)],check=True,stdout=subprocess.DEVNULL)
    original=(HERE/'original-action-client.luau').read_text();new=(ROOT/FILES[1]).read_text()
    # The existing game remains the source of truth for launch and speed behavior.
    for boundary in [('local function applyLocalAbility','link(X.FX.OnClientEvent'),('local function action(name,state)','link(me.CharacterRemoving')]:
        start,end=boundary
        assert original[original.index(start):original.index(end)]==new[new.index(start):new.index(end)],f'Original movement/input block changed: {start}'
    server=(HERE/'original-action-service.luau').read_text()
    assert "emit('ShieldBlock',candidate,{Position=b})" in server
    assert "emit('TagHit',carrier,{Id=a.Id,Request=a.Request,Target=p,Position=position})" in server
    assert 'HABModalV15' not in new and 'HABModalOwnerV15' not in new and 'HABAbilityEffectsV15' not in new
    assert 'Render.Play' not in new and "require(X:WaitForChild('HABActionAnimationsV16'))" in new
    prefix=(ROOT/'tools/v12/tests/panic_fixture.luau.in').read_text().split('local panicExports')[0]
    fixture=(HERE/'fixture.luau.in').read_text().replace('{{ANIMATION}}',(ROOT/FILES[0]).read_text()).replace('{{CLIENT}}',new).replace('{{REGRESSIONS}}',(HERE/'regressions.luau').read_text())
    with tempfile.TemporaryDirectory(prefix='hab-v16-actions-') as d:
        p=Path(d)/'suite.luau';p.write_text(prefix+fixture)
        proc=subprocess.run([luau,str(p)],capture_output=True,text=True)
        print(proc.stdout,end='');print(proc.stderr,end='')
        if proc.returncode:raise SystemExit(proc.returncode)
        match=re.search(r'V16 actions: (\d+) assertions passed',proc.stdout);assert match
    report={'passed':True,'assertions':int(match.group(1)),'run_command':'python tools/v16/animation-tests/test_actions.py','checks':['Original HABWAS input binding and approved local launch/speed blocks preserved byte-for-byte.','Original server Swing/Throw/TagHit/ShieldBlock/Ability packet compatibility; no new server fields or remotes.','15 authored variants; nine ability gestures with grounded leg stances and reduced-motion blending.','Canonical R6, R15 role mapping and public AnimationConstraint aliases; finite transforms and neutral recovery.','Predicted pose rejection, exact authoritative contact time, respawn/death cleanup, and ownership restoration.','Latest accepted action can interrupt older weave visuals; a new weave interrupts an older action without changing physics.'],'limitations':'Offline Luau execution with a Roblox math/signal adapter. Native Studio animation, network replication, and loaded custom locomotion assets require playtesting.','sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in FILES},'original_sha256':{name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in ['original-action-client.luau','original-action-service.luau']}}
    (ROOT/'ActionsV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
