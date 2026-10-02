"""Generate original, textured city GLBs using headless Blender.

blender --background --factory-startup --python tools/generate_interiors.py -- --batch common
Models use meters, a floor origin, shared 256px albedo/roughness/normal maps,
beveled geometry, and embedded GLB images. Batches are safe to checkpoint.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/interiors"
TEXTURES = OUT / "textures"
SIZE = 256
PALETTE = {
    "walnut": ((.38, .21, .105), .72, 0),
    "lacquer": ((.48, .095, .07), .32, 0),
    "jade": ((.08, .43, .29), .26, .05),
    "brass": ((.64, .41, .13), .4, .78),
    "ceramic": ((.11, .42, .47), .22, 0),
    "silk": ((.075, .36, .27), .68, 0),
    "brocade": ((.58, .13, .09), .7, 0),
    "paper": ((.85, .76, .57), .88, 0),
    "stone": ((.27, .31, .3), .84, 0),
    "iron": ((.24, .27, .29), .52, .85),
    "water": ((.07, .36, .4), .16, .15),
    "ember": ((.8, .25, .045), .65, 0),
}
MATERIALS = {}
COMMON = ["tea_table", "carved_stool", "canopy_bed", "bookcase", "storage_chest", "floor_lantern", "ceramic_vase", "folding_screen"]
BUILDERS = {}


def register(name):
    def wrap(function):
        BUILDERS[name] = function
        return function
    return wrap


def texture_set(name, base, roughness):
    """Build repeatable material patterns and tangent normals inside Blender."""
    rng = random.Random(7301 + list(PALETTE).index(name))
    heights = []
    colors = []
    for y in range(SIZE):
        for x in range(SIZE):
            noise = rng.uniform(-1, 1)
            u, v = x / SIZE, y / SIZE
            if name in ["walnut", "lacquer"]:
                pattern = math.sin(u * math.tau * 28 + math.sin(v * 12) * 2 + math.sin(u * 13))
                seam = .58 if x % 64 < 2 else 1
                grain = (.86 + pattern * .13 + noise * .035) * seam
            elif name in ["silk", "brocade"]:
                weave = ((x % 4) / 4 - .4) * ((y % 4) / 4 - .4)
                diamond = abs((x % 48) - 24) + abs((y % 48) - 24)
                grain = .88 + noise * .04 + weave * .4
                if 21 < diamond < 24: grain += .3
            elif name == "paper":
                grain = .94 + noise * .07 + math.sin(v * 180) * .015
            elif name in ["jade", "stone", "water"]:
                vein = math.sin(u * 17 + math.sin(v * 15) * 2 + math.sin((u + v) * 33))
                grain = .85 + vein * .14 + noise * .035
            elif name == "ceramic":
                ring = .48 if y % 64 < 5 else 1
                grain = (.94 + math.sin(u * 30) * .025 + noise * .015) * ring
            else:
                grain = .86 + noise * .09 + math.sin(u * 65 + v * 39) * .04
                if name == "brass" and (x % 32 < 2 or y % 32 < 2): grain += .18
            heights.append(grain)
            colors.extend([min(.98, max(.01, c * grain)) for c in base] + [1])
    rough, normals = [], []
    for y in range(SIZE):
        for x in range(SIZE):
            i = y * SIZE + x
            value = max(.08, min(.97, roughness + (heights[i] - .9) * .22))
            rough.extend([value, value, value, 1])
            dx = heights[y * SIZE + (x + 1) % SIZE] - heights[y * SIZE + (x - 1) % SIZE]
            dy = heights[((y + 1) % SIZE) * SIZE + x] - heights[((y - 1) % SIZE) * SIZE + x]
            normal = Vector((-dx * .8, -dy * .8, 1)).normalized()
            normals.extend([normal.x * .5 + .5, normal.y * .5 + .5, normal.z * .5 + .5, 1])
    images = {}
    for channel, pixels in [("albedo", colors), ("roughness", rough), ("normal", normals)]:
        image = bpy.data.images.new(f"{name}_{channel}", width=SIZE, height=SIZE)
        if channel != "albedo": image.colorspace_settings.name = "Non-Color"
        image.pixels = pixels
        image.filepath_raw = str(TEXTURES / f"{name}_{channel}.png")
        image.file_format = "PNG"
        image.save()
        images[channel] = image
    return images


def make_materials():
    for name, (color, roughness, metallic) in PALETTE.items():
        images = texture_set(name, color, roughness)
        material = bpy.data.materials.new(name.capitalize())
        material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Metallic"].default_value = metallic
        for channel in ["albedo", "roughness", "normal"]:
            texture = material.node_tree.nodes.new("ShaderNodeTexImage")
            texture.image = images[channel]
            if channel == "normal":
                normal = material.node_tree.nodes.new("ShaderNodeNormalMap")
                material.node_tree.links.new(texture.outputs["Color"], normal.inputs["Color"])
                material.node_tree.links.new(normal.outputs["Normal"], shader.inputs["Normal"])
            else:
                material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color" if channel == "albedo" else "Roughness"])
        if name == "ember":
            shader.inputs["Emission Color"].default_value = (1, .18, .025, 1)
            shader.inputs["Emission Strength"].default_value = .7
        MATERIALS[name] = material


def cube(name, point, dimensions, material="walnut", bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=point)
    obj = bpy.context.object
    obj.name = name
    obj.scale = dimensions
    obj.data.materials.append(MATERIALS[material])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft crafted edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cylinder(name, point, radius, height, material="walnut", top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=radius, radius2=radius if top is None else top, depth=height, location=point)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(MATERIALS[material])
    return obj


def sphere(name, point, radius, material="ceramic", scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=point)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(MATERIALS[material])
    return obj


def ring(name, point, radius, thickness, material="brass", rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8, location=point, major_radius=radius, minor_radius=thickness, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(MATERIALS[material])
    return obj


@register("tea_table")
def tea_table():
    cube("Carved table top", (0, 0, .82), (2.1, 1.35, .15))
    cube("Red lacquer inset", (0, 0, .904), (1.75, 1.05, .025), "lacquer", .01)
    for x in [-.8, .8]:
        for y in [-.45, .45]:
            cylinder("Turned leg", (x, y, .39), .075, .78, top=.11)
            cylinder("Leg collar", (x, y, .18), .12, .09, "brass")
    for y in [-.54, .54]: cube("Apron", (0, y, .65), (1.75, .12, .2))


@register("carved_stool")
def carved_stool():
    cylinder("Round seat", (0, 0, .53), .38, .12)
    cylinder("Jade cushion", (0, 0, .6), .31, .06, "silk")
    for x in [-.23, .23]:
        for y in [-.23, .23]: cylinder("Foot", (x, y, .25), .06, .5)
    ring("Brace", (0, 0, .2), .3, .045, "walnut")


@register("canopy_bed")
def canopy_bed():
    cube("Bed frame", (0, 0, .4), (1.85, 3.15, .36))
    cube("Silk quilt", (0, -.08, .65), (1.7, 2.9, .2), "silk", .06)
    cube("Folded brocade", (0, -.83, .78), (1.72, .7, .08), "brocade", .04)
    sphere("Pillow", (0, 1.08, .8), .48, "paper", (1.45, .65, .3))
    for x in [-.85, .85]:
        for y in [-1.43, 1.43]:
            cylinder("Canopy post", (x, y, 1.35), .065, 2.7)
            sphere("Carved finial", (x, y, 2.78), .12, "brass")
    for y in [-1.43, 1.43]: cube("Canopy rail", (0, y, 2.63), (1.8, .1, .13))
    for x in [-.85, .85]: cube("Canopy rail", (x, 0, 2.63), (.1, 3, .13))
    for x in [-.84, .84]: cube("Brocade curtain", (x, .7, 1.77), (.05, 1.45, 1.6), "brocade", .01)


@register("bookcase")
def bookcase():
    for x in [-1.3, 1.3]: cube("Side stile", (x, 0, 1.3), (.15, .6, 2.6))
    cube("Back panel", (0, .25, 1.3), (2.65, .1, 2.6))
    for z in [.08, .75, 1.48, 2.22, 2.6]: cube("Shelf", (0, 0, z), (2.75, .66, .1))
    for level in range(3):
        for column in range(9):
            height = .36 + (column % 3) * .065
            cube("Thread-bound volume", (-1.1 + column * .27, -.05, .15 + level * .73 + height / 2), (.19, .38, height), "brocade" if column % 3 == 0 else "paper", .009)


@register("storage_chest")
def storage_chest():
    cube("Chest", (0, 0, .4), (1.45, .8, .8), "lacquer", .04)
    cube("Lid", (0, 0, .85), (1.5, .84, .15), "walnut", .05)
    for x in [-.5, .5]:
        cube("Brass binding", (x, -.425, .42), (.07, .03, .72), "brass", .008)
        cube("Lid binding", (x, 0, .94), (.07, .83, .03), "brass", .006)
    ring("Latch", (0, -.445, .6), .085, .025, rotation=(math.pi / 2, 0, 0))


@register("floor_lantern")
def floor_lantern():
    cylinder("Foot", (0, 0, .08), .36, .16)
    cylinder("Stem", (0, 0, .68), .065, 1.3)
    cylinder("Paper shade", (0, 0, 1.56), .29, .7, "paper")
    for z in [1.19, 1.94]: cylinder("Lacquer cap", (0, 0, z), .36, .09, "lacquer")
    for i in range(8):
        a = i * math.tau / 8
        cylinder("Shade rib", (math.cos(a) * .3, math.sin(a) * .3, 1.56), .017, .74, "brass")


@register("ceramic_vase")
def ceramic_vase():
    sphere("Glazed body", (0, 0, .43), .36, "ceramic", (1, 1, 1.2))
    cylinder("Neck", (0, 0, .79), .15, .3, "ceramic", top=.21)
    ring("Gold rim", (0, 0, .95), .21, .025)
    for i in range(5):
        a = i * math.tau / 5
        cylinder("Stem", (.07 * math.cos(a), .07 * math.sin(a), 1.2), .012, .55, "jade")
        sphere("Lotus bloom", (.12 * math.cos(a), .12 * math.sin(a), 1.45 + i * .03), .1, "brocade", (1, 1, .45))


@register("folding_screen")
def folding_screen():
    for panel in range(3):
        x = (panel - 1) * .78
        y = abs(panel - 1) * .15
        cube("Jade woven panel", (x, y, 1.1), (.7, .055, 1.85), "silk", .01)
        for dx in [-.37, .37]: cube("Frame", (x + dx, y, 1.08), (.055, .1, 2.16))
        for z in [.15, 2.08]: cube("Rail", (x, y, z), (.8, .1, .07))
        for z in [.58, 1.07, 1.58]: cube("Bamboo motif", (x, y - .04, z), (.025, .025, .42), "brass", .006)


def export_model(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        if block.users == 0: bpy.data.meshes.remove(block)
    BUILDERS[name]()
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH": continue
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.015)
        bpy.ops.object.mode_set(mode="OBJECT")
    points = [obj.matrix_world @ Vector(corner) for obj in bpy.context.scene.objects if obj.type == "MESH" for corner in obj.bound_box]
    low = [min(p[axis] for p in points) for axis in range(3)]
    high = [max(p[axis] for p in points) for axis in range(3)]
    center = [(low[i] + high[i]) / 2 for i in range(3)]
    # Join by material to reduce draw calls while keeping the crafted components.
    for material in MATERIALS.values():
        objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.data.materials[0] == material]
        if not objects: continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        bpy.context.object.name = name + "_" + material.name
    path = OUT / f"{name}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_yup=True, export_extras=True)
    return {"id": name, "path": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "center": [round(center[0], 5), round(center[2], 5), round(-center[1], 5)], "size": [round(high[0] - low[0], 5), round(high[2] - low[2], 5), round(high[1] - low[1], 5)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", choices=["common", "all"], default="all")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    TEXTURES.mkdir(parents=True, exist_ok=True)
    make_materials()
    manifest_path = OUT / "manifest.json"
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"models": []}
    models = {entry["id"]: entry for entry in previous["models"]}
    for name in COMMON if args.batch == "common" else BUILDERS:
        models[name] = export_model(name)
        print("INTERIOR_MODEL_GENERATED", name, flush=True)
    textures = [{"path": str(path.relative_to(OUT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path in sorted(TEXTURES.glob("*.png"))]
    manifest = {"generator": "Blender " + bpy.app.version_string + " headless", "source": "tools/generate_interiors.py", "texture_size": [SIZE, SIZE], "models": [models[name] for name in sorted(models)], "textures": textures}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("INTERIOR_LIBRARY_GENERATED models=%d textures=%d" % (len(models), len(textures)), flush=True)


if __name__ == "__main__":
    main()
