# Gera a arte em pixel do jogo por código: o chão pintado de cada área e os sprites do cenário.
# Uso (a partir da pasta do projeto):
#   python3 ferramentas/gerar_arte.py            -> tudo
#   python3 ferramentas/gerar_arte.py chao       -> só o chão das áreas
#   python3 ferramentas/gerar_arte.py sprites    -> só os sprites
# A paleta vem da referência aprovada (arte/referencias/branca-lago-a.jpg): azul-petróleo escuro,
# cinza de pedra, osso, lodo, musgo, vinho e o laranja das runas. Fica no lugar até a arte do SpriteCook.
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT_AREAS = os.path.join(ROOT, "arte", "areas")
OUT_SPRITES = os.path.join(ROOT, "arte", "sprites")
TW, TH = 64, 32

# ---------- paleta ----------

def hexes(*cs):
    return [tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for c in cs]

PAL = {
    # pedra azul-petróleo, do mais escuro ao mais claro
    "pedra": hexes("06090c", "0b1216", "111b20", "17242a", "1e2e35", "263941", "30454d", "3c535b", "4b636a", "5e767c", "758b8f"),
    # lodo e terra molhada
    "lodo": hexes("07090a", "0d1112", "13191a", "1a2223", "222c2b", "2c3634", "38423e"),
    # terra seca e marrom
    "terra": hexes("0f0d0c", "18140f", "221c16", "2e251d", "3b3026", "4a3d31"),
    # musgo apagado
    "musgo": hexes("10150f", "182014", "212a1a", "2b3521", "37422a", "445034"),
    # osso
    "osso": hexes("2b2823", "403b33", "585146", "736a5b", "8f8571", "aba08a", "c6bca4", "ddd4bd"),
    # água do lago
    "agua": hexes("020406", "04080b", "070d11", "0b1318", "101a20", "16232a", "1e2e36", "2a3e48"),
    # vinho, madeira escura, runa
    "vinho": hexes("1a0a0c", "2b1013", "3d171b", "522026", "6b2c31"),
    "madeira": hexes("120d0b", "1c1410", "281d17", "35271e", "443226"),
    "runa": hexes("5a2a0e", "8f4515", "c8651c", "f08a2c", "ffb45a", "ffd99a"),
    # madeira morta, cinza e seca
    "lenho": hexes("0b0a0a", "141211", "1d1a18", "282321", "342e2a", "433b35", "554b43", "6a5e54"),
    # vestido branco da Branca, frio
    "branco": hexes("202328", "34383d", "4f5459", "6e7378", "90959a", "b3b7b8", "d2d4d1", "e9eae4"),
    # pele clara da Branca
    "pele": hexes("2a2a2e", "403f44", "5b595d", "79767a", "98949a", "b7b2b5", "d3cfcf", "e8e4e1"),
    # pele cinza-violeta da Nanshe
    "gall": hexes("15151a", "1f1f26", "2a2a33", "373641", "464451", "575462", "6b6775", "827d8a"),
    "cabelo": hexes("040506", "090a0d", "0f1115", "16191f", "20242c", "2c323d", "3b4351"),
    "chifre": hexes("100d0c", "1b1715", "28221f", "362e29", "463c35", "584c43"),
    "olho": hexes("9fb9c8", "cfe6f5", "f2fbff"),
}
ALL = np.array([c for k in PAL for c in PAL[k]], dtype=np.float32)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.47


def quantize(rgb, ramp_names=None, dither=10.0):
    """Leva cada pixel para a cor mais próxima da paleta, com um pontilhado leve (Bayer 4x4)."""
    h, w, _ = rgb.shape
    pal = ALL if ramp_names is None else np.array([c for k in ramp_names for c in PAL[k]], dtype=np.float32)
    b = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    x = rgb.astype(np.float32) + b * dither
    out = np.empty((h, w, 3), dtype=np.uint8)
    step = 4096
    flat = x.reshape(-1, 3)
    res = out.reshape(-1, 3)
    for i in range(0, flat.shape[0], step):
        d = ((flat[i:i + step, None, :] - pal[None, :, :]) ** 2).sum(-1)
        res[i:i + step] = pal[d.argmin(1)].astype(np.uint8)
    return out


def ramp(name, t):
    """Cor contínua ao longo de uma rampa da paleta (t de 0 a 1), para misturar antes de quantizar."""
    r = np.array(PAL[name], dtype=np.float32)
    t = np.clip(t, 0.0, 1.0) * (len(r) - 1)
    i = np.floor(t).astype(int)
    j = np.minimum(i + 1, len(r) - 1)
    f = (t - i)[..., None]
    return r[i] * (1 - f) + r[j] * f


# ---------- ruído ----------

def value_noise(x, y, seed, scale):
    rng = np.random.default_rng(seed)
    g = rng.random((512, 512)).astype(np.float32)
    xs, ys = x * scale, y * scale
    x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
    fx, fy = xs - x0, ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    def at(i, j):
        return g[j % 512, i % 512]
    a = at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx
    b = at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx
    return a * (1 - fy) + b * fy


