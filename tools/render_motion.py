"""Run in headless Blender: UV-mapped deformable cutout meshes of the existing cast."""
import argparse, hashlib, json, math, sys, time
from pathlib import Path
import bpy
from mathutils import Vector

parser=argparse.ArgumentParser()
parser.add_argument("--plan",type=Path,required=True)
parser.add_argument("--region",required=True)
parser.add_argument("--output",type=Path,required=True)
parser.add_argument("--limit",type=int,default=0)
args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
root=Path(__file__).resolve().parents[1]
plan=json.loads(args.plan.read_text())
people=[p for p in plan["characters"] if p["region"]==args.region]
if args.limit:people=people[:args.limit]
args.output.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=8
scene.cycles.use_denoising=False
scene.cycles.use_adaptive_sampling=False
scene.render.resolution_x=scene.render.resolution_y=320
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.render.image_settings.color_depth="8"
scene.render.film_transparent=True
scene.render.threads_mode="FIXED"
scene.render.threads=4
scene.world.color=(0,0,0)
scene.view_settings.view_transform="Standard"
scene.view_settings.look="None"
scene.view_settings.exposure=0
scene.view_settings.gamma=1
scene.camera=None
bpy.ops.object.camera_add(location=(0,0,8))
camera=bpy.context.object
camera.data.type="ORTHO";camera.data.ortho_scale=2.28
scene.camera=camera
N=24
vertices=[((x/N-.5)*2,(y/N-.5)*2,0) for y in range(N+1) for x in range(N+1)]
faces=[(y*(N+1)+x,y*(N+1)+x+1,(y+1)*(N+1)+x+1,(y+1)*(N+1)+x) for y in range(N) for x in range(N)]
mesh=bpy.data.meshes.new("articulated_sprite_grid")
mesh.from_pydata(vertices,[],faces);mesh.update()
uv=mesh.uv_layers.new(name="source_pose")
obj=bpy.data.objects.new("existing_character_cutout",mesh)
scene.collection.objects.link(obj)
material=bpy.data.materials.new("unlit_source_rgba")
material.use_nodes=True
nodes=material.node_tree.nodes;nodes.clear()
tex=nodes.new("ShaderNodeTexImage");tex.interpolation="Linear";tex.extension="CLIP"
uvnode=nodes.new("ShaderNodeUVMap");uvnode.uv_map="source_pose"
emission=nodes.new("ShaderNodeEmission")
emission.inputs["Strength"].default_value=1
transparent=nodes.new("ShaderNodeBsdfTransparent")
alpha=nodes.new("ShaderNodeMath");alpha.operation="MULTIPLY";alpha.inputs[1].default_value=1
mix=nodes.new("ShaderNodeMixShader")
output=nodes.new("ShaderNodeOutputMaterial")
links=material.node_tree.links
links.new(uvnode.outputs["UV"],tex.inputs["Vector"])
links.new(tex.outputs["Color"],emission.inputs["Color"])
links.new(tex.outputs["Alpha"],alpha.inputs[0])
links.new(alpha.outputs[0],mix.inputs[0])
links.new(transparent.outputs[0],mix.inputs[1])
links.new(emission.outputs[0],mix.inputs[2])
links.new(mix.outputs[0],output.inputs["Surface"])
obj.data.materials.append(material)

def set_pose(rect,image):
    rx,ry,rw,rh=rect
    for poly in mesh.polygons:
        for loop_index in poly.loop_indices:
            vi=mesh.loops[loop_index].vertex_index
            x,y,_=vertices[vi];u=(x+1)/2;v=(y+1)/2
            uv.data[loop_index].uv=((rx+u*rw)/image.size[0],1-(ry+(1-v)*rh)/image.size[1])

def deform(state,k,count):
    p=k/count if state!="death" else k/(count-1)
    angle=2*math.pi*p
    for index,(x,y,z) in enumerate(vertices):
        top=max(0,(y+.1)/1.1)
        bottom=max(0,(-y+.25)/1.25)
        side=math.tanh(x*5)
        # Weights concentrate motion in lower limbs, arms and loose hair.
        arm=max(0,(abs(x)-.3)/.7)*max(0,1-abs(y-.1))
        if state=="idle":
            dx=.009*math.sin(angle)*top+.004*math.cos(angle)*arm*side
            dy=.009*math.cos(angle)*(y+1)/2
            nx=x+dx;ny=y+dy
        elif state=="walk":
            stride=math.sin(angle)
            nx=x+.04*stride*bottom*side+.012*math.cos(angle)*top
            ny=y+.025*math.cos(2*angle)*(1-bottom)+.032*stride*bottom*side
        elif state=="attack":
            pulse=math.sin(math.pi*p)**2
            nx=x-.028*math.sin(angle)*top+.055*pulse*arm
            ny=y+.017*math.cos(angle)*(y+1)/2+.025*pulse*arm
        else:
            # Keep the final frame nonempty; gameplay applies the terminal fade.
            nx=x*(1-.12*p)+.08*p*top
            ny=-1+(y+1)*(1-.42*p)-.015*math.sin(math.pi*p)*arm
        mesh.vertices[index].co=(nx,ny,0)
    mesh.update()
    alpha.inputs[1].default_value=(1-.62*p) if state=="death" else 1

started=time.monotonic()
report={"generator":bpy.app.version_string,"method":"headless Blender Cycles rendering of UV-mapped deformable cutout meshes","frame_size":[320,320],"states":plan["states"],"characters":[]}
for person in people:
    path=root/person["source"]
    image=bpy.data.images.load(str(path),check_existing=True)
    image.alpha_mode="STRAIGHT"
    tex.image=image
    directory=args.output/person["id"];directory.mkdir(exist_ok=True)
    index=0
    for pose,(state,count) in enumerate(plan["states"].items()):
        set_pose(person["rects"][pose],image)
        for k in range(count):
            deform(state,k,count)
            scene.render.filepath=str(directory/f"{index:02}.png")
            bpy.ops.render.render(write_still=True)
            index+=1
    report["characters"].append({**person,"source_sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"frames":index})
    print("CHARACTER_RENDERED",person["id"],index,round(time.monotonic()-started,2),flush=True)
report["seconds"]=round(time.monotonic()-started,3)
(args.output/"render.json").write_text(json.dumps(report,indent=2)+"\n")
print("MOTION_RENDER_PASS",len(people)*50,"seconds",report["seconds"],flush=True)
