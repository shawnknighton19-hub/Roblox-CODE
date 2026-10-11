"""Render exported carrier pose geometry (requires Pillow and NumPy)."""
from pathlib import Path
import argparse
import json,numpy as np
from PIL import Image,ImageDraw,ImageFont
parser=argparse.ArgumentParser();parser.add_argument('pose_data',type=Path);parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[3]/'CarrierPanicV12-Poses.png');args=parser.parse_args()
data=json.loads(args.pose_data.read_text());W,H=1240,830;im=Image.new('RGB',(W,H),(17,24,39));d=ImageDraw.Draw(im)
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16);bold=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',20)
cam=np.array([8,5,-12]);forward=-cam/np.linalg.norm(cam);right=np.cross(forward,[0,1,0]);right=right/np.linalg.norm(right);up=np.cross(right,forward)
coords=np.array([[-1,-1,-1],[-1,-1,1],[-1,1,-1],[-1,1,1],[1,-1,-1],[1,-1,1],[1,1,-1],[1,1,1]])
faces=[[0,4,6,2],[1,3,7,5],[0,1,5,4],[2,6,7,3],[0,2,3,1],[4,5,7,6]]
d.text((20,16),'HUSS-A-BOMB  |  PANIC CARRIER',font=bold,fill=(255,200,65))
for i,s in enumerate(data):
 col=i%4;row=i//4;x=col*310;y=row*355+58;origin=np.array([x+156,y+185]);allfaces=[]
 d.rounded_rectangle((x+8,y+4,x+302,y+347),radius=15,fill=(24,35,53),outline=(42,62,81),width=2)
 d.text((x+22,y+20),s['Rig']+' PANIC RUN',font=bold,fill=(94,231,255));d.text((x+22,y+49),f"Run cycle {col+1}/4",font=f,fill=(179,192,215))
 d.ellipse((x+74,y+297,x+236,y+317),fill=(10,18,29))
 for p in s['Parts']:
  cf=np.array(p['CFrame']);pos=cf[:3];rot=cf[3:].reshape(3,3);size=np.array(p['Size'])
  pts=(rot@(coords*size/2).T).T+pos
  color=(244,133,46) if 'Torso' in p['Name'] else (253,212,148) if p['Name']=='Head' or 'Hand' in p['Name'] else (255,160,63) if 'Arm' in p['Name'] else (89,218,251) if p['Name']=='Tear' else (46,77,105)
  for j,face in enumerate(faces):
   q=pts[face];xy=[tuple(origin+np.array([v@right,-(v-np.array([0,3.1,0]))@up])*37) for v in q]
   shade=[.68,.84,.75,1,.9,.72][j];allfaces.append((np.mean(q@forward),xy,tuple(int(c*shade) for c in color),p['Name']))
 for _,xy,c,name in sorted(allfaces,reverse=True):d.polygon(xy,fill=c,outline=(86,232,255) if name=='Tear' else (17,24,39))
d.text((20,782),'Actual authored upper-body transforms; example run legs and tear paths.',font=f,fill=(195,208,228))
d.text((20,805),'Offline geometry preview. Native Animator blending still requires a Roblox Studio play test.',font=f,fill=(138,157,185))
im.save(args.output)