def fbm(x, y, seed, scale, octaves=4):
    v = np.zeros_like(x, dtype=np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        v += value_noise(x, y, seed + o * 17, scale * (2 ** o)) * amp
        tot += amp
        amp *= 0.5
    return v / tot


def voronoi(x, y, seed, cell):
    """Pedras do calçamento: distância à borda da célula e um valor por célula."""
    rng = np.random.default_rng(seed)
    jit = rng.random((256, 256, 2)).astype(np.float32)
    val = rng.random((256, 256)).astype(np.float32)
    xs, ys = x / cell, y / cell
    ci, cj = np.floor(xs).astype(int), np.floor(ys).astype(int)
    d1 = np.full(x.shape, 9.0, dtype=np.float32)
    d2 = np.full(x.shape, 9.0, dtype=np.float32)
    v1 = np.zeros(x.shape, dtype=np.float32)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            i, j = ci + di, cj + dj
            p = jit[j % 256, i % 256]
            px, py = i + 0.15 + p[..., 0] * 0.7, j + 0.15 + p[..., 1] * 0.7
            d = np.sqrt((xs - px) ** 2 + (ys - py) ** 2)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            v1 = np.where(closer, val[j % 256, i % 256], v1)
            d1 = np.where(closer, d, d1)
    return (d2 - d1) * cell, v1


def blur_grid(g, n=1):
    for _ in range(n):
        p = np.pad(g, 1, mode="edge")
        g = (p[:-2, :-2] + p[:-2, 1:-1] + p[:-2, 2:] + p[1:-1, :-2] + p[1:-1, 1:-1] + p[1:-1, 2:] + p[2:, :-2] + p[2:, 1:-1] + p[2:, 2:]) / 9.0
    return g


def bilinear(g, x, y):
    h, w = g.shape
    x = np.clip(x - 0.5, 0, w - 1.001)
    y = np.clip(y - 0.5, 0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    return (g[y0, x0] * (1 - fx) + g[y0, x0 + 1] * fx) * (1 - fy) + (g[y0 + 1, x0] * (1 - fx) + g[y0 + 1, x0 + 1] * fx) * fy


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("salvo:", os.path.relpath(path, ROOT))


# ---------- chão das áreas ----------

def ground(area_id):
    area = json.load(open(os.path.join(ROOT, "areas", area_id + ".json")))
    rows = area["mapa"]
    h, w = len(rows), len(rows[0])
    grid = np.array([list(r) for r in rows])
    for b in area.get("construcoes", []):
        grid[b["y"]:b["y"] + b.get("h", 1), b["x"]:b["x"] + b.get("w", 1)] = "H"
    exterior = area.get("estilo", "interior") == "exterior"
    W, H = (w + h) * TW // 2, (w + h) * TH // 2
    v, u = np.mgrid[0:H, 0:W].astype(np.float32)
    X = u - h * TW / 2 + 0.5
    Y = v + 0.5
    wx = (X / (TW / 2) + Y / (TH / 2)) / 2
    wy = (Y / (TH / 2) - X / (TW / 2)) / 2
    inside = (wx >= 0) & (wy >= 0) & (wx < w) & (wy < h)
    ti = np.clip(np.floor(wx).astype(int), 0, w - 1)
    tj = np.clip(np.floor(wy).astype(int), 0, h - 1)
    tile = grid[tj, ti]
    seed = sum(map(ord, area_id))
    if exterior:
        water_ind = (grid == "~").astype(np.float32)
        f1 = bilinear(water_ind, wx, wy)
        f2 = bilinear(blur_grid(water_ind, 2), wx, wy)
        wob = fbm(wx, wy, seed + 5, 1.3, 3) - 0.5
        water = (f1 + wob * 0.35) > 0.5
        # terra: lajes de pedra meio enterradas, cascalho, terra escura e musgo, tudo em coordenadas do
        # mundo para não ter emenda entre as casas
        n_terr = fbm(wx, wy, seed + 1, 0.4)
        n_fine = fbm(wx, wy, seed + 2, 3.0, 3)
        n_mid = fbm(wx, wy, seed + 12, 1.2, 3)
        dirt = ramp("terra", 0.3 + (n_mid - 0.5) * 0.7) * 0.55 + ramp("lodo", 0.45 + (n_fine - 0.5) * 0.6) * 0.45
        col = dirt.copy()
        # cascalho: pedrinhas com um pixel claro em cima e sombra embaixo
        g = value_noise(wx, wy, seed + 13, 16.0)
        grav = (g > 0.8) & (n_terr > 0.3)
        col[grav] = ramp("pedra", 0.3 + (g[grav] - 0.8) * 1.5)
        gtop = grav & ~np.roll(grav, 1, axis=0)
        col[gtop] = ramp("pedra", np.full(gtop.sum(), 0.55))
        gsh = np.roll(grav, -1, axis=0) & ~grav
        col[gsh] *= 0.55
        # lajes grandes e irregulares saindo da terra
        edge, cellv = voronoi(wx, wy, seed + 3, 0.95)
        slab = (cellv > 0.62) & (n_terr > 0.42) & (edge > 0.05)
        sl = ramp("pedra", 0.3 + (cellv - 0.62) * 0.5 + (n_fine - 0.5) * 0.3)
        col = np.where(slab[..., None], sl, col)
        e_up, _ = voronoi(wx - 0.035, wy - 0.035, seed + 3, 0.95)
        e_dn, _ = voronoi(wx + 0.035, wy + 0.035, seed + 3, 0.95)
        lit = slab & (e_up < 0.05)
        col[lit] = ramp("pedra", 0.58 + (cellv[lit] - 0.5) * 0.3)
        shad = (cellv > 0.62) & (n_terr > 0.42) & (edge <= 0.05) & (e_dn > edge)
        col[shad] = col[shad] * 0.35
        # rachaduras dentro das lajes
        cr = slab & (np.abs(fbm(wx, wy, seed + 14, 2.2, 2) - 0.5) < 0.012)
        col[cr] *= 0.4
        # musgo nas partes secas
        n_moss = fbm(wx, wy, seed + 4, 0.7)
        moss = np.clip((n_moss - 0.6) * 4.0, 0, 1) * (1 - np.clip(f2 * 2.5, 0, 1))
        col = col * (1 - moss[..., None] * 0.75) + ramp("musgo", 0.25 + n_fine * 0.6) * moss[..., None] * 0.75
        # lodo e pedra molhada perto da água
        wet = np.clip((f2 - 0.08) * 3.0, 0, 1)
        mud = ramp("lodo", 0.2 + n_fine * 0.45)
        col = col * (1 - wet[..., None] * 0.7) + mud * wet[..., None] * 0.7
        sheen = (wet > 0.55) & (fbm(wx, wy, seed + 9, 5.0, 2) > 0.8)
        col[sheen] = ramp("pedra", np.full(sheen.sum(), 0.48))
        # lascas de osso soltas
        rng = np.random.default_rng(seed + 7)
        speck = rng.random(wx.shape)
        bonef = (speck < 0.0004) & ~water & (wet < 0.5)
        for dx in range(3):
            m = np.roll(bonef, dx, axis=1)
            col[m] = ramp("osso", np.full(m.sum(), 0.55 + dx * 0.05))
        # água: escura, mais funda longe da margem, com poucos riscos de luz curtos
        depth = np.clip((f2 - 0.45) * 1.6, 0, 1)
        n_str = value_noise(X / 30.0, Y / 1.6, seed + 11, 1.0)
        n_msk = value_noise(X / 140.0, Y / 40.0, seed + 15, 1.0)
        aw = ramp("agua", 0.68 - depth * 0.38 + (n_mid - 0.5) * 0.14)
        streak = (n_str > 0.84) & (n_msk > 0.45)
        aw[streak] = ramp("agua", 0.72 - depth[streak] * 0.25)
        # beira: uma linha fina de espuma apagada e lodo logo embaixo d'água
        lvl = f1 + wob * 0.35
        foam = water & (lvl < 0.525)
        sub = water & (lvl >= 0.525) & (lvl < 0.62)
        aw[sub] = aw[sub] * 0.6 + ramp("lodo", np.full(sub.sum(), 0.45)) * 0.4
        aw[foam] = ramp("pedra", np.full(foam.sum(), 0.4))
        col = np.where(water[..., None], aw, col)
    else:
        # chão de lajes de pedra dentro de casa
        edge, cellv = voronoi(wx * 1.0, wy * 2.0, seed + 3, 0.6)
        n_fine = fbm(wx, wy, seed + 2, 3.0, 3)
        col = ramp("pedra", 0.42 + (cellv - 0.5) * 0.18 + (n_fine - 0.5) * 0.2)
        col[edge < 0.05] *= 0.4
        rug = (np.abs(wx - w / 2) < 1.6) & (np.abs(wy - h / 2 - 0.3) < 1.1)
        stripes = (np.floor((wx + wy) * 3) % 3 == 0)
        col[rug] = ramp("vinho", 0.45 + n_fine[rug] * 0.4)
        col[rug & stripes] = ramp("osso", np.full((rug & stripes).sum(), 0.35))
        water = np.zeros_like(inside)
    # embaixo das paredes e penhascos: pedra escura (quase sempre coberta pelos sprites)
    under = (tile == "#") & ~water
    col[under] = ramp("pedra", 0.12 + n_fine[under] * 0.1)
    rgb = quantize(col)
    alpha = np.where(inside, 255, 0).astype(np.uint8)
    img = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    save(img, os.path.join(OUT_AREAS, area_id + "_chao.png"))


def all_grounds():
    for f in sorted(os.listdir(os.path.join(ROOT, "areas"))):
        if f.endswith(".json"):
            ground(f[:-5])




# ---------- sprites: motor de desenho ----------
# Cada sprite é pintado em camadas, do fundo para a frente. Cada pixel guarda a rampa da paleta e uma
# posição t nela (0 escuro, 1 claro); no fim o t é pontilhado (Bayer) e vira uma cor da rampa, e a
# figura ganha contorno escuro. A luz vem de cima e da esquerda, como no chão.

LIGHT = np.array([-0.55, -0.7, 0.62], dtype=np.float32)
LIGHT /= np.linalg.norm(LIGHT)
RAMPS = list(PAL.keys())


def poly_mask(w, h, pts):
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return np.array(im) > 0


def inner_dist(mask, maxd=40):
    """Distância (em pixels) de cada pixel da máscara até a borda."""
    d = np.zeros(mask.shape, dtype=np.float32)
    m = mask.copy()
    for _ in range(maxd):
        if not m.any():
            break
        d += m
        p = np.pad(m, 1)
        m = m & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    return d


def dilate(m):
    p = np.pad(m, 1)
    return m | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]


def lambert_from_height(hgt):
    gy, gx = np.gradient(hgt.astype(np.float32))
    n = np.dstack([-gx, -gy, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return np.clip((n * LIGHT).sum(2), 0, 1)


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return x, y


def bez(p0, p1, p2, p3, n=40):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2, p3 = (np.array(p, dtype=np.float32) for p in (p0, p1, p2, p3))
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def resample(pts, step=0.4):
    pts = np.array(pts, dtype=np.float32)
    seg = np.sqrt(((pts[1:] - pts[:-1]) ** 2).sum(1))
    s = np.concatenate([[0], np.cumsum(seg)])
    n = max(2, int(s[-1] / step) + 1)
    q = np.linspace(0, s[-1], n)
    return np.stack([np.interp(q, s, pts[:, 0]), np.interp(q, s, pts[:, 1])], 1), q / max(s[-1], 1e-6)


class Spr:
    def __init__(self, w, h, seed=0):
        self.w, self.h, self.seed = w, h, seed
        self.rid = np.full((h, w), -1, dtype=np.int16)  # rampa de cada pixel (-1 vazio)
        self.t = np.zeros((h, w), dtype=np.float32)
        self.dith = np.ones((h, w), dtype=np.float32)
        self.glow = np.zeros((h, w, 4), dtype=np.uint8)  # camada que brilha no escuro
        self.x, self.y = grid(w, h)

    def noise(self, scale, octaves=3, off=0):
        return fbm(self.x, self.y, self.seed + off, scale, octaves)

    def fill(self, mask, ramp_name, t, dither=1.0, edge=False):
        """Pinta a máscara com a rampa; `edge` escurece a borda da peça onde ela encosta em outra."""
        t = np.broadcast_to(np.asarray(t, dtype=np.float32), mask.shape)
        if edge:
            p = np.pad(mask, 1)
            border = mask & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
            under = dilate(self.rid >= 0) & border
            t = np.where(under, t * 0.55, t)
        self.rid[mask] = RAMPS.index(ramp_name)
        self.t[mask] = t[mask]
        self.dith[mask] = dither

    def shade(self, mask, ramp_name, base, contrast=0.6, height=None, dome=1.0, noise=0.05, nscale=0.4,
              edge=False, extra=None):
        if height is None:
            height = np.sqrt(inner_dist(mask)) * 2.0 * dome
        l = lambert_from_height(np.where(mask, height, 0))
        t = base + (l - 0.62) * contrast + (self.noise(nscale, 3, len(ramp_name)) - 0.5) * noise * 2
        if extra is not None:
            t = t + extra
        self.fill(mask, ramp_name, t, edge=edge)
        return t

    def tube(self, pts, r0, r1, ramp_name, base, contrast=0.7, noise=0.04, edge=True, extra=None, rfun=None):
        """Peça cilíndrica (osso, galho, braço): carimba círculos ao longo da curva."""
        pts, u = resample(pts)
        H = np.full((self.h, self.w), -1e9, dtype=np.float32)
        NX = np.zeros((self.h, self.w), dtype=np.float32)
        NY = np.zeros((self.h, self.w), dtype=np.float32)
        U = np.zeros((self.h, self.w), dtype=np.float32)
        for (cx, cy), uu in zip(pts, u):
            r = r0 + (r1 - r0) * uu
            if rfun is not None:
                r = rfun(uu, r)
            x0, x1 = int(np.floor(cx - r - 1)), int(np.ceil(cx + r + 1))
            y0, y1 = int(np.floor(cy - r - 1)), int(np.ceil(cy + r + 1))
            x0, y0 = max(x0, 0), max(y0, 0)
            x1, y1 = min(x1, self.w - 1), min(y1, self.h - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx = self.x[y0:y1 + 1, x0:x1 + 1] + 0.5 - cx
            gy = self.y[y0:y1 + 1, x0:x1 + 1] + 0.5 - cy
            d2 = gx * gx + gy * gy
            rr = max(r, 0.3)
            inside = d2 <= (rr + 0.3) ** 2
            hz = np.sqrt(np.clip(rr * rr - d2, 0, None)) + uu * 0.01
            sub = H[y0:y1 + 1, x0:x1 + 1]
            upd = inside & (hz > sub)
            sub[upd] = hz[upd]
            NX[y0:y1 + 1, x0:x1 + 1][upd] = np.clip(gx[upd] / rr, -1, 1)
            NY[y0:y1 + 1, x0:x1 + 1][upd] = np.clip(gy[upd] / rr, -1, 1)
            U[y0:y1 + 1, x0:x1 + 1][upd] = uu
        mask = H > -1e8
        nz = np.sqrt(np.clip(1 - NX ** 2 - NY ** 2, 0.05, 1))
        l = np.clip(NX * LIGHT[0] + NY * LIGHT[1] + nz * LIGHT[2], 0, 1)
        t = base + (l - 0.62) * contrast + (self.noise(0.5, 2, 33) - 0.5) * noise * 2
        if extra is not None:
            t = t + extra(U, mask)
        self.fill(mask, ramp_name, t, edge=edge)
        return mask

    def lean(self, base_y, amount, wave=0.0, seed=0):
        """Entorta a figura: cada linha anda para o lado conforme a altura (casas tortas)."""
        for yy in range(self.h):
            k = (base_y - yy) / max(base_y, 1)
            dx = int(round(k * amount + np.sin(yy * 0.05 + seed) * wave * k))
            if dx:
                for a in (self.rid, self.t, self.dith, self.glow):
                    a[yy] = np.roll(a[yy], dx, axis=0)

    def put_glow(self, mask, rgb, alpha=255):
        self.glow[mask] = list(rgb) + [alpha]

    def image(self, outline=True, out_k=0.32):
        h, w = self.rid.shape
        rgb = np.zeros((h, w, 3), dtype=np.float32)
        b = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
        for k, name in enumerate(RAMPS):
            m = self.rid == k
            if not m.any():
                continue
            r = np.array(PAL[name], dtype=np.float32)
            n = len(r)
            idx = np.clip(np.round(np.clip(self.t[m], 0, 1) * (n - 1) + b[m] * 0.9 * self.dith[m]), 0, n - 1).astype(int)
            rgb[m] = r[idx]
        alpha = (self.rid >= 0)
        if outline:
            ring = dilate(alpha) & ~alpha
            acc = np.zeros((h, w, 3), dtype=np.float32)
            cnt = np.zeros((h, w), dtype=np.float32)
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                sh = np.roll(np.roll(rgb, dy, 0), dx, 1)
                sa = np.roll(np.roll(alpha, dy, 0), dx, 1)
                acc += sh * sa[..., None]
                cnt += sa
            dark = acc / np.maximum(cnt, 1)[..., None] * out_k + np.array([3, 4, 6]) * (1 - out_k)
            pal = ALL
            flat = dark[ring]
            d = ((flat[:, None, :] - pal[None]) ** 2).sum(-1)
            rgb[ring] = pal[d.argmin(1)]
            alpha = alpha | ring
        out = np.dstack([rgb.astype(np.uint8), np.where(alpha, 255, 0).astype(np.uint8)])
        return Image.fromarray(out, "RGBA")

    def glow_image(self):
        if self.glow[..., 3].max() == 0:
            return None
        return Image.fromarray(self.glow, "RGBA")


SPRITES = {}  # nome -> {"ancora": [x, y], "brilho": bool}


def emit(name, spr, anchor, outline=True):
    save(spr.image(outline), os.path.join(OUT_SPRITES, name + ".png"))
    g = spr.glow_image()
    if g is not None:
        save(g, os.path.join(OUT_SPRITES, name + "_brilho.png"))
    SPRITES[name] = {"ancora": [int(anchor[0]), int(anchor[1])], "brilho": g is not None}


def noise1(n, seed, scale, amp, octaves=3):
    x = np.arange(n, dtype=np.float32)
    return (fbm(x, np.zeros_like(x) + seed * 3.1, seed, scale, octaves) - 0.5) * 2 * amp


# ---------- sprites: cenário de fora ----------

# Runas dos Gall gravadas na pedra (5 x 9), para pedras de runa e penhascos.
GLYPHS = [
    ["..#..", "..#..", ".###.", "#.#.#", "..#..", "..#..", ".#.#.", "#...#", "#...#"],
    ["#....", "##...", "#.#..", "#..#.", "#...#", "#..#.", "#.#..", "##...", "#...."],
    ["#...#", ".#.#.", "..#..", "..#..", "#####", "..#..", "..#..", ".#.#.", "#...#"],
    [".###.", "#...#", "#...#", ".#.#.", "..#..", "..#..", "###..", "..#..", "..#.."],
]
# a luz das runas soma por cima do brilho no jogo, então o brilho é pintado num laranja mais fundo
RUNE_CORE = PAL["runa"][2]
RUNE_HALO = PAL["runa"][1]


def glyph_mask(spr, gi, ox, oy, shear=0.0):
    m = np.zeros((spr.h, spr.w), dtype=bool)
    for r, row in enumerate(GLYPHS[gi % len(GLYPHS)]):
        for c, ch in enumerate(row):
            if ch == "#":
                yy, xx = int(oy + r + round(c * shear)), int(ox + c)
                if 0 <= yy < spr.h and 0 <= xx < spr.w:
                    m[yy, xx] = True
    return m


def carve_rune(spr, gi, ox, oy, shear):
    m = glyph_mask(spr, gi, ox, oy, shear)
    spr.t[m] = 0.05
    spr.put_glow(dilate(m) & ~m, RUNE_HALO, 110)
    spr.put_glow(m, RUNE_CORE, 255)


def cliff_sprite(name, seed, height, front=False, rune=-1):
    rng = np.random.default_rng(seed)
    W, cx = 84, 42
    jag_amp = 2.5 if front else height * 0.1
    top_extra = 6 if front else int(height * 0.5)
    H = int(height + 16 + 18 + top_extra + 4)
    cy = H - 18
    spr = Spr(W, H, seed)
    x, y = spr.x + 0.5, spr.y + 0.5
    xi = np.arange(W) + 0.5
    jag = noise1(W, seed, 0.12, jag_amp) + noise1(W, seed + 5, 0.45, jag_amp * 0.4)
    if not front:
        for _ in range(rng.integers(1, 4)):
            xk = rng.uniform(cx - 26, cx + 26)
            jag += np.maximum(0, rng.uniform(0.25, 0.5) * height - np.abs(xi - xk) * rng.uniform(1.6, 2.6))
    top = cy - height - 16 + np.abs(xi - cx) * 0.5 - jag
    bot = cy + 16 - np.abs(xi - cx) * 0.5
    lift = np.clip((cy - np.arange(H)) / max(height, 1), 0, 1.6)
    halfw = 34 - lift * 3 + noise1(H, seed + 9, 0.08, 3.5) + noise1(H, seed + 19, 0.4, 1.0)
    mask = (y >= top[None, :]) & (y <= bot[None, :]) & (np.abs(x - cx) <= halfw[:, None])
    slope = np.gradient(top)[None, :] * np.ones((H, 1))
    band = 5 + spr.noise(0.2, 2, 3) * 6
    is_top = (y < top[None, :] + band) & (np.abs(slope) < 1.0)
    base_top = cy - height - 16 + np.abs(x - cx) * 0.5
    meander = noise1(H, seed + 2, 0.1, 4)[:, None]
    left = x < cx + meander
    tone = np.where(left, 0.46, 0.24)
    spire = (y < base_top - 2) & ~is_top
    tone = np.where(spire, np.where(slope < 0, 0.5, 0.25), tone)
    tone = np.where(is_top, 0.66, tone)
    # blocos grandes da pedra viva: cada lasca com seu tom, separadas por fendas
    sx = np.where(left, x - cx, x - cx)
    edge, cellv = voronoi(sx / 13.0, (y - 0.5 * np.abs(x - cx)) / 9.0 + seed, seed, 1.0)
    side = ~is_top
    tone = tone + (cellv - 0.5) * 0.16
    tone = tone - ((edge < 0.07) & side) * 0.22
    lit_edge = (np.roll(edge, 1, axis=0) < 0.07) & (edge >= 0.07) & side
    tone = tone + lit_edge * 0.1
    bump = spr.noise(0.12, 3, 7) * 9
    tone = tone + (lambert_from_height(bump) - 0.6) * 0.3
    # luz na quina de cima e sombra perto do chão
    tone = tone + (y < top[None, :] + 1.5) * 0.12
    tone = tone - np.clip((y - (bot[None, :] - 14)) / 14, 0, 1) * 0.18
    spr.fill(mask, "pedra", tone, dither=0.7)
    moss = mask & is_top & (spr.noise(0.15, 3, 11) > 0.52)
    spr.fill(moss, "musgo", 0.3 + spr.noise(0.6, 2, 12) * 0.5)
    drip = mask & side & (edge >= 0.07) & (np.roll(moss, 2, axis=0) | np.roll(moss, 4, axis=0)) & (spr.noise(0.5, 1, 13) > 0.5)
    spr.fill(drip, "musgo", 0.25)
    if rune >= 0:
        carve_rune(spr, rune, cx - 20 + seed % 6, cy - height * 0.55, 0.5)
    emit(name, spr, (cx, cy))


def rock_sprite(name, seed, k=1.0):
    W, H = 48, 40
    cx, cy = 24, 30
    spr = Spr(W, H, seed)
    x, y = spr.x + 0.5, spr.y + 0.5
    rx, ry = 17 * k, 12 * k
    oy = cy - ry * 0.7
    ang = np.arctan2(y - oy, x - cx)
    rr = 1 + (value_noise(np.cos(ang) * 2 + 3, np.sin(ang) * 2 + 3, seed, 1.3) - 0.5) * 0.35
    mask = (((x - cx) / rx) ** 2 + ((y - oy) / ry) ** 2 < rr ** 2) & (y < cy + 4)
    _, cells = voronoi(x / 9, y / 9, seed, 1.0)
    hgt = np.sqrt(inner_dist(mask)) * 3.2 + cells * 3.5
    t = spr.shade(mask, "pedra", 0.46, 0.85, height=hgt, noise=0.04)
    t2 = t - np.clip((y - (cy - 3)) / 6, 0, 1) * 0.18
    spr.fill(mask, "pedra", t2)
    moss = mask & (y < oy - ry * 0.2) & (spr.noise(0.3, 2, 5) > 0.5)
    spr.fill(moss, "musgo", 0.35 + spr.noise(1.0, 2, 6) * 0.4)
    emit(name, spr, (cx, cy))


def dirt_mound(spr, cx, cy, rx, ry, seed):
    """Terra e cascalho amontoados onde o osso entra no chão."""
    x, y = spr.x + 0.5, spr.y + 0.5
    n = value_noise(x, y, seed, 0.45)
    m = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 0.55 + n * 0.6
    spr.shade(m, "terra", 0.55, 0.8, noise=0.1, nscale=1.0)
    grav = m & (value_noise(x, y, seed + 1, 1.4) > 0.68)
    spr.fill(grav, "pedra", 0.5)


def grime(spr, ramp_name, seed, amount=0.14):
    """Manchas e rachaduras finas na superfície (osso velho, madeira)."""
    m = spr.rid == RAMPS.index(ramp_name)
    n = spr.noise(0.25, 3, seed)
    spr.t[m & (n > 0.62)] -= amount
    c = m & (np.abs(spr.noise(0.18, 2, seed + 1) - 0.5) < 0.02)
    spr.t[c] -= amount * 1.6


def bone_extra(U, mask):
    # osso mais sujo e escuro perto de onde sai da terra
    return -(1 - U) ** 3 * 0.25


def ribcage_sprite(name, seed):
    rng = np.random.default_rng(seed)
    W, H = 108, 90
    ax, ay = 54, 70
    spr = Spr(W, H, seed)
    spine = bez((14, 78), (40, 70), (70, 60), (96, 50), 60)
    def sp(u):
        i = int(u * (len(spine) - 1))
        return spine[i]
    ribs = []
    for k in range(5):
        u = 0.1 + k * 0.19
        P = sp(u)
        hk = 50 - k * 6 + rng.uniform(-3, 3)
        ribs.append((P, hk, k))
    # costelas do lado de lá, mais baixas, aparecendo atrás da espinha
    for P, hk, k in reversed(ribs):
        B = P + np.array([3, -2])
        pts = bez(B, B + (6, -hk * 0.35), B + (16, -hk * 0.55), B + (20, -hk * 0.42), 30)
        spr.tube(pts, 2.4 - k * 0.15, 0.8, "osso", 0.42, extra=bone_extra)
    spr.tube(spine, 3.6, 2.4, "osso", 0.5, rfun=lambda u, r: r * (1 + 0.3 * max(0.0, np.sin(u * 46))), extra=bone_extra)
    for P, hk, k in reversed(ribs):
        B = P + np.array([-3, 2])
        pts = bez(B, B + (-15, -hk * 0.5), B + (-8, -hk * 1.12), B + (13 + k, -hk * 0.98), 50)
        spr.tube(pts, 3.8 - k * 0.25, 0.5, "osso", 0.56, contrast=0.85, extra=bone_extra,
                 rfun=lambda u, r: r * (1.0 + 0.35 * max(0.0, 1 - u * 5)))
        dirt_mound(spr, B[0] - 1, B[1] + 1, 6, 2.6, seed + k)
    dirt_mound(spr, 18, 78, 8, 3, seed + 9)
    grime(spr, "osso", seed)
    emit(name, spr, (ax, ay))


def arch_bone_sprite(name, seed):
    W, H = 96, 80
    ax, ay = 48, 66
    spr = Spr(W, H, seed)
    a = bez((14, 70), (12, 20), (60, 4), (82, 58), 60)
    b = bez((30, 74), (34, 36), (64, 26), (74, 64), 50)
    spr.tube(b, 2.6, 2.0, "osso", 0.44, extra=bone_extra)
    spr.tube(a, 4.0, 2.6, "osso", 0.56, contrast=0.85, rfun=lambda u, r: r * (1 + 0.15 * np.sin(u * 9)), extra=lambda U, m: -np.minimum(U, 1 - U) * 0 - ((np.minimum(U, 1 - U) < 0.12) * 0.12))
    for (cx, cy) in ((14, 70), (82, 60), (30, 74), (74, 65)):
        dirt_mound(spr, cx, cy + 1, 6, 2.6, seed + cx)
    # vértebras soltas
    for (cx, cy) in ((50, 72), (58, 75)):
        m = ((spr.x + 0.5 - cx) / 3.2) ** 2 + ((spr.y + 0.5 - cy) / 2.2) ** 2 < 1
        spr.shade(m, "osso", 0.5, 0.7)
    grime(spr, "osso", seed)
    emit(name, spr, (ax, ay))


def dead_tree_sprite(name, seed):
    rng = np.random.default_rng(seed)
    W, H = 132, 132
    ax, ay = 66, 120
    spr = Spr(W, H, seed)
    for dx, dy in ((-22, 4), (22, 3), (10, 8), (-14, -1), (16, -3)):
        ex, ey = ax + dx, ay + dy
        spr.tube(bez((ax, ay - 3), (ax + (ex - ax) * 0.3, ay + 1), (ax + (ex - ax) * 0.7, ey - 2), (ex, ey), 30), 3.4, 0.8, "lenho", 0.42)
    lean = rng.uniform(-6, 6)
    trunk = bez((ax, ay), (ax - 4, ay - 18), (ax + 5 + lean, ay - 34), (ax + lean, ay - 46), 50)
    spr.tube(trunk, 5.6, 3.4, "lenho", 0.46, contrast=0.85)
    def branch(p, ang, length, r, depth):
        mid = p + np.array([np.cos(ang), np.sin(ang)]) * length * 0.5 + rng.uniform(-3, 3, 2)
        a2 = ang + rng.uniform(-0.35, 0.35)
        end = p + np.array([np.cos(a2), np.sin(a2)]) * length
        pts = bez(p, (p + mid) / 2 + rng.uniform(-2, 2, 2), (mid + end) / 2 + rng.uniform(-2, 2, 2), end, 24)
        spr.tube(pts, r, max(r * 0.6, 0.3), "lenho", 0.46 + depth * 0.02, contrast=0.8, edge=r > 1.0)
        if depth > 0:
            for da in rng.choice([-0.55, -0.25, 0.3, 0.6], size=2 if depth < 2 else rng.integers(2, 4), replace=False):
                branch(end, a2 + da + rng.uniform(-0.15, 0.15), length * rng.uniform(0.6, 0.85), max(r * 0.6, 0.3), depth - 1)
    top = trunk[-1]
    branch(top, -np.pi / 2 - 0.55, 22, 3.0, 3)
    branch(top, -np.pi / 2 + 0.5, 24, 3.0, 3)
    branch(trunk[30], -np.pi / 2 - 1.15, 16, 2.2, 2)
    branch(trunk[25], -np.pi / 2 + 1.1, 14, 2.0, 2)
    grime(spr, "lenho", seed, 0.1)
    emit(name, spr, (ax, ay))


def runestone_sprite(name, seed, gi):
    W, H = 32, 64
    ax, ay = 16, 56
    spr = Spr(W, H, seed)
    x, y = spr.x + 0.5, spr.y + 0.5
    rng = np.random.default_rng(seed)
    pts = [(6, 55), (16, 59), (26, 55), (24, 16), (21, 9 + rng.uniform(-2, 2)), (13, 6), (8, 12)]
    mask = poly_mask(W, H, pts)
    split = 16 + noise1(H, seed, 0.2, 1.2)[:, None]
    tone = np.where(x < split, 0.48, 0.27)
    topline = 6 + np.abs(x - 13) * 0.45
    tone = np.where(y < topline + 4, 0.66, tone)
    tone = tone + (lambert_from_height(spr.noise(0.35, 3, 2) * 6) - 0.6) * 0.3
    tone = tone - np.clip((y - 46) / 12, 0, 1) * 0.15
    spr.fill(mask, "pedra", tone)
    moss = mask & (y > 46) & (spr.noise(0.4, 2, 4) > 0.5)
    spr.fill(moss, "musgo", 0.35 + spr.noise(1.0, 2, 5) * 0.4)
    carve_rune(spr, gi, 9, 22, 0.5)
    dirt_mound(spr, 16, 56, 11, 3.5, seed)
    emit(name, spr, (ax, ay))


def wall_bricks(spr, mask, xr, v, base, seed, row_h=8, brick_w=14):
    """Blocos de pedra assentados em fiadas, tortos, com argamassa escura e a quina de cima clara."""
    vv = v + noise1(1, seed, 1, 0)[0] + spr.noise(0.08, 2, seed) * 3
    row = np.floor(vv / row_h)
    fr = (vv / row_h) % 1.0
    cc = xr / brick_w + (row % 2) * 0.5 + spr.noise(0.1, 2, seed + 1) * 0.3
    col = np.floor(cc)
    fc = cc % 1.0
    hsh = (np.sin(row * 12.9898 + col * 78.233 + seed) * 43758.5453) % 1.0
    tone = base + (hsh - 0.5) * 0.14
    tone = tone + (fr > 0.78) * 0.09 - (fr < 0.22) * 0.06
    tone = tone + (lambert_from_height(spr.noise(0.25, 2, seed + 2) * 4) - 0.6) * 0.2
    mortar = (fr < 0.12) | (fc < 0.08)
    tone = np.where(mortar, base - 0.22, tone)
    spr.fill(mask, "pedra", tone, dither=0.6)
    return row


def house_sprite(name, seed):
    W, H = 244, 276
    F = np.array([122.0, 262.0])
    WH, RH = 58.0, 84.0
    L, R = F + (-96, -48), F + (96, -48)
    Lt, Ft, Rt = L - (0, WH), F - (0, WH), R - (0, WH)
    rl = F + (-48, -72 - WH - RH)
    rr = F + (48, -24 - WH - RH)
    spr = Spr(W, H, seed)
    x, y = spr.x + 0.5, spr.y + 0.5
    rng = np.random.default_rng(seed)
    # parede da esquerda (com a porta)
    lw = poly_mask(W, H, [L, F, Ft, Lt])
    xr = x - L[0]
    v = (L[1] + xr * 0.5) - y
    wall_bricks(spr, lw, xr, v, 0.46, seed)
    t = spr.t
    shadow = lw & (v > WH - 11 + spr.noise(0.3, 1, 3) * 3)
    t[shadow] -= 0.2
    found = lw & (v < 7)
    t[found] -= 0.08
    # porta em arco com pano de vinho pendurado
    dx = xr - 48
    door_top = 25 + np.sqrt(np.clip(12 ** 2 - dx ** 2, 0, None))
    door = lw & (np.abs(dx) < 12) & (v < door_top)
    frame = lw & (np.abs(dx) < 15) & (v < door_top + 3) & ~door & (v > -1)
    fx = np.clip(dx / 15, -1, 1)
    spr.fill(frame, "osso", 0.5 - fx * 0.2 + (v > door_top) * 0.1 + spr.noise(0.4, 2, 8) * 0.1 - 0.05)
    spr.fill(door, "pedra", 0.02)
    hem = 9 + noise1(W, seed + 4, 0.6, 3)[None, :] * np.ones((H, 1))
    cloth = door & (v > hem) & (v < door_top - 1.5)
    fold = np.sin(dx * 1.4 + spr.noise(0.2, 1, 9) * 3) * 0.12
    spr.fill(cloth, "vinho", 0.5 + fold - np.clip((door_top - v) < 4, 0, 1) * 0.2)
    pat = cloth & ((np.floor(v / 4) % 3) == 0) & ((np.floor((dx + 20) / 2) % 2) == 0)
    spr.fill(pat, "osso", 0.35)
    # parede da direita, com a empena
    rw = poly_mask(W, H, [F, R, Rt, rr, Ft])
    xr2 = x - F[0]
    v2 = (F[1] - xr2 * 0.5) - y
    wall_bricks(spr, rw, xr2, v2, 0.26, seed + 50)
    t = spr.t
    rake = rw & (v2 > WH - 2) & (v2 > WH + (48 - np.abs(xr2 - 48)) * (RH / 48) - 7)
    t[rake] -= 0.12
    t[rw & (v2 < 7)] -= 0.06
    # janela redonda com luz de runa por dentro
    wd2 = (xr2 - 46) ** 2 + (v2 - 34) ** 2
    glass = rw & (wd2 < 6.2 ** 2)
    ring = rw & (wd2 < 8.6 ** 2) & ~glass
    spr.fill(ring, "osso", 0.45 + (v2 - 34) / 30 + spr.noise(0.4, 2, 10) * 0.1)
    gt = 0.55 + (v2 - 34) / 20
    spr.fill(glass, "runa", gt)
    bars = glass & ((np.abs(xr2 - 46) < 0.7) | (np.abs(v2 - 34) < 0.7))
    spr.fill(bars, "osso", 0.3)
    spr.put_glow(glass & ~bars, PAL["runa"][3], 230)
    spr.put_glow(bars, PAL["runa"][1], 140)
    # janelinha escura no alto da empena
    hole = rw & ((xr2 - 48) ** 2 + (v2 - WH - 24) ** 2 < 3.6 ** 2)
    spr.fill(dilate(hole) & rw & ~hole, "osso", 0.4)
    spr.fill(hole, "pedra", 0.02)
    # telhado de lascas de pedra
    E1, E2 = Ft - Lt, rl - Lt
    det = E1[0] * E2[1] - E1[1] * E2[0]
    px, py = x - Lt[0], y - Lt[1]
    s = (px * E2[1] - py * E2[0]) / det
    tt = (E1[0] * py - E1[1] * px) / det
    s_end = 1.07 + 0.0 * tt
    roof = (s > -0.07) & (s < s_end) & (tt > -0.11) & (tt < 1.0)
    rows = 13
    rt = tt * rows + spr.noise(0.1, 2, 20) * 0.5
    row = np.floor(rt)
    ft = rt % 1.0
    cs = s * 18 + (row % 2) * 0.5 + spr.noise(0.15, 2, 23) * 0.4
    fs = cs % 1.0
    colk = np.floor(cs)
    hsh = (np.sin(row * 17.13 + colk * 41.7 + seed) * 4375.85) % 1.0
    gap = ft < 0.75 * np.abs(fs - 0.5)
    lip = (~gap) & (ft - 0.75 * np.abs(fs - 0.5) < 0.16)
    tone = 0.3 + (hsh - 0.5) * 0.12 + (1 - ft) * 0.08
    tone = np.where(lip, 0.55 + (hsh - 0.5) * 0.1, tone)
    tone = np.where(gap, 0.1, tone)
    tone = np.where(fs < 0.07, tone - 0.1, tone)
    missing = (hsh > 0.975) & (row > 0) & (row < rows - 1)
    tone = np.where(missing & ~lip, 0.03, tone)
    tone = tone + np.clip(tt - 0.8, 0, 1) * 0.3
    spr.fill(roof, "pedra", tone, dither=0.5)
    moss = roof & ~gap & (spr.noise(0.07, 3, 21) > 0.64) & (tt < 0.6)
    spr.fill(moss, "musgo", 0.2 + spr.noise(0.8, 2, 22) * 0.35)
    # cumeeira, beirais e chifres de osso
    spr.tube(np.array([rl + (-4, 2), rr + (4, 2)]), 2.8, 2.4, "osso", 0.5, extra=lambda U, m: -0.0 * U)
    spr.tube(np.array([Ft + (2, 2), rr + (2, -1)]), 2.2, 2.0, "osso", 0.42)
    spr.tube(np.array([rr + (2, -1), Rt + (7, 1)]), 2.2, 2.0, "osso", 0.36)
    for base, dirx, hgt in ((rl + (-3, 0), -1, 34), (rr + (3, 0), 1, 30), (rl + (rr - rl) * 0.5, 0.3, 20)):
        spr.tube(bez(base, base + (dirx * 3, -hgt * 0.4), base + (dirx * 10, -hgt * 0.8), base + (dirx * 16, -hgt), 30),
                 3.0, 0.5, "osso", 0.55, contrast=0.85)
    for corner, dirx, hgt in ((L, -1, 74), (F, 0.5, 66), (R, 1, 72)):
        b = corner + (0, 3)
        spr.tube(bez(b, b + (dirx * 12, -hgt * 0.35), b + (dirx * 14, -hgt * 0.8), b + (dirx * 4, -hgt), 40),
                 5.0, 0.6, "osso", 0.55, contrast=0.85, extra=bone_extra)
        dirt_mound(spr, b[0], b[1] + 1, 7, 2.8, seed + int(b[0]))
    grime(spr, "osso", seed)
    # degrau de pedra na porta
    step_c = L + (48, 24) + (0, 3)
    st = ((x - step_c[0]) / 15) ** 2 + ((y - step_c[1]) / 5) ** 2 < 1
    spr.shade(st, "pedra", 0.45, 0.7)
    spr.lean(F[1], 7, wave=2, seed=seed)
    emit(name, spr, F)


# ---------- sprites: dentro de casa ----------

def iso_box(spr, F, ex, ey, h, lift=0.0):
    """Caixa isométrica com a quina da frente em F. Devolve as máscaras e as coordenadas de cada face."""
    F = np.array(F, dtype=np.float32) - (0, lift)
    Lb = F - np.array([32, 16]) * ex
    Rb = F + np.array([32, -16]) * ey
    up = np.array([0, h])
    Ft, Lt, Rt = F - up, Lb - up, Rb - up
    Bt = Lt + np.array([32, -16]) * ey
    W, H = spr.w, spr.h
    x, y = spr.x + 0.5, spr.y + 0.5
    left = poly_mask(W, H, [Lb, F, Ft, Lt])
    right = poly_mask(W, H, [F, Rb, Rt, Ft]) & ~left
    top = poly_mask(W, H, [Lt, Ft, Rt, Bt]) & ~left & ~right
    lx = x - Lb[0]
    lv = (Lb[1] + lx * 0.5) - y
    rx = x - F[0]
    rv = (F[1] - rx * 0.5) - y
    return {"left": left, "right": right, "top": top, "lx": lx, "lv": lv, "rx": rx, "rv": rv}


def tile_front(center, ex, ey):
    c = np.array(center, dtype=np.float32)
    return c + np.array([32, 16]) * ex / 2 + np.array([-32, 16]) * ey / 2


def wall_block_sprite(name, seed, h, rune=-1):
    W, Hh = 70, int(h + 40)
    c = (35, Hh - 18)
    spr = Spr(W, Hh, seed)
    b = iso_box(spr, tile_front(c, 1, 1), 1, 1, h)
    wall_bricks(spr, b["left"], b["lx"], b["lv"], 0.44, seed, row_h=7, brick_w=11)
    wall_bricks(spr, b["right"], b["rx"], b["rv"], 0.25, seed + 3, row_h=7, brick_w=11)
    spr.fill(b["top"], "pedra", 0.56 + (spr.noise(0.2, 2, 5) - 0.5) * 0.12)
    t = spr.t
    t[b["left"] & (b["lv"] < 5)] -= 0.08
    if rune >= 0:
        carve_rune(spr, rune, 10, Hh - 18 - h * 0.6, 0.5)
    emit(name, spr, c)


def wardrobe_sprite(name, seed):
    W, H = 64, 100
    c = (32, 82)
    spr = Spr(W, H, seed)
    b = iso_box(spr, tile_front(c, 0.78, 0.62), 0.78, 0.62, 62)
    for face, xr, v, base in (("left", b["lx"], b["lv"], 0.5), ("right", b["rx"], b["rv"], 0.3)):
        m = b[face]
        plank = (xr / 5 + spr.noise(0.1, 1, 4) * 0.3) % 1.0
        grain = spr.noise(0.08, 2, 5) * 0.12 + (np.sin(v * 0.9 + xr * 0.3) * 0.03)
        tone = base + grain - (plank < 0.14) * 0.16
        tone = tone - (v > 56) * 0.0 + ((v > 54) & (v < 57)) * 0.1
        spr.fill(m, "lenho", tone, dither=0.6)
    spr.shade(b["top"], "lenho", 0.6, 0.3)
    seam = b["left"] & (np.abs(b["lx"] - 12.5) < 0.6) & (b["lv"] > 3) & (b["lv"] < 54)
    spr.fill(seam, "lenho", 0.05)
    for vv in (30, 33):
        hd = b["left"] & (np.abs(b["lx"] - 15) < 1.1) & (np.abs(b["lv"] - vv) < 1.1)
        spr.fill(hd, "osso", 0.6)
    grime(spr, "lenho", seed, 0.08)
    emit(name, spr, c)


def bed_sprite(name, seed):
    W, H = 72, 52
    c = (36, 36)
    spr = Spr(W, H, seed)
    ex, ey = 0.92, 0.62
    F = tile_front(c, ex, ey)
    # pés de osso
    for off in ((0, 0), (-32 * ex, -16 * ex), (32 * ey, -16 * ey)):
        p = F + np.array(off) + (0, -1)
        spr.tube(np.array([p, p - (0, 8)]), 1.4, 1.2, "osso", 0.45)
    fr = iso_box(spr, F, ex, ey, 5, lift=7)
    spr.fill(fr["left"], "lenho", 0.45 + spr.noise(0.1, 2, 2) * 0.1)
    spr.fill(fr["right"], "lenho", 0.28 + spr.noise(0.1, 2, 3) * 0.1)
    spr.fill(fr["top"], "lenho", 0.4)
    bl = iso_box(spr, F - (2, 1), ex * 0.92, ey * 0.95, 3, lift=12)
    x, y = spr.x, spr.y
    pat = ((np.floor((x + 2 * y) / 3) % 4) == 0) & ((np.floor((x - 2 * y) / 3) % 4) == 0)
    for face, base in (("left", 0.5), ("right", 0.3), ("top", 0.62)):
        m = bl[face]
        tone = base + (lambert_from_height(spr.noise(0.18, 2, 6) * 5) - 0.6) * 0.4
        spr.fill(m, "vinho", tone)
        spr.fill(m & pat & (face == "top"), "osso", 0.35)
    # travesseiro de pano no fundo
    pc = np.array(c) + (-17, -16)
    pm = ((x + 0.5 - pc[0]) / 8) ** 2 + ((y + 0.5 - pc[1]) / 3.6) ** 2 < 1
    spr.shade(pm, "osso", 0.5, 0.8)
    emit(name, spr, c)


def table_sprite(name, seed):
    W, H = 56, 58
    c = (28, 42)
    spr = Spr(W, H, seed)
    ex, ey = 0.6, 0.6
    F = tile_front(c, ex, ey)
    for off in ((-4, -2), (-32 * ex + 4, -16 * ex), (32 * ey - 4, -16 * ey)):
        p = F + np.array(off)
        spr.tube(np.array([p, p - (0, 22)]), 1.3, 1.1, "lenho", 0.45)
    tb = iso_box(spr, F, ex, ey, 4, lift=22)
    spr.fill(tb["left"], "pedra", 0.42)
    spr.fill(tb["right"], "pedra", 0.24)
    spr.shade(tb["top"], "pedra", 0.6, 0.4)
    x, y = spr.x + 0.5, spr.y + 0.5
    bc = np.array(c) + (-4, -28)
    bowl = ((x - bc[0]) / 4.5) ** 2 + ((y - bc[1]) / 2.6) ** 2 < 1
    spr.shade(bowl, "osso", 0.55, 0.8)
    inner = ((x - bc[0]) / 3) ** 2 + ((y - bc[1] + 0.8) / 1.4) ** 2 < 1
    spr.fill(inner, "osso", 0.2)
    cl = poly_mask(W, H, [np.array(c) + (2, -27), np.array(c) + (10, -31), np.array(c) + (14, -29), np.array(c) + (6, -25)])
    spr.fill(cl, "vinho", 0.5 + spr.noise(0.3, 1, 3) * 0.1)
    emit(name, spr, c)


def lamp_sprite(name, seed):
    W, H = 30, 52
    c = (15, 46)
    spr = Spr(W, H, seed)
    spr.tube(bez((15, 46), (14, 36), (16, 26), (15, 18), 20), 1.8, 1.2, "osso", 0.48)
    for dx in (-4, 4):
        spr.tube(bez((15, 20), (15 + dx, 17), (15 + dx * 1.3, 12), (15 + dx * 0.8, 8), 16), 1.1, 0.5, "osso", 0.52)
    x, y = spr.x + 0.5, spr.y + 0.5
    core = ((x - 15) / 3.2) ** 2 + ((y - 13) / 3.8) ** 2 < 1
    spr.fill(core, "runa", 0.7 - (y - 13) / 12)
    spr.put_glow(dilate(core) & ~core, PAL["runa"][1], 120)
    spr.put_glow(core, PAL["runa"][3], 255)
    dirt = ((x - 15) / 6) ** 2 + ((y - 46) / 2.2) ** 2 < 1
    spr.shade(dirt, "pedra", 0.4, 0.6)
    emit(name, spr, c)


def chest_sprite(name, seed):
    W, H = 52, 44
    c = (26, 30)
    spr = Spr(W, H, seed)
    ex, ey = 0.62, 0.5
    b = iso_box(spr, tile_front(c, ex, ey), ex, ey, 20)
    spr.fill(b["left"], "pedra", 0.42 + spr.noise(0.2, 2, 2) * 0.12)
    spr.fill(b["right"], "pedra", 0.24 + spr.noise(0.2, 2, 3) * 0.1)
    spr.shade(b["top"], "pedra", 0.6, 0.4)
    for face, xr, v, length in (("left", b["lx"], b["lv"], 32 * ex), ("right", b["rx"], b["rv"], 32 * ey)):
        for k in (0.25, 0.75):
            band = b[face] & (np.abs(xr - length * k) < 1.3)
            spr.fill(band, "osso", 0.55 if face == "left" else 0.38)
        lid = b[face] & (np.abs(v - 14) < 0.7)
        spr.fill(lid, "pedra", 0.08)
    lock = b["right"] & (np.abs(b["rx"] - 32 * ey * 0.5) < 1.5) & (np.abs(b["rv"] - 11) < 2.5)
    spr.fill(lock, "pedra", 0.7)
    spr.put_glow(lock, (130, 230, 255), 230)
    emit(name, spr, c)


def mist_sprite(name, seed):
    """Nuvem de névoa baixa: manchas suaves em poucos níveis de transparência, pontilhadas."""
    W, H = 200, 64
    x, y = grid(W, H)
    d = ((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2
    n = fbm(x, y, seed, 0.03, 4)
    a = np.clip((1 - d) * 1.4, 0, 1) * np.clip((n - 0.32) * 2.2, 0, 1)
    b = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    lv = np.clip(np.floor(a * 4 + b * 0.9 + 0.5), 0, 4) / 4
    col = np.array(PAL["pedra"][9], dtype=np.uint8)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[..., :3] = col
    img[..., 3] = (lv * 150).astype(np.uint8)
    save(Image.fromarray(img, "RGBA"), os.path.join(OUT_SPRITES, name + ".png"))
    SPRITES[name] = {"ancora": [W // 2, H // 2], "brilho": False}


# ---------- personagens ----------

def P(*a):
    return np.array(a, dtype=np.float32)


def jagged(x0, x1, y0, amp, n, seed):
    """Barra rasgada: pontos alternando para cima e para baixo (barra do vestido, tiras do xale)."""
    rng = np.random.default_rng(seed)
    xs = np.linspace(x0, x1, n)
    return [(xx, y0 + (amp if k % 2 else 0) + rng.uniform(-0.6, 0.6)) for k, xx in enumerate(xs)]


def branca_standing(frame=0, walking=False):
    W, H = 26, 48
    spr = Spr(W, H, 317 + frame)
    ph = frame * np.pi / 2
    bob = -1 if walking and frame % 2 == 1 else 0
    sw = np.sin(ph) if walking else 0.0
    def B(xx, yy):
        return P(xx, yy + bob)
    # cabelo atrás
    back = [B(8.5, 4), B(12, 2.4), B(15.6, 4.4), B(16.2, 8), B(14.6, 13), B(13, 16), B(12, 22)] + \
        [B(xx, yy) for xx, yy in reversed(jagged(7, 12, 29.5, 2.2, 7, 5))] + [B(6.6, 26), B(7, 18), B(7.4, 10)]
    hm = poly_mask(W, H, back)
    strand = np.sin(spr.x * 2.3 + spr.y * 0.2) * 0.06
    spr.shade(hm, "cabelo", 0.42, 0.7, noise=0.05, extra=strand)
    # braço de trás
    spr.tube([B(10.2, 16.6), B(9.6 - sw * 0.8, 21.5), B(9.9 - sw * 1.4, 27)], 0.85, 0.75, "pele", 0.5)
    # pernas e pés descalços
    for k, side in ((0, -1), (1, 1)):
        hx = 11 + k * 2.3
        fx = hx - 0.2 + side * 2.2 * sw
        lift = max(0.0, side * np.cos(ph)) * 1.2 if walking else 0.0
        spr.tube([P(hx, 33 + bob), P(fx + 0.2, 39), P(fx, 44.5 - lift)], 0.85, 0.7, "pele", 0.55 + k * 0.15)
        spr.tube([P(fx - 0.4, 45 - lift), P(fx + 2.2, 45.2 - lift)], 0.7, 0.6, "pele", 0.6 + k * 0.15)
    # vestido branco rasgado
    hem = jagged(7.2, 16.8, 34.6, 2.4, 9, 11 + frame)
    dress = [B(11, 14.4), B(14.2, 14.4), B(15.6, 15.6), B(15.2, 20), B(14.6, 24), B(15.2, 28)] + \
        [B(xx + sw * 0.4, yy) for xx, yy in reversed(hem)] + [B(9.5, 28), B(10, 24), B(9.6, 20), B(9.5, 15.6)]
    dm = poly_mask(W, H, dress)
    cyl = np.sqrt(np.clip(1 - ((spr.x + 0.5 - 12.5) / 5.5) ** 2, 0, 1)) * 5
    fold = np.sin(spr.x * 1.7 + np.sin(spr.y * 0.4) * 1.5) * 0.07 * (spr.y > 26 + bob)
    spr.shade(dm, "branco", 0.66, 0.75, height=cyl + inner_dist(dm) * 0.3, noise=0.04, extra=fold, edge=True)
    tear = dm & (np.abs(spr.x - 13.5) < 0.6) & (spr.y > 31 + bob)
    spr.fill(tear, "branco", 0.15)
    # braço da frente
    spr.tube([B(14.8, 16.2), B(15.7 + sw * 0.8, 21.5), B(15.5 + sw * 1.4, 27)], 0.9, 0.8, "pele", 0.75)
    # cabeça
    hx0, hy0 = 12.9, 9 + bob
    head = ((spr.x + 0.5 - hx0) / 3.3) ** 2 + ((spr.y + 0.5 - hy0) / 4.2) ** 2 < 1
    spr.shade(head, "pele", 0.82, 0.45, dome=0.8)
    # chifres pequenos escondidos no cabelo
    spr.tube([B(10.8, 4.4), B(10.1, 2.2), B(9.6, 0.9)], 0.95, 0.45, "chifre", 0.5, edge=False)
    spr.tube([B(13.9, 4), B(14.6, 2), B(15.2, 0.7)], 0.95, 0.45, "chifre", 0.55, edge=False)
    # franja e mecha da frente cobrindo parte do rosto
    front = [B(8.6, 6), B(10, 3.4), B(13, 2.5), B(15.7, 4.1), B(16.5, 7.2), B(15.4, 6.2), B(14.6, 7.2), B(13.4, 5.9),
             B(12.2, 8), B(11.5, 11), B(11.4, 15.5), B(10.2, 17.5), B(9.2, 13)]
    fm = poly_mask(W, H, front)
    spr.shade(fm, "cabelo", 0.45, 0.8, noise=0.04, extra=strand, edge=True)
    # olhos que brilham fraco
    for ex in (13, 15):
        m = (spr.x == ex) & (spr.y == int(hy0))
        spr.fill(m, "olho", 0.9)
        spr.put_glow(m, (226, 242, 255), 255)
    return spr, (12, 45)


def branca_lying():
    W, H = 54, 24
    spr = Spr(W, H, 318)
    # cabelo espalhado no chão molhado
    rng = np.random.default_rng(3)
    pts = []
    for k in range(18):
        a = np.pi * 0.35 + k / 17 * np.pi * 1.3
        r = 6.5 + rng.uniform(0, 4) * (k % 2)
        pts.append((10 + np.cos(a) * r * 1.3, 13 + np.sin(a) * r * 0.6))
    hm = poly_mask(W, H, pts)
    spr.shade(hm, "cabelo", 0.4, 0.6, extra=np.sin(np.arctan2(spr.y - 13, spr.x - 10) * 9) * 0.06)
    # braço de trás, quase escondido
    spr.tube([P(15, 10), P(21, 8.6), P(26, 9)], 0.95, 0.85, "pele", 0.5)
    # pernas
    spr.tube([P(33, 11.6), P(39, 11.2), P(45, 11.6)], 1.05, 0.9, "pele", 0.55)
    spr.tube([P(33, 14.2), P(39, 14.6), P(45, 15)], 1.1, 0.9, "pele", 0.7)
    spr.tube([P(45.2, 11.6), P(46.4, 9.6)], 0.8, 0.7, "pele", 0.45)
    spr.tube([P(45.2, 15), P(46.6, 13)], 0.8, 0.7, "pele", 0.72)
    # vestido encharcado, colado no corpo
    hem = jagged(9.2, 16.4, 34.2, 2.6, 7, 4)
    dress = [(14, 9.6), (19, 9), (25, 9.6), (29, 9.2)] + [(yy, xx) for xx, yy in hem] + [(29, 16.4), (24, 16.8), (18, 16.6), (14, 16)]
    dm = poly_mask(W, H, dress)
    cyl = np.sqrt(np.clip(1 - ((spr.y + 0.5 - 13) / 4.2) ** 2, 0, 1)) * 4
    t = spr.shade(dm, "branco", 0.5, 0.7, height=cyl, edge=True, extra=np.sin(spr.x * 1.3) * 0.06)
    wet = dm & (spr.noise(0.3, 2, 9) > 0.55)
    spr.t[wet] -= 0.16
    # braço da frente caído junto do corpo
    spr.tube([P(15, 15.6), P(21, 17.4), P(26.5, 17)], 1.05, 0.9, "pele", 0.72)
    # rosto virado para cima, olhos fechados
    face = ((spr.x + 0.5 - 11.2) / 2.8) ** 2 + ((spr.y + 0.5 - 12.6) / 3.2) ** 2 < 1
    spr.shade(face, "pele", 0.8, 0.45)
    spr.fill(face & (spr.x == 10) & ((spr.y == 11) | (spr.y == 14)), "pele", 0.25)
    bang = poly_mask(W, H, [(7, 9), (10, 8.4), (9.6, 12), (10.4, 16.8), (7, 17)])
    spr.shade(bang, "cabelo", 0.45, 0.7, edge=True)
    spr.tube([P(8.6, 9.6), P(6.8, 8.6)], 0.8, 0.4, "chifre", 0.5, edge=False)
    spr.tube([P(8.6, 15.8), P(6.8, 16.8)], 0.8, 0.4, "chifre", 0.5, edge=False)
    return spr, (26, 15)


def branca_sitting():
    W, H = 34, 42
    spr = Spr(W, H, 319)
    back = [(9, 10), (12, 8), (16, 9.5), (16.5, 14), (14.5, 22), (13, 30)] + \
        [(xx, yy) for xx, yy in reversed(jagged(6.5, 12.5, 37.5, 1.6, 7, 8))] + [(6.4, 30), (7, 20), (7.6, 13)]
    hm = poly_mask(W, H, back)
    strand = np.sin(spr.x * 2.3 + spr.y * 0.2) * 0.06
    spr.shade(hm, "cabelo", 0.42, 0.7, extra=strand)
    spr.tube([P(10.6, 22), P(8.6, 29), P(7.4, 36.5)], 0.85, 0.75, "pele", 0.5)
    spr.tube([P(13, 34), P(19, 35), P(25, 36)], 1.05, 0.9, "pele", 0.55)
    spr.tube([P(14, 36), P(20, 37.4), P(25.4, 38.4)], 1.1, 0.9, "pele", 0.7)
    spr.tube([P(25.4, 36), P(26.4, 34)], 0.8, 0.7, "pele", 0.45)
    spr.tube([P(25.8, 38.4), P(27, 36.4)], 0.8, 0.7, "pele", 0.72)
    dress = [(11.5, 19.6), (14.5, 19.6), (16, 21), (15.6, 27), (19, 31), (22.5, 33.4), (21.4, 35.6), (23, 37.8), (17, 39), (12, 38.6), (9.6, 36), (9.8, 28), (10, 21)]
    dm = poly_mask(W, H, dress)
    spr.shade(dm, "branco", 0.62, 0.75, edge=True, extra=np.sin(spr.x * 1.6 + spr.y * 0.5) * 0.06)
    spr.tube([P(15, 21.6), P(17.2, 27), P(20, 31)], 0.9, 0.8, "pele", 0.75)
    hx0, hy0 = 13.6, 14
    head = ((spr.x + 0.5 - hx0) / 3.3) ** 2 + ((spr.y + 0.5 - hy0) / 4.2) ** 2 < 1
    spr.shade(head, "pele", 0.82, 0.45, dome=0.8)
    spr.tube([P(11.5, 9.4), P(10.8, 7.2), P(10.3, 5.9)], 0.95, 0.45, "chifre", 0.5, edge=False)
    spr.tube([P(14.6, 9), P(15.3, 7), P(15.9, 5.7)], 0.95, 0.45, "chifre", 0.55, edge=False)
    front = [(9.3, 11), (10.7, 8.4), (13.7, 7.5), (16.4, 9.1), (17.2, 12.2), (16.1, 11.2), (15.3, 12.2), (14.1, 10.9),
             (12.9, 13), (12.2, 16), (12.1, 20.5), (10.9, 22.5), (9.9, 18)]
    fm = poly_mask(W, H, front)
    spr.shade(fm, "cabelo", 0.45, 0.8, extra=strand, edge=True)
    for ex in (14, 16):
        m = (spr.x == ex) & (spr.y == 14)
        spr.fill(m, "olho", 0.9)
        spr.put_glow(m, (226, 242, 255), 255)
    return spr, (13, 37)


NANSHE_POSES = {
    # pontos do corpo: quadris, joelhos, tornozelos, ombros, cotovelos, pulsos, cintura, cabeça
    "em_pe": dict(W=44, H=82, anchor=(20, 78), lean=0.0,
                  legs=[((18, 48), (17.6, 62), (17, 76)), ((22, 48), (22.6, 62), (23, 76))],
                  arms=[((15.2, 26), (13.6, 40), (13.6, 52)), ((25, 25.6), (26.6, 39), (26.6, 52))],
                  neck=(20, 16), head=(20.6, 12), waist=40, chest=24),
    "agachada": dict(W=46, H=66, anchor=(20, 62), lean=0.0,
                     legs=[((17, 46), (24, 40), (18.5, 60)), ((19.5, 47.5), (27.5, 45), (23.5, 61))],
                     arms=[((21.6, 30.5), (24.6, 41), (27, 51)), ((27.2, 30), (31, 40), (32.4, 50.5))],
                     neck=(26.2, 21.5), head=(27.8, 17.5), waist=46, chest=30),
}


def nanshe_sprite(pose):
    q = NANSHE_POSES[pose]
    W, H = q["W"], q["H"]
    spr = Spr(W, H, 900 + len(pose))
    hx, hy = q["head"]
    nx, ny = q["neck"]
    sh_b, sh_f = q["arms"][0][0], q["arms"][1][0]
    wy = q["waist"]
    wx = (q["legs"][0][0][0] + q["legs"][1][0][0]) / 2
    # cabelo atrás, até os ombros
    hb = poly_mask(W, H, [(hx - 4, hy - 4), (hx + 3, hy - 5.5), (hx + 4.6, hy), (hx + 3, hy + 6), (sh_f[0] - 1, sh_f[1] + 4),
                          (sh_b[0] + 1, sh_b[1] + 5), (hx - 5, hy + 7), (hx - 5, hy)])
    spr.shade(hb, "cabelo", 0.4, 0.6, extra=np.sin(spr.x * 2.1) * 0.05)
    # braço de trás, longo, com garras
    def arm(pts, base, claw_dir):
        spr.tube([P(*p) for p in pts], 1.45, 1.1, "gall", base)
        wr = P(*pts[2])
        spr.tube([wr - (0, 3.5), wr - (0, 2.2)], 1.5, 1.5, "osso", base + 0.05, edge=False)
        hand = wr + (claw_dir * 0.3, 2.5)
        spr.tube([wr, hand], 1.4, 1.3, "gall", base)
        for k in range(4):
            off = (k - 1.5) * 1.2
            tip = hand + (off + claw_dir * 0.8, 8.5 + (k % 2) * 1.5)
            spr.tube(bez(hand + (off * 0.6, 0), hand + (off, 3), tip + (-claw_dir * 0.6, -2), tip, 12), 0.7, 0.3, "chifre", 0.45, edge=False)
    arm(q["arms"][0], 0.5, -0.5)
    # pernas finas com pés de garra
    for k, (hp, kn, an) in enumerate(q["legs"]):
        spr.tube([P(*hp), P(*kn), P(*an)], 1.7, 1.15, "gall", 0.5 + k * 0.15)
        a = P(*an)
        for d in (-1.4, 0.2, 1.8):
            spr.tube([a, a + (d + 1.0, 1.6)], 0.8, 0.4, "chifre", 0.4, edge=False)
    # saia de tiras: marrom, azul-marinho, vinho e osso
    strips = [("terra", 0.45), ("pedra", 0.36), ("vinho", 0.45), ("osso", 0.3), ("pedra", 0.3), ("terra", 0.36), ("vinho", 0.38), ("pedra", 0.4)]
    rng = np.random.default_rng(7)
    ground = q["anchor"][1]
    crouch = pose == "agachada"
    for k, (rp, base) in enumerate(strips):
        x0 = wx - 6.5 + k * 1.75 + (4 if crouch else 0)
        length = rng.uniform(7, 11) if crouch else min(rng.uniform(14, 24), ground - wy - 4)
        tilt = 3.5 if crouch else 0.0
        top0, top1 = (x0, wy), (x0 + 2.2, wy)
        end = wy + length
        pts = [top0, top1, (x0 + 2.4 + tilt, end - (k % 2)), (x0 + 1.2 + tilt, end + 1.5), (x0 + tilt, end - 0.5)]
        m = poly_mask(W, H, pts)
        spr.shade(m, rp, base, 0.6, extra=np.sin(spr.y * 0.8 + k) * 0.05, edge=True)
        dots = m & ((spr.y.astype(int) + k) % 5 == 0) & ((spr.x.astype(int) % 2) == 0)
        spr.fill(dots, "osso", 0.35)
    # tronco magro
    tor = poly_mask(W, H, [(nx - 1.6, ny + 3), (nx + 1.8, ny + 3), (sh_f[0], sh_f[1] - 1), (sh_f[0] - 1.5, q["chest"] + 8),
                           (wx + 3, wy), (wx - 3, wy), (sh_b[0] + 1.5, q["chest"] + 8), (sh_b[0], sh_b[1] - 1)])
    spr.shade(tor, "gall", 0.58, 0.6)
    ribs = tor & ((spr.y.astype(int) % 3) == 0) & (spr.y > q["chest"] + 2)
    spr.t[ribs] -= 0.12
    # cinto com contas
    spr.tube([P(wx - 3.6, wy), P(wx + 3.6, wy)], 1.3, 1.3, "terra", 0.42)
    for k in range(4):
        bm = (spr.x == int(wx - 3 + k * 2)) & (spr.y == int(wy + 2 + k % 2))
        spr.fill(bm | np.roll(bm, 1, axis=0), "osso", 0.6)
    # xale com padrão e franja
    sx0, sx1 = sh_b[0] - 1.5, sh_f[0] + 2.2
    sy0 = min(sh_b[1], sh_f[1]) - 3
    sy1 = q["chest"] + 10
    shawl = [(nx - 2.5, ny + 4), (nx + 3, ny + 4), (sx1, sh_f[1]), (sx1 + 0.8, sy1 - 3)] + \
        [(xx, yy) for xx, yy in reversed(jagged(sx0 - 0.8, sx1 + 0.8, sy1 - 1, 2.2, 10, 2))] + [(sx0 - 0.8, sy1 - 3), (sx0, sh_b[1])]
    sm = poly_mask(W, H, shawl)
    spr.shade(sm, "pedra", 0.55, 0.6, edge=True)
    pat = sm & ((((spr.x + spr.y).astype(int)) % 4) == 0) & ((((spr.x - spr.y).astype(int)) % 4) == 0)
    spr.fill(pat, "osso", 0.5)
    band = sm & (np.abs(spr.y - (sy1 - 4)) < 0.6)
    spr.fill(band, "vinho", 0.42)
    # braço da frente
    arm(q["arms"][1], 0.72, 0.5)
    # pescoço e cabeça
    spr.tube([P(nx, ny + 4), P(hx - 0.2, hy + 3)], 1.4, 1.4, "gall", 0.6)
    head = ((spr.x + 0.5 - hx) / 3.7) ** 2 + ((spr.y + 0.5 - hy) / 4.6) ** 2 < 1
    spr.shade(head, "gall", 0.78, 0.45, dome=0.8)
    cheek = head & (spr.y > hy + 1) & (spr.x < hx)
    spr.t[cheek] -= 0.08
    # chifres curvos com contas
    for side, base in ((-1, 0.38), (1, 0.55)):
        r0 = P(hx + side * 1.8, hy - 3.6)
        c = bez(r0, r0 + (side * 2, -6), r0 + (side * 9, -5), r0 + (side * 7.5, 2), 30)
        curl = bez(c[-1], c[-1] + (-side * 0.5, 2.5), c[-1] + (-side * 3, 2.6), c[-1] + (-side * 3, 0.8), 12)
        spr.tube(np.concatenate([c, curl]), 1.9, 0.7, "chifre", base, contrast=0.8,
                 extra=lambda U, m: (np.sin(U * 40) > 0.6) * -0.12)
        for k, d in enumerate((4.5, 7)):
            bp = r0 + (side * d, -2.5 + k)
            spr.tube([bp, bp + (0, 4.5 + k)], 0.5, 0.5, "osso", 0.3, edge=False)
            bead = (spr.x == int(bp[0])) & ((spr.y == int(bp[1] + 5 + k)) | (spr.y == int(bp[1] + 6 + k)))
            spr.fill(bead, "osso", 0.65)
    # mechas pretas emoldurando o rosto
    for xx, ln in ((hx - 4.0, 10), (hx + 4.1, 8)):
        spr.tube([P(xx, hy - 3.5), P(xx - 0.3, hy + 2), P(xx + 0.2, hy + ln)], 0.7, 0.5, "cabelo", 0.4, edge=False)
    fr = poly_mask(W, H, [(hx - 3.8, hy - 2), (hx - 2, hy - 5.2), (hx + 2.5, hy - 5.4), (hx + 3.9, hy - 2.6), (hx + 1, hy - 3.6), (hx - 1.5, hy - 3)])
    spr.shade(fr, "cabelo", 0.42, 0.6)
    # olhos que brilham
    for ex in (int(hx), int(hx + 2.4)):
        m = (spr.x == ex) & (spr.y == int(hy))
        spr.fill(m, "olho", 0.95)
        spr.put_glow(m, (240, 236, 214), 255)
    return spr, q["anchor"]



def sprites():
    for k, (hgt, rune) in enumerate(((58, -1), (70, -1), (82, 0), (64, -1), (96, -1), (76, 2))):
        cliff_sprite("penhasco_%d" % k, 11 + k * 7, hgt, rune=rune)
    for k, hgt in enumerate((14, 18, 22)):
        cliff_sprite("penhasco_baixo_%d" % k, 90 + k, hgt, front=True)
    for k, sc in enumerate((1.0, 0.8, 1.15)):
        rock_sprite("pedra_%d" % k, 30 + k, sc)
    ribcage_sprite("ossos_0", 3)
    arch_bone_sprite("ossos_1", 5)
    dead_tree_sprite("arvore_0", 4)
    dead_tree_sprite("arvore_1", 9)
    for k, gi in enumerate((0, 2, 3)):
        runestone_sprite("runa_%d" % k, 40 + k, gi)
    house_sprite("casa_nanshe", 7)
    for k in range(3):
        wall_block_sprite("parede_%d" % k, 60 + k, 46)
    wall_block_sprite("parede_runa", 64, 46, rune=0)
    for k in range(2):
        wall_block_sprite("parede_baixa_%d" % k, 70 + k, 14)
    wardrobe_sprite("armario", 1)
    bed_sprite("cama", 1)
    table_sprite("mesa", 1)
    lamp_sprite("luminaria", 1)
    chest_sprite("bau", 1)
    for k in range(3):
        mist_sprite("nevoa_%d" % k, 80 + k)
    spr, a = branca_standing(0, False)
    emit("branca_parada", spr, a)
    for f in range(4):
        spr, a = branca_standing(f, True)
        emit("branca_andando_%d" % f, spr, a)
    spr, a = branca_lying()
    emit("branca_deitada", spr, a)
    spr, a = branca_sitting()
    emit("branca_sentada", spr, a)
    for pose in ("em_pe", "agachada"):
        spr, a = nanshe_sprite(pose)
        emit("nanshe_" + pose, spr, a)
    path = os.path.join(OUT_SPRITES, "sprites.json")
    json.dump(SPRITES, open(path, "w"), indent=1, sort_keys=True)
    print("salvo:", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    what = sys.argv[1:] or ["chao", "sprites"]
    if "chao" in what:
        all_grounds()
    if "sprites" in what:
        sprites()
