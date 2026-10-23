"""Generates all game sounds and the background music procedurally.

Run from the project root:  python3 tools/gen_audio.py
Writes assets/sfx/*.wav and assets/music/*.ogg (needs numpy; ffmpeg for ogg).
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "music")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=8.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t * decay)


def sweep(f0, f1, dur):
    t = t_axis(dur)
    f = np.linspace(f0, f1, len(t))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def highpass(x, alpha):
    return x - lowpass(x, alpha)


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def bell(freqs, dur, decay=5.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        out += np.sin(2 * np.pi * f * t) * np.exp(-t * decay * (1 + i * 0.6)) / (i + 1)
    return out


def sfx():
    s = {}
    s["tap"] = sweep(500, 900, 0.07) * env(int(SR * 0.07), decay=40)
    s["lavash"] = lowpass(noise(0.16), 0.08) * env(int(SR * 0.16), 0.01, 18) * 3
    chop = highpass(noise(0.14), 0.5) * env(int(SR * 0.14), 0.02, 22)
    click = sweep(2400, 1800, 0.02) * env(int(SR * 0.02), decay=120)
    chop[: len(click)] += click * 0.6
    s["chop"] = chop
    s["plop"] = sweep(420, 240, 0.09) * env(int(SR * 0.09), decay=30)
    roll = lowpass(noise(0.3), 0.15) * np.sin(np.linspace(0, np.pi, int(SR * 0.3))) ** 2
    s["roll"] = roll * 2
    s["clank"] = bell([620, 1170, 1830, 2650], 0.3, 14)
    s["perfect"] = bell([1320, 1980], 0.35, 7)
    cash = np.concatenate([bell([880, 1760], 0.09, 18), bell([1320, 2640], 0.4, 6)])
    coins = highpass(noise(0.49), 0.6) * env(int(SR * 0.49), 0.001, 14) * 0.15
    s["cash"] = cash + coins
    t = t_axis(0.35)
    saw = 2 * ((150 * t + 3 * np.sin(2 * np.pi * 9 * t)) % 1) - 1
    s["angry"] = lowpass(saw, 0.2) * env(len(t), 0.01, 6)
    s["bell"] = bell([1500, 2010, 3100], 0.6, 5)
    s["burnt"] = lowpass(noise(0.4), 0.05) * env(int(SR * 0.4), 0.05, 6) * 3
    s["error"] = np.concatenate([sweep(220, 200, 0.08), np.zeros(int(SR * 0.04)), sweep(180, 160, 0.12)]) * 0.7
    s["ui"] = sweep(1200, 1000, 0.03) * env(int(SR * 0.03), decay=80)
    notes = [523.25, 659.25, 783.99, 1046.5]
    s["jingle"] = np.concatenate([bell([f, f * 2], 0.16, 9) for f in notes[:-1]] + [bell([notes[-1], notes[-1] * 2], 0.8, 3)])
    sizzle = highpass(noise(2.0), 0.7) * 0.25
    crackle = np.zeros(int(SR * 2.0))
    for p in rng.integers(0, len(crackle) - 400, 60):
        crackle[p:p + 400] += highpass(noise(400 / SR), 0.8) * env(400, 0.0005, 300) * rng.uniform(0.3, 1.0)
    loop = sizzle + crackle
    fade = int(SR * 0.05)
    loop[:fade] *= np.linspace(0, 1, fade)
    loop[-fade:] *= np.linspace(1, 0, fade)
    s["sizzle"] = loop
    rain = lowpass(noise(3.0), 0.35) * 0.5 + highpass(noise(3.0), 0.9) * 0.15
    fade = int(SR * 0.08)
    rain[:fade] *= np.linspace(0, 1, fade)
    rain[-fade:] *= np.linspace(1, 0, fade)
    s["rain"] = rain
    os.makedirs(SFX_DIR, exist_ok=True)
    for name, x in s.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), norm(x, 0.5 if name in ("sizzle", "rain") else 0.7))


def music():
    """Cozy lo-fi loop: 8 bars at 88 bpm, Fmaj7 - Em7 - Dm7 - Cmaj7."""
    bpm = 88
    beat = 60 / bpm
    bars = 8
    total = int(SR * beat * 4 * bars)
    out = np.zeros(total)
    chords = [
        [174.61, 220.0, 261.63, 329.63],
        [164.81, 196.0, 246.94, 293.66],
        [146.83, 174.61, 220.0, 261.63],
        [130.81, 164.81, 196.0, 246.94],
    ]

    def add(x, start):
        s = int(start * SR)
        e = min(total, s + len(x))
        out[s:e] += x[: e - s]

    def pluck(f, dur, vol):
        t = t_axis(dur)
        tone = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t) + 0.1 * np.sin(2 * np.pi * 3 * f * t)
        return tone * env(len(t), 0.01, 2.2) * vol

    for bar in range(bars):
        ch = chords[bar % 4]
        b0 = bar * 4 * beat
        add(pluck(ch[0] / 2, beat * 2, 0.5), b0)
        add(pluck(ch[0] / 2, beat * 1.5, 0.35), b0 + beat * 2.5)
        for k, f in enumerate(ch[1:]):
            add(pluck(f, beat * 3, 0.16), b0 + k * 0.03)
            add(pluck(f, beat * 2, 0.11), b0 + beat * 2 + k * 0.03)
        melody = [ch[3] * 2, ch[2] * 2, ch[3] * 2, ch[1] * 2]
        for k in range(4):
            if (bar + k) % 3 != 2:
                add(pluck(melody[k], beat * 0.9, 0.08), b0 + k * beat + beat * 0.5)
        for k in range(8):
            hat = highpass(noise(0.05), 0.8) * env(int(SR * 0.05), 0.001, 70) * (0.05 if k % 2 else 0.03)
            add(hat, b0 + k * beat / 2)
        for k in (0, 2):
            kick = sweep(110, 45, 0.18) * env(int(SR * 0.18), 0.002, 14) * 0.5
            add(kick, b0 + k * beat)
    out = lowpass(out, 0.35)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    wav = os.path.join(MUSIC_DIR, "night_loop.wav")
    write_wav(wav, norm(out, 0.6))
    ogg = os.path.join(MUSIC_DIR, "night_loop.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)


if __name__ == "__main__":
    sfx()
    music()
    print("audio generated")
