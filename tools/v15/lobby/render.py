"""Offline geometry preview, with approximate typography; not a Roblox screenshot."""
import bpy,json,math,argparse,sys
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import output_dir
from inspect_geometry import scene as prepare_scene
parser=argparse.ArgumentParser();parser.add_argument('--scene');parser.add_argument('--out-dir');parser.add_argument('--original');parser.add_argument('--luau')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []);OUT=output_dir(args.out_dir)
DOC=json.loads(Path(args.scene).read_text()) if args.scene else prepare_scene(OUT,original=args.original,luau=args.luau)[0]
CENTER=Vector((0,1.5,86.66000366210938))
def walk(n):
 yield n
 for c in n.get('children',[]):yield from walk(c)
def v(d):return Vector((d['X'],d['Y'],d['Z']))
def transform(q):
 q=q-CENTER
 return (q.x,-q.z,q.y)
boxv=[(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]
boxf=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
buckets={}
for n in walk(DOC['instances'][0]):
 p=n['props']
 if n['class'] not in ('Part','WedgePart','SpawnLocation','MeshPart') or p.get('Transparency',0)>.8:continue
 cf=p['CFrame'];size=v(p['Size']);pos=v(cf['p']);rot=Matrix([cf['m'][i:i+3] for i in (0,3,6)])
 color=p.get('Color',{'R':.5,'G':.5,'B':.5});rgb=tuple(round(color[k],3) for k in 'RGB');material=p.get('Material',{}).get('Name','')
 key=(rgb,material=='Neon');vs,fs=buckets.setdefault(key,([],[]));offset=len(vs)
 shape=p.get('Shape',{}).get('Name','Block');coords=boxv;faces=boxf
 if n['class']=='WedgePart':
  coords=[(-1,-1,-1),(-1,-1,1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,1)];faces=[(0,3,4,1),(1,4,5,2),(0,2,5,3),(0,1,2),(3,5,4)]
 elif shape in ('Cylinder','Ball'):
  coords=[];faces=[];segments=24;rings=13 if shape=='Ball' else 2
  for i in range(rings):
   axis=-1+2*i/(rings-1);radial=math.sqrt(max(0,1-axis*axis)) if shape=='Ball' else 1
   for j in range(segments):coords.append((axis,radial*math.cos(j*math.tau/segments),radial*math.sin(j*math.tau/segments)))
  for i in range(rings-1):
   for j in range(segments):k=(j+1)%segments;faces.append((i*segments+j,i*segments+k,(i+1)*segments+k,(i+1)*segments+j))
  faces.extend([tuple(reversed(range(segments))),tuple(range((rings-1)*segments,rings*segments))])
 for q in coords:vs.append(transform(pos+rot@Vector((q[0]*size.x/2,q[1]*size.y/2,q[2]*size.z/2))))
 fs.extend(tuple(offset+i for i in f) for f in faces)
for (rgb,neon),(vs,fs) in buckets.items():
 mesh=bpy.data.meshes.new('ActualParts');mesh.from_pydata(vs,[],fs);mesh.update();obj=bpy.data.objects.new('ActualParts',mesh);bpy.context.collection.objects.link(obj)
 mat=bpy.data.materials.new(str(rgb));mat.diffuse_color=(*rgb,1);mat.use_nodes=True
 bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Roughness'].default_value=.55
 if neon:bs.inputs['Emission Color'].default_value=(*rgb,1);bs.inputs['Emission Strength'].default_value=.3
 obj.data.materials.append(mat)
# Label text is derived from the actual sign labels; Blender's font is an approximation.
mat=bpy.data.materials.new('Sign white');mat.diffuse_color=(1,1,1,1)
for n in walk(DOC['instances'][0]):
 if n['class']!='Part':continue
 p=n['props'];preview=n.get('previewSign')
 guis=[c for c in n.get('children',[]) if c['class']=='SurfaceGui']
 if not preview and guis:
  labels=[d for d in walk(guis[0]) if d['class']=='TextLabel']
  if labels:preview={'text':labels[0]['props']['Text'],'face':guis[0]['props']['Face']['Name']}
 if not preview or preview['face'] not in ('Front','Back'):continue
 cf=p['CFrame'];size=v(p['Size']);pos=v(cf['p']);rot=Matrix([cf['m'][i:i+3] for i in (0,3,6)])
 sign=1 if preview['face']=='Back' else -1
 location=Vector(transform(pos+rot@Vector((0,0,sign*(size.z/2+.04)))))
 curve=bpy.data.curves.new('ActualSignText','FONT');curve.body=preview['text'];curve.align_x='CENTER';curve.align_y='CENTER';curve.size=min(size.y*.35,size.x/max(1,len(preview['text']))*1.6);curve.extrude=0
 ob=bpy.data.objects.new('SignText',curve);bpy.context.collection.objects.link(ob);ob.location=location;curve.materials.append(mat)
 normal=rot@Vector((0,0,sign));normal=Vector((normal.x,-normal.z,normal.y));up=rot@Vector((0,1,0));up=Vector((up.x,-up.z,up.y));right=up.cross(normal)
 ob.rotation_euler=Matrix(((right.x,up.x,normal.x),(right.y,up.y,normal.y),(right.z,up.z,normal.z))).to_euler()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.color=(.35,.39,.48)
bpy.ops.object.light_add(type='AREA',location=(0,-100,180));bpy.context.object.data.energy=190000;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=160
bpy.ops.object.light_add(type='SUN',location=(-100,-100,200));sun=bpy.context.object;sun.data.energy=2;sun.rotation_euler=(.45,-.3,-.6);sun.data.angle=.25
bpy.ops.object.camera_add(location=(165,-220,215));camera=bpy.context.object;target=Vector((0,10,0));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=270;scene.camera=camera
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/'LobbyV15-Overview.png');scene.view_settings.view_transform='Standard';bpy.ops.render.render(write_still=True)
camera.location=(60,-185,112);target=Vector((0,2,9));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=208;scene.render.filepath=str(OUT/'LobbyV15-Arrival.png');bpy.ops.render.render(write_still=True)
