"""Monta game/assets/sfx/ a partir de art/third_party/ (só CC0) e de síntese procedural.

Uso:  python tools/audio/build_sfx.py
Precisa de numpy, scipy e ffmpeg (com libvorbis) no PATH.

Cada saída tem nome semântico `<grupo>_NN.ogg` (ou `<grupo>.ogg` para loops); o audio_director.gd
agrupa pelo prefixo. One-shots: mono 44,1 kHz, silêncio aparado, fade curto, pico em -1 dBFS
(o volume final de cada grupo é decidido no código). Loops: emenda com crossfade e RMS alvo.
Os sons `syn:` são gerados aqui (ruído filtrado + envelopes), semente fixa, sem material externo.
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TP = os.path.join(ROOT, "art", "third_party")
OUT = os.path.join(ROOT, "game", "assets", "sfx")
SR = 44100

K_IMP = "kenney_impact-sounds/Audio/"
K_SCI = "kenney_sci-fi-sounds/Audio/"
K_RPG = "kenney_rpg-audio/Audio/"
BFH = "oga_rubberduck_75-breaking-falling-hit/"
C1 = "oga_rubberduck_100-cc0-sfx/"
C2 = "oga_rubberduck_100-cc0-sfx-2/"
WAT = "oga_rubberduck_40-water-splash/"
SW = "oga_artisticdude_swishes/"
EL = "oga_faxcorp_electricity/"
ST = "oga_bart_steam-release/"


# ---------------------------------------------------------------- E/S

def load(rel, channels=1):
    p = os.path.join(TP, rel)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", str(channels), "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, channels) if channels > 1 else x


def save(name, x):
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    ch = 1 if x.ndim == 1 else x.shape[1]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")],
                   input=x.tobytes(), check=True)


# ---------------------------------------------------------------- processamento

def trim(x, db=-50.0, pad=0.005):
    a = np.abs(x if x.ndim == 1 else x.max(axis=1))
    th = a.max() * 10 ** (db / 20)
    idx = np.nonzero(a > th)[0]
    if idx.size == 0:
        return x
    s = max(0, idx[0] - int(pad * SR))
    e = min(len(x), idx[-1] + int(pad * SR))
    return x[s:e]


def fade(x, fin=0.002, fout=0.03):
    n = len(x)
    env = np.ones(n)
    a = min(n // 2, int(fin * SR))
    b = min(n // 2, int(fout * SR))
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if b > 0:
        env[-b:] = np.linspace(1, 0, b) ** 2
    return x * (env if x.ndim == 1 else env[:, None])


def peak(x, db=-1.0):
    m = np.abs(x).max()
    return x if m <= 0 else x * (10 ** (db / 20) / m)


def rms_norm(x, db=-20.0, peak_db=-1.0):
    r = np.sqrt(np.mean(x ** 2))
    g = 10 ** (db / 20) / max(r, 1e-9)
    g = min(g, 10 ** (peak_db / 20) / max(np.abs(x).max(), 1e-9))
    return x * g


def pitch(x, ratio):
    """Muda altura e duração juntas (fita). ratio > 1 = mais agudo e curto."""
    if ratio == 1.0:
        return x
    n = int(len(x) / ratio)
    src = np.arange(n) * ratio
    return np.interp(src, np.arange(len(x)), x)


def seg(x, t0, t1):
    return x[int(t0 * SR):int(t1 * SR)]


def mix(*parts):
    """parts: (sinal, atraso_s, ganho)."""
    n = max(int(d * SR) + len(s) for s, d, g in parts)
    out = np.zeros(n)
    for s, d, g in parts:
        i = int(d * SR)
        out[i:i + len(s)] += s * g
    return out


def loopify(x, xf=2.0):
    """Emenda o fim no começo com crossfade de potência constante."""
    f = int(xf * SR)
    head, tail = x[:f], x[-f:]
    t = np.linspace(0, np.pi / 2, f)
    w_in, w_out = np.sin(t), np.cos(t)
    if x.ndim > 1:
        w_in, w_out = w_in[:, None], w_out[:, None]
    body = x[f:-f]
    return np.concatenate([tail * w_out + head * w_in, body])


def oneshot(x, fout=0.03):
    return peak(fade(trim(x), 0.002, fout))


# ---------------------------------------------------------------- síntese

RNG = np.random.default_rng(20260924)


def lp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2))
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def tvec(dur):
    return np.arange(int(dur * SR)) / SR


def thump(f0=60.0, f1=34.0, dur=0.5, tau=0.14):
    t = tvec(dur)
    f = f1 + (f0 - f1) * np.exp(-t / 0.08)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t / tau) * np.minimum(1, t / 0.003)
    click = lp(RNG.standard_normal(len(t)), 900) * np.exp(-t / 0.012) * 0.6
    return np.sin(ph) * env + click


def rumble(dur, attack=0.05, tau=0.8, fc=160.0):
    t = tvec(dur)
    w = np.cumsum(RNG.standard_normal(len(t)))
    w = hp(w, 18)
    w = lp(w, fc, 3)
    w /= np.abs(w).max() + 1e-9
    env = np.minimum(1, t / attack) * np.exp(-np.maximum(0, t - attack) / tau)
    return w * env


def grains(dur, rate, decay, lo=300.0, hi=4000.0, glen=(0.004, 0.03), rise=0.0):
    """Estalos de pedra/entulho: grãos de ruído filtrado em processo de Poisson."""
    n = int(dur * SR)
    out = np.zeros(n + int(0.05 * SR))
    t = 0.0
    while t < dur:
        r = rate * (np.exp(-t / decay) if rise <= 0 else min(1.0, t / rise))
        t += RNG.exponential(1.0 / max(r, 1.0))
        if t >= dur:
            break
        L = int(RNG.uniform(*glen) * SR)
        c = RNG.uniform(lo, hi)
        g = bp(RNG.standard_normal(L + 64), c * 0.7, min(c * 1.4, SR / 2 - 100))[64:]
        g *= np.exp(-np.arange(L) / (L / 3)) * RNG.uniform(0.2, 1.0) ** 2
        i = int(t * SR)
        out[i:i + L] += g[:len(out) - i]
    return out


def syn_concreto_grande(k):
    base = thump(55 - 6 * k, 32, 0.9, 0.2)
    crunch = grains(1.3, 900, 0.35, 250, 3500)
    rum = rumble(2.4, 0.03, 0.9, 150)
    return mix((base, 0, 1.0), (peak(crunch, 0), 0.005, 0.55), (peak(rum, 0), 0, 0.7))


def syn_desmoronamento(k):
    rum = rumble(2.6, 0.5, 1.4, 120 + 30 * k)
    crunch = grains(2.2, 500, 99, 200, 2500, (0.006, 0.05), rise=1.2)
    return mix((peak(rum, 0), 0, 0.9), (peak(crunch, 0), 0.2, 0.45))


def syn_rangido(k):
    """Rangido de estrutura: pulsos de atrito (stick-slip) em ressonadores, crescendo."""
    dur = 1.1
    n = int(dur * SR)
    x = np.zeros(n)
    t = 0.0
    f = 60.0 + 15 * k
    while t < dur:
        fr = f * (1 + 0.9 * t / dur) * RNG.uniform(0.8, 1.2)
        t += 1.0 / fr
        i = int(t * SR)
        if i < n:
            x[i] = RNG.uniform(0.4, 1.0)
    y = bp(x, 180, 520) * 1.0 + bp(x, 800, 1500) * 0.6 + bp(x, 2200, 3200) * 0.25
    tt = tvec(dur)[:len(y)]
    env = (tt / dur) ** 1.6 * np.minimum(1, (dur - tt) / 0.12)
    return y * env


def syn_faisca(k):
    dur = 0.12 + 0.05 * k
    n = int(dur * SR)
    imp = (RNG.random(n) < 0.03) * RNG.uniform(-1, 1, n)
    cr = hp(imp, 1800) * 1.0
    t = tvec(dur)[:n]
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.15 * bp(RNG.standard_normal(n), 100, 3000)
    env = np.exp(-t / (dur / 3))
    return (cr + buzz) * env


def syn_choque(k):
    dur = 0.5
    t = tvec(dur)
    sq = np.sign(np.sin(2 * np.pi * (100 + 20 * k) * t)) * 0.5
    am = 0.5 + 0.5 * lp(RNG.standard_normal(len(t)), 30) / 0.05
    am = np.clip(am, 0, 1.5)
    imp = (RNG.random(len(t)) < 0.02) * RNG.uniform(-1, 1, len(t))
    y = bp(sq * am, 150, 5000) + hp(imp, 1500) * 1.4
    env = np.minimum(1, t / 0.005) * np.exp(-t / 0.22)
    return y * env


def syn_revoada(k):
    dur = 1.1
    n = int(dur * SR)
    out = np.zeros(n)
    t = 0.02
    rate = 11.0 + k
    while t < dur - 0.06:
        L = int(0.045 * SR)
        g = bp(RNG.standard_normal(L + 64), 500, 2600)[64:]
        g *= np.sin(np.linspace(0, np.pi, L)) * np.exp(-t / 0.6) * RNG.uniform(0.5, 1.0)
        i = int(t * SR)
        out[i:i + L] += g
        t += 1.0 / (rate * RNG.uniform(0.85, 1.15))
    return out


def syn_hit_grave(k):
    return thump(80 - 8 * k, 42, 0.35, 0.09)


# ---------------------------------------------------------------- tabela

def K(rel, ratio=1.0, t=None):
    x = load(rel)
    if t:
        x = seg(x, *t)
    return pitch(x, ratio)


ONESHOTS = {
    # combate
    "sfx_hit_leve": [K(K_IMP + "impactPunch_medium_%03d.ogg" % i) for i in range(5)],
    "sfx_hit_forte": [K(K_IMP + "impactPunch_heavy_%03d.ogg" % i) for i in range(5)],
    "sfx_hit_grave": [syn_hit_grave(k) for k in range(3)],
    "sfx_whoosh_leve": [K(SW + "swish-%d.wav" % i, 1.1) for i in (1, 2, 5, 6, 10, 11)],
    "sfx_whoosh_forte": [K(SW + "swish-7.wav", 0.8), K(SW + "swish-9.wav", 0.8), K(SW + "swish-3.wav", 0.72),
                         K(SW + "swish-4.wav", 0.7), K(C2 + "sfx100v2_air_03.ogg", 0.9)],
    "sfx_esquiva": [K(SW + "swish-%d.wav" % i, 1.25) for i in (12, 13, 8)],
    "sfx_grab": [K(K_RPG + "cloth%d.ogg" % i) for i in (1, 2, 3)],
    "sfx_throw": [K(K_RPG + "clothBelt.ogg"), K(K_RPG + "clothBelt2.ogg")],
    "sfx_land": [K(K_IMP + "footstep_concrete_%03d.ogg" % i, 0.9) for i in range(5)],
    "sfx_corpo_impacto": [K(K_IMP + "impactSoft_heavy_%03d.ogg" % i) for i in range(5)],
    "sfx_escudo_hit": [K(K_SCI + "forceField_000.ogg", 1.2, (0, 0.45)), K(K_SCI + "forceField_001.ogg", 1.2, (0, 0.45)),
                       K(EL + "shieldhit.wav", 1.0, (0, 0.6))],
    "sfx_escudo_quebra": [mix((K("oga_tinyworlds_glass-break/glass_breaking.wav"), 0, 0.9),
                              (K(K_SCI + "forceField_003.ogg", 0.6), 0, 0.6))],
    "sfx_explosao_carga": [K(K_SCI + "forceField_004.ogg", 1.35, (0, 0.35))],
    "sfx_explosao": [K(K_SCI + "explosionCrunch_%03d.ogg" % i) for i in range(5)],
    "sfx_explosao_grave": [K(K_SCI + "lowFrequency_explosion_000.ogg"), K(K_SCI + "lowFrequency_explosion_001.ogg")],
    "sfx_ko": [mix((K(K_SCI + "lowFrequency_explosion_000.ogg"), 0, 1.0), (K(K_SCI + "explosionCrunch_004.ogg", 0.7), 0, 0.5)),
               mix((K(K_SCI + "lowFrequency_explosion_001.ogg", 0.85), 0, 1.0), (K(K_SCI + "explosionCrunch_001.ogg", 0.75), 0, 0.5))],
    "sfx_respawn": [K(K_SCI + "forceField_002.ogg", 1.3, (0, 0.5))],
    # materiais: vidro
    "brk_vidro_impacto": [K(K_IMP + "impactGlass_heavy_%03d.ogg" % i) for i in range(5)],
    "brk_vidro_ruptura": [K(BFH + "bfh1_glass_breaking_%02d.ogg" % i) for i in range(1, 7)]
                         + [K(C2 + "sfx100v2_glass_%02d.ogg" % i) for i in (2, 3, 5)],
    "brk_vidro_grande": [K("oga_tinyworlds_glass-break/glass_breaking.wav"), K(C1 + "glass_04.ogg"), K(C1 + "glass_05.ogg")],
    "brk_vidro_cauda": [K(BFH + "bfh1_glass_falling_%02d.ogg" % i) for i in range(1, 5)],
    "brk_vidro_lasca": [K(K_IMP + "impactGlass_light_%03d.ogg" % i) for i in range(5)],
    # divisória (gesso/madeira leve)
    "brk_divisoria_impacto": [K(K_IMP + "impactPlank_medium_%03d.ogg" % i) for i in range(5)],
    "brk_divisoria_ruptura": [K(BFH + "bfh1_wood_breaking_%02d.ogg" % i) for i in range(1, 5)]
                             + [K(BFH + "bfh1_breaking_02.ogg"), K(BFH + "bfh1_breaking_03.ogg")],
    "brk_divisoria_cauda": [K(BFH + "bfh1_wood_falling_01.ogg"), K(BFH + "bfh1_wood_falling_02.ogg"),
                            K(BFH + "bfh1_falling_05.ogg"), K(BFH + "bfh1_falling_06.ogg")],
    "brk_divisoria_lasca": [K(K_IMP + "impactWood_light_%03d.ogg" % i) for i in range(5)],
    # tijolo
    "brk_tijolo_impacto": [K(K_IMP + "impactMining_%03d.ogg" % i) for i in range(5)],
    "brk_tijolo_ruptura": [K(BFH + "bfh1_rock_breaking_%02d.ogg" % i) for i in (1, 2, 3)] + [K(BFH + "bfh1_breaking_01.ogg")],
    "brk_tijolo_cauda": [K(BFH + "bfh1_rock_falling_%02d.ogg" % i) for i in (1, 3, 5, 7, 9)],
    "brk_tijolo_lasca": [K(K_IMP + "impactMining_%03d.ogg" % i, 1.35) for i in range(5)],
    # concreto
    "brk_concreto_impacto": [mix((K(BFH + "bfh1_hit_%02d.ogg" % i, 0.8), 0, 0.8), (syn_hit_grave(k), 0, 0.5))
                             for k, i in enumerate((2, 6, 7, 12))],
    "brk_concreto_ruptura": [mix((K(BFH + "bfh1_rock_breaking_%02d.ogg" % i, 0.82), 0, 0.9),
                                 (grains(0.5, 700, 0.2, 250, 3000), 0, 0.35)) for i in (1, 2, 3)],
    "brk_concreto_grande": [mix((syn_concreto_grande(k), 0, 1.0), (K(BFH + "bfh1_rock_falling_%02d.ogg" % i, 0.85), 0.25, 0.4))
                            for k, i in enumerate((1, 4, 9))],
    "brk_concreto_cauda": [K(BFH + "bfh1_rock_falling_%02d.ogg" % i, 0.85) for i in (2, 4, 6, 8)],
    "brk_concreto_lasca": [K(K_IMP + "impactMining_%03d.ogg" % i, 1.05) for i in range(5)],
    # núcleo (aço)
    "brk_nucleo_impacto": [K(K_IMP + "impactMetal_heavy_%03d.ogg" % i) for i in range(5)],
    "brk_nucleo_lasca": [K(K_IMP + "impactMetal_light_%03d.ogg" % i) for i in range(5)],
    # entulho
    "brk_entulho_impacto": [K(C2 + "sfx100v2_stones_%02d.ogg" % i) for i in (1, 2, 3)],
    "brk_entulho_lasca": [K(C2 + "sfx100v2_stones_%02d.ogg" % i, 1.3) for i in (1, 2, 3)],
    # colapso
    "sfx_rangido": [mix((syn_rangido(k), 0, 0.8), (K(K_RPG + "creak%d.ogg" % (k + 1), 0.55), 0.3, 0.6)) for k in range(3)],
    "sfx_desmoronamento": [syn_desmoronamento(k) for k in range(2)],
    # objetos
    "prop_madeira_impacto": [K(K_IMP + "impactWood_heavy_%03d.ogg" % i) for i in range(5)],
    "prop_metal_impacto": [K(K_IMP + "impactMetal_medium_%03d.ogg" % i) for i in range(5)],
    "prop_lata_impacto": [K(K_IMP + "impactTin_medium_%03d.ogg" % i) for i in range(5)],
    "prop_metal_quebra": [K(BFH + "bfh1_metal_falling_%02d.ogg" % i) for i in range(1, 6)],
    "prop_metal_hit": [K(BFH + "bfh1_metal_hit_%02d.ogg" % i) for i in range(1, 7)],
    "prop_extintor_jato": [K(C2 + "sfx100v2_air_01.ogg"), K(C2 + "sfx100v2_air_02.ogg")],
    # fixos
    "fix_vapor_jato": [K(ST + "steam_hisses_-_Marker_%d.wav" % i) for i in (1, 2, 4)],
    "fix_fogo_ignicao": [mix((K(K_SCI + "explosionCrunch_002.ogg", 0.6), 0, 0.7), (K(K_SCI + "thrusterFire_000.ogg", 1.0, (0, 1.2)), 0, 0.8))],
    "fix_queima": [K(K_SCI + "thrusterFire_%03d.ogg" % i, 1.2, (0.3, 0.7)) for i in (1, 2, 3)],
    "fix_faisca": [syn_faisca(k) for k in range(4)],
    "fix_choque": [mix((syn_choque(k), 0, 1.0), (K("oga_themightyglider_electric-buzz/buzz.ogg", 1.0, (0, 0.5)), 0, 0.5)) for k in range(2)],
    "fix_entorta": [mix((K(K_IMP + "impactMetal_medium_%03d.ogg" % i, 0.7), 0, 0.8), (K(K_RPG + "creak3.ogg", 0.5), 0.02, 0.7))
                    for i in (1, 3, 4)],
    "fix_poste_queda": [mix((K(BFH + "bfh1_metal_falling_01.ogg", 0.8), 0, 0.8), (K(K_IMP + "impactMetal_heavy_000.ogg", 0.6), 0.15, 0.8)),
                        mix((K(BFH + "bfh1_metal_falling_02.ogg", 0.75), 0, 0.8), (K(K_IMP + "impactMetal_heavy_003.ogg", 0.6), 0.1, 0.8))],
    "fix_neon_estalo": [K(BFH + "bfh1_glass_hit_01.ogg"), K(BFH + "bfh1_glass_hit_02.ogg")],
    "fix_extingue": [mix((K(C1 + "splash_01.ogg"), 0, 0.8), (K(ST + "steam_hisses_-_Marker_3.wav", 1.2), 0.05, 0.6)),
                     mix((K(C1 + "splash_02.ogg"), 0, 0.8), (K(ST + "steam_hisses_-_Marker_5.wav", 1.2), 0.05, 0.6))],
    "fix_agua_jorro": [K(WAT + "splash_%02d.ogg" % i) for i in (3, 7, 11)],
    # ambiente
    "sfx_passaros_revoada": [syn_revoada(k) for k in range(3)],
}

LOOPS = {
    # nome: (sinal, crossfade s, RMS dB)
    "fix_agua_loop": lambda: (K(C2 + "sfx100v2_loop_water_01.ogg"), 1.0, -18),
    "fix_hidrante_loop": lambda: (K(C2 + "sfx100v2_loop_water_03.ogg"), 1.0, -16),
    "fix_vapor_loop": lambda: (np.concatenate([seg(K(ST + "steam_hisses_-_Marker_%d.wav" % i), 0.15, 1.6) for i in (1, 2, 3, 4)]), 0.3, -16),
    "fix_gas_loop": lambda: (pitch(np.concatenate([seg(K(ST + "steam_hisses_-_Marker_%d.wav" % i), 0.2, 1.6) for i in (5, 3)]), 1.5), 0.25, -20),
    "fix_fogo_loop": lambda: (K("oga_pagdev_fireplace-loop/fire.wav", 1.0, (2.0, 12.0)), 1.5, -16),
    "fix_eletrico_loop": lambda: (K(EL + "snaploop.wav"), 0.2, -18),
    "fix_fiacao_loop": lambda: (np.tile(K(EL + "crackleelectricityloop.wav"), 5), 0.05, -20),
    "fix_neon_loop": lambda: (np.tile(K("oga_themightyglider_electric-buzz/buzz.ogg"), 3), 0.05, -24),
    "fix_pavio_loop": lambda: (pitch(np.concatenate([seg(K(ST + "steam_hisses_-_Marker_%d.wav" % i), 0.2, 1.5) for i in (2, 4)]), 1.7), 0.15, -18),
}

AMB_LOOPS = {
    "amb_cidade_loop": ("oga_ignasd_high-traffic-road/gatve_Varniu_2.ogg", 3.0, -20),
    "amb_passaros_loop": ("oga_isaiah658_ambient-birds/birds-isaiah658.ogg", 2.0, -22),
}


def crowd_cuts(rel, n, length, stereo=True):
    x = load(rel, 2 if stereo else 1)
    mono = x.mean(axis=1) if stereo else x
    hop = int(0.25 * SR)
    L = int(length * SR)
    energy = [(np.sqrt(np.mean(mono[i:i + L] ** 2)), i) for i in range(0, len(mono) - L, hop)]
    energy.sort(reverse=True)
    picks = []
    for e, i in energy:
        if all(abs(i - j) > L for j in picks):
            picks.append(i)
        if len(picks) == n:
            break
    return [x[i:i + L] for i in sorted(picks)]


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".ogg"):
            os.remove(os.path.join(OUT, f))
    count = 0
    for group, sounds in ONESHOTS.items():
        for i, x in enumerate(sounds):
            fo = 0.25 if group.endswith(("_cauda", "_grande", "desmoronamento", "rangido", "_ko", "explosao_grave")) else 0.04
            save("%s_%02d" % (group, i + 1), oneshot(x, fo))
            count += 1
    for name, fn in LOOPS.items():
        x, xf, db = fn()
        x = trim(x, -60)
        save(name, rms_norm(loopify(x, xf), db))
        count += 1
    for name, (rel, xf, db) in AMB_LOOPS.items():
        x = load(rel, 2)
        save(name, rms_norm(loopify(x, xf), db))
        count += 1
    for i, x in enumerate(crowd_cuts("oga_starninjas_crowd-shouting/crowd_shouting.ogg", 3, 2.6)):
        save("amb_publico_susto_%02d" % (i + 1), peak(fade(x, 0.12, 0.9)))
        count += 1
    for i, x in enumerate(crowd_cuts("oga_expl0it3r_applause/applause-clapping-church-crowd-immersive.wav", 3, 3.5)):
        save("amb_publico_aplauso_%02d" % (i + 1), peak(fade(x, 0.25, 1.4)))
        count += 1
    print("%d arquivos em %s" % (count, OUT))


if __name__ == "__main__":
    sys.exit(main())
