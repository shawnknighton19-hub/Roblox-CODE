"""Blender gallery of actual TrailDesignsV13.Preview output, not imagined designs."""
import bpy, json, math, argparse, sys
from pathlib import Path
from mathutils import Vector, Matrix

parser=argparse.ArgumentParser()
parser.add_argument('--input',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
data=json.loads(args.input.read_text());args.output.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,rgb,metal=False,neon=False,alpha=1):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    s=mat.node_tree.nodes.get('Principled BSDF');s.inputs['Base Color'].default_value=(*rgb,1)
    s.inputs['Metallic'].default_value=.48 if metal else .02;s.inputs['Roughness'].default_value=.3
    s.inputs['Alpha'].default_value=alpha
    if neon:s.inputs['Emission Color'].default_value=(*rgb,1);s.inputs['Emission Strength'].default_value=.45
    return mat
def vec(d):return Vector((d['X'],d['Y'],d['Z']))
def convert(v):return Vector((v.x,-v.z,v.y))
conv=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
offsets=[]
for index,entry in enumerate(data):
    offset=Vector(((index%5-2)*6.7,0,(2-index//5)*3.5));offsets.append(offset)
    for node in entry['object']['children']:
        if node['class'] not in ('Part','WedgePart'):continue
        p=node['props'];size=vec(p['Size']);cf=p['CFrame'];pos=convert(vec(cf['p']))
        rotation=Matrix([cf['m'][i:i+3] for i in (0,3,6)]);shape=p.get('Shape',{}).get('Name','Block')
        if node['class']=='WedgePart':
            vertices=[(-1,-1,-1),(1,-1,-1),(-1,-1,1),(1,-1,1),(-1,1,1),(1,1,1)]
            faces=[(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)]
            mesh=bpy.data.meshes.new('Wedge');mesh.from_pydata(vertices,[],faces);mesh.update()
            ob=bpy.data.objects.new('Wedge',mesh);bpy.context.collection.objects.link(ob)
            bpy.context.view_layer.objects.active=ob;scale=size/2
        elif shape=='Ball':
            bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12);scale=Vector((size.x,size.z,size.y))/2
        elif shape=='Cylinder':
            bpy.ops.mesh.primitive_cylinder_add(vertices=20);scale=Vector((size.y,size.z,size.x))/2
        else:bpy.ops.mesh.primitive_cube_add();scale=size/2
        ob=bpy.context.view_layer.objects.active;ob.name=p['Name'];ob.scale=scale
        if shape=='Ball':ob.rotation_euler=(conv@rotation@conv.inverted()).to_euler()
        elif shape=='Cylinder':ob.rotation_euler=(conv@rotation@Matrix.Rotation(math.pi/2,3,'Y')).to_euler()
        else:ob.rotation_euler=(conv@rotation).to_euler()
        ob.location=offset+pos+Vector((0,0,.15))
        rgb=[p['Color'][k] for k in 'RGB'];kind=p.get('Material',{}).get('Name','SmoothPlastic')
        ob.data.materials.append(material(ob.name,rgb,kind=='Metal',kind=='Neon',max(.2,1-p.get('Transparency',0))))
        if shape in ('Ball','Cylinder'):
            for face in ob.data.polygons:face.use_smooth=True
    bpy.ops.mesh.primitive_cube_add(size=1,location=offset+Vector((0,1.25,-.05)))
    bpy.context.object.scale=(6.4,.08,3.28)
    bpy.context.object.data.materials.append(material('Card',(.024,.044,.076)))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.render.resolution_x=1800;scene.render.resolution_y=1120;scene.render.resolution_percentage=100
scene.world.color=(.13,.17,.22)
bpy.ops.object.light_add(type='AREA',location=(-9,-12,16));bpy.context.object.data.energy=2200;bpy.context.object.data.size=15
bpy.context.object.rotation_euler=(Vector((0,0,0))-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(12,-9,4));bpy.context.object.data.energy=1500;bpy.context.object.data.size=12
bpy.context.object.rotation_euler=(Vector((0,0,0))-bpy.context.object.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-40,3));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=35;scene.camera=camera
font_path=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
font=bpy.data.fonts.load(str(font_path)) if font_path.exists() else bpy.data.fonts.get('Bfont')
textmat=material('Label',(.9,.96,1),neon=True)
def label(text,pos,size):
    curve=bpy.data.curves.new('Label','FONT');curve.body=text;curve.font=font
    curve.align_x='CENTER';curve.align_y='CENTER';curve.size=size
    ob=bpy.data.objects.new('Label',curve);bpy.context.collection.objects.link(ob)
    ob.location=pos;ob.rotation_euler=camera.rotation_euler;ob.data.materials.append(textmat)
for entry,offset in zip(data,offsets):
    label(entry['item']['name'],offset+Vector((0,-.4,-1.03)),.33)
    label(str(entry['parts'])+' pooled parts',offset+Vector((0,-.4,-1.37)),.17)
label('HUSS A BOMB  /  SCULPTED TRAILS',Vector((0,0,9.3)),.65)
label('Actual V13 trail geometry • Offline preview • Roblox materials and motion require Studio playtest',Vector((0,-.3,-9.6)),.245)
scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(args.output);bpy.ops.render.render(write_still=True)
