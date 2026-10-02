"""Register source rectangles; never resize, paint, or recolor generated art."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/sprites/hires'

def main():
    (OUT/'frames').mkdir(exist_ok=True)
    m={'source':'ChatGPT image generation','requested_sheet_resolution':[4096,4096], 'layout':[8,8], 'poses':['idle','walk','attack','death'],'active_npcs':100,'active_monsters':100,'atlases':[], 'frames':[]}
    for kind in ['npc','monster','hero']:
        for sheet in range(1 if kind=='hero' else 7):
            path=OUT/f'{kind}_{sheet}.png';im=Image.open(path).convert('RGBA');w,h=im.size
            assert w>=1200 and h>=1200
            m['atlases'].append({'path':path.name,'size':[w,h],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
            for char in range(16):
                for pose in range(4):
                    x=((char%2)*4+pose)*w/8+1;y=(char//2)*h/8+1
                    rect=[x,y,w/8-2,h/8-2];id=f'{kind}_{sheet*16+char:03}_{pose}'
                    resource=f'frames/{id}.tres'
                    (OUT/resource).write_text(f'''[gd_resource type="AtlasTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/hires/{path.name}" id="1"]

[resource]
atlas = ExtResource("1")
region = Rect2({', '.join(map(str,rect))})
filter_clip = true
''')
                    pixels=im.crop((round(x),round(y),round(x+rect[2]),round(y+rect[3])))
                    assert pixels.getchannel('A').getextrema()[1]>0
                    m['frames'].append({'id':id,'character':sheet*16+char,'kind':kind,'pose':pose,'resource':resource,'rect':rect,'pixel_sha256':hashlib.sha256(pixels.tobytes()).hexdigest()})
    (OUT/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    print('HIRES_SPRITES_REGISTERED',len(m['frames']),'frames',m['atlases'][0]['size'])
if __name__=='__main__':main()
