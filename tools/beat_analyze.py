"""Карта бітів для треків гри (для візуальних ефектів під музику).
Запуск: python3 tools/beat_analyze.py            — усі треки з scripts/autoload/audio.gd (TRACKS: id + path)
        python3 tools/beat_analyze.py file.ogg   — лише надрукувати результат для одного файлу
Записує scripts/autoload/beat_maps.gd — константу MAPS: id → [час, сила, перша_доля, час, сила, перша_доля, …]:
  час        — момент біта, с від початку треку;
  сила       — 0..1: наскільки «вдаряє» біт (бочка/бас) з урахуванням гучності ділянки
               (у тихому вступі пульсація слабка, у приспіві — сильна);
  перша_доля — 1, якщо це перша доля такту (раз на 4 біти), інакше 0.

Алгоритм (без librosa; потрібні ffmpeg, numpy, scipy):
  1. Огинаюча атак (спектральний потік) з кроком ~5,8 мс. Перед тим — HPSS (ударні окремо від тягучих нот),
     щоб сітку будувати лише за бочкою й малим барабаном.
  2. Темп — автокореляція (повільніше 95 BPM — подвоюємо: для пульсації під музику потрібна кожна доля).
  3. РІВНА СІТКА на весь трек: період уточнюється до ±0,05% і фаза до ~6 мс — так, щоб на вузлах сітки
     сумарно були найсильніші атаки. Електронна музика тримає темп рівно, тож сітка не «перескакує»
     на сусідні удари й не дрейфує (попередній трекер подекуди зсувався на 40–200 мс).
  4. Локальне уточнення: кожні 16 бітів сітку можна зсунути до ±40 мс (якщо трек трохи «пливе»), згладжено.
  5. Перша доля такту: малий барабан — на 2-й і 4-й долях, тож перша — одна з двох інших (де сильніша бочка).
Новий трек у TRACKS — просто перезапустити скрипт."""
import os, re, subprocess, sys
import numpy as np
from scipy.signal import stft
from scipy.ndimage import maximum_filter1d, uniform_filter1d, median_filter

SR = 22050
HOP = 128
NFFT = 1024
FPS = SR / HOP
## Потік спектра «бачить» атаку трохи раніше, ніж вона звучить (вікно аналізу заходить на неї наперед):
## на синтетичному треку з відомими ударами зсув −12 мс — компенсуємо.
ONSET_DELAY = 0.012


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def envelopes(y):
    """Огинаючі атак. Спершу HPSS (розділення на ударні й тональні): у тональній частині — тягучі ноти
    (синт-бас шістнадцятими, акорди), у ударній — бочка, малий барабан, тарілки. Сітку будуємо за ударними,
    інакше безперервний бас тягне її на 1/16 такту (так було з «A R E S» і «Hex»)."""
    f, _, z = stft(y, fs=SR, nperseg=NFFT, noverlap=NFFT - HOP, boundary=None, padded=False)
    mag = np.abs(z).astype(np.float32)
    harm = median_filter(mag, size=(1, 31))        # горизонтальні лінії — тягучі ноти
    perc = median_filter(mag, size=(31, 1))        # вертикальні — удари
    mask = perc ** 2 / (perc ** 2 + harm ** 2 + 1e-12)
    pmag = np.log1p(100.0 * mag * mask)
    mag = np.log1p(100.0 * mag)
    flux = np.maximum(0.0, np.diff(mag, axis=1))
    pflux = np.maximum(0.0, np.diff(pmag, axis=1))
    full = flux.sum(axis=0)
    low = pflux[f < 150.0].sum(axis=0)              # бочка
    mid = pflux[(f >= 150.0) & (f < 3000.0)].sum(axis=0)   # малий барабан, клеп
    power = np.abs(z[f < 4000.0]).mean(axis=0)
    loud = np.sqrt(np.maximum(uniform_filter1d(power ** 2, size=int(FPS)), 0.0))[1:]

    def norm(e):
        e = np.maximum(e - uniform_filter1d(e, size=int(FPS * 0.5)), 0.0)
        return e / (np.percentile(e, 99.5) + 1e-9)
    return norm(full), norm(low), norm(mid), loud / (np.percentile(loud, 95) + 1e-9)


def tempo_period(env):
    e = env - env.mean()
    n = 1 << (2 * len(e) - 1).bit_length()
    spec = np.fft.rfft(e, n)
    ac = np.fft.irfft(spec * np.conj(spec), n)[:len(e)]
    lags = np.arange(len(ac)) / FPS
    bpm = 60.0 / np.maximum(lags, 1e-9)
    prior = np.exp(-0.5 * (np.log2(bpm / 125.0) / 0.8) ** 2)
    score = np.where((bpm >= 70) & (bpm <= 190), ac * prior, -np.inf)
    period = lags[int(np.argmax(score))]
    if 60.0 / period < 95.0:
        period /= 2.0
    return period


def sample(env, times_s):
    """Значення огинаючої в моменти times_s (лінійна інтерполяція; кадр k ↔ час t0 + k/FPS)."""
    idx = (times_s - (0.5 * HOP / SR + NFFT / (2 * SR))) * FPS
    return np.interp(idx, np.arange(len(env)), env, left=0.0, right=0.0)


