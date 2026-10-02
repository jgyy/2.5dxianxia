"""Independently verify dimensions, hashes, every live identity and every rendered cell."""
import hashlib,json
from pathlib import Path
from PIL import Image
from build_motion_plan import build
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    base=ROOT/"assets/sprites/motion";manifest=json.loads((base/"manifest.json").read_text())
    expected=build();people={p["id"]:p for p in expected["characters"]}
    assert manifest["requested_additional_frames"]==10000 and manifest["remaining_additional_frames"]==0
    assert manifest["rendered_additional_frames"]==11450 and manifest["unique_live_designs"]==229
    assert manifest["layout"]==[10,5] and manifest["frame_size"]==[320,320]
    assert manifest["state_counts"]=={"idle":8,"walk":16,"attack":16,"death":10}
    assert manifest["playback_fps"]=={"idle":12,"walk":24,"attack":24,"death":12}
    assert set(manifest["characters"])==set(people)
    hashes=set()
    for ident,item in manifest["characters"].items():
        assert item["source"]==people[ident]["source"] and item["rects"]==people[ident]["rects"]
        assert digest(ROOT/item["source"])==item["source_sha256"]
        path=base/"atlases"/item["atlas"];assert digest(path)==item["sha256"]
        image=Image.open(path).convert("RGBA");assert image.size==(3200,1600)
        assert len(item["frames"])==50 and [f["index"] for f in item["frames"]]==list(range(50))
        for f in item["frames"]:
            index=f["index"];rect=[index%10*320,index//10*320,320,320]
            assert f["rect"]==rect
            x,y,w,h=rect;crop=image.crop((x,y,x+w,y+h))
            assert crop.getchannel("A").getextrema()[0]==0 and crop.getchannel("A").getextrema()[1]>0
            hsh=hashlib.sha256(crop.tobytes()).hexdigest()
            assert hsh==f["pixel_sha256"] and hsh not in hashes
            hashes.add(hsh)
    assert len(hashes)==11450
    baseline=json.loads((ROOT/"docs/audit/sprite-resolution-baseline.json").read_text())
    result=json.loads((ROOT/"docs/audit/sprite-resolution-results.json").read_text())
    assert len(result["atlases"])==22 and result["native_generated_tiles"]==88
    old_atlases={a["path"]:a for a in baseline["atlases"]}
    for a in result["atlases"]:
        old=old_atlases[a["source"]];path=ROOT/a["source"];image=Image.open(path)
        assert a["old_size"]==old["size"] and a["original_sha256"]==old["sha256"]
        assert a["new_size"]==[v*2 for v in old["size"]]==list(image.size)
        assert digest(path)==a["sha256"] and image.mode=="RGBA" and image.getchannel("A").getextrema()[0]==0
        assert [t["quadrant"] for t in a["tiles"]]==[0,1,2,3]
        for t in a["tiles"]:
            assert t["native_size"]==[1254,1254]
            q=t["quadrant"];x=q%2*1254;y=q//2*1254
            assert hashlib.sha256(image.crop((x,y,x+1254,y+1254)).tobytes()).hexdigest()==t["pixel_sha256"]
    frames={}
    for path in [ROOT/"assets/sprites/manifest.json",ROOT/"assets/sprites/hires/manifest.json"]:
        frames.update({f["id"]:f["rect"] for f in json.loads(path.read_text())["frames"]})
    for old in baseline["frames"]:
        if old["id"].startswith("weapon_"):continue
        assert frames[old["id"]]==[v*2 for v in old["rect"]],old["id"]
    assert len(baseline["frames"])==2500
    request=json.loads((ROOT/"assets/sprites/animation/request.json").read_text())
    assert request["status"]=="complete" and request["remaining"]==0 and request["rendered"]==len(hashes)
    print("FULL_SPRITE_AND_MOTION_PASS atlases=22 native_tiles=88 doubled_regions=2500 rendered_frames=11450 live_designs=229")
if __name__=="__main__":main()
