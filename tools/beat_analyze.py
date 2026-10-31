"""Карта бітів для треків гри (для візуальних ефектів під музику).
Запуск: python3 tools/beat_analyze.py   (з кореня проєкту; потрібні ffmpeg, numpy, scipy)
Читає список треків з scripts/autoload/audio.gd (TRACKS: id + path), аналізує кожен файл
і записує scripts/autoload/beat_maps.gd — константу MAPS: id → [час, сила, час, сила, …].
  час  — момент біта, с від початку треку;
  сила — 0..1: наскільки «вдаряє» біт (низькі частоти — бочка/бас) з урахуванням гучності ділянки,
         тож у тихому вступі пульсація слабка, а в приспіві — сильна.
Алгоритм (без librosa): onset-огинаюча (спектральний потік), темп — автокореляція з пріоритетом ~120 BPM,
біти — динамічне програмування (Ellis, 2007), сила — потік низьких частот біля біта.
Новий трек у TRACKS — просто перезапустити скрипт."""
import json, os, re, subprocess, sys
import numpy as np
from scipy.signal import stft
from scipy.ndimage import maximum_filter1d, uniform_filter1d

SR = 22050
HOP = 512
NFFT = 2048
FPS = SR / HOP


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def onset_envelopes(y):
    f, _, z = stft(y, fs=SR, nperseg=NFFT, noverlap=NFFT - HOP, boundary=None, padded=False)
    mag = np.log1p(100.0 * np.abs(z))
    flux = np.maximum(0.0, np.diff(mag, axis=1))
    full = flux.sum(axis=0)
    low = flux[f < 160.0].sum(axis=0)          # бочка й бас
    rms = np.sqrt(np.maximum(uniform_filter1d(np.abs(z[f < 4000.0]).mean(axis=0) ** 2, size=int(FPS)), 0.0))[1:]
    def norm(e):
        e = e - uniform_filter1d(e, size=int(FPS))  # прибираємо повільний фон
        e = np.maximum(e, 0.0)
        return e / (np.percentile(e, 99) + 1e-9)
    return norm(full), norm(low), rms / (np.percentile(rms, 95) + 1e-9)


def tempo(env):
    env = env - env.mean()
    ac = np.correlate(env, env, mode="full")[len(env) - 1:]
    lags = np.arange(len(ac))
    bpm = 60.0 * FPS / np.maximum(lags, 1)
    ok = (bpm >= 70) & (bpm <= 190)
    prior = np.exp(-0.5 * (np.log2(bpm / 120.0) / 0.9) ** 2)
    score = np.where(ok, ac * prior, -np.inf)
    lag = int(np.argmax(score))
    # Уточнення: параболічна інтерполяція піку.
    if 1 <= lag < len(ac) - 1:
        a, b, c = ac[lag - 1], ac[lag], ac[lag + 1]
        lag = lag + 0.5 * (a - c) / (a - 2 * b + c + 1e-9)
    # Повільніше за 95 BPM — майже завжди половинний темп (бочка на кожну другу долю):
    # для пульсації під музику беремо подвійний.
    if 60.0 * FPS / lag < 95.0:
        lag /= 2.0
    return 60.0 * FPS / lag, lag


def track_beats(env, period, tightness=100.0):
    n = len(env)
    score = env.copy()
    back = np.full(n, -1)
    lo, hi = int(round(period / 2)), int(round(period * 2))
    for t in range(lo, n):
        start = max(0, t - hi)
        prev = np.arange(start, t - lo + 1)
        if len(prev) == 0:
            continue
        cost = -tightness * np.log((t - prev) / period) ** 2
        cand = score[prev] + cost
        k = int(np.argmax(cand))
        if cand[k] > 0:
            score[t] = env[t] + cand[k]
            back[t] = prev[k]
    # Кінець — найкращий кадр в останньому періоді.
    t = int(np.argmax(score[n - int(period):])) + n - int(period)
    beats = []
    while t >= 0:
        beats.append(t)
        t = back[t]
    return np.array(beats[::-1])


def analyze(path):
    y = decode(path)
    full, low, loud = onset_envelopes(y)
    env = 0.6 * full + 0.4 * low
    bpm, period = tempo(env)
    beats = track_beats(env, period)
    # Сила біта: максимум потоку низьких частот у ±60 мс, нормований по треку, з урахуванням гучності.
    w = max(1, int(0.06 * FPS))
    low_peak = maximum_filter1d(low, size=2 * w + 1)
    raw = low_peak[beats] * 0.75 + maximum_filter1d(full, size=2 * w + 1)[beats] * 0.25
    raw = raw / (np.percentile(raw, 90) + 1e-9)
    strength = np.clip(raw, 0.0, 1.0) * np.clip(loud[np.minimum(beats, len(loud) - 1)], 0.15, 1.0)
    times = (beats + 0.5) * HOP / SR + NFFT / (2 * SR)   # кадр STFT → центр вікна
    # Перевірка якості: onset на бітах vs. у випадкових місцях.
    rnd = np.random.default_rng(0).integers(0, len(env), len(beats))
    quality = env[beats].mean() / (env[rnd].mean() + 1e-9)
    return bpm, times, strength, quality, len(y) / SR


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audio = open(os.path.join(root, "scripts/autoload/audio.gd"), encoding="utf-8").read()
    tracks = re.findall(r'\{"id": &"([^"]+)".*?"path": "res://([^"]+)"', audio)
    maps = {}
    for tid, rel in tracks:
        bpm, times, strength, quality, dur = analyze(os.path.join(root, rel))
        intervals = np.diff(times)
        print(f"{tid:18s} {bpm:6.1f} BPM  бітів {len(times):4d}  довжина {dur:5.0f} с  "
              f"ритм ±{intervals.std() * 1000:4.0f} мс  чіткість {quality:4.1f}  сила сер. {strength.mean():.2f}")
        maps[tid] = (bpm, times, strength)
    out = ["extends RefCounted",
           "## ЗГЕНЕРОВАНО tools/beat_analyze.py — не редагувати вручну.",
           "## Біти треків для візуальних ефектів під музику: id → [час (с), сила 0..1, час, сила, …].",
           "## Звичайні масиви (PackedFloat32Array([...]) не може бути константою) — Audio перетворює їх сам.",
           "",
           "const BPM: Dictionary = {"]
    for tid, (bpm, _, _) in maps.items():
        out.append(f'\t&"{tid}": {bpm:.1f},')
    out.append("}")
    out.append("")
    out.append("const MAPS: Dictionary = {")
    for tid, (_, times, strength) in maps.items():
        vals = ", ".join(f"{t:.3f}, {s:.2f}" for t, s in zip(times, strength))
        out.append(f'\t&"{tid}": [{vals}],')
    out.append("}")
    open(os.path.join(root, "scripts/autoload/beat_maps.gd"), "w", encoding="utf-8").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
