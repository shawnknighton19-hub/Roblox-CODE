#!/usr/bin/env python3
"""Execute the actual V16 animation and lifecycle against original HABWAS protocols."""
from pathlib import Path
import hashlib,json,os,re,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
FILES=['HABWeaveAnimationsV16.luau','DodgeWeaveV16.client.luau']
def source(regressions):
    fixture=(HERE/'fixture.luau.in').read_text()
    return (HERE/'adapter.luau').read_text()+fixture.replace('{{MODULE}}',(ROOT/FILES[0]).read_text()).replace('{{CLIENT}}',(ROOT/FILES[1]).read_text()).replace('{{REGRESSIONS}}',regressions)
def execute(regressions):
    with tempfile.TemporaryDirectory(prefix='hab-v16-weave-') as tmp:
        script=Path(tmp)/'suite.luau';script.write_text(source(regressions))
        return subprocess.run([os.environ.get('LUAU','/workspace/.cloud-tools/bin/luau'),str(script)],capture_output=True,text=True)
def main():
    for name in FILES:
        subprocess.run([os.environ.get('LUAU_COMPILE','/workspace/.cloud-tools/bin/luau-compile'),str(ROOT/name)],check=True,stdout=subprocess.DEVNULL)
    client=(ROOT/FILES[1]).read_text();module=(ROOT/FILES[0]).read_text()
    for forbidden in ['AssemblyLinearVelocity=','WalkSpeed=','CFrame=','FireServer(', 'Instance.new(', 'AnimationId', 'ApplyImpulse(']:
        assert forbidden not in client+module, f'Unexpected gameplay/VFX/asset write: {forbidden}'
    original=(HERE/'original-weave.luau').read_text()
    assert 'local DURATION = .72' in original
    for protocol in ['MovementActionId','MovementAction','DiveEnd','DodgeIFrameRequest','HussDodgeV5']:
        assert protocol in original and protocol in client
    result=execute((HERE/'regressions.luau').read_text())
    print(result.stdout,end='');print(result.stderr,end='')
    if result.returncode: raise SystemExit(result.returncode)
    match=re.search(r'V16 weave: (\d+) assertions passed',result.stdout);assert match
    grounding=json.loads(result.stdout.split('GROUNDING_JSON:')[1].strip())
    report={'passed':True,'assertions':int(match.group(1)),'checks':['Eight distinct directional full-body clips and canonical connected R6/R15 skeletons.','Original .72-second animation window and local MovementActionId/remote DodgeIFrameRequest contract.','No movement, velocity, cooldown, collision, camera, asset loading or cosmetic VFX writes.','Foot-plane correction through joint transforms only; sampled grounding error recorded below.','Fresh Animator restoration, action/weave ownership, late replicated rigs, packet latency, death, pause, respawn and teardown.'], 'limitations':'Offline actual-source Luau with deterministic math and signal adapter. Roblox Animator evaluation order, visual polish with live movement and online replication still require Studio playtesting.', 'grounding':grounding,'sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in FILES},'original_sha256':hashlib.sha256((HERE/'original-weave.luau').read_bytes()).hexdigest()}
    (ROOT/'WeaveV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
