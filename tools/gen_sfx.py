#!/usr/bin/env python3
"""Reproducible, dependency-free arcade SFX. Run from any directory."""

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "assets/audio/sfx"
DURATIONS = {
    "countdown_tick": 0.17,
    "countdown_go": 0.47,
    "finish": 1.55,
    "crash": 0.62,
    "jump": 0.33,
    "land_clean": 0.22,
    "slime_land": 0.43,
    "boost": 0.53,
    "ui_tick": 0.045,
    "ui_confirm": 0.12,
}


def shape(t, duration, attack=0.008, decay=0.12):
    return min(1.0, t / attack) * math.exp(-t / decay) * min(1.0, (duration - t) / 0.012)


def tone(phase, brightness=0.25):
    return (math.sin(phase) + brightness * math.sin(2 * phase) +
            brightness * 0.28 * math.sin(3 * phase))


def synth(name, duration, rng):
    samples = []
    phase = 0.0
    smooth = 0.0
    for i in range(round(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        smooth += 0.085 * (noise - smooth)
        if name == "ui_tick":
            freq = 1050
            value = math.sin(phase) * shape(t, duration, 0.008, 0.018)
        elif name == "ui_confirm":
            freq = 660 if t < 0.055 else 880
            value = tone(phase, 0.1) * shape(t, duration, 0.003, 0.08)
        elif name == "countdown_tick":
            freq = 710 - 70 * min(t / duration, 1)
            value = tone(phase, 0.16) * shape(t, duration, 0.003, 0.065)
        elif name == "countdown_go":
            freq = 850 + 440 * min(t / 0.09, 1)
            value = tone(phase, 0.38) * shape(t, duration, 0.006, 0.27)
            value += 0.17 * math.sin(phase * 1.5) * shape(t, duration, 0.006, 0.2)
        elif name == "finish":
            # Three brass-like notes, then a held major chord.
            notes = ((0.00, 0.24, 523.25), (0.23, 0.24, 659.25),
                     (0.46, 0.24, 783.99), (0.69, 0.85, 1046.5))
            value = 0.0
            for start, length, pitch in notes:
                local = t - start
                if 0 <= local < length:
                    env = shape(local, length, 0.009, 0.50)
                    value += tone(2 * math.pi * pitch * local, 0.42) * env * 0.54
            if t >= 0.69:
                local = t - 0.69
                value += 0.18 * (math.sin(2 * math.pi * 659.25 * local) +
                                 math.sin(2 * math.pi * 783.99 * local)) * shape(local, 0.85, 0.009, 0.5)
            freq = 523.25
        elif name == "crash":
            freq = 155 * math.exp(-t * 7) + 39
            value = (0.85 * math.sin(phase) * shape(t, duration, 0.002, 0.16) +
                     0.67 * noise * shape(t, duration, 0.004, 0.11) +
                     0.27 * math.sin(2 * math.pi * 930 * t * math.exp(-2 * t)) *
                     shape(t, duration, 0.002, 0.24))
        elif name == "jump":
            freq = 310 + 370 * (1 - math.exp(-t * 15)) + 24 * math.sin(2 * math.pi * 19 * t) * math.exp(-t * 13)
            value = tone(phase, 0.34) * shape(t, duration, 0.004, 0.16)
        elif name == "land_clean":
            freq = 230 * math.exp(-t * 19) + 100
            value = (math.sin(phase) + 0.28 * smooth) * shape(t, duration, 0.002, 0.056)
        elif name == "slime_land":
            freq = 210 * math.exp(-t * 9) + 62 + 13 * math.sin(2 * math.pi * 12 * t)
            value = (0.8 * math.sin(phase) + 1.2 * smooth +
                     0.15 * noise * math.exp(-t * 23)) * shape(t, duration, 0.004, 0.19)
        else:  # boost: filtered noise sweep with rising whistle
            freq = 330 + 1100 * (t / duration) ** 1.4
            value = (0.9 * smooth + 0.42 * math.sin(phase)) * (
                math.sin(math.pi * t / duration) ** 0.8) * min(1.0, t / 0.012, (duration - t) / 0.012)
        phase += 2 * math.pi * freq / RATE
        samples.append(value)
    peak = max(abs(x) for x in samples)
    assert peak > 0, name
    gain = 10 ** (-3 / 20) / peak
    return [max(-32768, min(32767, round(x * gain * 32767))) for x in samples]


def generate():
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (name, duration) in enumerate(DURATIONS.items()):
        samples = synth(name, duration, random.Random(2600 + index))
        with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
            wav.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
            wav.writeframes(struct.pack(f"<{len(samples)}h", *samples))
        print(f"{name}: {len(samples) / RATE:.3f}s")


def check():
    for name, duration in DURATIONS.items():
        path = OUT / f"{name}.wav"
        assert path.is_file(), f"missing: {path}"
        with wave.open(str(path), "rb") as wav:
            assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, RATE), path
            actual = wav.getnframes() / RATE
            assert abs(actual - duration) < 0.001, (name, actual)
            data = wav.readframes(wav.getnframes())
        values = struct.unpack(f"<{len(data) // 2}h", data)
        peak = max(abs(v) for v in values) / 32768
        assert 0.6 < peak < 1.0, (name, peak)
        assert sum(v != 0 for v in values) > len(values) // 4, name
        assert max(abs(v) for v in values[:16] + values[-16:]) < 0.1 * 32768, name
        print(f"PASS {name}: {actual:.3f}s, {20 * math.log10(peak):.2f} dBFS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify generated WAV files")
    args = parser.parse_args()
    check() if args.check else generate()
