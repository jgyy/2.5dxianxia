"""Verify and collect all rendered regions into a permanent, lossless library."""
import argparse,hashlib,json,shutil
from pathlib import Path
from PIL import Image
from build_motion_plan import build
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument("--input",type=Path,required=True)
args=parser.parse_args()
base=ROOT/"assets/sprites/motion";out=base/"atlases";out.mkdir(parents=True,exist_ok=True)
expected=build();ids={p["id"] for p in expected["characters"]}
characters={};hashes=set();reports=[]
for path in sorted(args.input.rglob("render.json")):
    report=json.loads(path.read_text());reports.append({"generator":report["generator"],"seconds":report["seconds"],"characters":len(report["characters"])})
    for item in report["characters"]:
        ident=item["id"];assert ident in ids and ident not in characters
        atlas=path.parent/item["atlas"]
        assert hashlib.sha256(atlas.read_bytes()).hexdigest()==item["sha256"]
        image=Image.open(atlas).convert("RGBA");assert image.size==(3200,1600)
        assert len(item["frames"])==50
        for frame in item["frames"]:
            x,y,w,h=frame["rect"];crop=image.crop((x,y,x+w,y+h))
            digest=hashlib.sha256(crop.tobytes()).hexdigest()
            assert digest==frame["pixel_sha256"] and digest not in hashes and crop.getchannel("A").getextrema()[1]>0
            hashes.add(digest)
        shutil.copyfile(atlas,out/item["atlas"])
        characters[ident]=item
assert set(characters)==ids and len(hashes)==11450
manifest={"format":1,"source":"Headless Blender renders of deformable UV cutout meshes using AI-upgraded existing artwork","generator_versions":sorted({r["generator"] for r in reports}),"layout":[10,5],"frame_size":[320,320],"state_counts":expected["states"],"playback_fps":{"idle":12,"walk":24,"attack":24,"death":12},"requested_additional_frames":10000,"rendered_additional_frames":11450,"separately_image_generated_poses":16,"remaining_additional_frames":0,"unique_live_designs":229,"characters":dict(sorted(characters.items()))}
(base/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
request={"requested":10000,"rendered":11450,"additional_authored_poses":16,"remaining":0,"status":"complete","scope":"Animation frames for the existing 100 NPCs, 100 monster species, 13 core identities and 16 Lin Yue appearances","state_frame_targets":expected["states"],"characters":[{"id":p["id"],"frames":50,"status":"complete"} for p in sorted(expected["characters"],key=lambda p:p["id"])]}
(ROOT/"assets/sprites/animation/request.json").write_text(json.dumps(request,indent=2)+"\n")
evidence={"rendered_frames":11450,"visible_distinct_pixel_hashes":len(hashes),"covered_live_designs":229,"state_counts":expected["states"],"frame_size":[320,320],"lossless_packing_verified":True,"regions":reports}
(ROOT/"docs/audit/motion-results.json").write_text(json.dumps(evidence,indent=2)+"\n")
print("COMPLETE_MOTION_LIBRARY_PASS",len(hashes),"frames",len(characters),"existing designs")
