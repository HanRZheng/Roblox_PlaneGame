#!/usr/bin/env python3
"""Generate original, asset-free engine layers for Around the World V23."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 24_000
TAU = math.tau
OUTPUT = Path(__file__).resolve().parents[1] / "audio"


def shaped_noise(count: int, seed: int, smoothing: float) -> list[float]:
    random_source = random.Random(seed)
    value = 0.0
    result: list[float] = []
    for _ in range(count):
        value = value * smoothing + random_source.uniform(-1.0, 1.0) * (1.0 - smoothing)
        result.append(value)
    return result


def save(name: str, seconds: float, builder, looped: bool) -> None:
    count = int(seconds * RATE)
    noise = shaped_noise(count, sum(map(ord, name)), 0.82)
    samples = [builder(i / RATE, i / max(1, count - 1), noise[i]) for i in range(count)]
    if looped:
        blend_count = int(RATE * 0.24)
        opening = samples[:blend_count]
        for i in range(blend_count):
            blend = (i + 1) / blend_count
            samples[-blend_count + i] = samples[-blend_count + i] * (1 - blend) + opening[i] * blend
    peak = max(0.001, max(abs(value) for value in samples))
    scale = 0.88 / peak
    pcm = b"".join(struct.pack("<h", int(max(-1, min(1, value * scale)) * 32767)) for value in samples)
    with wave.open(str(OUTPUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm)


def idle(t: float, _: float, noise: float) -> float:
    pulse = 0.18 * math.sin(TAU * 54 * t) + 0.11 * math.sin(TAU * 108 * t + 0.5)
    fan = 0.12 * math.sin(TAU * 214 * t) + 0.05 * math.sin(TAU * 428 * t)
    return pulse + fan + noise * 1.15


def power(t: float, _: float, noise: float) -> float:
    fan = 0.22 * math.sin(TAU * 118 * t) + 0.12 * math.sin(TAU * 236 * t + 0.4)
    whine = 0.09 * math.sin(TAU * 705 * t) + 0.045 * math.sin(TAU * 1410 * t)
    modulation = 0.82 + 0.18 * math.sin(TAU * 7 * t)
    return (fan + whine) * modulation + noise * 1.75


def takeoff(t: float, _: float, noise: float) -> float:
    fan = 0.20 * math.sin(TAU * 146 * t) + 0.11 * math.sin(TAU * 292 * t + 0.2)
    turbine = 0.10 * math.sin(TAU * 912 * t) + 0.06 * math.sin(TAU * 1368 * t)
    roar = noise * (2.35 + 0.34 * math.sin(TAU * 5 * t))
    return fan + turbine + roar


def reverse(t: float, _: float, noise: float) -> float:
    cascade = 0.15 * math.sin(TAU * 86 * t) + 0.09 * math.sin(TAU * 172 * t)
    pulses = 0.72 + 0.28 * abs(math.sin(TAU * 8.5 * t))
    return cascade + noise * 2.65 * pulses


def shutdown(t: float, progress: float, noise: float) -> float:
    envelope = (1 - progress) ** 1.28
    frequency = 185 - 142 * progress
    phase = TAU * (185 * t - 71 * t * progress)
    wind_down = 0.34 * math.sin(phase) + 0.10 * math.sin(phase * 2.02)
    return envelope * (wind_down + noise * 1.25) + 0.02 * math.sin(TAU * frequency * t) * envelope


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    save("V23_Engine_Idle.wav", 4.0, idle, True)
    save("V23_Engine_Power.wav", 4.0, power, True)
    save("V23_Engine_Takeoff.wav", 5.0, takeoff, True)
    save("V23_Engine_Reverse.wav", 4.0, reverse, True)
    save("V23_Engine_Shutdown.wav", 4.2, shutdown, False)


if __name__ == "__main__":
    main()
