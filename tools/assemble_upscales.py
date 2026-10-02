"""Losslessly arrange native AI-generated quarter tiles; no resampling or painting."""
import argparse,hashlib,json,subprocess
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument("--tiles",type=Path,required=True);parser.add_argument("--source-ref",required=True)
args=parser.parse_args()
manifest=json.loads((args.tiles/"manifest.json").read_text())
assert manifest["required_tiles"]==len(manifest["tiles"])==88
baseline=json.loads((ROOT/"docs/audit/sprite-resolution-baseline.json").read_text())
records=[]
for old in baseline["atlases"]:
    tiles=sorted([t for t in manifest["tiles"] if t["source"]==old["path"]],key=lambda t:t["quadrant"])
    assert [t["quadrant"] for t in tiles]==[0,1,2,3]
    atlas=Image.new("RGBA",(2508,2508));evidence=[]
    for tile in tiles:
        path=args.tiles/Path(tile["path"]).name
        assert subprocess.check_output(["git","hash-object",str(path)],text=True).strip()==tile["blob"]
        image=Image.open(path)
        assert image.mode=="RGBA" and image.size==(1254,1254) and image.getchannel("A").getextrema()[0]==0
        x=tile["quadrant"]%2*1254;y=tile["quadrant"]//2*1254
        atlas.paste(image,(x,y))
        assert atlas.crop((x,y,x+1254,y+1254)).tobytes()==image.tobytes()
        evidence.append({"quadrant":tile["quadrant"],"native_size":[1254,1254],"blob":tile["blob"],"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"pixel_sha256":hashlib.sha256(image.tobytes()).hexdigest()})
    path=ROOT/old["path"];atlas.save(path,"PNG",compress_level=6)
    restored=Image.open(path);assert restored.tobytes()==atlas.tobytes()
    records.append({"source":old["path"],"original_sha256":old["sha256"],"old_size":old["size"],"new_size":[2508,2508],"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"tiles":evidence})
report={"method":"ChatGPT image generation, exact-quarter references, native 2x tiles, lossless assembly without resampling","source_reference":"jgyy/2.5dxianxia@"+args.source_ref,"original_ref":baseline["original_ref"],"scale":2,"atlases":records,"source_atlases":22,"native_generated_tiles":88,"original_frame_regions":len(baseline["frames"])}
(ROOT/"docs/audit/sprite-resolution-results.json").write_text(json.dumps(report,indent=2)+"\n")
print("SPRITE_UPSCALE_ASSEMBLY_PASS",len(records),"atlases",len(manifest["tiles"]),"native tiles")
