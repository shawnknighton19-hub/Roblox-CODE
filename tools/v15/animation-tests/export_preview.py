#!/usr/bin/env python3
"""Export actual procedural poses as canonical R6 geometry, then render an offline contact sheet/GIF."""
from pathlib import Path
import subprocess,tempfile,json
ROOT=Path(__file__).resolve().parents[3]
prefix=(ROOT/'tools/v12/tests/panic_fixture.luau.in').read_text().split('local panicExports')[0]
code=prefix+'\nlocal A=(function()\n'+(ROOT/'HABActionAnimationsV15.luau').read_text()+'\nend)()\n'+r'''
local kinds={'Swing','Hammer','Throw','Hit','Block','Shield','Leap','Speed','Decoy','Jester','Bubble','Pogo','Disco','Confetti'}
local output={}
for _,kind in ipairs(kinds) do
 local p=makePlayer(kind,false);local c=p.Character;local joints={}
 c.HumanoidRootPart.CFrame=CFrame.new(0,3,0)
 for _,j in ipairs(c:GetDescendants()) do if j:IsA('Motor6D') then joints[#joints+1]=j end end
 local frames={}
 for i=0,39 do
  local age=i*.04;local sample=A.Sample(kind,age,kind=='Swing' or kind=='Hammer' and {Contact=.055} or {})
  -- Explicit options avoid boolean truthiness when the clip is Swing.
  if kind=='Swing' or kind=='Hammer' then sample=A.Sample(kind,age,{Contact=.055,Duration=.48}) end
  if kind=='Throw' then sample=A.Sample(kind,age,{Contact=.06}) end
  for _,j in ipairs(joints) do
   local info=A.JointInfo(j);j.Transform=CFrame.identity
   if sample and info then
    local target=info.Axes:Inverse()*A.Transform(sample,info.Role,false)*info.Axes
    j.Transform=CFrame.identity:Lerp(target,A.Weight(sample,info.Role,false,false))
   end
  end
  for _=1,8 do for _,j in ipairs(joints) do j.Part1.CFrame=j.Part0.CFrame*j.C0*j.Transform*j.C1:Inverse() end end
  local parts={}
  for _,part in ipairs(c:GetChildren()) do if part:IsA('BasePart') and part.Name~='HumanoidRootPart' then
   parts[#parts+1]={Name=part.Name,Size={part.Size.X,part.Size.Y,part.Size.Z},CFrame={part.CFrame:GetComponents()}}
  end end
  frames[#frames+1]={Age=age,Parts=parts}
 end
 output[#output+1]={Name=kind,Duration=A.Clips[kind].Duration,Frames=frames}
end
print('POSE_JSON:'..json(output))
'''
code=code.replace("local sample=A.Sample(kind,age,kind=='Swing' or kind=='Hammer' and {Contact=.055} or {})", "local sample=A.Sample(kind,age,{})")
with tempfile.TemporaryDirectory(prefix='hab-poses-') as d:
 p=Path(d)/'export.luau';p.write_text(code)
 proc=subprocess.run(['/workspace/.cloud-tools/bin/luau',str(p)],check=True,capture_output=True,text=True)
 data=json.loads(proc.stdout.split('POSE_JSON:')[1])
(ROOT/'tools/v15/animation-tests/pose-preview.json').write_text(json.dumps(data,separators=(',',':')))
print('Exported',len(data),'clips / 40 samples each from actual animation module.')
