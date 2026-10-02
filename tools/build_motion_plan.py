"""Inventory every live sprite identity; do not create new cast members."""
import json, argparse
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
GROUPS = ["villagers","spirit_beasts","corrupted","sect_heroes","ancient_spirits","female_protagonist"]
STATES = {"idle":8, "walk":16, "attack":16, "death":10}

def build():
    hires=json.loads((ROOT/"assets/sprites/hires/manifest.json").read_text())
    legacy=json.loads((ROOT/"assets/sprites/manifest.json").read_text())
    hf={f["id"]:f for f in hires["frames"]}
    lf={f["id"]:f for f in legacy["frames"]}
    campaign=json.loads((ROOT/"content/campaign/index.json").read_text())
    plan=[]
    for person in campaign["npcs"]+campaign["monsters"]:
        ident=person["id"]; kind=ident.split("_")[0]; num=int(ident.split("_")[1])
        plan.append({"id":ident,"name":person["name"],"region":person["region"],"source":f"assets/sprites/hires/{kind}_{num//16}.png","rects":[hf[f"{ident}_{p}"]["rect"] for p in range(4)]})
    for n in range(16):
        ident=f"hero_{n:03}"
        plan.append({"id":ident,"name":f"Lin Yue appearance {n}","region":"region_00","source":"assets/sprites/hires/hero_0.png","rects":[hf[f"{ident}_{p}"]["rect"] for p in range(4)]})
    rows={(0,1),(0,2),(3,7),(4,15)}
    rows.update((2,2+i) for i in range(3))
    rows.update((2 if i%2==0 else 1,i%14) for i in range(8))
    for sheet,row in sorted(rows):
        ident=f"{GROUPS[sheet]}_{row:02}"
        plan.append({"id":ident,"name":ident,"region":"region_00","source":f"assets/sprites/atlas_{sheet}.png","rects":[lf[f"{ident}_{p:02}"]["rect"] for p in (0,4,8,12)]})
    assert len(plan)==229 and len({p["id"] for p in plan})==229
    return {"format":1,"frame_size":[320,320],"states":STATES,"characters":plan,"total_rendered_frames":len(plan)*sum(STATES.values())}

if __name__=="__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("--output",type=Path,default=ROOT/".tools/motion-plan.json")
    args=parser.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    plan=build();args.output.write_text(json.dumps(plan,indent=2)+"\n")
    print("MOTION_PLAN",len(plan["characters"]),plan["total_rendered_frames"])
