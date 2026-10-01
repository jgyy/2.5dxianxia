"""Run with blender --background --factory-startup --python tools/generate_world.py.

Creates 16 object families x 64 seeded geometric/material variations, each with
its own GLB and PNG texture. Sources, outputs, and hashes are recorded in JSON.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
import random
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/world"
OUT.mkdir(parents=True, exist_ok=True)
FAMILIES = ["bamboo", "pine", "rock", "crystal", "gate", "pavilion", "lantern", "bridge", "shrine", "wall", "bench", "sword", "urn", "banner", "pagoda", "ruin"]
COLORS = [(0.17, .35, .23), (.11, .27, .25), (.34, .42, .44), (.12, .72, .58), (.37, .24, .16), (.27, .18, .12), (.85, .44, .16), (.34, .25, .16), (.36, .44, .42), (.28, .35, .36), (.39, .28, .17), (.43, .62, .64), (.28, .5, .46), (.63, .18, .13), (.29, .25, .19), (.34, .4, .4)]


def cube(name, pos, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj


def cone(name, pos, r1, r2, depth, mat, verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def texture_material(family, variant, rng):
    color = COLORS[FAMILIES.index(family)]
    img = bpy.data.images.new(f"{family}_{variant:02}_albedo", width=32, height=32)
    pixels = []
    tint = [rng.uniform(.8, 1.15) for _ in range(3)]
    for y in range(32):
        for x in range(32):
            grain = rng.uniform(.8, 1.15) * (1.08 if (x + y + variant) % 7 == 0 else 1)
            pixels.extend([min(.98, c * tint[i] * grain) for i, c in enumerate(color)] + [1])
    img.pixels = pixels
    img.filepath_raw = str(OUT / f"{family}_{variant:02}.png")
    img.file_format = "PNG"
    img.save()
    mat = bpy.data.materials.new(f"{family}_{variant:02}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .82
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if family in ["crystal", "lantern"]:
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = .55
    return mat


def build(f, v, mat, rng):
    s = .85 + v / 180
    if f == "bamboo":
        h = rng.uniform(3.0, 5.6) * s
        for n in range(6):
            cone("Stem", (0, 0, h * (n + .5) / 6), .08, .07, h / 6, mat)
            cone("Joint", (0, 0, h * n / 6), .095, .095, .05, mat)
        for n in range(7):
            a = rng.uniform(0, math.tau)
            leaf = cube("Leaf", (math.cos(a) * .33, math.sin(a) * .33, h * rng.uniform(.5, .95)), (.85, .18, .045), mat)
            leaf.rotation_euler = (0, .28, a)
    elif f == "pine":
        cone("Trunk", (0, 0, 2 * s), .2, .12, 4 * s, mat)
        for n in range(4):
            cone("Needles", (0, 0, (2.3 + n * .65) * s), (1.5 - n * .27) * s, 0, 1.7 * s, mat, 9)
    elif f in ["rock", "ruin"]:
        for n in range(1 if f == "rock" else 4):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(n * .45, rng.uniform(-.2, .2), .4 * s))
            obj = bpy.context.object
            obj.name = "WeatheredStone"
            obj.scale = (rng.uniform(.5, 1.5) * s, rng.uniform(.6, 1.2) * s, rng.uniform(.5, 1.4) * s)
            obj.rotation_euler.z = rng.uniform(0, math.tau)
            obj.data.materials.append(mat)
    elif f == "crystal":
        for n in range(3):
            h = rng.uniform(.7, 1.5) * s
            obj = cone("Jade", ((n - 1) * .28, rng.uniform(-.15, .15), h / 2), .22, 0, h, mat, 5)
            obj.rotation_euler.y = (n - 1) * .2
    elif f == "gate":
        for x in [-2, 2]:
            cone("Pillar", (x * s, 0, 2.2 * s), .19, .16, 4.4 * s, mat)
        cube("Lintel", (0, 0, 3.8 * s), (5.3 * s, .35, .32), mat)
        cube("Roof", (0, 0, 4.35 * s), (5.8 * s, .65, .28), mat)
        for x in [-2.5, 2.5]:
            eave = cube("RaisedEave", (x * s, 0, 4.5 * s), (1.0 * s, .65, .25), mat)
            eave.rotation_euler.y = math.copysign(-.24, x)
    elif f in ["pavilion", "pagoda"]:
        tiers = 1 if f == "pavilion" else 3
        for level in range(tiers):
            z = level * 2.4 * s
            width = (3 - level * .45) * s
            cube("Floor", (0, 0, z + .2), (width, width, .3), mat)
            for x in [-1, 1]:
                for y in [-1, 1]:
                    cone("Column", (x * width * .4, y * width * .4, z + 1.3 * s), .12, .12, 2.2 * s, mat)
            roof = cone("Roof", (0, 0, z + 2.7 * s), width * .9, 0, 1.2 * s, mat, 4)
            roof.rotation_euler.z = math.pi / 4
    elif f == "lantern":
        cone("Post", (0, 0, 1.2 * s), .07, .07, 2.4 * s, mat)
        cone("Light", (0, 0, 2 * s), .35, .35, .55 * s, mat)
        cone("Cap", (0, 0, 2.4 * s), .5, .05, .25, mat, 4)
    elif f == "bridge":
        cube("Deck", (0, 0, .3), (3 * s, 5 * s, .3), mat)
        for x in [-1.45, 1.45]:
            cube("Rail", (x * s, 0, 1.0), (.1, 5 * s, .15), mat)
            for y in [-2, 0, 2]:
                cube("Post", (x * s, y * s, .7), (.15, .15, 1.0), mat)
    elif f == "shrine":
        for n in range(3):
            cube("Base", (0, 0, n * .2 + .1), ((2 - n * .3) * s, (2 - n * .3) * s, .2), mat)
        cube("Altar", (0, 0, 1.05 * s), (1.2 * s, .7 * s, 1.1 * s), mat)
        cone("SacredSpire", (0, 0, 1.8 * s), .5, 0, .8, mat, 4)
    elif f == "wall":
        cube("Wall", (0, 0, 1.1 * s), (3 * s, .4, 2.2 * s), mat)
        cube("Cap", (0, 0, 2.25 * s), (3.2 * s, .6, .18), mat)
    elif f == "bench":
        cube("Seat", (0, 0, .5), (1.8 * s, .5, .12), mat)
        for x in [-.65, .65]:
            cube("Leg", (x * s, 0, .25), (.12, .4, .5), mat)
    elif f == "sword":
        cube("Blade", (0, 0, 1.1 * s), (.12, .045, 1.6 * s), mat)
        cube("Guard", (0, 0, .4 * s), (.5, .12, .07), mat)
        cone("Grip", (0, 0, .2 * s), .07, .07, .4 * s, mat)
    elif f == "urn":
        cone("Foot", (0, 0, .1), .3 * s, .3 * s, .2, mat)
        cone("Belly", (0, 0, .45 * s), .35 * s, .55 * s, .6 * s, mat, 12)
        cone("Neck", (0, 0, .8 * s), .55 * s, .25 * s, .25 * s, mat, 12)
        cone("Lid", (0, 0, 1 * s), .32 * s, .1, .14, mat, 12)
    elif f == "banner":
        cone("Pole", (0, 0, 1.4 * s), .055, .055, 2.8 * s, mat)
        cube("Cloth", (.5 * s, 0, 2.0 * s), (1 * s, .025, 1.3 * s), mat)


def main():
    manifest = {"generator": "headless Blender", "blender": bpy.app.version_string, "seed": 7301, "models": []}
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    variants = 64 if not args else int(args[0])
    for fi, family in enumerate(FAMILIES):
        for v in range(variants):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            rng = random.Random(7301 + fi * 1000 + v)
            mat = texture_material(family, v, rng)
            build(family, v, mat, rng)
            path = OUT / f"{family}_{v:02}.glb"
            bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_draco_mesh_compression_enable=False)
            manifest["models"].append({"family": family, "variant": v, "glb": path.name, "texture": f"{family}_{v:02}.png", "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        print(f"ASSET_FAMILY_COMPLETE {family} {variants}", flush=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"WORLD_LIBRARY_COMPLETE {len(manifest['models'])}", flush=True)


if __name__ == "__main__":
    main()
