#!/usr/bin/env python3
"""Offline block-rig pose preview; not a Roblox engine screenshot."""
from pathlib import Path
import json,numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[3]
data=json.loads((ROOT/'tools/v16/animation-tests/pose-preview.json').read_text())
fontdir=Path('/usr/share/fonts/truetype/dejavu')
f=ImageFont.truetype(str(fontdir/'DejaVuSans.ttf'),14);b=ImageFont.truetype(str(fontdir/'DejaVuSans-Bold.ttf'),18)
cam=np.array([8,4,-14.]);forward=-cam/np.linalg.norm(cam);right=np.cross(forward,[0,1,0]);right/=np.linalg.norm(right);up=np.cross(right,forward)
verts=np.array([[-1,-1,-1],[-1,-1,1],[-1,1,-1],[-1,1,1],[1,-1,-1],[1,-1,1],[1,1,-1],[1,1,1]])
faces=[[0,4,6,2],[1,3,7,5],[0,1,5,4],[2,6,7,3],[0,2,3,1],[4,5,7,6]]
labels={'Swing':'RIGHT HOOK','Hammer':'OVERHAND','Throw':'THROW','Hit':'HIT RECOIL','Block':'PARRY','Shield':'PHASE GUARD','Leap':'SKYVAULT','Speed':'OVERDRIVE','Decoy':'PARTY DOUBLE','Jester':'JESTER SPIN','Bubble':'SOAP SPRINT','Pogo':'POGO POP','Disco':'DISCO DOUBLE','Confetti':'CONFETTI CANNON'}
def draw(frame_number):
 im=Image.new('RGB',(1040,1170),(14,21,33));d=ImageDraw.Draw(im)
 d.text((18,14),'HUSS-A-BOMB  /  V16 ACTION POSES',font=b,fill=(253,210,92))
 d.text((18,40),'Actual R6 poses, with grounded stance alignment. Offline preview; 1.6x slow motion.',font=f,fill=(165,184,208))
 for i,clip in enumerate(data):
  x=(i%4)*260;y=(i//4)*270+68
  d.rounded_rectangle((x+5,y+2,x+255,y+265),radius=16,fill=(24,36,53),outline=(44,68,88),width=2)
  d.text((x+15,y+13),labels[clip['Name']],font=b,fill=(127,231,243))
  origin=np.array([x+131,y+164]);polys=[]
  d.ellipse((x+65,y+233,x+201,y+248),fill=(11,19,31))
  highlight=[2,1,2,1,2,4,4,3,6,11,5,5,8,6]
  sample=clip['Frames'][highlight[i] if frame_number is None else frame_number]
  def project(v):return tuple(origin+np.array([v@right,-(v-np.array([0,2.6,0]))@up])*28)
  for part in sample['Parts']:
   cf=np.array(part['CFrame']);pos=cf[:3];rot=cf[3:].reshape(3,3)
   points=(rot@(verts*np.array(part['Size'])/2).T).T+pos
   color=(255,147,58) if part['Name']=='Torso' else (255,211,147) if part['Name']=='Head' else (245,177,99) if 'Arm' in part['Name'] else (49,101,149)
   for j,face in enumerate(faces):
    q=points[face];shade=[.68,.84,.75,1,.9,.72][j];polys.append((np.mean(q@forward),[project(v) for v in q],tuple(int(c*shade) for c in color)))
   if part['Name']=='Head':
    # Two small neutral eyes only identify the facing direction in the block rig.
    for ex in [-.28,.28]:
     pointsEye=np.array([rot@np.array([ex+dx,dy,-.508])+pos for dx,dy in [(-.05,-.04),(-.05,.08),(.05,.08),(.05,-.04)]])
     polys.append((np.mean(pointsEye@forward)-.015,[project(v) for v in pointsEye],(29,36,49)))
  for _,xy,c in sorted(polys,reverse=True):d.polygon(xy,fill=c,outline=(14,23,36))
  d.text((x+15,y+244),f"{sample['Age']:.2f}s / {clip['Duration']:.2f}s",font=f,fill=(163,182,207))
 d.text((18,1150),'Cosmetic pose only: camera, facing, collision, velocity and cooldowns remain controlled by gameplay.',font=f,fill=(159,180,204))
 return im
frames=[draw(i) for i in range(40)]
draw(None).save(ROOT/'ActionAnimationsV16-Poses.png')
frames[0].save(ROOT/'ActionAnimationsV16-Preview.gif',save_all=True,append_images=frames[1:]+[frames[-1]]*10,duration=65,loop=0,optimize=True)
print('Rendered V16 contact sheet and slow-motion pose GIF.')
