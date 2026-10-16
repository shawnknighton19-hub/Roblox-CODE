"""Create a labeled contact sheet from the fifteen Blender geometry renders."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import argparse
def gallery(source,out):
 files=sorted(Path(source).glob('*.png'));assert len(files)==15
 image=Image.new('RGB',(1800,2018),(24,32,55));draw=ImageDraw.Draw(image)
 fontpath=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
 font=ImageFont.truetype(str(fontpath),22) if fontpath.exists() else ImageFont.load_default()
 for i,path in enumerate(files):
  x=i%3*600;y=i//3*392;preview=Image.open(path).convert('RGB');preview.thumbnail((596,350));image.paste(preview,(x,y));draw.text((x+14,y+356),path.stem.replace('_',' '),font=font,fill='white')
 draw.text((14,1975),'Generated V16 map geometry • Offline render; Roblox Studio appearance may differ',font=font,fill=(185,200,220));image.save(out)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('out');a=p.parse_args();gallery(a.source,a.out)
