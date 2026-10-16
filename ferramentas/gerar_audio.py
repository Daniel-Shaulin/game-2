# Gera as músicas, os mapas de notas e os sons PROVISÓRIOS do protótipo.
# Uso: python3 ferramentas/gerar_audio.py  (a partir da pasta jogo/)
# As notas do combate saem dos mesmos eventos que geram o áudio, então ficam no tempo da música.
import json
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")


def save_wav(name, sig):
    sig = np.tanh(sig * 1.2)
    peak = np.max(np.abs(sig)) or 1.0
    sig = sig / peak * 0.9
    data = (sig * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tvec(dur):
    return np.arange(int(dur * SR)) / SR


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def kick():
    t = tvec(0.35)
    f = 42 + 85 * np.exp(-t * 32)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.95


def snare(rng):
    t = tvec(0.25)
    n = np.diff(rng.uniform(-1, 1, len(t)), prepend=0)
    return n * 0.45 * np.exp(-t * 16) + np.sin(2 * np.pi * 170 * t) * np.exp(-t * 28) * 0.35


def hat(rng, amp=0.13):
    t = tvec(0.05)
    n = np.diff(rng.uniform(-1, 1, len(t)), prepend=0)
    return n * np.exp(-t * 80) * amp


def bell(freq, dur=1.8, amp=0.22):
    t = tvec(dur)
    s = np.zeros_like(t)
    for ratio, dec, a in ((1.0, 2.5, 1.0), (2.76, 4.0, 0.5), (5.4, 7.0, 0.3), (8.9, 10.0, 0.15)):
        s += np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * dec) * a
    return s * amp


def pluck(freq, amp=0.25):
    t = tvec(0.4)
    saw = 2 * ((t * freq) % 1.0) - 1
    return saw * np.exp(-t * 11) * amp


def bass(freq, dur, amp=0.28):
    t = tvec(dur)
    saw = 2 * ((t * freq) % 1.0) - 1 + 0.5 * (2 * ((t * freq * 1.005) % 1.0) - 1)
    env = np.minimum(1.0, t * 200) * np.exp(-t * 5)
    return lowpass(saw * env, 0.08) * amp


def drone(total, root, amp=0.1):
    t = tvec(total)
    lfo = 0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * t)
    s = (np.sin(2 * np.pi * root * t) + np.sin(2 * np.pi * root * 1.007 * t)
         + 0.6 * np.sin(2 * np.pi * root * 16 / 15 * t) + 0.3 * np.sin(2 * np.pi * root * 2.01 * t))
    return s * lfo * amp


def place(buf, sig, t):
    i = int(t * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


def note_freq(semi, base=41.2):
    return base * 2 ** (semi / 12)


class Circles:
    """Posições dos círculos e sliders do modo osu (a área livre da tela no modo osu)."""
    X0, X1, Y0, Y1 = 280, 1180, 160, 620

    def __init__(self, rng):
        self.rng = rng
        self.pos = np.array([730.0, 390.0])

    def _inside(self, p):
        return self.X0 <= p[0] <= self.X1 and self.Y0 <= p[1] <= self.Y1

    def next(self, lo=130, hi=240):
        for _ in range(40):
            ang = self.rng.uniform(0, 2 * np.pi)
            p = self.pos + self.rng.uniform(lo, hi) * np.array([np.cos(ang), np.sin(ang)])
            if self._inside(p):
                self.pos = p
                return [round(float(p[0])), round(float(p[1]))]
        self.pos = np.array([730.0, 390.0])
        return [730, 390]

    def curve(self, start, end):
        a, b = np.array(start, float), np.array(end, float)
        d = b - a
        perp = np.array([-d[1], d[0]]) / (np.linalg.norm(d) or 1.0)
        c = (a + b) / 2 + perp * self.rng.uniform(-90, 90)
        c = np.clip(c, [self.X0, self.Y0], [self.X1, self.Y1])
        return [round(float(c[0])), round(float(c[1]))]


def pad(freq, dur, amp=0.18):
    t = tvec(dur)
    env = np.minimum(1.0, t * 30) * np.minimum(1.0, (dur - t) * 20)
    return (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.003 * t)) * env * amp


