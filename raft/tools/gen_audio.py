"""Generates the game's sounds procedurally.

Run from the project root:  python3 tools/gen_audio.py
Writes assets/sfx/*.wav and assets/sfx/ocean.ogg (needs numpy; ffmpeg for ogg).
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
rng = np.random.default_rng(11)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=8.0):
    t = np.arange(n) / SR
    return np.clip(t / max(attack, 1e-4), 0, 1) * np.exp(-t * decay)


def sweep(f0, f1, dur):
    f = np.linspace(f0, f1, int(SR * dur))
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


def bell(freqs, dur, decay=5.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for i, f in enumerate(freqs):
        out += np.sin(2 * np.pi * f * t) * np.exp(-t * decay * (1 + i * 0.6)) / (i + 1)
    return out


def norm(x, peak=0.7):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(*parts, gap=0.0):
    g = np.zeros(int(SR * gap))
    out = []
    for p in parts:
        out += [p, g]
    return np.concatenate(out)


def sfx():
    s = {}
    n = int(SR * 0.4)
    s["throw"] = highpass(lowpass(noise(0.4), 0.25), 0.05) * np.sin(np.linspace(0, np.pi, n)) ** 2
    splash = lowpass(noise(0.7), 0.3) * env(int(SR * 0.7), 0.004, 7)
    bubbles = mix(*[np.concatenate([np.zeros(int(SR * rng.uniform(0.05, 0.4))), sweep(f, f * 1.8, 0.05) * env(int(SR * 0.05), decay=40) * 0.3])
                    for f in rng.uniform(500, 900, 6)])
    s["splash"] = mix(splash, bubbles)
    s["snag"] = mix(sweep(320, 140, 0.09) * env(int(SR * 0.09), decay=30), highpass(noise(0.02), 0.6) * 0.5)
    s["pop"] = mix(sweep(280, 720, 0.09) * env(int(SR * 0.09), decay=28), np.concatenate([np.zeros(int(SR * 0.05)), bell([1320, 1980], 0.25, 12) * 0.4]))
    s["reel"] = highpass(noise(0.03), 0.7) * env(int(SR * 0.03), 0.001, 120)
    s["hammer"] = mix(bell([170, 410, 880], 0.3, 22), lowpass(noise(0.12), 0.2) * env(int(SR * 0.12), 0.001, 35))
    s["build_fail"] = seq(bell([140, 300], 0.12, 30), bell([120, 260], 0.16, 26), gap=0.05)
    s["eat"] = seq(*[highpass(noise(0.07), 0.45) * env(int(SR * 0.07), 0.002, 40) for _ in range(3)], gap=0.06)
    s["drink"] = seq(*[sweep(230, 120, 0.12) * env(int(SR * 0.12), 0.01, 18) for _ in range(3)], gap=0.08)
    rustle = lowpass(noise(0.35), 0.4) * np.sin(np.linspace(0, np.pi, int(SR * 0.35)))
    s["craft"] = mix(rustle * 0.6, np.concatenate([np.zeros(int(SR * 0.25)), bell([880, 1320], 0.4, 8) * 0.5]))
    s["click"] = sweep(1300, 1000, 0.03) * env(int(SR * 0.03), decay=80)
    t = t_axis(0.5)
    s["hurt"] = mix(sweep(160, 60, 0.5) * env(len(t), 0.005, 5), lowpass(noise(0.5), 0.1) * env(len(t), 0.005, 8))
    notes = [523.25, 659.25, 783.99, 1046.5]
    s["goal"] = np.concatenate([bell([f, f * 2], 0.13, 10) for f in notes[:-1]] + [bell([notes[-1], notes[-1] * 2], 0.7, 3)])
    s["ready"] = mix(bell([1046.5, 2093], 0.6, 5), np.concatenate([np.zeros(int(SR * 0.12)), bell([1318.5, 2637], 0.6, 5)]))
    crackle = np.zeros(int(SR * 0.6))
    for p in rng.integers(0, len(crackle) - 300, 25):
        crackle[p:p + 300] += highpass(noise(300 / SR), 0.8) * env(300, 0.0005, 300) * rng.uniform(0.3, 1.0)
    s["ignite"] = mix(lowpass(noise(0.6), 0.12) * np.sin(np.linspace(0, np.pi, int(SR * 0.6))) * 1.5, crackle * 0.6)
    crunch = np.concatenate([highpass(noise(0.05), 0.3) * env(int(SR * 0.05), 0.001, 30) for _ in range(4)])
    s["bite"] = mix(crunch, bell([95, 190], 0.4, 9) * 0.8, lowpass(noise(0.4), 0.06) * env(int(SR * 0.4), 0.002, 9))
    s["shark_hit"] = mix(bell([120, 260], 0.3, 18), lowpass(noise(0.5), 0.25) * env(int(SR * 0.5), 0.003, 8) * 0.8)
    t = t_axis(1.1)
    drone = np.sin(2 * np.pi * 73.4 * t) * 0.6 + np.sin(2 * np.pi * 77.8 * t) * 0.4
    s["warning"] = drone * (env(len(t), 0.02, 2.4) + np.concatenate([np.zeros(int(SR * 0.45)), env(len(t) - int(SR * 0.45), 0.02, 3.0)]))
    creak = sweep(180, 120, 0.35) * (0.6 + 0.4 * np.sin(np.linspace(0, 40, int(SR * 0.35)))) * env(int(SR * 0.35), 0.02, 5)
    s["door"] = mix(creak * 0.7, np.concatenate([np.zeros(int(SR * 0.3)), bell([140, 320], 0.2, 25)]))
    rumble = lowpass(noise(2.4), 0.012) * 9.0
    crack = highpass(noise(0.25), 0.5) * env(int(SR * 0.25), 0.001, 14)
    s["thunder"] = mix(crack * 0.6, rumble * env(int(SR * 2.4), 0.05, 1.6))
    os.makedirs(OUT, exist_ok=True)
    for name, x in s.items():
        write_wav(os.path.join(OUT, name + ".wav"), norm(x, 0.7))


def ocean():
    """A seamless 16 s loop: low rumble plus slow swells of surf hiss."""
    dur = 16.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    rumble = lowpass(noise(dur), 0.01) * 6.0
    hiss = highpass(lowpass(noise(dur), 0.3), 0.02)
    swell = np.zeros(n)
    for k, (period, phase) in enumerate([(16.0, 0.0), (8.0, 1.3), (5.333, 2.1)]):
        swell += (0.5 + 0.5 * np.sin(2 * np.pi * t / period + phase)) ** 3 / (k + 1)
    x = rumble * 0.6 + hiss * swell * 0.8
    fade = int(SR * 1.0)
    head = x[:fade].copy()
    x[-fade:] = x[-fade:] * np.linspace(1, 0, fade) + head * np.linspace(0, 1, fade)
    x = x[fade:]
    wav = os.path.join(OUT, "_ocean.wav")
    write_wav(wav, norm(x, 0.6))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, "ocean.ogg")], check=True)
    os.remove(wav)


def rain():
    """A seamless 8 s rain loop: bright hiss with soft patter."""
    dur = 8.0
    x = highpass(lowpass(noise(dur), 0.55), 0.08) * 0.5
    for p in rng.integers(0, len(x) - 200, 900):
        x[p:p + 200] += highpass(noise(200 / SR), 0.7) * env(200, 0.0005, 400) * rng.uniform(0.1, 0.5)
    fade = int(SR * 0.5)
    head = x[:fade].copy()
    x[-fade:] = x[-fade:] * np.linspace(1, 0, fade) + head * np.linspace(0, 1, fade)
    x = x[fade:]
    wav = os.path.join(OUT, "_rain.wav")
    write_wav(wav, norm(x, 0.55))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, "rain.ogg")], check=True)
    os.remove(wav)


def birds():
    """A gull's cry (two harsh falling calls) and a sail flapping open."""
    r = np.random.default_rng(23)
    calls = []
    for f0 in (1500, 1350):
        t = t_axis(0.32)
        f = f0 * (1 - 0.45 * (t / t[-1]) ** 0.7) * (1 + 0.03 * np.sin(2 * np.pi * 28 * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.35 * np.sin(3 * ph) + 0.2 * np.sin(5 * ph)
        rasp = highpass(r.standard_normal(len(t)) * 0.3, 0.3)
        calls.append((tone + rasp) * env(len(t), 0.015, 5) * np.sin(np.linspace(0, np.pi, len(t))) ** 0.4)
    write_wav(os.path.join(OUT, "gull.wav"), norm(seq(*calls, gap=0.09), 0.6))
    n = int(SR * 0.7)
    flutter = (np.sin(np.linspace(0, 2 * np.pi * 18, n)) * 0.5 + 0.5) ** 2
    body = lowpass(r.standard_normal(n), 0.15) * flutter * env(n, 0.02, 4)
    snap = np.concatenate([np.zeros(int(SR * 0.45)), lowpass(r.standard_normal(int(SR * 0.25)), 0.3) * env(int(SR * 0.25), 0.002, 25)])
    write_wav(os.path.join(OUT, "flap.wav"), norm(mix(body, snap * 1.2), 0.6))


if __name__ == "__main__":
    sfx()
    ocean()
    rain()
    birds()
    print("ok:", sorted(os.listdir(OUT)))
