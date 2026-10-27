"""Генератор кривої траси з кутів (так зроблено «Міську вулицю»).
Ламана з вершин (x, z, радіус); кожен кут скруглюється дугою, точки — кожні ~2-4 м.
Запуск: python3 tools/track_layout.py <масштаб> <points.json> <plan.png>
Друкує довжину й кути, зберігає точки (для Curve3D у .tscn) і план згори.
Поточні вершини — «Міська вулиця» (масштаб 1.45, ~1420 м)."""
import math, json, sys
from PIL import Image, ImageDraw
SCALE = float(sys.argv[1]) if len(sys.argv) > 1 else 1.25
# (x, z, радіус скруглення) — замкнений контур, старт на першому відрізку (рух до -z)
V = [
    (0, 70, 16),
    (0, -50, 28),      # S-вигин на стартовій прямій
    (22, -82, 28),
    (22, -165, 13),    # праворуч у квартал
    (95, -165, 13),    # ліворуч
    (95, -250, 20),    # шпилька навколо площі з голограмою, частина 1
    (150, -250, 20),   # частина 2
    (150, -185, 14),   # ринкова шикана: ліво-право-ліво-право
    (178, -185, 14),
    (178, -150, 14),
    (210, -150, 16),
    (210, -25, 15),    # праворуч у неоновий тунель
    (60, -25, 13),     # вихід з тунелю ліворуч
    (60, 25, 15),      # подвійний поворот перед фінішем
    (28, 25, 15),
    (28, 70, 14),
]
P = [(x * SCALE, z * SCALE, r) for x, z, r in V]
n = len(P)
def sub(a, b): return (a[0]-b[0], a[1]-b[1])
def norm(v):
    l = math.hypot(*v); return (v[0]/l, v[1]/l)
pts = []   # щільні точки (x, z)
corners = []
for i in range(n):
    prev, cur, nxt = P[i-1], P[i], P[(i+1) % n]
    d1 = norm(sub(cur, prev)); d2 = norm(sub(nxt, cur))
    ang = math.acos(max(-1, min(1, d1[0]*d2[0] + d1[1]*d2[1])))
    r = cur[2]
    t = r * math.tan(ang / 2)
    a = (cur[0] - d1[0]*t, cur[1] - d1[1]*t)
    b = (cur[0] + d2[0]*t, cur[1] + d2[1]*t)
    cross = d1[0]*d2[1] - d1[1]*d2[0]
    # центр дуги — збоку від a на відстані r
    side = 1 if cross > 0 else -1
    nrm = (-d1[1]*side, d1[0]*side)
    c = (a[0] + nrm[0]*r, a[1] + nrm[1]*r)
    a0 = math.atan2(a[1]-c[1], a[0]-c[0]); a1 = math.atan2(b[1]-c[1], b[0]-c[0])
    da = a1 - a0
    while da > math.pi: da -= 2*math.pi
    while da < -math.pi: da += 2*math.pi
    corners.append((a, b, c, r, a0, da, t))
# збираємо: дуга кута i, потім прямий відрізок до початку дуги i+1
for i in range(n):
    a, b, c, r, a0, da, t = corners[i]
    steps = max(2, int(abs(da) * r / 2.0))
    for k in range(steps + 1):
        ang = a0 + da * k / steps
        pts.append((c[0] + r*math.cos(ang), c[1] + r*math.sin(ang)))
    na = corners[(i+1) % n][0]
    seg = math.hypot(na[0]-b[0], na[1]-b[1])
    if seg < 0: print("OVERLAP corner", i)
    m = max(1, int(seg / 4.0))
    for k in range(1, m):
        pts.append((b[0] + (na[0]-b[0])*k/m, b[1] + (na[1]-b[1])*k/m))
# старт: обертаємо список так, щоб перша точка була на першому відрізку біля (0,0)
start = min(range(len(pts)), key=lambda k: abs(pts[k][0]) + abs(pts[k][1]) if abs(pts[k][0]) < 1 else 1e9)
pts = pts[start:] + pts[:start]
L = sum(math.hypot(pts[k][0]-pts[k-1][0], pts[k][1]-pts[k-1][1]) for k in range(len(pts)))
print("points", len(pts), "length %.0f m" % L, "first", pts[0], "second", pts[1])
for i,(a,b,c,r,a0,da,t) in enumerate(corners):
    print("corner %d r=%d turn=%+.0f deg tangent_len=%.1f" % (i, r, math.degrees(da), t))
json.dump(pts, open(sys.argv[2] if len(sys.argv) > 2 else "/dev/null", "w"))
# план
minx = min(p[0] for p in pts) - 40; maxx = max(p[0] for p in pts) + 40
minz = min(p[1] for p in pts) - 40; maxz = max(p[1] for p in pts) + 40
k = 2.0
im = Image.new("RGB", (int((maxx-minx)*k), int((maxz-minz)*k)), (15, 10, 25))
d = ImageDraw.Draw(im)
xy = [((p[0]-minx)*k, (p[1]-minz)*k) for p in pts]
d.line(xy + [xy[0]], fill=(80, 80, 90), width=int(14*k))
d.line(xy + [xy[0]], fill=(255, 60, 200), width=2)
d.ellipse([xy[0][0]-6, xy[0][1]-6, xy[0][0]+6, xy[0][1]+6], fill=(60, 255, 255))
im.save(sys.argv[3] if len(sys.argv) > 3 else "/tmp/plan.png")
