"""Export all permanent atlas regions as individual lossless RGBA sprite PNGs."""
import argparse,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument("--output",type=Path,required=True);parser.add_argument("--character")
args=parser.parse_args()
base=ROOT/"assets/sprites/motion"
manifest=json.loads((base/"manifest.json").read_text());count=0
for ident,item in manifest["characters"].items():
    if args.character and ident!=args.character:continue
    image=Image.open(base/"atlases"/item["atlas"])
    folder=args.output/ident;folder.mkdir(parents=True,exist_ok=True)
    for frame in item["frames"]:
        x,y,w,h=frame["rect"]
        image.crop((x,y,x+w,y+h)).save(folder/f"{frame['index']:02}.png","PNG")
        count+=1
assert count>0
print("SPRITE_PNG_EXPORT_PASS",count)
