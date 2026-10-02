"""Lossless packing of Blender renders; verify every frame has distinct visible pixels."""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument("--input",type=Path,required=True);parser.add_argument("--output",type=Path,required=True)
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
report=json.loads((args.input/"render.json").read_text())
result={k:v for k,v in report.items() if k!="characters"}
result["characters"]=[];all_hashes=set()
for person in report["characters"]:
    atlas=Image.new("RGBA",(3200,1600));frames=[]
    for index in range(50):
        frame=Image.open(args.input/person["id"]/f"{index:02}.png").convert("RGBA")
        assert frame.size==(320,320) and frame.getchannel("A").getextrema()[0]==0 and frame.getchannel("A").getextrema()[1]>0, (person["id"],index,frame.size,frame.getchannel("A").getextrema())
        digest=hashlib.sha256(frame.tobytes()).hexdigest()
        assert digest not in all_hashes, f"Duplicate rendered frame: {person['id']} {index}"
        all_hashes.add(digest)
        x=index%10*320;y=index//10*320
        atlas.paste(frame,(x,y))
        frames.append({"index":index,"rect":[x,y,320,320],"pixel_sha256":digest})
    path=args.output/f"{person['id']}.webp"
    atlas.save(path,"WEBP",lossless=True,exact=True,method=6)
    restored=Image.open(path).convert("RGBA")
    assert restored.tobytes()==atlas.tobytes()
    result["characters"].append({**person,"atlas":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"frames":frames})
(args.output/"render.json").write_text(json.dumps(result,indent=2)+"\n")
print("MOTION_PACK_PASS",len(all_hashes),flush=True)
