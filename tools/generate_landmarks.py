"""Blender 5.2 headless: 12 regional landmarks x 3 variations, 128px textures."""
import bpy,hashlib,json,math,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/landmarks';OUT.mkdir(parents=True,exist_ok=True)
TYPES=['lotus_terrace','jade_observatory','ferry_dock','frost_arch','ember_forge','ink_archive','meteor_dais','moonwell','thunder_obelisk','dream_orchard','bone_ossuary','dawn_sanctuary']
PALETTES=[(.2,.6,.4),(.3,.7,.65),(.65,.35,.15),(.5,.7,.9),(.8,.25,.1),(.15,.25,.35),(.4,.4,.7),(.35,.6,.8),(.65,.6,.8),(.8,.4,.6),(.65,.6,.45),(.8,.7,.35)]
def cube(name,p,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(mat);return o
def cone(name,p,r,depth,mat,tip=0):
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r,radius2=tip,depth=depth,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(mat);return o
def ring(name,p,r,minor,mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=8,location=p,major_radius=r,minor_radius=minor);o=bpy.context.object;o.name=name;o.data.materials.append(mat)
def material(kind,v):
    rng=random.Random(7000+kind*100+v);im=bpy.data.images.new(f'landmark_{kind}_{v}',width=128,height=128);pixels=[]
    for y in range(128):
        for x in range(128):
            grain=rng.uniform(.85,1.15)*(1.2 if x%24<2 or y%24<2 else 1)
            pixels.extend([min(.98,c*grain) for c in PALETTES[kind]]+[1])
    im.pixels=pixels;im.filepath_raw=str(OUT/f'{TYPES[kind]}_{v:02}.png');im.file_format='PNG';im.save()
    m=bpy.data.materials.new(im.name);m.use_nodes=True;bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.7;t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],bsdf.inputs['Base Color']);return m
def build(kind,v,m):
    size=1+v*.15
    cube('Foundation',(0,0,.12),(3.5*size,3*size,.24),m)
    if kind==0:
        for i in range(3):cone('LotusTier',(0,0,.3+i*.28),1.5-i*.3,.25,m,1.5-i*.3)
        for i in range(8):
            a=i*math.tau/8;petal=cone('LotusPetal',(math.cos(a)*.8,math.sin(a)*.8,1.15),.3,1,m);petal.rotation_euler=(math.sin(a)*.5,math.cos(a)*.5,a)
    elif kind==1:
        for i in range(3):
            ring('CelestialRing',(0,0,2),1.1+i*.1,.06,m);bpy.context.object.rotation_euler[i]=math.pi/2
        cone('Pedestal',(0,0,.8),.5,1.5,m,.3)
    elif kind==2:
        cube('Dock',(0,1,.5),(3,5,.3),m)
        for x in [-1.3,1.3]:
            for y in [-1,1,3]:cone('Mooring',(x,y,1),.12,1.8,m,.12)
        cube('Gangway',(0,4,.45),(1,2,.15),m)
    elif kind==3:
        for x in [-1.2,1.2]:cone('IceColumn',(x,0,1.6),.4,3.2,m,.2)
        cube('FrozenLintel',(0,0,3.2),(3.3,.5,.5),m)
        for x in [-1,-.5,0,.5,1]:cone('Icicle',(x,0,2.8),.15,.7,m)
    elif kind==4:
        cone('Furnace',(0,0,1),1,1.8,m,.8);cone('Chimney',(0,.4,2.8),.35,2,m,.3)
        for x in [-1.2,1.2]:cube('Bellows',(x,0,.8),(.8,1,.7),m)
        ring('FurnaceRim',(0,0,1.8),.85,.1,m)
    elif kind==5:
        for x in [-1.4,1.4]:cube('ArchivePost',(x,0,1.5),(.15,.7,3),m)
        for z in [.4,1.1,1.8,2.5]:
            cube('Shelf',(0,0,z),(3,.8,.1),m)
            for i in range(8):cone('Scroll',(-1.1+i*.3,0,z+.23),.09,.36,m,.09)
    elif kind==6:
        for i in range(4):cone('MeteorStep',(0,0,.2+i*.25),1.6-i*.25,.22,m,1.6-i*.25)
        cone('Meteor',(0,0,1.65),.6,1.2,m,.15)
    elif kind==7:
        ring('Well',(0,0,.7),1.1,.25,m);ring('WellBase',(0,0,.2),1.3,.2,m)
        for x in [-1.3,1.3]:cube('MoonPost',(x,0,1.8),(.15,.15,3.2),m)
        cube('MoonBeam',(0,0,3.3),(3,.2,.2),m);ring('Moon',(0,0,2.7),.4,.08,m);bpy.context.object.rotation_euler.x=math.pi/2
    elif kind==8:
        cone('ThunderPillar',(0,0,1.6),.65,3.1,m,.3)
        for i in range(3):ring('Conductor',(0,0,1+i*.6),.8-i*.15,.08,m)
        cone('LightningTip',(0,0,3.6),.3,1,m)
    elif kind==9:
        cone('DreamTrunk',(0,0,1.5),.3,3,m,.2)
        for i in range(7):
            a=i*math.tau/7;cone('DreamPetal',(math.cos(a)*.7,math.sin(a)*.7,2.7),.6,.8,m,.1)
    elif kind==10:
        cube('Ossuary',(0,0,1.3),(2.5,1.3,2.4),m)
        for x in [-.8,0,.8]:
            for z in [.6,1.4,2.2]:ring('AncestorSeal',(x,-.69,z),.22,.045,m);bpy.context.object.rotation_euler.x=math.pi/2
        cone('Roof',(0,0,2.8),2,.6,m)
    else:
        for x in [-1.3,1.3]:cone('DawnColumn',(x,0,1.8),.17,3.5,m,.17)
        cone('DawnRoof',(0,0,3.8),2.2,.8,m)
        ring('SunDisk',(0,0,2.4),.7,.12,m);bpy.context.object.rotation_euler.x=math.pi/2
        cone('DawnAltar',(0,0,.7),.6,1,m,.6)
manifest={'generator':'Blender 5.2.2 LTS headless','models':[]}
for kind,name in enumerate(TYPES):
    for v in range(3):
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        for collection in [bpy.data.materials,bpy.data.images,bpy.data.meshes]:
            for block in list(collection):
                if block.users==0:collection.remove(block)
        m=material(kind,v);build(kind,v,m)
        for obj in bpy.context.scene.objects:
            if obj.type=='MESH':
                bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);obj.select_set(False)
                if not obj.data.uv_layers:bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
        path=OUT/f'{name}_{v:02}.glb';bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True)
        tex=OUT/f'{name}_{v:02}.png';manifest['models'].append({'id':f'{name}_{v:02}','region':f'region_{kind:02}','path':path.name,'texture':tex.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'texture_sha256':hashlib.sha256(tex.read_bytes()).hexdigest()})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('LANDMARKS_COMPLETE',len(manifest['models']))
