"""Render executed map geometry in Blender; this is not a Studio screenshot."""
import bpy,json,math,sys,argparse
from mathutils import Vector,Matrix
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--scene',required=True);p.add_argument('--out-dir',required=True);p.add_argument('--only');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
DOC=json.loads(Path(a.scene).read_text());OUT=Path(a.out_dir);OUT.mkdir(parents=True,exist_ok=True)
def walk(n):
 yield n
 for c in n.get('children',[]):yield from walk(c)
def v(d):return Vector((d['X'],d['Y'],d['Z']))
def transform(q):return q.x,-q.z,q.y
boxv=[(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]
boxf=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
library=next(n for n in DOC['instances'] if n['props']['Name']=='MapLibrary')
for model in library['children']:
 name=model['props']['Name']
 if a.only and name not in a.only.split(','):continue
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 buckets={}
 for n in walk(model):
  q=n['props']
  if n['class'] not in ('Part','WedgePart') or q.get('Transparency',0)>.8:continue
  cf=q['CFrame'];size=v(q['Size']);pos=v(cf['p']);rot=Matrix([cf['m'][i:i+3] for i in (0,3,6)])
  rgb=tuple(round(q['Color'][k],3) for k in 'RGB');verts,faces=buckets.setdefault(rgb,([],[]));offset=len(verts)
  shape=q.get('Shape',{}).get('Name','Block');coords=boxv;fs=boxf
  if n['class']=='WedgePart':coords=[(-1,-1,-1),(-1,-1,1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,1)];fs=[(0,3,4,1),(1,4,5,2),(0,2,5,3),(0,1,2),(3,5,4)]
  elif shape in ('Ball','Cylinder'):
   coords=[];fs=[];segments=24;rings=13 if shape=='Ball' else 2
   for i in range(rings):
    axis=-1+2*i/(rings-1);radial=math.sqrt(max(0,1-axis*axis)) if shape=='Ball' else 1
    for j in range(segments):coords.append((axis,radial*math.cos(j*math.tau/segments),radial*math.sin(j*math.tau/segments)))
   for i in range(rings-1):
    for j in range(segments):k=(j+1)%segments;fs.append((i*segments+j,i*segments+k,(i+1)*segments+k,(i+1)*segments+j))
   fs.extend([tuple(reversed(range(segments))),tuple(range((rings-1)*segments,rings*segments))])
  for b in coords:verts.append(transform(pos+rot@Vector((b[0]*size.x/2,b[1]*size.y/2,b[2]*size.z/2))))
  faces.extend(tuple(offset+i for i in f) for f in fs)
 for rgb,(verts,faces) in buckets.items():
  mesh=bpy.data.meshes.new('AuthoredGeometry');mesh.from_pydata(verts,[],faces);mesh.update();ob=bpy.data.objects.new('AuthoredGeometry',mesh);bpy.context.collection.objects.link(ob)
  mat=bpy.data.materials.new(str(rgb));mat.diffuse_color=(*rgb,1);mat.use_nodes=True
  bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb,1);bs.inputs['Roughness'].default_value=.46;ob.data.materials.append(mat)
 # SurfaceGui labels are real source text, set in a substitute offline font.
 white=bpy.data.materials.new('Sign lettering');white.diffuse_color=(1,1,1,1)
 for n in walk(model):
  if n['class']!='Part':continue
  guis=[c for c in n.get('children',[]) if c['class']=='SurfaceGui']
  if not guis:continue
  labels=[l for l in walk(guis[0]) if l['class']=='TextLabel']
  if not labels:continue
  q=n['props'];cf=q['CFrame'];pos=v(cf['p']);size=v(q['Size']);rot=Matrix([cf['m'][i:i+3] for i in (0,3,6)])
  text=labels[0]['props']['Text'];location=Vector(transform(pos+rot@Vector((0,0,size.z/2+.05))))
  curve=bpy.data.curves.new('Real sign text','FONT');curve.body=text;curve.align_x='CENTER';curve.align_y='CENTER';curve.size=min(size.y*.47,size.x/max(1,len(text))*1.45)
  ob=bpy.data.objects.new('Real sign text',curve);bpy.context.collection.objects.link(ob);ob.location=location;curve.materials.append(white)
  normal=rot@Vector((0,0,1));normal=Vector((normal.x,-normal.z,normal.y));up=rot@Vector((0,1,0));up=Vector((up.x,-up.z,up.y));right=up.cross(normal)
  ob.rotation_euler=Matrix(((right.x,up.x,normal.x),(right.y,up.y,normal.y),(right.z,up.z,normal.z))).to_euler()
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=False
 scene.render.resolution_x=960;scene.render.resolution_y=740;scene.render.resolution_percentage=100;scene.world.color=(.37,.4,.48)
 bpy.ops.object.light_add(type='AREA',location=(0,-90,190));light=bpy.context.object;light.data.energy=190000;light.data.shape='DISK';light.data.size=160
 bpy.ops.object.light_add(type='SUN',location=(-100,-100,200));sun=bpy.context.object;sun.data.energy=2;sun.rotation_euler=(.45,-.3,-.6);sun.data.angle=.25
 bpy.ops.object.camera_add(location=(160,-225,230));camera=bpy.context.object;target=Vector((0,0,3));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=max(model['attributes']['MapWidth'],model['attributes']['MapDepth'])*1.24;scene.camera=camera
 scene.render.image_settings.file_format='PNG';scene.render.filepath=str(OUT/(name.replace(' ','_')+'.png'));scene.view_settings.view_transform='Standard';bpy.ops.render.render(write_still=True)
 print('RENDERED',name,flush=True)
