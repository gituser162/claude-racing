"""Генератор кривої траси «Спіраль» (scenes/track/spiral_tower.tscn).
Дах вежі → лівий заїзд на спіраль → спуск по спіралі навколо вежі → вихід по дотичній на землі.
Запуск: python3 tools/spiral_layout.py <points.json> [plan.png]
Друкує довжини й ключові точки; points.json — список [x, y, z] для Curve3D (точки без ручок, ~2 м).
Ключові числа (центр вежі, радіуси, висота) повторюються в tscn і spiral_features.gd — міняти разом."""
import math, json, sys

CENTER = (0.0, 8.0)       # центр вежі (x, z); радіус вежі = RING_R - ROAD_HALF - 2 (плита від стіни до колон)
ROAD_HALF = 10.0          # половина ширини дороги (road_width 20 м)
RING_R = 33.0             # радіус осьової лінії спіралі (тісний — щоб увесь спуск ішов у заносі)
DROP_R = 12.0             # радіус заїзду з даху на спіраль
ROOF_START_Z = 26.0       # початок кривої на даху (за стартовою сіткою); лінія старту — z = -4 (start_offset 30)
HEIGHT = 100.8            # дах (y = 0) → земля (y = -HEIGHT): 28 поверхів по 3,6 м
TURNS = 7.5               # обертів спіралі
BLEND = 30.0              # плавний перехід ухилу на початку й у кінці спуску, м
EXIT_LEN = 230.0          # пряма виходу: фініш + зона гальмування
STEP = 2.0

pts = []
def add(x, y, z):
    if pts and math.dist(pts[-1], (x, y, z)) < 0.2:
        return
    pts.append((x, y, z))

# 1. Пряма на даху: x = 0, рух до -z.
cx, cz = CENTER
d = 0.0 - cx                                     # відстань прямої від центру вежі
dz = math.sqrt((RING_R - DROP_R) ** 2 - (d - DROP_R) ** 2)
za = cz - dz                                     # де починається дуга заїзду
z = ROOF_START_Z
while z > za:
    add(0.0, 0.0, z)
    z -= STEP
# 2. Дуга заїзду (ліворуч) навколо A до точки дотику T зі спіраллю.
ax, az = -DROP_R, za
ux, uz = (ax - cx) / (RING_R - DROP_R), (az - cz) / (RING_R - DROP_R)
tx, tz = cx + ux * RING_R, cz + uz * RING_R
a0 = math.atan2(za - az, 0.0 - ax)               # = 0
a1 = math.atan2(tz - az, tx - ax)
while a1 > a0:
    a1 -= 2 * math.pi                            # рух — зі спаданням кута
n = max(2, int(abs(a1 - a0) * DROP_R / STEP))
for k in range(n + 1):
    a = a0 + (a1 - a0) * k / n
    add(ax + DROP_R * math.cos(a), 0.0, az + DROP_R * math.sin(a))
# 3. Спіраль: кут спадає (той самий напрямок обертання), висота — плавний ухил.
phi0 = math.atan2(tz - cz, tx - cx)
S = TURNS * 2 * math.pi * RING_R
grade = HEIGHT / (S - BLEND)                     # кожен перехід «з'їдає» пів BLEND
def ramp(s):
    def sm(t):
        t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)
    return sm(s / BLEND) * sm((S - s) / BLEND)
n = int(S / STEP)
y = 0.0
ds = S / n
for k in range(n + 1):
    s = k * ds
    if k > 0:
        y -= grade * 0.5 * (ramp(s - ds) + ramp(s)) * ds
    phi = phi0 - s / RING_R
    add(cx + RING_R * math.cos(phi), y, cz + RING_R * math.sin(phi))
y_end = y
phi_e = phi0 - S / RING_R
ex, ez = cx + RING_R * math.cos(phi_e), cz + RING_R * math.sin(phi_e)
# дотична (рух зі спаданням кута): d/dphi * (-1)
dx, dzz = math.sin(phi_e), -math.cos(phi_e)
# 4. Пряма виходу.
k = 1
while k * STEP <= EXIT_LEN:
    add(ex + dx * k * STEP, y_end, ez + dzz * k * STEP)
    k += 1

pts = [(round(x, 3), round(y, 3), round(z, 3)) for x, y, z in pts]
length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
print(f"точок {len(pts)}, довжина {length:.1f} м, спіраль {S:.1f} м, ухил {grade*100:.2f}%, "
      f"висота за оберт {grade * 2 * math.pi * RING_R:.2f} м")
print(f"T ({tx:.2f}, {tz:.2f}); дуга заїзду від z={za:.2f}; низ спіралі y={y_end:.2f} у ({ex:.2f}, {ez:.2f}), "
      f"вихід у напрямку ({dx:.3f}, {dzz:.3f}); кінець ({pts[-1][0]}, {pts[-1][2]})")
# Перевірка: де проїжджа частина (з відбійниками, ±ROAD_HALF + 0,5 м) проходить над/під іншою ділянкою траси,
# між ними має лишатися запас (бажано від ~12 м: плита 1 м + машина + камера).
cum = [0.0]
for i in range(len(pts) - 1):
    cum.append(cum[-1] + math.dist(pts[i], pts[i + 1]))
samples = []   # (x, z, y, cum)
for i in range(len(pts)):
    a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
    hx, hz = b[0] - a[0], b[2] - a[2]
    hl = math.hypot(hx, hz)
    rx, rz = -hz / hl, hx / hl                 # праворуч від руху (рух до -z → праворуч +x)
    w = ROAD_HALF + 0.5
    for lat in (-w, -w / 2, 0.0, w / 2, w):
        samples.append((pts[i][0] + rx * lat, pts[i][2] + rz * lat, pts[i][1], cum[i]))
grid = {}
for k, sm in enumerate(samples):
    grid.setdefault((int(sm[0] // 3), int(sm[1] // 3)), []).append(k)
worst = (1e9, None)
for k, (x, z, y, c) in enumerate(samples):
    for gx in (-1, 0, 1):
        for gz in (-1, 0, 1):
            for m in grid.get((int(x // 3) + gx, int(z // 3) + gz), []):
                o = samples[m]
                if abs(o[3] - c) > 40.0 and math.hypot(o[0] - x, o[1] - z) < 1.0:
                    gap = abs(o[2] - y)
                    if gap < worst[0]:
                        worst = (gap, (round(c), round(o[3])))
print(f"найменший вертикальний проміжок між плитами, що перекриваються: {worst[0]:.2f} м (offset {worst[1]})")
json.dump(pts, open(sys.argv[1] if len(sys.argv) > 1 else "spiral_points.json", "w"))
if len(sys.argv) > 2:
    from PIL import Image, ImageDraw
    img = Image.new("RGB", (900, 900), (10, 10, 16))
    dr = ImageDraw.Draw(img)
    def P(x, z): return (450 + x * 1.6, 450 + z * 1.6)
    dr.ellipse([*P(cx - 32, cz - 32), *P(cx + 32, cz + 32)], outline=(90, 90, 120))
    for i in range(len(pts) - 1):
        c = int(255 * (1 + pts[i][1] / HEIGHT))
        dr.line([P(pts[i][0], pts[i][2]), P(pts[i + 1][0], pts[i + 1][2])], fill=(255 - c // 2, c, 255), width=2)
    img.save(sys.argv[2])
