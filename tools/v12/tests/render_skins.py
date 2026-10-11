import bpy,json,math,argparse,sys
from pathlib import Path
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
parser=argparse.ArgumentParser(description='Offline view of the exact exported Roblox bomb parts.')
parser.add_argument('--input',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
data=json.loads(args.input.read_text());args.output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def walk(n):
 yield n
 for c in n.get('children',[]):yield from walk(c)
def material(name,rgb,metal,neon,transparent):
 m=bpy.data.materials.new(name);m.use_nodes=True;s=m.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*rgb,1);s.inputs['Metallic'].default_value=.48 if metal else .05;s.inputs['Roughness'].default_value=.27
 if neon:s.inputs['Emission Color'].default_value=(*rgb,1);s.inputs['Emission Strength'].default_value=.5
 if transparent:s.inputs['Transmission Weight'].default_value=.35;s.inputs['Roughness'].default_value=.15
 return m
def vec(d):return Vector((d['X'],d['Y'],d['Z']))
def converted(v):return Vector((v.x,-v.z,v.y))
offsets=[]
for index,entry in enumerate(data):
 offset=Vector(((index%5-2)*5.4,(2-index//5)*5.5,0));offsets.append(offset)
 for n in walk(entry['object']):
  if n['class'] not in ('Part','WedgePart'):continue
  v=n['props'];size=vec(v['Size']);cf=v['CFrame'];pos=converted(vec(cf['p']));r=Matrix([cf['m'][i:i+3] for i in (0,3,6)]);conv=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
  shape=v.get('Shape',{}).get('Name','Block')
  if n['class']=='WedgePart':
   verts=[(-1,-1,-1),(1,-1,-1),(-1,-1,1),(1,-1,1),(-1,1,1),(1,1,1)];faces=[(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)]
   mesh=bpy.data.meshes.new('Wedge');mesh.from_pydata(verts,[],faces);mesh.update();ob=bpy.data.objects.new('Wedge',mesh);bpy.context.collection.objects.link(ob);bpy.context.view_layer.objects.active=ob;ob.select_set(True);scale=Vector((size.x,size.y,size.z))/2
  elif shape=='Ball':bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12);scale=Vector((size.x,size.z,size.y))/2
  elif shape=='Cylinder':bpy.ops.mesh.primitive_cylinder_add(vertices=20);scale=Vector((size.y,size.z,size.x))/2
  else:bpy.ops.mesh.primitive_cube_add();scale=Vector((size.x,size.y,size.z))/2
  ob=bpy.context.view_layer.objects.active;ob.name=v.get('Name','BombDetail');ob.scale=scale
  if shape=='Ball':ob.rotation_euler=(conv@r@conv.inverted()).to_euler()
  elif shape=='Cylinder':ob.rotation_euler=(conv@r@Matrix.Rotation(math.pi/2,3,'Y')).to_euler()
  else:ob.rotation_euler=(conv@r).to_euler()
  ob.location=offset+pos+Vector((0,0,1.5))
  color=v['Color'];rgb=[color[k] for k in 'RGB'];mat=v.get('Material',{}).get('Name','Metal');ob.data.materials.append(material(ob.name,rgb,mat=='Metal',mat=='Neon',v.get('Transparency',0)>.15))
  if shape in ('Ball','Cylinder'):
   for f in ob.data.polygons:f.use_smooth=True
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=1.75,depth=.18,location=offset+Vector((0,0,-.09)));bpy.context.object.data.materials.append(material('Pedestal',(.065,.092,.15),False,False,False))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.2));bpy.context.object.data.materials.append(material('Floor',(.014,.026,.047),False,False,False))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.render.resolution_x=1700;scene.render.resolution_y=1700;scene.render.resolution_percentage=100;scene.world.color=(.23,.27,.35)
bpy.ops.object.light_add(type='AREA',location=(-10,-10,27));bpy.context.object.data.energy=12000;bpy.context.object.data.size=18
bpy.ops.object.light_add(type='AREA',location=(15,6,22));bpy.context.object.data.energy=10000;bpy.context.object.data.size=14
bpy.ops.object.camera_add(location=(0,-15,36));camera=bpy.context.object;target=Vector((0,0,0));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=30;scene.camera=camera
# Text is part of this offline preview scene, not an in-game object.
font_path=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf');font=bpy.data.fonts.load(str(font_path)) if font_path.exists() else bpy.data.fonts.get('Bfont')
textmat=bpy.data.materials.new('Label');textmat.use_nodes=True;nodes=textmat.node_tree.nodes;nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');emission=nodes.new('ShaderNodeEmission');emission.inputs['Color'].default_value=(.9,.95,1,1);emission.inputs['Strength'].default_value=1;textmat.node_tree.links.new(emission.outputs[0],out.inputs[0])
def label(body,position,size):
 curve=bpy.data.curves.new('Label','FONT');curve.body=body;curve.font=font;curve.align_x='CENTER';curve.align_y='CENTER';curve.size=size
 ob=bpy.data.objects.new('Label',curve);bpy.context.collection.objects.link(ob);ob.location=position;ob.rotation_euler=camera.rotation_euler;ob.data.materials.append(textmat)
for entry,offset in zip(data,offsets):label(entry['item']['name'],offset+Vector((0,-2.15,.15)),.32)
q=camera.rotation_euler.to_quaternion();up=q@Vector((0,1,0));normal=q@Vector((0,0,1))
label('HUSS A BOMB  /  SCULPTED BOMB COLLECTION',up*13.1+normal*3,.65)
label('Actual authored V12 geometry · Offline render · Lighting and materials approximate Roblox',up*-13+normal*13,.255)
scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(args.output);bpy.ops.render.render(write_still=True)
