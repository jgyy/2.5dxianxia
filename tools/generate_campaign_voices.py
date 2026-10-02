"""Synthetic eSpeak NG dialogue; no actor recordings or cloned voices."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/audio'
def main():
    command=os.environ.get('ESPEAK_COMMAND') or shutil.which('espeak-ng')
    if not command:raise SystemExit('Install espeak-ng, or provide ESPEAK_COMMAND.')
    c=json.loads((ROOT/'content/campaign/index.json').read_text());m={'source':'eSpeak NG synthetic female voices','voices':[]}
    for i,npc in enumerate(c['npcs']):
        line=f"I am {npc['name']}, the {npc['role']} of {c['regions'][i%12]['name']}. Read my account, hear the witnesses, and return when you know what this binding costs."
        path=OUT/f"voice_{npc['id']}.wav"
        subprocess.run([command,'-v',f'en+f{1+i%4}','-s',str(138+i%5*3),'-p',str(48+i%9*3),'-w',str(path),line],check=True,stdout=subprocess.DEVNULL)
        m['voices'].append({'id':npc['id'],'path':path.name,'text':line,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT/'campaign_voices.json').write_text(json.dumps(m,indent=2)+'\n');print('CAMPAIGN_VOICES_COMPLETE',len(m['voices']))
if __name__=='__main__':main()
