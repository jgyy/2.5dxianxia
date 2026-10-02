"""Build a visible lantern-camp beacon with the installed headless Blender."""
import bpy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/props"
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
image = bpy.data.images.new("camp_surface",width=64,height=64)
pixels=[]
for y in range(64):
    for x in range(64):
        engraved = x % 16 in (0,1) or y % 16 in (0,1)
        grain = 0.84 + ((x*37+y*53)%17)/100
        base = (0.48,0.65,0.51) if engraved else (0.25,0.4,0.32)
        pixels.extend([channel*grain for channel in base]+[1])
image.pixels=pixels
texture=OUT/"camp_surface.png"
image.filepath_raw=str(texture)
image.file_format="PNG"
image.save()
stone=bpy.data.materials.new("CarvedJade")
stone.use_nodes=True
bsdf=stone.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value=0.8
node=stone.node_tree.nodes.new("ShaderNodeTexImage")
node.image=image
stone.node_tree.links.new(node.outputs["Color"],bsdf.inputs["Base Color"])
brass=bpy.data.materials.new("LanternBrass")
brass.diffuse_color=(0.6,0.34,0.1,1)
light=bpy.data.materials.new("WarmLantern")
light.use_nodes=True
shader=light.node_tree.nodes.get("Principled BSDF")
shader.inputs["Base Color"].default_value=(1,0.53,0.12,1)
shader.inputs["Emission Color"].default_value=(1,0.36,0.07,1)
shader.inputs["Emission Strength"].default_value=2.0
def cylinder(name,position,radius,depth,material,vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=position)
    obj=bpy.context.object
    obj.name=name
    obj.data.materials.append(material)
    return obj
cylinder("CampFoundation",(0,0,0.12),1.0,0.24,stone)
cylinder("BeaconPedestal",(0,0,0.42),0.66,0.35,stone)
for i in range(6):
    angle=i*math.tau/6
    petal=cylinder("LotusPetal",(math.cos(angle)*0.42,math.sin(angle)*0.42,0.7),0.2,0.18,brass,8)
    petal.scale.y=1.5
    petal.rotation_euler.z=angle
cylinder("LanternStem",(0,0,1.22),0.11,1.15,brass)
cylinder("LanternGlow",(0,0,1.76),0.31,0.65,light,8)
for i in range(8):
    angle=i*math.tau/8
    cylinder("LanternRib",(math.cos(angle)*0.33,math.sin(angle)*0.33,1.76),0.025,0.73,brass,6)
for z in [1.4,2.12]:
    cylinder("LanternCap",(0,0,z),0.44,0.12,brass,8)
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=0.62,radius2=0,depth=0.34,location=(0,0,2.33))
bpy.context.object.name="BeaconRoof"
bpy.context.object.data.materials.append(stone)
for obj in list(bpy.context.scene.objects):
    if obj.type=="MESH":
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if not obj.data.uv_layers:
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project()
            bpy.ops.object.mode_set(mode="OBJECT")
model=OUT/"camp_beacon.glb"
bpy.ops.export_scene.gltf(filepath=str(model),export_format="GLB",export_yup=True)
manifest={"generator":"Blender "+bpy.app.version_string+" headless", "model":"camp_beacon.glb","sha256":hashlib.sha256(model.read_bytes()).hexdigest(),"texture":"camp_surface.png","texture_sha256":hashlib.sha256(texture.read_bytes()).hexdigest(),"purpose":"Visible southern lantern camp for rest and resource renewal"}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("CAMP_BEACON_GENERATED",bpy.app.version_string)