def make_song(name, bpm, bars, sections, seed, prog, kill_ratio):
    """sections: lista (bar_inicio, bar_fim, tipo) com tipo 'lanes' (D F J K) ou 'circles' (mouse + D F)."""
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = bars * 4 * beat
    buf = np.zeros(int(total * SR) + SR)
    buf[: int(total * SR)] += drone(total, note_freq(prog[0], 41.2))
    notes = []
    circles = Circles(rng)
    last_lane = -1

    def lane(choices):
        nonlocal last_lane
        opts = [c for c in choices if c != last_lane] or choices
        last_lane = int(rng.choice(opts))
        return last_lane

    def kind_of(bar):
        for a, b, k in sections:
            if a <= bar <= b:
                return k
        return None

    for bar in range(bars):
        t0 = bar * 4 * beat
        k = kind_of(bar)
        root = prog[bar % len(prog)]
        # base rítmica (toca em todos os compassos)
        for s in range(8):
            place(buf, hat(rng, 0.10 if s % 2 else 0.14), t0 + s * beat / 2)
        if k is None:
            if bar % 2 == 0:
                place(buf, bell(note_freq(root + 36), 2.5, 0.12), t0)
            continue
        for s in range(8):
            place(buf, bass(note_freq(root + 12), beat / 2), t0 + s * beat / 2)
        intense = bar >= (sections[0][0] + 4)
        if k == "lanes":
            for b in (0, 2):
                place(buf, kick(), t0 + b * beat)
                notes.append({"t": t0 + b * beat, "k": "l", "lane": lane([0, 1, 2, 3])})
            for b in (1, 3):
                place(buf, snare(rng), t0 + b * beat)
                notes.append({"t": t0 + b * beat, "k": "l", "lane": lane([0, 1, 2, 3])})
            if bar % 2 == 1:
                place(buf, kick(), t0 + 2.5 * beat)
                notes.append({"t": t0 + 2.5 * beat, "k": "l", "lane": lane([0, 1, 2, 3])})
            if intense and bar % 2 == 0:
                for b in (0.5, 1.5):
                    place(buf, pluck(note_freq(root + 24)), t0 + b * beat)
                    notes.append({"t": t0 + b * beat, "k": "l", "lane": lane([0, 1, 2, 3])})
        else:  # modo osu: mira com o mouse, acerta com D/F (ou clique); sem pistas
            for b in (0, 2):
                place(buf, kick(), t0 + b * beat)
            place(buf, snare(rng) * 0.6, t0 + 3 * beat)
            hits = (0, 1, 2, 3) if not intense else (0, 1)
            for i, b in enumerate(hits):
                place(buf, bell(note_freq(root + 36 + (7 if i % 2 else 0)), 0.9, 0.2), t0 + b * beat)
                x, y = circles.next()
                notes.append({"t": t0 + b * beat, "k": "c", "x": x, "y": y})
            if intense:
                # slider: acerta a cabeça e segura D/F seguindo a bolinha até o fim
                dur = 1.5 * beat
                x, y = circles.next()
                ex, ey = circles.next(160, 260)
                cx, cy = circles.curve([x, y], [ex, ey])
                place(buf, bell(note_freq(root + 36), 0.9, 0.2), t0 + 2 * beat)
                place(buf, pad(note_freq(root + 31), dur), t0 + 2 * beat)
                notes.append({"t": t0 + 2 * beat, "k": "s", "x": x, "y": y, "dur": round(dur, 4),
                              "cx": cx, "cy": cy, "ex": ex, "ey": ey})
    notes.sort(key=lambda n: n["t"])
    for n in notes:
        n["t"] = round(n["t"], 4)
    save_wav(name + ".wav", buf[: int(total * SR)])
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump({"bpm": bpm, "length": round(total, 4), "kill_ratio": kill_ratio, "notes": notes}, f)
    print(name, "duração", round(total, 1), "s, notas", len(notes))


