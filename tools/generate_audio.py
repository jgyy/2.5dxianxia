"""Generate original synthesized ambience/SFX and explicitly synthetic voices.

Usage: python3 tools/generate_audio.py --espeak /path/to/espeak-ng
Set ESPEAK_DATA_PATH when using an unpacked local installation.
"""
import argparse
import array
import json
import math
import os
from pathlib import Path
import random
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio"
RATE = 22050
LINES = {
    "arrival": ("en-gb", 145, 38, "Cloudrest valley. The mountain remembers. Find Mei beneath the lanterns."),
    "mei": ("en-us", 148, 62, "You carry his sword. Then you survived the fire. Bring me three moon lotus. Their roots remember clean water."),
    "shen": ("en-gb", 130, 24, "Three wardens hold the seals. Restore their altars. Qi is power. What you do with it is cultivation."),
    "lan": ("en-us", 143, 46, "At the summit, you may sever the binding, or inherit it. The mountain will remember your choice."),
    "seals": ("en-gb", 135, 40, "The three meridians breathe again. Immortal Xu waits at the ruined pagoda."),
    "xu": ("en-gb", 126, 20, "I only wanted to hear her laugh again. Tell me, cultivator. Was that too much to ask of heaven?"),
}


def write(name, values):
    samples = array.array("h", [int(max(-1, min(1, v)) * 28000) for v in values])
    with wave.open(str(OUT / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
        stream.writeframes(samples.tobytes())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--espeak", default="espeak-ng")
    args = parser.parse_args()
    OUT.mkdir(exist_ok=True, parents=True)
    rng = random.Random(7301)
    for name, duration in [("step", .12), ("sword", .28), ("hit", .18), ("hurt", .22), ("gather", .7), ("seal", 1.5)]:
        values = []
        for n in range(int(RATE * duration)):
            t = n / RATE
            envelope = math.sin(math.pi * t / duration) * math.exp(-t * (5 if name in ["gather", "seal"] else 12))
            if name in ["gather", "seal"]:
                value = sum(math.sin(math.tau * f * t) / (i + 1) for i, f in enumerate([440, 660, 880, 1100])) * .22
            elif name == "sword":
                value = rng.uniform(-1, 1) * .45 + math.sin(math.tau * (300 - t * 700) * t) * .1
            elif name == "step":
                value = rng.uniform(-1, 1) * .15
            else:
                value = rng.uniform(-1, 1) * .35 + math.sin(math.tau * 70 * t) * .25
            values.append(value * envelope)
        write(name, values)
    # Pentatonic plucked notes, wind, and a slow harmonic drone. Loop-safe fade.
    seconds = 24
    notes = [220, 246.94, 293.66, 329.63, 392, 440, 392, 329.63, 293.66, 246.94, 220, 293.66]
    values = []
    for n in range(RATE * seconds):
        t = n / RATE
        local = t % 2
        freq = notes[int(t / 2) % len(notes)]
        pluck = (math.sin(math.tau * freq * t) + .3 * math.sin(math.tau * freq * 2 * t)) * math.exp(-local * 3.6) * .16
        drone = (math.sin(math.tau * 110 * t) + math.sin(math.tau * 164.81 * t)) * .025
        fade = min(1, t, seconds - t)
        values.append((pluck + drone + rng.uniform(-.012, .012)) * fade)
    write("valley", values)
    for name, (voice, speed, pitch, line) in LINES.items():
        subprocess.run([args.espeak, "-v", voice, "-s", str(speed), "-p", str(pitch), "-w", str(OUT / f"voice_{name}.wav"), line], check=True)
    (OUT / "manifest.json").write_text(json.dumps({"music_and_sfx": "Original deterministic synthesis", "voices": "Local eSpeak NG synthetic speech, no human likeness", "dialogue": {k: v[3] for k, v in LINES.items()}}, indent=2) + "\n")
    print("AUDIO_LIBRARY_COMPLETE 7 ambience/effects, 6 synthetic voice clips")


if __name__ == "__main__":
    main()