def fit_grid(env, period, duration):
    """Період і фаза рівної сітки, на вузлах якої найсильніші атаки."""
    best = (-1.0, period, 0.0)
    for p in period * (1.0 + np.arange(-0.008, 0.0081, 0.0002)):
        phases = np.arange(0.0, p, 0.002)
        n = np.arange(int(duration / p) + 1)
        grid = phases[:, None] + n[None, :] * p
        score = sample(env, grid.ravel()).reshape(grid.shape).sum(axis=1)
        k = int(np.argmax(score))
        if score[k] > best[0]:
            best = (score[k], p, phases[k])
    _, p, ph = best
    # Тонке уточнення.
    for _ in range(2):
        cands = [(sample(env, ph2 + np.arange(int(duration / p2) + 1) * p2).sum(), p2, ph2)
                 for p2 in p * (1.0 + np.arange(-0.0003, 0.00031, 0.00005))
                 for ph2 in ph + np.arange(-0.004, 0.0041, 0.001)]
        _, p, ph = max(cands)
    return p, ph


def refine(env, beats):
    """Локальні зсуви сітки (до ±40 мс) по 16 бітів, згладжені; повертає уточнені часи."""
    shifts = np.arange(-0.040, 0.0401, 0.002)
    centers, offs = [], []
    for a in range(0, len(beats), 16):
        seg = beats[a:a + 16]
        score = np.array([sample(env, seg + s).sum() for s in shifts])
        if score.max() <= 0.0:
            continue
        # Зсув лише якщо він помітно кращий за нульовий (інакше лишаємо сітку).
        k = int(np.argmax(score))
        zero = score[len(shifts) // 2]
        offs.append(shifts[k] if score[k] > zero * 1.15 else 0.0)
        centers.append(seg.mean())
    if len(offs) < 3:
        return beats
    offs = median_filter(np.array(offs), size=3, mode="nearest")
    return beats + np.interp(beats, centers, offs)


def analyze(path):
    y = decode(path)
    duration = len(y) / SR
    full, low, mid, loud = envelopes(y)
    # Сітка — за ударними: бочка (низ) і малий барабан (середина); тарілки й тягучі ноти не враховуються.
    env = 0.6 * low + 0.4 * mid
    period = tempo_period(env)
    p, ph = fit_grid(env, period, duration)
    beats = ph + np.arange(int((duration - ph) / p) + 1) * p
    beats = beats[beats < duration - 0.05]
    beats = refine(env, beats)
    # Сила біта: найсильніша атака низьких частот (і трохи всього спектра) у ±25 мс від біта.
    w = max(1, int(0.025 * FPS))
    low_peak, full_peak = maximum_filter1d(low, 2 * w + 1), maximum_filter1d(full, 2 * w + 1)
    mid_peak = maximum_filter1d(mid, 2 * w + 1)
    raw = 0.6 * sample(low_peak, beats) + 0.25 * sample(mid_peak, beats) + 0.15 * sample(full_peak, beats)
    raw /= np.percentile(raw, 90) + 1e-9
    strength = np.clip(raw, 0.0, 1.0) * np.clip(sample(loud, beats), 0.15, 1.0)
    # Перша доля такту. Малий барабан зазвичай на 2-й і 4-й долях (там більше «верху», ніж басу) —
    # тож перша доля одна з двох інших; з них — та, де сильніший удар баса/бочки.
    mid_at, low_at = sample(mid_peak, beats), sample(low_peak, beats)
    snare = [mid_at[k::2].mean() - low_at[k::2].mean() for k in range(2)]
    cand = [k for k in range(4) if k % 2 != int(np.argmax(snare))]
    phase = max(cand, key=lambda k: low_at[k::4].mean())
    down = np.zeros(len(beats))
    down[phase::4] = 1.0
    # Якість: атаки на бітах проти посередині між бітами.
    on, off = sample(env, beats).mean(), sample(env, beats + p / 2).mean()
    return 60.0 / p, beats + ONSET_DELAY, strength, down, on / (off + 1e-9), duration


def main():
    if len(sys.argv) > 1:
        bpm, beats, strength, down, q, dur = analyze(sys.argv[1])
        print(f"{bpm:.2f} BPM, бітів {len(beats)}, перший {beats[0]:.3f} с, на біті/між бітами {q:.1f}")
        return
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audio = open(os.path.join(root, "scripts/autoload/audio.gd"), encoding="utf-8").read()
    tracks = re.findall(r'\{"id": &"([^"]+)".*?"path": "res://([^"]+)"', audio)
    maps = {}
    for tid, rel in tracks:
        bpm, beats, strength, down, q, dur = analyze(os.path.join(root, rel))
        print(f"{tid:18s} {bpm:7.2f} BPM  бітів {len(beats):4d}  {dur:4.0f} с  на біті/між бітами {q:4.1f}  "
              f"сила сер. {strength.mean():.2f}")
        maps[tid] = (bpm, beats, strength, down)
    out = ["extends RefCounted",
           "## ЗГЕНЕРОВАНО tools/beat_analyze.py — не редагувати вручну.",
           "## Біти треків для візуальних ефектів під музику: id → [час (с), сила 0..1, перша доля 0/1, …].",
           "## Звичайні масиви (PackedFloat32Array([...]) не може бути константою) — Audio перетворює їх сам.",
           "",
           "const BPM: Dictionary = {"]
    for tid, (bpm, *_rest) in maps.items():
        out.append(f'\t&"{tid}": {bpm:.2f},')
    out += ["}", "", "const MAPS: Dictionary = {"]
    for tid, (_, beats, strength, down) in maps.items():
        vals = ", ".join(f"{t:.3f}, {s:.2f}, {int(d)}" for t, s, d in zip(beats, strength, down))
        out.append(f'\t&"{tid}": [{vals}],')
    out.append("}")
    open(os.path.join(root, "scripts/autoload/beat_maps.gd"), "w", encoding="utf-8").write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
