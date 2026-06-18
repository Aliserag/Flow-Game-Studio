#!/usr/bin/env python3
"""
WARBAND procedural music generator.

Produces looping drones with simple harmonic progressions for each phase.
NOT real music — placeholders that establish presence and tone. A composer
will replace them by overwriting the same paths.
"""

from pathlib import Path
import sys

import numpy as np
from scipy.io import wavfile

SAMPLE_RATE = 22050  # half rate to keep file sizes manageable
OUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "audio" / "music"


def fade(samples, fade_in=1.0, fade_out=1.0, sr=SAMPLE_RATE):
    n = len(samples)
    f_in = int(fade_in * sr)
    f_out = int(fade_out * sr)
    if f_in > 0:
        samples[:f_in] *= np.linspace(0, 1, f_in)
    if f_out > 0:
        samples[-f_out:] *= np.linspace(1, 0, f_out)
    return samples


def sine_drone(freqs, duration, sr=SAMPLE_RATE, vibrato_depth=2.0, vibrato_rate=0.3):
    """Sum of detuned sines with slow vibrato."""
    t = np.linspace(0, duration, int(sr * duration), endpoint=False)
    out = np.zeros_like(t, dtype=np.float32)
    for f in freqs:
        vibrato = vibrato_depth * np.sin(2 * np.pi * vibrato_rate * t)
        phase = 2 * np.pi * np.cumsum(f + vibrato) / sr
        out += np.sin(phase).astype(np.float32) / len(freqs)
    return out


def progression(chord_freqs_list, beat_duration, sr=SAMPLE_RATE):
    """Concatenate sine_drones built from each chord_freqs entry."""
    out = []
    for chord in chord_freqs_list:
        out.append(sine_drone(chord, beat_duration, sr))
    return np.concatenate(out)


def slow_pulse(freq, beat_freq, duration, sr=SAMPLE_RATE):
    """Sine wave with slow amplitude pulse — heartbeat-like."""
    base = sine_drone([freq], duration, sr)
    t = np.linspace(0, duration, int(sr * duration), endpoke=False) if False else \
        np.linspace(0, duration, int(sr * duration), endpoint=False)
    pulse = 0.5 + 0.5 * np.sin(2 * np.pi * beat_freq * t)
    return base * pulse.astype(np.float32)


def low_drum(beat_freq, total_duration, sr=SAMPLE_RATE):
    """Periodic short low-frequency hits."""
    out = np.zeros(int(sr * total_duration), dtype=np.float32)
    hit_dur = int(0.18 * sr)
    interval = int(sr / beat_freq)
    t_hit = np.linspace(0, 0.18, hit_dur, endpoint=False)
    hit = np.sin(2 * np.pi * 60 * t_hit) * np.exp(-6 * np.linspace(0, 1, hit_dur))
    for start in range(0, len(out) - hit_dur, interval):
        out[start:start + hit_dur] += hit.astype(np.float32)
    return out


def save_wav(name, samples, peak_db=-12.0):
    samples = np.clip(samples, -1, 1)
    peak = np.max(np.abs(samples))
    if peak > 0:
        target = 10 ** (peak_db / 20.0)
        samples = samples * (target / peak)
    pcm = (samples * 32767).astype(np.int16)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / name
    wavfile.write(out, SAMPLE_RATE, pcm)
    size_kb = out.stat().st_size / 1024
    print(f"  wrote {out.relative_to(OUT_DIR.parent.parent.parent)}  ({size_kb:.0f} KB, {len(pcm)/SAMPLE_RATE:.1f}s)")


# Music chords (Hz). Low desaturated minor triads.
A_MINOR    = [110, 130.81, 164.81]
D_MINOR    = [73.42, 110, 146.83]
F_MAJOR    = [87.31, 130.81, 174.61]
E_MINOR    = [82.41, 123.47, 164.81]


def make_menu():
    """Slow, contemplative drone."""
    progression_chords = [A_MINOR, D_MINOR, F_MAJOR, E_MINOR]
    music = progression(progression_chords, beat_duration=4.0)
    music = fade(music, fade_in=2.0, fade_out=2.0)
    save_wav("mus_menu_main_loop.wav", music)


def make_tavern():
    """Smoky, low strings drone."""
    progression_chords = [A_MINOR, A_MINOR, D_MINOR, A_MINOR]
    music = progression(progression_chords, beat_duration=3.5)
    music = fade(music, fade_in=1.5, fade_out=1.5)
    save_wav("mus_tavern_weighted_loop.wav", music)


def make_map():
    """Sparse, tense drone with very slow pulse."""
    progression_chords = [E_MINOR, A_MINOR, E_MINOR, D_MINOR]
    music = progression(progression_chords, beat_duration=3.0)
    music = fade(music, fade_in=1.0, fade_out=1.0)
    save_wav("mus_map_traverse_loop.wav", music)


def make_battle():
    """Driving low drum + brass-like square overlay."""
    duration = 16.0
    drum = low_drum(beat_freq=2.4, total_duration=duration) * 0.6
    progression_chords = [A_MINOR, E_MINOR, A_MINOR, F_MAJOR]
    brass = progression(progression_chords, beat_duration=4.0) * 0.4
    music = drum[:len(brass)] + brass[:len(drum)]
    music = fade(music, fade_in=0.5, fade_out=1.0)
    save_wav("mus_battle_drive_loop.wav", music)


def make_victory():
    """Restrained stinger — single dignified chord with slow fade."""
    music = sine_drone(A_MINOR, 4.0)
    music = fade(music, fade_in=0.2, fade_out=2.5)
    save_wav("mus_victory_stinger.wav", music)


def make_gameover():
    """Grim low single note + slow decay."""
    music = sine_drone([55, 73.42], 5.0)  # low A + D
    music = fade(music, fade_in=0.5, fade_out=3.5)
    save_wav("mus_gameover_stinger.wav", music)


def main() -> int:
    print(f"Generating WARBAND procedural music → {OUT_DIR}")
    make_menu()
    make_tavern()
    make_map()
    make_battle()
    make_victory()
    make_gameover()
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