def ambient():
    rng = np.random.default_rng(7)
    t = tvec(40.0)
    wind = lowpass(rng.uniform(-1, 1, len(t)), 0.02) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t)) * 2.0
    s = wind + drone(40.0, 36.7, 0.08)
    for tt in (3.0, 14.0, 26.0, 33.0):
        place(s, bell(note_freq(rng.integers(30, 42)), 4.0, 0.05), tt)
    fade = np.minimum(1.0, np.minimum(t, 40.0 - t) / 1.5)
    save_wav("ambiente.wav", s * fade * 0.5)


def sfx():
    rng = np.random.default_rng(3)
    t = tvec(0.06)
    save_wav("acerto.wav", np.sin(2 * np.pi * 1400 * t) * np.exp(-t * 60) * 0.3)
    t = tvec(0.3)
    save_wav("erro.wav", (np.sin(2 * np.pi * (90 - 40 * t) * t) + 0.3 * rng.uniform(-1, 1, len(t))) * np.exp(-t * 10))
    t = tvec(0.5)
    n = np.diff(rng.uniform(-1, 1, len(t)), prepend=0)
    save_wav("lanterna.wav", n * np.exp(-t * 8) * 0.5 + np.sin(2 * np.pi * 3000 * t) * np.exp(-t * 30) * 0.2)
    save_wav("moeda.wav", bell(1320, 0.6, 0.4) + np.pad(bell(1760, 0.5, 0.3), (int(0.1 * SR), 0))[: int(0.6 * SR)])
    t = tvec(0.5)
    beep = np.where(t < 0.12, np.sin(2 * np.pi * 1000 * t), 0) + np.where((t > 0.2) & (t < 0.32), np.sin(2 * np.pi * 1500 * t), 0)
    save_wav("sinal.wav", beep * 0.4)
    t = tvec(0.05)
    save_wav("clique.wav", np.sin(2 * np.pi * 900 * t) * np.exp(-t * 90) * 0.4)
    t = tvec(1.5)
    stab = sum(np.sin(2 * np.pi * f * t) for f in (110, 116.5, 155.6, 233)) * np.exp(-t * 2.5)
    save_wav("alerta.wav", stab * 0.4)


def fala():
    # "bip" baixo e curto que toca enquanto o texto do diálogo aparece
    t = tvec(0.045)
    save_wav("fala.wav", np.sin(2 * np.pi * 330 * t) * np.exp(-t * 60) * 0.3 + np.sin(2 * np.pi * 495 * t) * np.exp(-t * 90) * 0.1)


def itens():
    # pegar um item: tecido arrastado + toque grave
    rng = np.random.default_rng(5)
    t = tvec(0.35)
    rustle = lowpass(rng.uniform(-1, 1, len(t)), 0.25) * np.exp(-t * 14) * 0.5
    save_wav("item.wav", rustle + np.sin(2 * np.pi * 220 * t) * np.exp(-t * 18) * 0.25)
    # curar: dois tons que sobem devagar
    t = tvec(0.9)
    env = np.minimum(t / 0.15, 1.0) * np.exp(-t * 3.5)
    save_wav("curar.wav", (np.sin(2 * np.pi * 392 * t) + 0.6 * np.sin(2 * np.pi * 587 * t)) * env * 0.22)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # Inimigo de teste 1: rápido, mais pistas
    make_song("combate_a", 140, 22, [(2, 7, "lanes"), (8, 11, "circles"), (12, 15, "lanes"), (16, 19, "circles")],
              seed=11, prog=[4, 4, 0, 2], kill_ratio=0.7)
    # Inimigo de teste 2: mais lento, mais círculos
    make_song("combate_b", 100, 18, [(2, 5, "circles"), (6, 9, "lanes"), (10, 15, "circles")],
              seed=23, prog=[0, 1, 0, -2], kill_ratio=0.7)
    ambient()
    sfx()
    fala()
    itens()
