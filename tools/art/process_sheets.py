#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pipeline de processamento de arte do lote 02 (Docs/arte/prompts_arte_lote02.md §7).

Lê art/lote02/**.png (+ JSON irmão com asset_id, kind, grid, loop) e escreve:
  game/assets/{chr,bg,mod,prop,fx,ui}/...      (PNG + JSON de metadados)
  art/lote02/_preview/                          (GIFs, pranchas, relatório de consistência)

Uso:
  python tools/art/process_sheets.py                       # tudo o que existir
  python tools/art/process_sheets.py --only chr            # uma categoria
  python tools/art/process_sheets.py --asset chr_faisca_idle
  python tools/art/process_sheets.py --input caminho.png --grid 3x1 \
         [--out-root DIR] [--preview-root DIR]              # arquivo avulso (teste)

Observações:
  * --asset de uma animação de lutador reprocessa o lutador inteiro: o tamanho de célula e a
    escala dependem de todas as animações dele (escala única, pivô comum).
  * Nada é corrigido em silêncio: frames fora dos limites continuam exportados e são listados
    em `flags` no JSON e no relatório.
  * Só Pillow + numpy.

LIMITES DE CONSISTÊNCIA (frames fora deles recebem `flag`)
  H_RATIO_RANGE      altura do frame / mediana da altura do idle, só em frames no chão das
                     animações de pé (STANDING_ANIMS). Fora de [0.85, 1.15] = personagem
                     desenhado em outra escala ou pose agachada onde não devia.
  HIST_MAX           distância de Hellinger (0..1) entre histogramas hue×sat do frame e do
                     idle frame 1 (alpha 0 ignorado). > 0.40 = paleta/figurino divergente.
  HIST_MAX_FX        idem para animações com efeito desenhado (EFFECT_ANIMS): > 0.55.
  PIVOT_DX_MAX       |centro horizontal na folha - centro da célula| / altura do idle > 0.20
                     = personagem fora do centro da célula (pode indicar invasão de célula).
  FOOT_DY_MAX        frames no chão: |linha dos pés - linha de base mediana da folha| /
                     altura do idle > 0.06 = pés fora da linha de base.
  AREA_RANGE         área opaca / mediana da área do idle: STANDING_ANIMS [0.55, 1.8];
                     demais [0.30, 3.0].
  CRUZA_CELULA       parte do frame atravessa a borda da grade (foi recuperada inteira, pois a
                     fatia é por componente conectado; indica folha fora da regra "nada cruza").
  CORTADO            conteúdo passou até da folga de meia célula: parte perdida.
  FUNDIDO_VIZINHO    o frame encosta no vizinho (um componente > 1.5 célula): cortado pela grade.
  EMPTY              célula sem conteúdo.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import glob
import json
import math
import os
import re
import sys
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFont

# --------------------------------------------------------------------------------------------
# Configuração
# --------------------------------------------------------------------------------------------
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(ROOT, "art", "lote02")
OUT_ROOT = os.path.join(ROOT, "game", "assets")
PREVIEW_ROOT = os.path.join(SRC_DIR, "_preview")

PX_PER_WORLD = 4
FIGHTER_HEIGHT_WORLD = {"faisca": 44, "brasa": 50, "bloco": 56}

# Limites (ver docstring)
H_RATIO_RANGE = (0.85, 1.15)
HIST_MAX = 0.40
HIST_MAX_FX = 0.55
PIVOT_DX_MAX = 0.20
FOOT_DY_MAX = 0.06
AREA_RANGE_STANDING = (0.55, 1.8)
AREA_RANGE_OTHER = (0.30, 3.0)

STANDING_ANIMS = {"idle", "run", "jab", "strong", "grab", "stun", "carry_run", "throw_obj"}
EFFECT_ANIMS = {"strong", "strong_up", "burst", "stomp", "spike", "land", "hurt", "ko"}

# Frames aéreos (1-based). "all" = todos. O centro horizontal usa o corpo inteiro e a altura
# vertical preserva a posição relativa à linha de base da folha (o salto real vem da simulação).
AERIAL_FRAMES: dict[str, object] = {
    "jump": {2, 3, 4, 5},
    "fall": "all",
    "hurt": "all",
    "spike": "all",
    "air_dodge": "all",
    "grabbed": "all",
    "ko": "all_but_last",
}

FPS_TABLE = {"idle": 10, "run": 14, "carry_run": 14}
ATTACK_ANIMS = {"jab", "strong", "strong_up", "stomp", "spike", "burst", "grab", "throw_obj"}
FPS_ATTACK = 18
FPS_DEFAULT = 12
FPS_FX = 24
FX_LOOP = {"fx_escudo", "fx_aviso_colapso"}

# Quantidade de frames/loop por animação (fallback quando o JSON não traz a grade)
ANIM_TABLE = {
    "idle": (8, True), "run": (8, True), "jump": (6, False), "jab": (6, False),
    "strong": (8, False), "hurt": (6, False), "grab": (6, False), "burst": (8, False),
    "fall": (6, True), "land": (6, False), "strong_up": (8, False), "stomp": (8, False),
    "spike": (6, False), "grabbed": (6, True), "carry_idle": (6, True), "carry_run": (8, True),
    "throw_obj": (6, False), "shield": (6, True), "roll": (8, False), "spot_dodge": (6, False),
    "air_dodge": (6, False), "stun": (6, True), "ko": (6, False), "victory": (8, True),
}
EXPRESSIONS = ["neutro", "determinado", "gritando", "dor", "atordoado", "rindo", "bravo", "vitoria"]
PORTRAIT_ORDER = ["bloco", "faisca", "brasa"]  # ui_retratos 3×1

PROP_TARGET_H = {"prop_caixa": 64, "prop_barril": 80, "prop_maquina": 160}
PROP_EXTRAS = [("cone", 64), ("lixeira", 80), ("hidrante", 64), ("banco", 64)]  # alturas provisórias
BG_WIDTH = 1280
INTERIOR_WIDTH = 1024
TEXTURE_SIZE = 256
SEAM_RATIO_MAX = 1.3     # costura / p90 das diferenças internas; acima disso tenta blend de borda
KIT_NAMES = {
    "mod_fachada_detalhes": ["janela", "toldo", "neon", "ar_condicionado", "calha", "escada_incendio",
                             "caixa_dagua", "antena"],
    "dec_rachaduras": ["fina", "media", "teia", "queimado", "cratera", "aviso_laranja", "poeira",
                       "tinta_lascada"],
    "brk_bordas": ["vidro", "divisoria", "tijolo", "concreto", "entulho", "asfalto"],
}
KIT_GRID = {"mod_fachada_detalhes": (4, 2), "dec_rachaduras": (4, 2), "brk_bordas": (1, 6)}

# Remoção de fundo
ALPHA_USEFUL_FRAC = 0.02          # >= 2% dos pixels com alpha < 16 => alpha já é útil
MAGENTA = np.array([255, 0, 255], np.float32)
TOL_MAGENTA = (60.0, 130.0)       # distância RGB: < in => transparente; > out => opaco
TOL_FLAT = (18.0, 48.0)           # cor chapada qualquer (só regiões ligadas à borda)
SPILL_BAND = 3                    # px de franja onde se aplica despill de magenta

# Ilhas soltas: área < max(MIN_PX, FRAC × maior componente) é removida
ISLAND = {"chr": (30, 0.0015), "prop": (30, 0.002), "ui": (20, 0.001), "fx": (6, 0.0),
          "bg": (12, 0.0), "kit": (8, 0.0), "anchor": (40, 0.002)}
UI_GROUP_RADIUS = 10              # px de dilatação para agrupar letras/partes de um elemento UI
UI_TEXT_ASSETS = {"ui_banners"}  # só nestes as letras de uma linha são unidas
UI_LINE_GAP = 0.35               # vão máximo (× altura) para unir partes de um mesmo elemento
UI_MIN_FRAC = 0.01                # grupos UI menores que 1% do maior são ignorados

CELL_MARGIN = 6                   # px (saída) de folga em volta da maior pose
PREVIEW_BG = (128, 128, 128)
OPAQUE_ALPHA = 128                # limiar para medições (pés, bbox de medida, áreas)

VERBOSE = True


def log(*a):
    if VERBOSE:
        print(*a, flush=True)


# --------------------------------------------------------------------------------------------
# Metadados
# --------------------------------------------------------------------------------------------
@dataclass
class Asset:
    png: str
    meta: dict
    asset_id: str
    kind: str
    grid: tuple | None      # (cols, rows, frames)
    loop: bool | None
    revision: int = 0
    extra: dict = field(default_factory=dict)


def _to_int(v):
    try:
        if v is None:
            return None
        return int(v)
    except (TypeError, ValueError):
        return None


def parse_grid(meta: dict):
    """Aceita grid como dict (columns/cols/colunas/x, rows/linhas/y, frames/quadros), lista
    [c, r(, f)] ou string '4x2'. Também chaves soltas no topo."""
    g = None
    for k in ("grid", "grade", "sheet_grid", "layout"):
        if k in meta:
            g = meta[k]
            break
    cols = rows = frames = None
    if isinstance(g, dict):
        low = {str(k).lower(): v for k, v in g.items()}
        for k in ("columns", "cols", "colunas", "col", "x", "c", "w"):
            if k in low:
                cols = _to_int(low[k]); break
        for k in ("rows", "linhas", "lin", "y", "r", "h"):
            if k in low:
                rows = _to_int(low[k]); break
        for k in ("frames", "quadros", "count", "n", "cells"):
            if k in low:
                frames = _to_int(low[k]); break
    elif isinstance(g, (list, tuple)) and len(g) >= 2:
        cols, rows = _to_int(g[0]), _to_int(g[1])
        frames = _to_int(g[2]) if len(g) > 2 else None
    elif isinstance(g, str):
        m = re.match(r"\s*(\d+)\s*[x×X*]\s*(\d+)", g)
        if m:
            cols, rows = int(m.group(1)), int(m.group(2))
    if cols is None:
        cols = _to_int(meta.get("columns") or meta.get("cols"))
    if rows is None:
        rows = _to_int(meta.get("rows"))
    if frames is None:
        frames = _to_int(meta.get("frames") or meta.get("frame_count"))
    if cols and rows:
        return (cols, rows, frames or cols * rows)
    if frames:
        return (None, None, frames)
    return None


def parse_loop(meta: dict):
    v = meta.get("loop")
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        return v.strip().lower() in ("sim", "true", "yes", "1", "loop")
    return None


def read_json(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        return json.load(f)


def load_asset(png: str, grid_override=None) -> Asset:
    stem = os.path.splitext(os.path.basename(png))[0]
    meta = {}
    js = os.path.splitext(png)[0] + ".json"
    if os.path.exists(js):
        try:
            meta = read_json(js)
        except Exception as e:  # noqa: BLE001
            log(f"  ! JSON ilegível {js}: {e}")
    asset_id = str(meta.get("asset_id") or stem)
    grid = grid_override or parse_grid(meta)
    return Asset(png=png, meta=meta, asset_id=asset_id, kind=str(meta.get("kind", "")),
                 grid=grid, loop=parse_loop(meta), revision=_to_int(meta.get("revision")) or 0)


def category(asset_id: str) -> str:
    p = asset_id.split("_", 1)[0]
    if p in ("mod", "brk", "dec"):
        return "mod"
    return p


def discover(src_dir: str) -> list[Asset]:
    files = [f for f in glob.glob(os.path.join(src_dir, "**", "*.png"), recursive=True)
             if "_preview" not in f.replace("\\", "/").split("/")
             and not os.path.basename(f).startswith("_")]
    by_id: dict[str, Asset] = {}
    for f in sorted(files):
        a = load_asset(f)
        cur = by_id.get(a.asset_id)
        if cur is None or (a.revision, os.path.getmtime(a.png)) > (cur.revision, os.path.getmtime(cur.png)):
            by_id[a.asset_id] = a
    return list(by_id.values())


# --------------------------------------------------------------------------------------------
# Rotulagem de componentes conectados (8-vizinhança) por runs + union-find, só numpy
# --------------------------------------------------------------------------------------------
class Components:
    def __init__(self, mask: np.ndarray):
        H, W = mask.shape
        self.shape = (H, W)
        m = np.zeros((H, W + 2), np.int8)
        m[:, 1:-1] = mask
        d = np.diff(m, axis=1)
        sr, sc = np.nonzero(d == 1)
        er, ec = np.nonzero(d == -1)
        n = len(sr)
        self.row, self.s, self.e = sr, sc, ec
        parent = list(range(n))

        def find(x):
            while parent[x] != x:
                parent[x] = parent[parent[x]]
                x = parent[x]
            return x

        rs = np.searchsorted(sr, np.arange(H + 1)).tolist()
        S, E = sc.tolist(), ec.tolist()
        for y in range(H - 1):
            i, a1 = rs[y], rs[y + 1]
            j, b1 = rs[y + 1], rs[y + 2]
            while i < a1 and j < b1:
                if S[i] <= E[j] and S[j] <= E[i]:
                    ri, rj = find(i), find(j)
                    if ri != rj:
                        parent[max(ri, rj)] = min(ri, rj)
                if E[i] < E[j]:
                    i += 1
                else:
                    j += 1
        roots = np.array([find(i) for i in range(n)], np.int64) if n else np.zeros(0, np.int64)
        uniq, lab = np.unique(roots, return_inverse=True)
        self.lab = lab
        self.n = len(uniq)
        L = (ec - sc).astype(np.int64)
        self.area = np.bincount(lab, weights=L, minlength=self.n).astype(np.int64) if n else np.zeros(0, np.int64)
        if n:
            self.x0 = np.full(self.n, W, np.int64); np.minimum.at(self.x0, lab, sc)
            self.x1 = np.zeros(self.n, np.int64); np.maximum.at(self.x1, lab, ec)
            self.y0 = np.full(self.n, H, np.int64); np.minimum.at(self.y0, lab, sr)
            self.y1 = np.zeros(self.n, np.int64); np.maximum.at(self.y1, lab, sr + 1)
        else:
            self.x0 = self.x1 = self.y0 = self.y1 = np.zeros(0, np.int64)

    def mask_of(self, keep: np.ndarray) -> np.ndarray:
        """keep: bool por componente -> máscara de pixels."""
        out = np.zeros(self.shape, bool)
        idx = np.nonzero(keep[self.lab])[0]
        R, S, E = self.row[idx].tolist(), self.s[idx].tolist(), self.e[idx].tolist()
        for y, s, e in zip(R, S, E):
            out[y, s:e] = True
        return out

    def touches_border(self) -> np.ndarray:
        H, W = self.shape
        return (self.x0 == 0) | (self.y0 == 0) | (self.x1 == W) | (self.y1 == H)


def dilate(mask: np.ndarray, r: int) -> np.ndarray:
    if r <= 0:
        return mask.copy()
    out = mask.copy()
    for k in range(1, r + 1):
        out[:, k:] |= mask[:, :-k]
        out[:, :-k] |= mask[:, k:]
    tmp = out.copy()
    for k in range(1, r + 1):
        out[k:, :] |= tmp[:-k, :]
        out[:-k, :] |= tmp[k:, :]
    return out


# --------------------------------------------------------------------------------------------
# Fundo e ilhas
# --------------------------------------------------------------------------------------------
def remove_background(img: Image.Image, report: dict) -> np.ndarray:
    """Retorna array RGBA float32 [0..255] com fundo removido."""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    alpha = a[..., 3]
    if img.mode in ("RGBA", "LA", "PA") or "transparency" in img.info:
        frac = float((alpha < 16).mean())
        if frac >= ALPHA_USEFUL_FRAC:
            report["fundo"] = f"alpha original ({frac:.0%} transparente)"
            return a
    H, W = alpha.shape
    p = max(4, min(H, W) // 64)
    patches = [a[:p, :p, :3], a[:p, -p:, :3], a[-p:, :p, :3], a[-p:, -p:, :3]]
    meds = np.array([np.median(x.reshape(-1, 3), axis=0) for x in patches])
    bg = np.median(meds, axis=0)
    spread = float(np.max(np.linalg.norm(meds - bg, axis=1)))
    is_magenta = float(np.linalg.norm(bg - MAGENTA)) < 90
    if spread > 30 and not is_magenta:
        report["fundo"] = f"ALERTA: cantos discordam (spread {spread:.0f}); fundo mantido"
        return a
    rgb = a[..., :3]
    d = np.linalg.norm(rgb - bg[None, None, :], axis=2)
    tin, tout = TOL_MAGENTA if is_magenta else TOL_FLAT
    ab = np.clip((d - tin) / (tout - tin), 0.0, 1.0)
    if not is_magenta:
        # só remove regiões parecidas com o fundo e ligadas à borda da imagem
        cand = d < tout
        comp = Components(cand)
        keep = comp.touches_border()
        border_region = comp.mask_of(keep)
        ab = np.where(border_region, ab, 1.0)
    # unmix: C = a·F + (1-a)·B  ->  F = (C - (1-a)·B) / a
    semi = (ab > 0.02) & (ab < 0.999)
    fa = np.maximum(ab, 0.02)[..., None]
    unmixed = (rgb - (1.0 - fa) * bg[None, None, :]) / fa
    rgb = np.where(semi[..., None], np.clip(unmixed, 0, 255), rgb)
    if is_magenta:
        edge = dilate(ab < 0.5, SPILL_BAND) & (ab >= 0.5)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        spill = np.clip(np.minimum(r, b) - g, 0, None) * edge
        rgb = rgb - spill[..., None] * np.array([1.0, 0.0, 1.0], np.float32)
    out = np.dstack([rgb, alpha * ab])
    report["fundo"] = (f"{'magenta' if is_magenta else 'cor chapada'} "
                       f"rgb({bg[0]:.0f},{bg[1]:.0f},{bg[2]:.0f}) removido, tol {tin:.0f}-{tout:.0f}"
                       + (", despill" if is_magenta else ", só regiões ligadas à borda"))
    return out


def remove_islands(rgba: np.ndarray, min_px: int, frac: float) -> tuple[np.ndarray, int, int]:
    """Remove componentes pequenos. Retorna (rgba, n_removidos, px_removidos)."""
    alpha = rgba[..., 3]
    mask = alpha >= 32
    if not mask.any():
        return rgba, 0, 0
    comp = Components(mask)
    thr = max(min_px, frac * float(comp.area.max()))
    keep = comp.area >= thr
    n_rem = int((~keep).sum())
    if n_rem == 0:
        return rgba, 0, 0
    kept = dilate(comp.mask_of(keep), 2)
    removed_px = int(comp.area[~keep].sum())
    out = rgba.copy()
    out[..., 3] = np.where(kept, alpha, 0)
    return out, n_rem, removed_px


def to_image(rgba: np.ndarray) -> Image.Image:
    a = np.clip(rgba + 0.5, 0, 255).astype(np.uint8)
    a[a[..., 3] == 0, :3] = 0
    return Image.fromarray(a, "RGBA")


def bbox_alpha(alpha: np.ndarray, thr: float = 1):
    ys, xs = np.nonzero(alpha >= thr)
    if len(ys) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def crop_rgba(rgba: np.ndarray, pad: int = 0) -> tuple[np.ndarray, tuple | None]:
    bb = bbox_alpha(rgba[..., 3])
    if bb is None:
        return rgba[:1, :1] * 0, None
    x0, y0, x1, y1 = bb
    H, W = rgba.shape[:2]
    x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(W, x1 + pad), min(H, y1 + pad)
    return rgba[y0:y1, x0:x1], (x0, y0, x1, y1)


def resize_rgba(img: Image.Image, w: int, h: int) -> Image.Image:
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    return img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")


def split_grid(rgba: np.ndarray, cols: int, rows: int, frames: int | None = None):
    H, W = rgba.shape[:2]
    xs = [round(i * W / cols) for i in range(cols + 1)]
    ys = [round(j * H / rows) for j in range(rows + 1)]
    cells = []
    for j in range(rows):
        for i in range(cols):
            cells.append(rgba[ys[j]:ys[j + 1], xs[i]:xs[i + 1]].copy())
    if frames:
        cells = cells[:frames]
    return cells


@dataclass
class Cell:
    rgba: np.ndarray          # canvas expandido (célula nominal + folga de cada lado)
    pad_x: int
    pad_y: int
    w: int                    # tamanho nominal da célula
    h: int
    crossed: bool = False     # algum pedaço saiu da célula nominal (recuperado inteiro)
    fused: bool = False       # componente ligado a outro frame: cortado na borda da grade


def extract_cells(rgba: np.ndarray, cols: int, rows: int, frames: int | None = None,
                  pad_frac: float = 0.5) -> list[Cell]:
    """Fatia a grade por componentes: cada componente conectado vai inteiro para a célula que
    contém o seu centro de massa, mesmo que atravesse a borda da grade (o pedaço não é cortado).
    Componente mais largo/alto que 1.5 célula (dois frames encostados) é cortado pela grade."""
    H, W = rgba.shape[:2]
    xs = [round(i * W / cols) for i in range(cols + 1)]
    ys = [round(j * H / rows) for j in range(rows + 1)]
    cw, ch = W / cols, H / rows
    mask = rgba[..., 3] >= 32
    comp = Components(mask)
    n_cells = cols * rows
    if comp.n:
        L = (comp.e - comp.s).astype(np.float64)
        sx = np.bincount(comp.lab, weights=(comp.s + comp.e - 1) * L / 2.0, minlength=comp.n)
        sy = np.bincount(comp.lab, weights=comp.row * L, minlength=comp.n)
        cx, cy = sx / comp.area, sy / comp.area
        ci = np.clip((cx // cw).astype(int), 0, cols - 1)
        cj = np.clip((cy // ch).astype(int), 0, rows - 1)
        owner = cj * cols + ci
        fused = ((comp.x1 - comp.x0) > 1.5 * cw) | ((comp.y1 - comp.y0) > 1.5 * ch)
    px, py = int(cw * pad_frac), int(ch * pad_frac)
    padded = np.zeros((H + 2 * py, W + 2 * px, 4), np.float32)
    padded[py:py + H, px:px + W] = rgba
    cells = []
    count = frames or n_cells
    for k in range(min(count, n_cells)):
        i, j = k % cols, k // cols
        x0, x1, y0, y1 = xs[i], xs[i + 1], ys[j], ys[j + 1]
        cellmask = np.zeros((H, W), bool)
        crossed = is_fused = False
        if comp.n:
            mine = (owner == k) & ~fused
            if mine.any():
                cellmask |= comp.mask_of(mine)
                crossed = bool(((comp.x0[mine] < x0) | (comp.x1[mine] > x1) |
                                (comp.y0[mine] < y0) | (comp.y1[mine] > y1)).any())
            fz = fused & ((comp.x0 < x1) & (comp.x1 > x0) & (comp.y0 < y1) & (comp.y1 > y0))
            if fz.any():
                is_fused = True
                grid_rect = np.zeros((H, W), bool)
                grid_rect[y0:y1, x0:x1] = True
                cellmask |= comp.mask_of(fz) & grid_rect
        keep = dilate(cellmask, 2)  # franja de alpha baixo em volta do que é da célula
        keep_p = np.zeros(padded.shape[:2], bool)
        keep_p[py:py + H, px:px + W] = keep
        wx0, wx1 = x0, x1 + 2 * px   # janela = célula nominal + folga (coordenadas do padded)
        wy0, wy1 = y0, y1 + 2 * py
        win = padded[wy0:wy1, wx0:wx1].copy()
        win[..., 3] = np.where(keep_p[wy0:wy1, wx0:wx1], win[..., 3], 0)
        cells.append(Cell(win, px, py, x1 - x0, y1 - y0, crossed, is_fused))
    return cells


def grid_of(asset: Asset, default):
    g = asset.grid
    if g and g[0] and g[1]:
        return g
    if g and g[2] and default and default[0] * default[1] >= g[2]:
        return (default[0], default[1], g[2])
    return default


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def rel(p):
    try:
        return os.path.relpath(p, ROOT).replace("\\", "/")
    except ValueError:
        return p.replace("\\", "/")


# --------------------------------------------------------------------------------------------
# Métricas
# --------------------------------------------------------------------------------------------
def hs_hist(rgba: np.ndarray) -> np.ndarray | None:
    m = rgba[..., 3] >= OPAQUE_ALPHA
    if m.sum() < 20:
        return None
    rgb = np.clip(rgba[..., :3][m], 0, 255).astype(np.uint8)
    hsv = np.asarray(Image.fromarray(rgb.reshape(-1, 1, 3), "RGB").convert("HSV")).reshape(-1, 3).astype(np.int32)
    h, s, v = hsv[:, 0], hsv[:, 1], hsv[:, 2]
    chroma = s >= 40
    hb = (h * 24) // 256
    sb = np.clip((s - 40) * 3 // 216, 0, 2)
    idx_c = hb * 3 + sb                     # 0..71
    idx_g = 72 + np.clip(v * 4 // 256, 0, 3)  # tons neutros por valor
    idx = np.where(chroma, idx_c, idx_g)
    hist = np.bincount(idx, minlength=76).astype(np.float64)
    return hist / hist.sum()


def hellinger(p, q):
    if p is None or q is None:
        return None
    return float(math.sqrt(max(0.0, 1.0 - np.sum(np.sqrt(p * q)))))


def is_aerial(anim: str, fi: int, n: int) -> bool:
    spec = AERIAL_FRAMES.get(anim)
    if spec is None:
        return False
    if spec == "all":
        return True
    if spec == "all_but_last":
        return fi < n - 1
    return (fi + 1) in spec


def anim_fps(anim: str) -> int:
    if anim in FPS_TABLE:
        return FPS_TABLE[anim]
    if anim in ATTACK_ANIMS:
        return FPS_ATTACK
    return FPS_DEFAULT


# --------------------------------------------------------------------------------------------
# Lutadores
# --------------------------------------------------------------------------------------------
def fighter_of(asset_id: str):
    m = re.match(r"chr_([a-z0-9]+)_(.+)$", asset_id)
    if not m:
        return None, None
    return m.group(1), m.group(2)


def measure_frame(cell: np.ndarray):
    alpha = cell[..., 3]
    mm = alpha >= OPAQUE_ALPHA
    ys, xs = np.nonzero(mm)
    if len(ys) == 0:
        return None
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
    h = y1 - y0
    low = ys >= y1 - max(1, h // 3)
    return {
        "x0": x0, "x1": x1, "y0": y0, "y1": y1, "h": h, "w": x1 - x0,
        "area": int(mm.sum()),
        "cx_feet": float(xs[low].mean()), "cx_body": float(xs.mean()),
        "foot": float(y1),
    }


def process_fighter(name: str, assets: list[Asset], out_root: str, prev_root: str, summary: dict):
    log(f"[chr] {name}: {len(assets)} folha(s)")
    target_h = FIGHTER_HEIGHT_WORLD.get(name, 50) * PX_PER_WORLD
    fdir = os.path.join(out_root, "chr", name)
    os.makedirs(fdir, exist_ok=True)
    anims = {}
    extras = []
    for a in assets:
        _, anim = fighter_of(a.asset_id)
        if anim in ("anchor", "expressoes"):
            extras.append((anim, a))
        else:
            anims[anim] = a
    fsum = {"escala": None, "anims": {}, "extras": [], "flags": []}
    summary.setdefault("chr", {})[name] = fsum

    anchor_hist = None
    for kind, a in extras:
        rep = {}
        rgba = remove_background(Image.open(a.png), rep)
        if kind == "anchor":
            rgba, nrem, _ = remove_islands(rgba, *ISLAND["anchor"])
            crop, _ = crop_rgba(rgba, 2)
            to_image(crop).save(os.path.join(fdir, "anchor.png"))
            anchor_hist = hs_hist(crop)
            fsum["extras"].append(f"anchor.png ({rep.get('fundo')}; {nrem} ilhas removidas)")
        else:
            cols, rows, n = grid_of(a, (4, 2, 8))
            cells = split_grid(rgba, cols, rows, n)
            crop, _ = crop_rgba(rgba, 2)
            to_image(crop).save(os.path.join(fdir, "expressoes.png"))
            for i, c in enumerate(cells):
                c, _, _ = remove_islands(c, *ISLAND["chr"])
                cc, bb = crop_rgba(c, 2)
                nm = EXPRESSIONS[i] if i < len(EXPRESSIONS) else f"{i + 1:02d}"
                if bb:
                    to_image(cc).save(os.path.join(fdir, f"expressao_{nm}.png"))
            fsum["extras"].append(f"expressoes.png + {len(cells)} recortes ({rep.get('fundo')})")

    if not anims:
        return

    # 1) fatiar, limpar e medir no espaço da folha
    data = {}
    for anim, a in sorted(anims.items()):
        default_n, default_loop = ANIM_TABLE.get(anim, (8, False))
        default_grid = (4, 2, 8) if default_n == 8 else (3, 2, 6)
        cols, rows, n = grid_of(a, default_grid)
        rep = {}
        rgba = remove_background(Image.open(a.png), rep)
        cells = extract_cells(rgba, cols, rows, n)
        frames = []
        for i, cobj in enumerate(cells):
            c, nrem, prem = remove_islands(cobj.rgba, *ISLAND["chr"])
            m = measure_frame(c)
            frames.append({"cell": c, "m": m, "islands": nrem, "island_px": prem,
                           "crossed": cobj.crossed, "fused": cobj.fused,
                           "aerial": is_aerial(anim, i, len(cells))})
        c0 = cells[0] if cells else Cell(np.zeros((1, 1, 4), np.float32), 0, 0, 1, 1)
        ground_feet = [f["m"]["foot"] - c0.pad_y for f in frames if f["m"] and not f["aerial"]]
        baseline = float(np.median(ground_feet)) if ground_feet else None
        data[anim] = {"asset": a, "grid": (cols, rows, len(cells)), "frames": frames, "rep": rep,
                      "baseline": baseline, "cell_h": c0.h, "cell_w": c0.w, "pad": (c0.pad_x, c0.pad_y),
                      "loop": a.loop if a.loop is not None else default_loop}

    # 2) referência: idle
    ref_note = "idle"
    if "idle" in data:
        ref_frames = [f for f in data["idle"]["frames"] if f["m"] and not f["aerial"]]
    else:
        ref_frames = []
    if not ref_frames:
        ref_note = "PROVISÓRIA (sem idle): mediana dos frames no chão disponíveis"
        ref_frames = [f for d in data.values() for f in d["frames"] if f["m"] and not f["aerial"]]
        if not ref_frames:
            ref_frames = [f for d in data.values() for f in d["frames"] if f["m"]]
    if not ref_frames:
        log(f"  ! {name}: nenhum frame com conteúdo")
        return
    idle_h = float(np.median([f["m"]["h"] for f in ref_frames]))
    idle_area = float(np.median([f["m"]["area"] for f in ref_frames]))
    ref_hist = hs_hist(ref_frames[0]["cell"])
    scale = target_h / idle_h
    fsum["escala"] = {"ref": ref_note, "altura_ref_src_px": round(idle_h, 1), "alvo_px": target_h,
                      "escala": round(scale, 4)}
    # linha de base de fallback para folhas só aéreas
    idle_base_frac = None
    if "idle" in data and data["idle"]["baseline"] is not None:
        idle_base_frac = data["idle"]["baseline"] / data["idle"]["cell_h"]

    # 3) pivô de origem, métricas e extensão escalada
    ext = {"l": 1, "r": 1, "u": 1, "d": 1}
    for anim, d in data.items():
        base = d["baseline"]
        if base is None:
            base = (idle_base_frac if idle_base_frac is not None else 0.88) * d["cell_h"]
        d["baseline_used"] = base
        cw = d["cell_w"]
        padx, pady = d["pad"]
        for i, f in enumerate(d["frames"]):
            m = f["m"]
            flags = []
            met = {"frame": i + 1, "aereo": f["aerial"], "ilhas_removidas": f["islands"]}
            if f["fused"]:
                flags.append("FUNDIDO_VIZINHO")
            if m is None:
                flags.append("EMPTY")
                met["flags"] = flags
                f["met"] = met
                continue
            px = m["cx_body"] if f["aerial"] else m["cx_feet"]
            py = base + pady if f["aerial"] else m["foot"]
            f["pivot_src"] = (px, py)
            # métricas
            hr = m["h"] / idle_h
            ar = m["area"] / idle_area
            hd = hellinger(hs_hist(f["cell"]), ref_hist)
            ha = hellinger(hs_hist(f["cell"]), anchor_hist) if anchor_hist is not None else None
            dx = (px - padx - cw / 2) / idle_h
            dy = (m["foot"] - pady - base) / idle_h
            met.update({"altura_src_px": m["h"], "altura_ratio": round(hr, 3),
                        "area_px": m["area"], "area_ratio": round(ar, 3),
                        "hist_dist_idle1": None if hd is None else round(hd, 3),
                        "hist_dist_anchor": None if ha is None else round(ha, 3),
                        "pivot_src": [round(px - padx, 1), round(py - pady, 1)],
                        "pivot_dx_rel": round(dx, 3), "pe_dy_rel": round(dy, 3)})
            standing = anim in STANDING_ANIMS and not f["aerial"]
            if standing and not (H_RATIO_RANGE[0] <= hr <= H_RATIO_RANGE[1]):
                flags.append(f"ALTURA {hr:.2f}")
            lim = HIST_MAX_FX if anim in EFFECT_ANIMS else HIST_MAX
            if hd is not None and hd > lim:
                flags.append(f"COR {hd:.2f}")
            if abs(dx) > PIVOT_DX_MAX:
                flags.append(f"PIVO_X {dx:+.2f}")
            if not f["aerial"] and abs(dy) > FOOT_DY_MAX:
                flags.append(f"PES {dy:+.2f}")
            arng = AREA_RANGE_STANDING if standing else AREA_RANGE_OTHER
            if not (arng[0] <= ar <= arng[1]):
                flags.append(f"AREA {ar:.2f}")
            H, W = f["cell"].shape[:2]
            bb = bbox_alpha(f["cell"][..., 3], 32)
            if bb and (bb[0] <= 0 or bb[1] <= 0 or bb[2] >= W or bb[3] >= H):
                flags.append("CORTADO")       # passou até da folga: parte perdida
            elif f["crossed"]:
                flags.append("CRUZA_CELULA")  # recuperado inteiro, mas a folha invadiu o vizinho
            met["flags"] = flags
            f["met"] = met
            # extensão escalada em torno do pivô (bbox com alpha > 0)
            bb0 = bbox_alpha(f["cell"][..., 3])
            f["bbox"] = bb0
            ext["l"] = max(ext["l"], (px - bb0[0]) * scale)
            ext["r"] = max(ext["r"], (bb0[2] - px) * scale)
            ext["u"] = max(ext["u"], (py - bb0[1]) * scale)
            ext["d"] = max(ext["d"], (bb0[3] - py) * scale)

    half = int(math.ceil(max(ext["l"], ext["r"]))) + CELL_MARGIN
    frame_w = 2 * half
    below = int(math.ceil(ext["d"])) + CELL_MARGIN
    frame_h = int(math.ceil(ext["u"])) + CELL_MARGIN + below
    frame_w += frame_w % 2
    frame_h += (4 - frame_h % 4) % 4
    pivot = (frame_w // 2, frame_h - below)
    fsum["celula"] = [frame_w, frame_h]
    fsum["pivo"] = list(pivot)

    # 4) exportar
    pdir = os.path.join(prev_root, "chr", name)
    os.makedirs(pdir, exist_ok=True)
    board_rows = []
    for anim in sorted(data, key=lambda k: list(ANIM_TABLE).index(k) if k in ANIM_TABLE else 99):
        d = data[anim]
        a = d["asset"]
        n = len(d["frames"])
        strip = Image.new("RGBA", (frame_w * n, frame_h), (0, 0, 0, 0))
        out_frames = []
        for i, f in enumerate(d["frames"]):
            cell_img = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
            if f["m"] is not None:
                x0, y0, x1, y1 = f["bbox"]
                piece = to_image(f["cell"][y0:y1, x0:x1])
                sw, sh = (x1 - x0) * scale, (y1 - y0) * scale
                piece = resize_rgba(piece, sw, sh)
                px, py = f["pivot_src"]
                ox = int(round(pivot[0] - (px - x0) * scale))
                oy = int(round(pivot[1] - (py - y0) * scale))
                cell_img.alpha_composite(piece, (ox, oy)) if ox >= 0 and oy >= 0 else cell_img.paste(piece, (ox, oy), piece)
            strip.paste(cell_img, (i * frame_w, 0))
            out_frames.append(cell_img)
        png_out = os.path.join(fdir, f"{anim}.png")
        strip.save(png_out)
        fps = anim_fps(anim)
        mets = [f["met"] for f in d["frames"]]
        flagged = [m["frame"] for m in mets if m.get("flags")]
        meta = {
            "asset_id": a.asset_id, "fighter": name, "anim": anim, "status": "candidate",
            "frame_w": frame_w, "frame_h": frame_h, "frames": n,
            "pivot": list(pivot), "fps": fps, "loop": bool(d["loop"]),
            "px_per_world_px": PX_PER_WORLD,
            "altura_mundo_px": FIGHTER_HEIGHT_WORLD.get(name), "escala": round(scale, 4),
            "fonte": {"arquivo": rel(a.png), "revision": a.revision, "grade": list(d["grid"][:2]),
                      "celula_src": [d["cell_w"], d["cell_h"]], "fundo": d["rep"].get("fundo"),
                      "linha_base_src": round(d["baseline_used"], 1),
                      "referencia_escala": ref_note},
            "metricas": mets, "frames_marcados": flagged,
            "gerado_por": "tools/art/process_sheets.py",
            "gerado_em": _dt.datetime.now().isoformat(timespec="seconds"),
        }
        save_json(os.path.join(fdir, f"{anim}.json"), meta)
        fsum["anims"][anim] = {"frames": n, "fps": fps, "loop": bool(d["loop"]), "metricas": mets,
                               "fonte": rel(a.png), "fundo": d["rep"].get("fundo")}
        for m in mets:
            if m.get("flags"):
                fsum["flags"].append((anim, m["frame"], m["flags"]))
        # prévia GIF
        write_gif(out_frames, pivot, fps, os.path.join(pdir, f"{anim}.gif"))
        board_rows.append((anim, out_frames))
        log(f"  {anim}: {n} frames, {len(flagged)} marcados -> {rel(png_out)}")
    write_board(board_rows, pivot, frame_w, frame_h, os.path.join(pdir, f"prancha_{name}.png"),
                title=f"{name}  escala {scale:.3f}  celula {frame_w}x{frame_h}  pivo {pivot}")


def compose_preview(frame: Image.Image, pivot) -> Image.Image:
    bg = Image.new("RGBA", frame.size, PREVIEW_BG + (255,))
    bg.alpha_composite(frame)
    dr = ImageDraw.Draw(bg)
    dr.line([(0, pivot[1]), (frame.size[0], pivot[1])], fill=(255, 60, 60, 255), width=1)
    dr.line([(pivot[0], pivot[1] - 6), (pivot[0], pivot[1] + 6)], fill=(255, 60, 60, 255), width=1)
    return bg.convert("RGB")


def write_gif(frames, pivot, fps, path):
    imgs = [compose_preview(f, pivot).convert("P", palette=Image.ADAPTIVE, colors=255) for f in frames]
    if not imgs:
        return
    imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=int(round(1000 / fps)),
                 loop=0, disposal=2, optimize=False)


def get_font(size=14):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def write_board(rows, pivot, fw, fh, path, title="", scale=0.5):
    if not rows:
        return
    label_w = 120
    ncols = max(len(r[1]) for r in rows)
    sw, sh = int(fw * scale), int(fh * scale)
    W = label_w + ncols * sw
    H = 24 + len(rows) * sh
    board = Image.new("RGB", (W, H), (96, 96, 96))
    dr = ImageDraw.Draw(board)
    font = get_font(14)
    dr.text((6, 4), title, fill=(255, 255, 255), font=font)
    for r, (anim, frames) in enumerate(rows):
        y = 24 + r * sh
        dr.text((6, y + sh // 2 - 8), anim, fill=(255, 255, 255), font=font)
        for c, f in enumerate(frames):
            im = compose_preview(f, pivot).resize((sw, sh), Image.LANCZOS)
            board.paste(im, (label_w + c * sw, y))
            dr.rectangle([label_w + c * sw, y, label_w + (c + 1) * sw - 1, y + sh - 1], outline=(70, 70, 70))
    board.save(path)


# --------------------------------------------------------------------------------------------
# Props, texturas, fundos, FX, UI, kits
# --------------------------------------------------------------------------------------------
def export_strip(pieces, out_png, out_json, meta_extra, align="bottom"):
    """pieces: lista de Image RGBA recortadas e já escaladas. Célula única, alinhadas pela base
    (props) ou pelo centro (fx)."""
    fw = max(p.size[0] for p in pieces) + 2 * CELL_MARGIN
    fh = max(p.size[1] for p in pieces) + 2 * CELL_MARGIN
    fw += fw % 2
    fh += fh % 2
    strip = Image.new("RGBA", (fw * len(pieces), fh), (0, 0, 0, 0))
    for i, p in enumerate(pieces):
        ox = i * fw + (fw - p.size[0]) // 2
        oy = fh - CELL_MARGIN - p.size[1] if align == "bottom" else (fh - p.size[1]) // 2
        strip.alpha_composite(p, (ox, oy))
    strip.save(out_png)
    pivot = [fw // 2, fh - CELL_MARGIN] if align == "bottom" else [fw // 2, fh // 2]
    meta = {"frame_w": fw, "frame_h": fh, "frames": len(pieces), "pivot": pivot,
            "px_per_world_px": PX_PER_WORLD, "status": "candidate",
            "gerado_por": "tools/art/process_sheets.py"}
    meta.update(meta_extra)
    save_json(out_json, meta)
    return fw, fh


def process_prop(a: Asset, out_root, summary):
    rep = {}
    rgba = remove_background(Image.open(a.png), rep)
    cols, rows, n = grid_of(a, (4, 1, 4))
    cells = [c.rgba for c in extract_cells(rgba, cols, rows, n)]
    odir = os.path.join(out_root, "prop")
    os.makedirs(odir, exist_ok=True)
    crops = []
    for c in cells:
        c, _, _ = remove_islands(c, *ISLAND["prop"])
        cc, bb = crop_rgba(c)
        crops.append(cc if bb else None)
    if a.asset_id == "prop_extras":
        outs = []
        for i, cc in enumerate(crops):
            if cc is None:
                continue
            nm, th = PROP_EXTRAS[i] if i < len(PROP_EXTRAS) else (f"{i + 1:02d}", 64)
            im = to_image(cc)
            s = th / im.size[1]
            im = resize_rgba(im, im.size[0] * s, th)
            fn = f"prop_extras_{nm}.png"
            im.save(os.path.join(odir, fn))
            save_json(os.path.join(odir, f"prop_extras_{nm}.json"),
                      {"asset_id": a.asset_id, "item": nm, "size": list(im.size),
                       "pivot": [im.size[0] // 2, im.size[1]], "px_per_world_px": PX_PER_WORLD,
                       "altura_alvo_px": th, "escala": round(s, 4), "fonte": rel(a.png),
                       "status": "candidate"})
            outs.append(fn)
        summary.setdefault("outros", []).append((a.asset_id, f"{len(outs)} itens: {', '.join(outs)}; {rep.get('fundo')}"))
        return
    valid = [c for c in crops if c is not None]
    if not valid:
        summary.setdefault("outros", []).append((a.asset_id, "ALERTA: sem conteúdo"))
        return
    th = PROP_TARGET_H.get(a.asset_id, 64)
    s = th / valid[0].shape[0]  # estado intacto define a escala
    pieces = []
    for cc in crops:
        if cc is None:
            pieces.append(Image.new("RGBA", (1, 1), (0, 0, 0, 0)))
            continue
        im = to_image(cc)
        pieces.append(resize_rgba(im, im.size[0] * s, im.size[1] * s))
    fw, fh = export_strip(pieces, os.path.join(odir, f"{a.asset_id}.png"), os.path.join(odir, f"{a.asset_id}.json"),
                          {"asset_id": a.asset_id, "estados": ["intacto", "rachado", "muito_danificado", "quebrado"][:len(pieces)],
                           "loop": False, "fps": 0, "altura_alvo_px": th, "escala": round(s, 4),
                           "fonte": rel(a.png), "fundo": rep.get("fundo")})
    summary.setdefault("outros", []).append((a.asset_id, f"tira {len(pieces)}×{fw}x{fh}, escala {s:.3f}; {rep.get('fundo')}"))


def seam_ratio(arr: np.ndarray):
    """Diferença média entre colunas (linhas) opostas da borda, dividida pelo percentil 90 das
    diferenças entre colunas (linhas) vizinhas do interior. ~1 = a costura não se destaca."""
    a = arr[..., :3].astype(np.float32)
    cols = np.abs(a[:, 1:] - a[:, :-1]).mean(axis=(0, 2))
    rows = np.abs(a[1:] - a[:-1]).mean(axis=(1, 2))
    sx = np.abs(a[:, 0] - a[:, -1]).mean() / max(float(np.percentile(cols, 90)), 1e-3)
    sy = np.abs(a[0] - a[-1]).mean() / max(float(np.percentile(rows, 90)), 1e-3)
    return float(sx), float(sy)


def make_tileable(arr: np.ndarray, axes=(True, True), band: float = 0.25) -> np.ndarray:
    """Blend simples: mistura a imagem com ela mesma deslocada meia volta nos eixos com costura;
    nas bordas prevalece a versão deslocada (cujas bordas são o miolo original, contínuo), no
    centro a original. Pode deixar fantasma de padrões regulares: por isso é registrado."""
    H, W = arr.shape[:2]
    rolled = arr
    if axes[0]:
        rolled = np.roll(rolled, W // 2, axis=1)
    if axes[1]:
        rolled = np.roll(rolled, H // 2, axis=0)

    def ramp(n, on):
        if not on:
            return np.ones(n)
        t = np.minimum(np.arange(n), np.arange(n)[::-1]) / (band * n)
        t = np.clip(t, 0, 1)
        return t * t * (3 - 2 * t)
    w = np.minimum(ramp(H, axes[1])[:, None], ramp(W, axes[0])[None, :])[..., None]
    return arr * w + rolled * (1 - w)


def process_texture(a: Asset, out_root, summary):
    im = Image.open(a.png).convert("RGB")
    s = min(im.size)
    if im.size[0] != im.size[1]:
        l, t = (im.size[0] - s) // 2, (im.size[1] - s) // 2
        im = im.crop((l, t, l + s, t + s))
    im = im.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)
    arr = np.asarray(im).astype(np.float32)
    before = seam_ratio(arr)
    blended = False
    after = before
    if max(before) > SEAM_RATIO_MAX:
        cand = make_tileable(arr, (before[0] > SEAM_RATIO_MAX, before[1] > SEAM_RATIO_MAX))
        after = seam_ratio(cand)
        if max(after) < max(before):
            pdir = os.path.join(PREVIEW_ROOT, "mod")
            os.makedirs(pdir, exist_ok=True)
            Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), "RGB").save(
                os.path.join(pdir, f"{a.asset_id}_sem_blend.png"))
            arr, blended = cand, True
        else:
            after = before
    odir = os.path.join(out_root, "mod")
    os.makedirs(odir, exist_ok=True)
    Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), "RGB").save(os.path.join(odir, f"{a.asset_id}.png"))
    save_json(os.path.join(odir, f"{a.asset_id}.json"),
              {"asset_id": a.asset_id, "size": [TEXTURE_SIZE, TEXTURE_SIZE], "mundo_px": TEXTURE_SIZE // PX_PER_WORLD,
               "celulas": 8, "seam_antes": [round(x, 2) for x in before], "seam_depois": [round(x, 2) for x in after],
               "blend_borda": blended, "fonte": rel(a.png), "status": "candidate"})
    summary.setdefault("outros", []).append(
        (a.asset_id, f"256×256; costura x/y {before[0]:.2f}/{before[1]:.2f}"
                     + (f" -> blend de borda aplicado -> {after[0]:.2f}/{after[1]:.2f}" if blended
                     else (" (ok, sem blend)" if max(before) <= SEAM_RATIO_MAX else " ALERTA: blend não melhorou, original mantido"))))


def process_background(a: Asset, out_root, summary):
    im = Image.open(a.png)
    width = INTERIOR_WIDTH if a.asset_id.startswith("mod_interior") else BG_WIDTH
    opaque = a.asset_id == "bg_ceu" or a.asset_id.startswith("mod_interior") \
        or a.meta.get("requested_transparency") is False
    rep = {}
    if opaque:
        rgba = np.asarray(im.convert("RGBA")).astype(np.float32)
        rep["fundo"] = "opaco (mantido)"
        nrem = 0
    else:
        rgba = remove_background(im, rep)
        rgba, nrem, _ = remove_islands(rgba, *ISLAND["bg"])
    out = to_image(rgba)
    h = round(out.size[1] * width / out.size[0])
    out = resize_rgba(out, width, h) if not opaque else out.convert("RGB").resize((width, h), Image.LANCZOS).convert("RGBA")
    odir = os.path.join(out_root, "bg")
    os.makedirs(odir, exist_ok=True)
    out.save(os.path.join(odir, f"{a.asset_id}.png"))
    save_json(os.path.join(odir, f"{a.asset_id}.json"),
              {"asset_id": a.asset_id, "size": list(out.size), "opaco": opaque, "fundo": rep.get("fundo"),
               "ilhas_removidas": nrem, "fonte": rel(a.png), "status": "candidate"})
    summary.setdefault("outros", []).append((a.asset_id, f"{out.size[0]}×{out.size[1]}; {rep.get('fundo')}"))


def process_fx(a: Asset, out_root, summary):
    rep = {}
    rgba = remove_background(Image.open(a.png), rep)
    cols, rows, n = grid_of(a, (4, 2, 8))
    cells = [c.rgba for c in extract_cells(rgba, cols, rows, n)]
    cleaned = []
    for c in cells:
        c, _, _ = remove_islands(c, *ISLAND["fx"])
        cleaned.append(c)
    # recorte simétrico em torno do centro da célula, comum a todos os frames
    ch, cw = min(c.shape[0] for c in cleaned), min(c.shape[1] for c in cleaned)
    hx = hy = 1
    for c in cleaned:
        bb = bbox_alpha(c[..., 3])
        if bb:
            hx = max(hx, cw / 2 - bb[0], bb[2] - cw / 2)
            hy = max(hy, ch / 2 - bb[1], bb[3] - ch / 2)
    hx, hy = int(math.ceil(hx)) + 2, int(math.ceil(hy)) + 2
    fw, fh = 2 * hx, 2 * hy
    strip = Image.new("RGBA", (fw * len(cleaned), fh), (0, 0, 0, 0))
    for i, c in enumerate(cleaned):
        im = to_image(c[:ch, :cw])
        strip.paste(im, (i * fw + hx - cw // 2, hy - ch // 2), im)
    name = a.asset_id[3:] if a.asset_id.startswith("fx_") else a.asset_id
    odir = os.path.join(out_root, "fx")
    os.makedirs(odir, exist_ok=True)
    strip.save(os.path.join(odir, f"{name}.png"))
    loop = a.asset_id in FX_LOOP
    save_json(os.path.join(odir, f"{name}.json"),
              {"asset_id": a.asset_id, "frame_w": fw, "frame_h": fh, "frames": len(cleaned),
               "pivot": [hx, hy], "fps": FPS_FX, "loop": loop, "px_per_world_px": PX_PER_WORLD,
               "escala": 1.0, "fonte": rel(a.png), "fundo": rep.get("fundo"), "status": "candidate"})
    summary.setdefault("outros", []).append((a.asset_id, f"tira {len(cleaned)}×{fw}x{fh}, loop={loop}; {rep.get('fundo')}"))


def merge_line_groups(comp: Components, ids) -> list[list[int]]:
    """Une componentes na mesma linha (sobreposição vertical > 50% da menor altura) separados por
    um vão horizontal menor que UI_LINE_GAP × altura — ex.: letras e "!" de um banner."""
    groups = [[int(k)] for k in ids]

    def box(g):
        return (min(comp.x0[g]), min(comp.y0[g]), max(comp.x1[g]), max(comp.y1[g]))
    changed = True
    while changed:
        changed = False
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                a, b = box(groups[i]), box(groups[j])
                ov = min(a[3], b[3]) - max(a[1], b[1])
                hmin = min(a[3] - a[1], b[3] - b[1])
                gap = max(a[0], b[0]) - min(a[2], b[2])
                if ov > 0.5 * hmin and gap < UI_LINE_GAP * max(a[3] - a[1], b[3] - b[1]):
                    groups[i] += groups.pop(j)
                    changed = True
                    break
            if changed:
                break
    return groups


def process_ui(a: Asset, out_root, summary):
    rep = {}
    rgba = remove_background(Image.open(a.png), rep)
    rgba, _, _ = remove_islands(rgba, *ISLAND["ui"])
    odir = os.path.join(out_root, "ui")
    os.makedirs(odir, exist_ok=True)
    whole, _ = crop_rgba(rgba, 2)
    to_image(whole).save(os.path.join(odir, f"{a.asset_id}.png"))
    items = []
    if a.asset_id == "ui_retratos":
        cols, rows, n = grid_of(a, (3, 1, 3))
        for i, c in enumerate(split_grid(rgba, cols, rows, n)):
            cc, bb = crop_rgba(c, 2)
            if not bb:
                continue
            fn = f"{a.asset_id}_{i + 1:02d}.png"
            to_image(cc).save(os.path.join(odir, fn))
            items.append(fn)
            if i < len(PORTRAIT_ORDER):
                cdir = os.path.join(out_root, "chr", PORTRAIT_ORDER[i])
                os.makedirs(cdir, exist_ok=True)
                to_image(cc).save(os.path.join(cdir, "retrato.png"))
    else:
        mask = rgba[..., 3] >= 32
        comp = Components(dilate(mask, UI_GROUP_RADIUS))
        if comp.n:
            big = comp.area >= UI_MIN_FRAC * comp.area.max()
            ids = np.nonzero(big)[0]
            groups = merge_line_groups(comp, ids) if a.asset_id in UI_TEXT_ASSETS else [[int(k)] for k in ids]
            order = sorted(groups, key=lambda g: (int(min(comp.y0[g])) // 64, int(min(comp.x0[g]))))
            for idx, g in enumerate(order):
                keep = np.zeros(comp.n, bool); keep[g] = True
                gm = comp.mask_of(keep)
                sub = rgba.copy()
                sub[..., 3] = np.where(gm, sub[..., 3], 0)
                cc, bb = crop_rgba(sub, 2)
                if not bb:
                    continue
                fn = f"{a.asset_id}_{idx + 1:02d}.png"
                to_image(cc).save(os.path.join(odir, fn))
                items.append(fn)
    save_json(os.path.join(odir, f"{a.asset_id}.json"),
              {"asset_id": a.asset_id, "size": [int(whole.shape[1]), int(whole.shape[0])], "elementos": items,
               "fundo": rep.get("fundo"), "fonte": rel(a.png), "status": "candidate"})
    summary.setdefault("outros", []).append((a.asset_id, f"{len(items)} elementos; {rep.get('fundo')}"))


def process_kit(a: Asset, out_root, summary):
    rep = {}
    rgba = remove_background(Image.open(a.png), rep)
    cols, rows = KIT_GRID[a.asset_id]
    g = grid_of(a, (cols, rows, cols * rows))
    names = KIT_NAMES[a.asset_id]
    odir = os.path.join(out_root, "mod")
    os.makedirs(odir, exist_ok=True)
    whole, _ = crop_rgba(rgba, 2)
    to_image(whole).save(os.path.join(odir, f"{a.asset_id}.png"))
    items = []
    for i, c in enumerate(split_grid(rgba, g[0], g[1], g[2])):
        c, _, _ = remove_islands(c, *ISLAND["kit"])
        cc, bb = crop_rgba(c, 1)
        if not bb:
            continue
        nm = names[i] if i < len(names) else f"{i + 1:02d}"
        fn = f"{a.asset_id}_{nm}.png"
        to_image(cc).save(os.path.join(odir, fn))
        items.append(fn)
    save_json(os.path.join(odir, f"{a.asset_id}.json"),
              {"asset_id": a.asset_id, "elementos": items, "fundo": rep.get("fundo"), "fonte": rel(a.png),
               "escala": 1.0, "status": "candidate"})
    summary.setdefault("outros", []).append((a.asset_id, f"{len(items)} recortes em escala da fonte; {rep.get('fundo')}"))


# --------------------------------------------------------------------------------------------
# Relatório
# --------------------------------------------------------------------------------------------
def write_report(out_root, prev_root, summary):
    """Reconstrói o relatório a partir dos JSONs em disco (vale para execuções parciais)."""
    lines = ["# Relatório de consistência — lote 02", "",
             f"Gerado por `tools/art/process_sheets.py` em {_dt.datetime.now().isoformat(timespec='seconds')}.",
             "Status de todos os assets: **candidate**. Frames marcados continuam exportados; refazer ou aceitar é",
             "decisão humana.", "",
             "Limites: altura/idle ∈ [0.85, 1.15] (animações de pé, frames no chão); distância de cor",
             "(Hellinger hue×sat vs idle f1) ≤ 0.40 (≤ 0.55 em animações com efeito desenhado);",
             "|Δx do pivô| ≤ 0.20 da altura do idle; |Δy dos pés| ≤ 0.06 (frames no chão); área/idle ∈",
             "[0.55, 1.8] em pé, [0.30, 3.0] demais; CRUZA_CELULA = parte do frame atravessa a borda da grade",
             "(recuperada inteira); CORTADO = parte perdida; FUNDIDO_VIZINHO = frame encostado no vizinho.", "",
             "Colunas: h = altura/idle; cor = dist. idle f1; cor⚓ = dist. âncora (informativa); dx/dy =",
             "deslocamento do pivô na folha (fração da altura do idle); área = área/idle; ilhas = ilhas removidas.",
             ""]
    chr_dir = os.path.join(out_root, "chr")
    for name in sorted(os.listdir(chr_dir)) if os.path.isdir(chr_dir) else []:
        jsons = sorted(glob.glob(os.path.join(chr_dir, name, "*.json")))
        metas = []
        for j in jsons:
            try:
                m = read_json(j)
            except Exception:  # noqa: BLE001
                continue
            if "metricas" in m:
                metas.append(m)
        if not metas:
            continue
        metas.sort(key=lambda m: list(ANIM_TABLE).index(m["anim"]) if m["anim"] in ANIM_TABLE else 99)
        m0 = metas[0]
        lines += [f"## {name}", "",
                  f"Escala {m0['escala']} (referência: {m0['fonte'].get('referencia_escala')}), "
                  f"altura-alvo {(m0.get('altura_mundo_px') or 0) * PX_PER_WORLD} px, célula {m0['frame_w']}×{m0['frame_h']}, "
                  f"pivô {m0['pivot']}. Animações: {len(metas)}.", ""]
        flagged = [(m["anim"], x["frame"], x["flags"]) for m in metas for x in m["metricas"] if x.get("flags")]
        total = sum(m["frames"] for m in metas)
        lines.append(f"**Frames marcados: {len(flagged)} de {total}.**")
        lines.append("")
        for anim, fr, fl in flagged:
            lines.append(f"- `{anim}` f{fr}: {', '.join(fl)}")
        if flagged:
            lines.append("")
        lines += ["| anim | f | aéreo | h | cor | cor⚓ | dx | dy | área | ilhas | flags |",
                  "|---|---|---|---|---|---|---|---|---|---|---|"]
        for m in metas:
            for x in m["metricas"]:
                def g(k):
                    v = x.get(k)
                    return "–" if v is None else (f"{v:.2f}" if isinstance(v, float) else str(v))
                lines.append(f"| {m['anim']} | {x['frame']} | {'s' if x.get('aereo') else ''} | {g('altura_ratio')} | "
                             f"{g('hist_dist_idle1')} | {g('hist_dist_anchor')} | {g('pivot_dx_rel')} | {g('pe_dy_rel')} | "
                             f"{g('area_ratio')} | {g('ilhas_removidas')} | {' '.join(x.get('flags', []))} |")
        lines.append("")
    # outros: manifesto acumulado
    man_path = os.path.join(prev_root, "manifesto_processamento.json")
    man = {}
    if os.path.exists(man_path):
        try:
            man = read_json(man_path)
        except Exception:  # noqa: BLE001
            man = {}
    for aid, note in summary.get("outros", []):
        man[aid] = note
    for name, fs in summary.get("chr", {}).items():
        for e in fs.get("extras", []):
            man[f"chr_{name}_{e.split('.')[0]}"] = e
    save_json(man_path, man)
    if man:
        lines += ["## Outros assets", "", "| asset | resultado |", "|---|---|"]
        for k in sorted(man):
            lines.append(f"| `{k}` | {man[k]} |")
        lines.append("")
    os.makedirs(prev_root, exist_ok=True)
    with open(os.path.join(prev_root, "relatorio_consistencia.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


# --------------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------------
# Figurantes (§8.4): altura-alvo do corpo em px (= altura em jogo × 4). Rotina define a escala;
# reações (_medo, _uau) usam a MESMA escala para a pessoa não mudar de tamanho ao reagir.
NPC_TARGET_H = {"criancas": 120, "sofa_tv": 150}
NPC_DEFAULT_H = 160
_npc_scale: dict = {}


def npc_base(asset_id: str) -> str:
    base = asset_id[len("npc_"):]
    for suf in ("_medo", "_uau"):
        if base.endswith(suf):
            return base[: -len(suf)]
    return base


def process_npc(a: Asset, out_root, summary):
    rep = {}
    rgba = remove_background(Image.open(a.png), rep)
    cols, rows, n = grid_of(a, (4, 2, 8))
    cells = [c.rgba for c in extract_cells(rgba, cols, rows, n)]
    crops = []
    for c in cells:
        c, _, _ = remove_islands(c, *ISLAND["chr"])
        cc, bb = crop_rgba(c)
        crops.append(cc if bb else None)
    valid = [c for c in crops if c is not None]
    if not valid:
        summary.setdefault("outros", []).append((a.asset_id, "ALERTA: sem conteúdo"))
        return
    base = npc_base(a.asset_id)
    if base not in _npc_scale or a.asset_id == "npc_" + base:
        med = sorted(c.shape[0] for c in valid)[len(valid) // 2]
        _npc_scale[base] = NPC_TARGET_H.get(base, NPC_DEFAULT_H) / med
    sc = _npc_scale[base]
    pieces = []
    for cc in crops:
        if cc is None:
            pieces.append(Image.new("RGBA", (1, 1), (0, 0, 0, 0)))
            continue
        im = to_image(cc)
        pieces.append(resize_rgba(im, im.size[0] * sc, im.size[1] * sc))
    odir = os.path.join(out_root, "npc")
    os.makedirs(odir, exist_ok=True)
    loop = a.asset_id == "npc_" + base
    fw, fh = export_strip(pieces, os.path.join(odir, f"{a.asset_id}.png"), os.path.join(odir, f"{a.asset_id}.json"),
                          {"asset_id": a.asset_id, "loop": loop, "fps": 10 if loop else 12,
                           "escala": round(sc, 4), "fonte": rel(a.png), "fundo": rep.get("fundo")})
    summary.setdefault("outros", []).append((a.asset_id, f"npc tira {len(pieces)}×{fw}x{fh}, escala {sc:.3f}"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--only", choices=["chr", "bg", "mod", "prop", "fx", "ui", "npc"])
    ap.add_argument("--asset", help="asset_id (animação de lutador reprocessa o lutador inteiro)")
    ap.add_argument("--input", nargs="+", help="PNG(s) avulsos em vez de art/lote02")
    ap.add_argument("--grid", help="grade de fallback, ex. 3x1 (usada quando o JSON não traz grade)")
    ap.add_argument("--src", default=SRC_DIR)
    ap.add_argument("--out-root", default=OUT_ROOT)
    ap.add_argument("--preview-root", default=PREVIEW_ROOT)
    args = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:  # noqa: BLE001
        pass

    grid_cli = None
    if args.grid:
        m = re.match(r"(\d+)\s*[x×X]\s*(\d+)", args.grid)
        if not m:
            ap.error("--grid no formato CxL, ex. 3x1")
        grid_cli = (int(m.group(1)), int(m.group(2)), int(m.group(1)) * int(m.group(2)))

    if args.input:
        assets = []
        for p in args.input:
            a = load_asset(os.path.abspath(p))
            if (a.grid is None or not a.grid[0]) and grid_cli:
                a.grid = grid_cli
            assets.append(a)
    else:
        assets = discover(args.src)
        if grid_cli:
            for a in assets:
                if a.grid is None or not a.grid[0]:
                    a.grid = grid_cli

    if args.only:
        assets = [a for a in assets if category(a.asset_id) == args.only]
    if args.asset:
        f, _ = fighter_of(args.asset)
        if f:
            assets = [a for a in assets if a.asset_id.startswith(f"chr_{f}_") or a.asset_id == args.asset]
        else:
            assets = [a for a in assets if a.asset_id == args.asset]
    if not assets:
        log("Nenhum asset encontrado.")
        return 0

    summary: dict = {}
    fighters: dict[str, list[Asset]] = {}
    errors = []
    for a in sorted(assets, key=lambda x: x.asset_id):
        cat = category(a.asset_id)
        try:
            if cat == "chr":
                f, _ = fighter_of(a.asset_id)
                if f:
                    fighters.setdefault(f, []).append(a)
                continue
            log(f"[{cat}] {a.asset_id}")
            if a.asset_id in KIT_GRID:
                process_kit(a, args.out_root, summary)
            elif a.asset_id.startswith("mod_textura_"):
                process_texture(a, args.out_root, summary)
            elif a.asset_id.startswith(("bg_", "mod_interior_")):
                process_background(a, args.out_root, summary)
            elif cat == "prop":
                process_prop(a, args.out_root, summary)
            elif cat == "fx":
                process_fx(a, args.out_root, summary)
            elif cat == "ui":
                process_ui(a, args.out_root, summary)
            elif cat == "npc":
                process_npc(a, args.out_root, summary)
            else:
                log(f"  (sem regra para {a.asset_id}; ignorado)")
        except Exception as e:  # noqa: BLE001
            errors.append((a.asset_id, repr(e)))
            log(f"  ! ERRO {a.asset_id}: {e!r}")
    for name, lst in sorted(fighters.items()):
        try:
            process_fighter(name, lst, args.out_root, args.preview_root, summary)
        except Exception as e:  # noqa: BLE001
            errors.append((f"chr_{name}", repr(e)))
            log(f"  ! ERRO chr_{name}: {e!r}")
            import traceback; traceback.print_exc()
    write_report(args.out_root, args.preview_root, summary)
    log(f"Relatório: {rel(os.path.join(args.preview_root, 'relatorio_consistencia.md'))}")
    for name, fs in summary.get("chr", {}).items():
        log(f"  {name}: {len(fs['flags'])} frames marcados em {len(fs['anims'])} animações")
    if errors:
        log(f"{len(errors)} erro(s): {errors}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
