#!/usr/bin/env python3
"""Render actual V16 client joint output as an offline R6 pose study, not a Studio screenshot."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from test_weave import ROOT,HERE,execute
EXPORT=r'''
local clips={}
for _,action in ipairs({'DiveForward','DiveBack','DiveLeft','DiveRight','DiveForwardLeft','DiveForwardRight','DiveBackLeft','DiveBackRight'}) do
 reset(owner);localAction(action)
 local frames={}
 for i=0,36 do
  tick(i==0 and 0 or .02)
  local state=exports.States[owner];local c=owner.Character
  -- Forward kinematics for export only: production never writes part CFrame.
  for _=1,7 do for _,j in ipairs(state.joints) do
   local m=j.motor;m.Part1.CFrame=m.Part0.CFrame*m.C0*m.Transform*m.C1:Inverse()
  end end
  local parts={}
  for _,part in ipairs(c:GetChildren()) do if part:IsA('BasePart') and part.Name~='HumanoidRootPart' then
   parts[#parts+1]={Name=part.Name,Size={part.Size.X,part.Size.Y,part.Size.Z},CFrame={part.CFrame:GetComponents()}}
  end end
  frames[#frames+1]={Age=i*.02,Parts=parts}
 end
 clips[#clips+1]={Name=action,Frames=frames}
end
print('PREVIEW_JSON:'..json(clips))
'''
def main():
    result=execute(EXPORT)
    if result.returncode:raise RuntimeError(result.stderr)
    data=json.loads(result.stdout.split('PREVIEW_JSON:')[1])
    (HERE/'pose-preview.json').write_text(json.dumps(data,separators=(',',':')))
    fontdir=Path('/usr/share/fonts/truetype/dejavu')
    normal=ImageFont.truetype(str(fontdir/'DejaVuSans.ttf'),16)
    small=ImageFont.truetype(str(fontdir/'DejaVuSans.ttf'),13)
    bold=ImageFont.truetype(str(fontdir/'DejaVuSans-Bold.ttf'),20)
    cam=np.array([8.,4,-14]);forward=-cam/np.linalg.norm(cam);right=np.cross(forward,[0,1,0]);right/=np.linalg.norm(right);up=np.cross(right,forward)
    verts=np.array([[-1,-1,-1],[-1,-1,1],[-1,1,-1],[-1,1,1],[1,-1,-1],[1,-1,1],[1,1,-1],[1,1,1]])
    faces=[[0,4,6,2],[1,3,7,5],[0,1,5,4],[2,6,7,3],[0,2,3,1],[4,5,7,6]]
    labels=['FORWARD SLIP','BRACED BACKSTEP','LEFT POWER STEP','RIGHT POWER STEP','FORWARD LEFT','FORWARD RIGHT','BACK LEFT','BACK RIGHT']
    def draw(index=None):
        im=Image.new('RGB',(1200,930),(15,21,32));d=ImageDraw.Draw(im)
        d.text((24,18),'HUSS-A-BOMB / DIRECTIONAL WEAVE',font=bold,fill=(255,209,84))
        d.text((24,48),'Actual V16 joint poses. Offline R6 study; existing movement adds the travel through the arena.',font=normal,fill=(163,188,212))
        d.text((24,72),'Duck > shoulder slip > planted reach > recovery.  Original 0.72s duration; no physics changes.',font=small,fill=(163,188,212))
        def rig(sample,x,y,scale=31):
            center=np.array([x+145,y+163]);polys=[]
            def project(v):return tuple(center+np.array([v@right,-(v-np.array([0,2.6,0]))@up])*scale)
            floor=np.array([[-2.5,0,-1.8],[2.5,0,-1.8],[2.5,0,1.8],[-2.5,0,1.8]])
            d.polygon([project(v) for v in floor],fill=(18,30,43))
            for part in sample['Parts']:
                cf=np.array(part['CFrame']);pos=cf[:3];rot=cf[3:].reshape(3,3)
                points=(rot@(verts*np.array(part['Size'])/2).T).T+pos
                color=(25,195,204) if part['Name']=='Torso' else (255,216,160) if part['Name']=='Head' else (244,177,100) if 'Arm' in part['Name'] else (55,105,155)
                for j,face in enumerate(faces):
                    q=points[face];shade=[.68,.84,.75,1,.9,.72][j]
                    polys.append((np.mean(q@forward),[project(v) for v in q],tuple(int(c*shade) for c in color)))
                if part['Name']=='Head':
                    for ex in [-.28,.28]:
                        pointsEye=np.array([rot@np.array([ex+dx,dy,-.508])+pos for dx,dy in [(-.05,-.04),(-.05,.08),(.05,.08),(.05,-.04)]])
                        polys.append((np.mean(pointsEye@forward)-.015,[project(v) for v in pointsEye],(29,36,49)))
            for _,xy,c in sorted(polys,reverse=True):d.polygon(xy,fill=c,outline=(14,23,36))
        for i,clip in enumerate(data):
            x=(i%4)*300;y=(i//4)*285+104
            d.rounded_rectangle((x+8,y,x+292,y+275),radius=15,fill=(26,39,55),outline=(50,73,93),width=2)
            d.text((x+20,y+16),labels[i],font=bold,fill=(123,236,226))
            sample=clip['Frames'][10 if index is None else index]
            rig(sample,x,y)
            d.text((x+20,y+248),f"{sample['Age']:.2f} / 0.72 seconds",font=small,fill=(166,187,207))
        d.text((24,690),'FORWARD SLIP / CHOREOGRAPHY',font=bold,fill=(255,209,84))
        for i,(name,frame) in enumerate([('LOAD',2),('DRIVE',7),('REACH',11),('PLANT',21),('RECOIL',26),('RELEASE',35)]):
            x=i*200;y=710
            rig(data[0]['Frames'][frame],x-45,y-25,24)
            d.text((x+20,905),name,font=small,fill=(163,188,212))
        return im
    draw().save(ROOT/'WeaveV16-Poses.png')
    frames=[draw(i) for i in range(37)]
    frames[0].save(ROOT/'WeaveV16-Preview.gif',save_all=True,append_images=frames[1:]+[frames[-1]]*10,duration=40,loop=0,optimize=True)
    print('Rendered exact V16 client poses: WeaveV16-Poses.png and WeaveV16-Preview.gif (half speed).')
if __name__=='__main__':main()
