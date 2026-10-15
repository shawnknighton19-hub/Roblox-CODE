#!/usr/bin/env python3
"""Draw offline layout previews from real V15 GuiObject properties collected by tests.
This is not a native Roblox screenshot; font metrics and gradient shading are approximate.
"""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'previews/v15-ui';OUT.mkdir(parents=True,exist_ok=True)
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def render(snapshot):
 name,w,h,records=snapshot
 image=Image.new('RGB',(w,h+24),(74,100,130));d=ImageDraw.Draw(image)
 for y in range(h):
  t=y/max(1,h-1);d.line((0,y,w,y),fill=(round(82-44*t),round(118-59*t),round(151-70*t)))
 d.text((24,20),'HUSS A BOMB  /  V15 UI',font=ImageFont.truetype(font_path,16),fill=(165,201,227))
 def rgb(v):return tuple(round(max(0,min(1,c))*255) for c in v)
 for r in sorted(enumerate(records),key=lambda pair:(pair[1][5],pair[0])):
  name_,x,y,rw,rh,z,red,green,blue,alpha,radius,txt,ts,tr,tg,tb,align,rot,stroke,sr,sg,sb=r[1]
  if x+rw<0 or y+rh<0 or x>w or y>h:continue
  # Ignore screen-size transparent containers and anything clipped by a scrolling page.
  layer=Image.new('RGBA',(max(1,math.ceil(rw))+12,max(1,math.ceil(rh))+12));ld=ImageDraw.Draw(layer)
  color=rgb([red,green,blue])+ (round((1-alpha)*255),)
  if alpha<.99:
   ld.rounded_rectangle((5,5,rw+5,rh+5),radius=max(0,min(radius,rw/2,rh/2)),fill=color,outline=rgb([sr,sg,sb])+(255,) if stroke else None,width=max(1,round(stroke)))
  if txt:
   font=ImageFont.truetype(font_path,max(8,round(ts*.89)))
   lines=txt.split('\n');maxWidth=max(8,rw-10)
   wrapped=[]
   for line in lines:
    words=line.split();row=''
    for word in words:
     test=(row+' '+word).strip()
     if ld.textlength(test,font=font)>maxWidth and row:wrapped.append(row);row=word
     else:row=test
    wrapped.append(row)
   height=len(wrapped)*ts*1.08
   for i,line in enumerate(wrapped):
    width=ld.textlength(line,font=font)
    tx=5 if align=='Left' else rw-width if align=='Right' else (rw-width)/2+5
    ty=(rh-height)/2+i*ts*1.08+4
    if ty<rh-2:ld.text((tx,ty),line,font=font,fill=rgb([tr,tg,tb]),stroke_width=1 if ts>=18 else 0,stroke_fill=(13,20,28))
  if rot:layer=layer.rotate(-rot,resample=Image.Resampling.BICUBIC,expand=True)
  image.paste(layer,(round(x-(layer.width-rw)/2),round(y-(layer.height-rh)/2)),layer)
 d=ImageDraw.Draw(image);d.rectangle((0,h,w,h+24),fill=(17,23,39));d.text((18,h+4),'OFFLINE LAYOUT PREVIEW • Actual UI tree; Roblox font rendering and game scene require Studio.',font=ImageFont.truetype(font_path,10),fill=(189,205,228))
 target=OUT/f'{name}.png';image.save(target);return target
if __name__=='__main__':
 import sys
 source=Path(sys.argv[1]).read_text()
 if source.lstrip().startswith('['):
  for snapshot in json.loads(source):
   if snapshot[0] in ('lobby','match'):print(render(snapshot))
 else:
  for line in source.splitlines():
   if line.startswith('UI_SNAPSHOT '):print(render(json.loads(line[12:])))
