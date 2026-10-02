"""Independent validation of new image sources, frame mappings, GLBs, and voices."""
import hashlib,json,struct,wave
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    base=ROOT/'assets/sprites/hires';m=json.loads((base/'manifest.json').read_text())
    assert len(m['atlases'])==15 and len(m['frames'])==960
    sources={}
    for a in m['atlases']:
        p=base/a['path'];assert sha(p)==a['sha256'];im=Image.open(p).convert('RGBA');assert list(im.size)==a['size'];assert im.getchannel('A').getextrema()[0]==0;sources[a['path']]=im
    hashes=set()
    for f in m['frames']:
        sheet=f['character']//16;p=sources[f['kind']+f'_{sheet}.png'];x,y,w,h=f['rect']
        assert w>=150 and h>=150 and 0<=x<x+w<=p.width and 0<=y<y+h<=p.height
        pix=p.crop((round(x),round(y),round(x+w),round(y+h)))
        assert pix.getchannel('A').getextrema()[1]>0
        hsh=hashlib.sha256(pix.tobytes()).hexdigest();assert hsh==f['pixel_sha256'];hashes.add(hsh)
        resource=(base/f['resource']).read_text();assert 'filter_clip = true' in resource
        assert 'Rect2('+', '.join(map(str,f['rect']))+')' in resource
    assert len(hashes)==960
    c=json.loads((ROOT/'content/campaign/index.json').read_text())
    ids={f['id'] for f in m['frames']}
    for person in c['npcs']+c['monsters']:
        for pose in range(4):assert person['id']+f'_{pose}' in ids
    base=ROOT/'assets/landmarks';landmarks=json.loads((base/'manifest.json').read_text())['models'];assert len(landmarks)==36
    assert len({x['region'] for x in landmarks})==12
    model_hashes=set();tex_hashes=set()
    for lm in landmarks:
        p=base/lm['path'];h=sha(p);assert h==lm['sha256'];model_hashes.add(h)
        ptex=base/lm['texture'];assert sha(ptex)==lm['texture_sha256'];tex_hashes.add(sha(ptex));assert Image.open(ptex).size==(128,128)
        data=p.read_bytes();magic,version,length=struct.unpack_from('<4sII',data);assert magic==b'glTF' and version==2 and length==len(data)
        size,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a;doc=json.loads(data[20:20+size]);assert doc['meshes'] and doc['materials'] and doc['images'];assert all('bufferView' in i for i in doc['images'])
    assert len(model_hashes)==len(tex_hashes)==36
    voice=json.loads((ROOT/'assets/audio/campaign_voices.json').read_text());assert len(voice['voices'])==100
    for item in voice['voices']:
        p=ROOT/'assets/audio'/item['path'];assert sha(p)==item['sha256']
        with wave.open(str(p)) as wav:assert wav.getnframes()>0 and wav.getnchannels()==1
    print('EXPANSION_ASSETS_PASS frames=960 npc_actors=100 monster_actors=100 landmarks=36 voices=100')
if __name__=='__main__':main()
