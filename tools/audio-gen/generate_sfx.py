#!/usr/bin/env python3
"""
WARBAND procedural SFX generator.

Generates simple WAV files matching the events defined in data/audio.json.
These are basic synthesized placeholders — sine/triangle/noise envelopes,
not finished sound design. A real audio team will replace them by overwriting
the same paths.

Usage:
    pip install numpy scipy
    python3 tools/audio-gen/generate_sfx.py
"""

from pathlib import Path
import sys

import numpy as np
from scipy.io import wavfile

SAMPLE_RATE = 44100
OUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "audio" / "sfx"


def envelope(samples, attack=0.005, decay=0.15):
    """Exponential decay envelope applied in-place. Clamps to sample count."""
    n = len(samples)
    a_n = min(int(attack * SAMPLE_RATE), n)
    d_n = min(int(decay * SAMPLE_RATE), n - a_n)
    env = np.zeros(n, dtype=np.float32)
    if a_n > 0:
        env[:a_n] = np.linspace(0, 1, a_n)
    if d_n > 0:
        env[a_n:a_n + d_n] = np.exp(-3 * np.linspace(0, 1, d_n))
    return samples * env


def sine(freq, duration, sr=SAMPLE_RATE):
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    return np.sin(2 * np.pi * freq * t).astype(np.float32)


def square(freq, duration, sr=SAMPLE_RATE):
    return np.sign(sine(freq, duration, sr)).astype(np.float32)


def noise(duration, sr=SAMPLE_RATE):
    return np.random.uniform(-1, 1, int(sr * duration)).astype(np.float32)


def pitch_sweep(start_freq, end_freq, duration, sr=SAMPLE_RATE):
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    freq = np.linspace(start_freq, end_freq, len(t))
    phase = 2 * np.pi * np.cumsum(freq) / sr
    return np.sin(phase).astype(np.float32)


def save_wav(name, samples, peak_db=-1.0):
    samples = np.clip(samples, -1, 1)
    peak = np.max(np.abs(samples))
    if peak > 0:
        target = 10 ** (peak_db / 20.0)
        samples = samples * (target / peak)
    pcm = (samples * 32767).astype(np.int16)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / name
    wavfile.write(out, SAMPLE_RATE, pcm)
    print(f"  wrote {out.relative_to(OUT_DIR.parent.parent.parent)}  ({len(pcm)/SAMPLE_RATE*1000:.0f} ms)")


def make_hit():
    """Thud + light metallic ping."""
    body = envelope(sine(120, 0.18), attack=0.002, decay=0.18) * 0.7
    metal = envelope(noise(0.05), attack=0.001, decay=0.05) * 0.3
    metal_high = envelope(sine(1200, 0.04), attack=0.001, decay=0.04) * 0.2
    out = body + np.pad(metal, (0, len(body) - len(metal))) \
              + np.pad(metal_high, (0, len(body) - len(metal_high)))
    save_wav("sfx_combat_hit_blade_01.wav", out)


def make_crit():
    """Heavier impact + bigger ring."""
    body = envelope(sine(80, 0.28), attack=0.002, decay=0.28) * 0.8
    ring = envelope(sine(440, 0.20), attack=0.005, decay=0.18) * 0.4
    crack = envelope(noise(0.06), attack=0.001, decay=0.06) * 0.5
    out = body + np.pad(ring, (0, len(body) - len(ring))) \
              + np.pad(crack, (0, len(body) - len(crack)))
    save_wav("sfx_combat_hit_crit_01.wav", out)


def make_orc_death():
    """Throaty grunt — falling pitch sweep + breathy noise."""
    duration = 0.45
    grunt = envelope(pitch_sweep(220, 80, duration), attack=0.01, decay=0.45) * 0.7
    breath = envelope(noise(duration), attack=0.05, decay=0.4) * 0.2
    save_wav("sfx_combat_orc_death_01.wav", grunt + breath)


def make_kill_banner():
    """A short brass-like stinger — two-tone descending."""
    a = envelope(square(440, 0.10), attack=0.002, decay=0.10) * 0.4
    b = envelope(square(330, 0.18), attack=0.002, decay=0.18) * 0.5
    out = np.concatenate([a, b])
    save_wav("sfx_ui_kill_banner_01.wav", out)


def make_hire_bell():
    """Single bell ring."""
    fund = envelope(sine(660, 0.55), attack=0.003, decay=0.55) * 0.6
    harm = envelope(sine(1320, 0.40), attack=0.003, decay=0.40) * 0.3
    out = fund + np.pad(harm, (0, len(fund) - len(harm)))
    save_wav("sfx_ui_hire_bell_01.wav", out)


def make_gold_spend():
    """Two short coin-like clinks."""
    a = envelope(sine(1100, 0.06), attack=0.001, decay=0.06) * 0.5
    b = envelope(sine(880, 0.08), attack=0.001, decay=0.08) * 0.4
    silence = np.zeros(int(0.05 * SAMPLE_RATE), dtype=np.float32)
    out = np.concatenate([a, silence, b])
    save_wav("sfx_ui_gold_spend_01.wav", out)


def make_ui_click():
    """Soft tick."""
    out = envelope(sine(500, 0.04), attack=0.001, decay=0.04) * 0.4
    save_wav("sfx_ui_button_click_01.wav", out)


def make_boss_intro():
    """Low rumble + horn."""
    duration = 1.4
    horn = envelope(square(110, duration), attack=0.05, decay=duration) * 0.5
    rumble = envelope(noise(duration), attack=0.10, decay=duration) * 0.25
    # low-pass filter the rumble crudely with a moving average
    win = 50
    rumble = np.convolve(rumble, np.ones(win) / win, mode="same").astype(np.float32)
    save_wav("sfx_combat_boss_intro_01.wav", horn + rumble)


def main() -> int:
    print(f"Generating WARBAND procedural SFX → {OUT_DIR}")
    make_hit()
    make_crit()
    make_orc_death()
    make_kill_banner()
    make_hire_bell()
    make_gold_spend()
    make_ui_click()
    make_boss_intro()
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
