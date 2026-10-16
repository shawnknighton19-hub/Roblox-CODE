#!/usr/bin/env python3
"""Run both production pose owners, in both callback registration orders."""
from pathlib import Path
import subprocess,tempfile,re,json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
FILES=['HABActionAnimationsV16.luau','HABActionClientV16.client.luau','HABWeaveAnimationsV16.luau','DodgeWeaveV16.client.luau']
REG=r'''
reset(owner)
local c=owner.Character;local root=c.HumanoidRootPart
local world=root.CFrame;local speed=root.AssemblyLinearVelocity
c:SetAttribute('MovementAction','DiveLeft');c:SetAttribute('MovementActionId',100)
check(c:GetAttribute('HABWeavePoseUntil')>clock,'actualweavestart')
tick(.08)
local ws=weaveExports.active[owner]
check(ws.started~=nil,'weaverenders')
exports.Pose(owner,clock,'Swing',45)
check(not exports.Poses[c],'predictiondoesnotoverwriteweave')
X.FX.OnClientEvent:Fire({Kind='Swing',Actor=owner,Id=601,Request=45,Time=clock,Duration=.48})
check(exports.Poses[c]~=nil,'acceptedattackstarts')
tick(.04)
check(ws.started==nil and c:GetAttribute('HABWeavePoseUntil')==nil,'acceptedattackcancelsolderactualweave')
check(exports.Poses[c]~=nil,'attackpersistsafteractualweaveclearsmarkers')
for _,j in ipairs(ws.joints) do check(j.base==nil and j.applied==nil,'oldweaveownercleans') end
local attackAt=clock
c:SetAttribute('MovementAction','DiveRight');c:SetAttribute('MovementActionId',101)
tick(.04)
check(ws.started~=nil,'newweaverenders')
check(exports.Poses[c]==nil and c:GetAttribute('HABActionPoseUntil')==nil,'newweavecancelspreviousacceptedattack')
check(root.CFrame==world and root.AssemblyLinearVelocity==speed,'bothposeownerspreservephysics')
c:SetAttribute('MovementAction','DiveEnd');c:SetAttribute('MovementActionId',102)
services.RunService.PreAnimation:Fire()
check(ws.started==nil and c:GetAttribute('HABWeavePoseUntil')==nil,'diveendclears')
for _,j in ipairs(c:GetDescendants()) do if j:IsA('Motor6D') then check(nearCF(j.Transform,CFrame.identity),'jointreturnsneutral') end end
-- Remote actor uses the original DodgeIFrameRequest protocol, without server edits.
reset(observer)
event.OnClientEvent:Fire(observer,'DiveForward',clock)
tick(.05)
check(weaveExports.active[observer].started~=nil,'originalremoteweaveevent')
X.FX.OnClientEvent:Fire({Kind='Ability',Actor=observer,Character=observer.Character,Ability='Shield',Mechanic='Shield',Id=602,Request=46,Time=clock,Duration=1})
tick(.04)
check(weaveExports.active[observer].started==nil,'remoteacceptedabilitywinsolderweave')
check(exports.Poses[observer.Character] and exports.Poses[observer.Character].Name=='Shield','remoteabilityvisible')
script.Destroying:Fire()
check(not exports.Poses[observer.Character] and next(weaveExports.active)==nil,'bothownersshutdown')
print('V16 pose integration: '..assertions..' assertions passed')
'''
def main():
    prefix=(ROOT/'tools/v12/tests/panic_fixture.luau.in').read_text().split('local panicExports')[0]
    prefix+='\nfunction methods:GetPropertyChangedSignal(key) return self:GetAttributeChangedSignal("property:"..key) end\n'
    fixture=(HERE/'fixture.luau.in').read_text()
    for key,name in [('ANIMATION',FILES[0]),('CLIENT',FILES[1])]:fixture=fixture.replace('{{'+key+'}}',(ROOT/name).read_text())
    fixture=fixture.replace('{{REGRESSIONS}}',REG)
    weave='\nlocal WeaveAnimation=(function()\n'+(ROOT/FILES[2]).read_text()+'\nend)()\nlocal weaveExports\ndo\n'+(ROOT/FILES[3]).read_text()+'\nweaveExports={active=active}\nend\n'
    # The require closure resolves the installed module name, not a new boot script.
    fixture=fixture.replace("local require=function(m)","local WeaveAnimation\nlocal weaveObject=Instance.new('ModuleScript',services.ReplicatedStorage);weaveObject.Name='HABWeaveAnimationsV16'\nlocal require=function(m)\n if m.Name=='HABWeaveAnimationsV16' then return WeaveAnimation end")
    weave=weave.replace('local WeaveAnimation=(function()','WeaveAnimation=(function()')
    counts=[]
    for order in ['weave_first','action_first']:
        f=fixture
        at=f.index('local exports') if order=='weave_first' else f.index('local assertions=0')
        f=f[:at]+weave+f[at:]
        with tempfile.TemporaryDirectory(prefix='hab-v16-owner-') as d:
            p=Path(d)/'test.luau';p.write_text(prefix+f)
            proc=subprocess.run(['/workspace/.cloud-tools/bin/luau',str(p)],capture_output=True,text=True)
            print(order+': '+proc.stdout,end='');print(proc.stderr,end='')
            if proc.returncode:raise SystemExit(proc.returncode)
            counts.append(int(re.search(r'integration: (\d+)',proc.stdout).group(1)))
    report={'passed':True,'assertions':sum(counts),'run_command':'python tools/v16/animation-tests/test_weave_integration.py','callback_orders':['weave_first','action_first'],'checks':['Both production pose owners execute against original movement attribute and remote protocol.','Local prediction yields weave; newer accepted strike/ability cancels weave pose without physics change.','New weave interrupts older accepted action; all owned transforms and markers restore.','Remote-actor ability interaction and complete cleanup.'],'limitations':'Offline math/signal adapter, not native Animator/replication.','sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in FILES}}
    (ROOT/'ActionWeaveIntegrationV16.validation.json').write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':main()
