"""Tata letak tile (SPEC §4) + pemotongan dengan overlap (SPEC §5).

Aturan emas terkait:
- #3 Tile bersebelahan WAJIB overlap >=1 piksel (berbagi baris/kolom tepi).
- #4 Tiap tile <= max_tile_px di kedua sisi.
- #6 Origin di tengah; tile simetris terhadap (0,0,0).
- #7 Position Y = -(size_y/2) untuk SEMUA tile.

Batas jumlah tile berasal dari TIGA sumber, diambil yang paling mengikat:
  (a) batas studs per-sumbu  : size_axis / max_tile_studs
  (b) batas piksel per-sumbu : dem_axis_px / max_tile_px  (PNG <= 4096)
  (c) batas VOLUME per impor : jumlah voxel per tile <= max_tile_voxels  <-- penentu

(c) adalah temuan uji lapangan: Roblox Terrain Importer menolak satu impor bila
volume region terlalu besar ("region volume is too large"). Region dipetakan ke
voxel 4x4x4 studs; total voxel per impor dibatasi (~2^32). Kunci: voxel/tile =
world_voxels / (tiles_x * tiles_z) — HANYA tergantung HASIL-KALI jumlah tile, jadi
kita cari grid dengan tile paling sedikit yang masih di bawah budget.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from math import ceil
from typing import List
import numpy as np

# Ukuran satu voxel terrain Roblox (studs per sisi). Region impor dipetakan ke
# grid voxel ini; jumlah voxel = (size_x/VOXEL)*(size_y/VOXEL)*(size_z/VOXEL).
VOXEL_STUDS = 4.0

# Kelipatan untuk voxel-align Size tile. Pakai 2*VOXEL (=8) supaya Size habis
# dibagi 4 DAN Position = (ix-(n-1)/2)*Size juga habis dibagi 4 untuk paritas n
# apa pun (n genap -> faktor 1/2 terserap). Hasil: tile menempel pas di grid voxel.
ALIGN_STUDS = 2.0 * VOXEL_STUDS


class TilingError(ValueError):
    pass


def tile_voxels(size_x: float, size_y: float, size_z: float) -> float:
    """Jumlah voxel 4x4x4 yang ditempati satu region impor (untuk cek budget)."""
    return (size_x / VOXEL_STUDS) * (size_y / VOXEL_STUDS) * (size_z / VOXEL_STUDS)


@dataclass
class TilePlan:
    ix: int
    iz: int
    file: str
    # batas piksel pada img16 global: baris [z0:z1), kolom [x0:x1)
    x0: int
    x1: int
    z0: int
    z1: int
    px_w: int
    px_h: int
    # parameter Roblox (studs)
    size_x: float
    size_y: float
    size_z: float
    position_x: float
    position_y: float
    position_z: float
    voxels: float = 0.0          # jumlah voxel region impor tile ini


@dataclass
class Layout:
    tiles_x: int
    tiles_z: int
    size_x_total: float
    size_z_total: float
    size_x_tile: float
    size_z_tile: float
    size_y: float
    position_y: float
    dem_w: int
    dem_h: int
    overlap_px: int
    voxels_per_tile: float = 0.0   # voxel/tile (seragam) — harus <= max_tile_voxels
    max_tile_voxels: float = 0.0   # budget yang dipakai
    warnings: List[str] = field(default_factory=list)
    tiles: List[TilePlan] = field(default_factory=list)


def _split_axis(total_px: int, n_tiles: int, overlap: int) -> List[tuple[int, int]]:
    """Bagi `total_px` kolom/baris menjadi `n_tiles` segmen dengan overlap.

    Segmen non-terakhir: [i*base, (i+1)*base + overlap)
    Segmen terakhir    : [(n-1)*base, total_px)   <- serap sisa pembagian di sini.

    Dua segmen bersebelahan berbagi tepat `overlap` indeks (untuk overlap=1:
    kolom (i+1)*base identik di kedua tile). Inilah jaminan tanpa-jahitan.
    """
    base = total_px // n_tiles
    if base < 1:
        raise TilingError(
            f"DEM terlalu kecil ({total_px} px) untuk {n_tiles} tile pada sumbu ini. "
            f"Kurangi jumlah tile atau pakai DEM beresolusi lebih tinggi."
        )
    bounds: List[tuple[int, int]] = []
    for i in range(n_tiles):
        a = i * base
        b = total_px if i == n_tiles - 1 else (i + 1) * base + overlap
        bounds.append((a, b))
    return bounds


def _choose_grid(size_x_total, size_z_total, tx_min, tz_min, prod_min):
    """Pilih (tiles_x, tiles_z) DETERMINISTIK: tile sesedikit mungkin.

    Syarat: tx >= tx_min, tz >= tz_min, tx*tz >= prod_min. Karena voxel/tile hanya
    bergantung pada hasil-kali tx*tz, semua grid dengan tx*tz >= prod_min memenuhi
    budget; kita pilih yang JUMLAH tile-nya minimum, lalu yang tile-nya paling
    mendekati persegi (rasio sisi terkecil) untuk kualitas terrain & simetri.
    """
    best = None
    best_key = None
    # tz cukup ditelusuri sampai prod_min (di atas itu hasil-kali hanya membesar).
    tz_hi = max(tz_min, prod_min)
    for tz in range(tz_min, tz_hi + 1):
        tx = max(tx_min, ceil(prod_min / tz))
        prod = tx * tz
        sx = size_x_total / tx
        sz = size_z_total / tz
        aspect = max(sx / sz, sz / sx) if sx > 0 and sz > 0 else 1.0
        # Kunci urut: jumlah tile dulu (minimum), lalu paling persegi, lalu tx kecil.
        key = (prod, round(aspect, 6), tx)
        if best is None or key < best_key:
            best, best_key = (tx, tz), key
    return best


def compute_layout(cfg, gmin: float, gmax: float, dem_h: int, dem_w: int) -> Layout:
    """Hitung jumlah tile, Size & Position tiap tile (SPEC §4) + batas piksel.

    Tidak menyentuh data piksel — murni perhitungan rencana. Aman untuk --dry-run.
    """
    scale = cfg.scale_studs_per_m

    # Ukuran dunia total (studs).
    size_x_total = cfg.box_width_km * 1000.0 * scale
    size_z_total = cfg.box_height_km * 1000.0 * scale

    warnings: List[str] = []

    # Tinggi relief (studs) & Position Y (aturan emas #7). Dihitung lebih dulu
    # karena ikut menentukan volume voxel per tile.
    size_y = (gmax - gmin) * scale
    position_y = -(size_y / 2.0)

    # Batas minimum per-sumbu (sekunder): studs & piksel.
    tx_min = max(ceil(size_x_total / cfg.max_tile_studs), ceil(dem_w / cfg.max_tile_px), 1)
    tz_min = max(ceil(size_z_total / cfg.max_tile_studs), ceil(dem_h / cfg.max_tile_px), 1)

    # Batas UTAMA: volume/voxel per impor. voxel/tile hanya tergantung HASIL-KALI
    # tiles_x*tiles_z, jadi tetapkan minimum hasil-kali lalu cari grid terkecil.
    # Align size_y dulu (tak tergantung jumlah tile). Position Y = -(Size_Y/2).
    orig_size_y = size_y
    if cfg.voxel_align and size_y > 0:
        size_y = max(ALIGN_STUDS, round(size_y / ALIGN_STUDS) * ALIGN_STUDS)
    position_y = -(size_y / 2.0)

    orig_x_total, orig_z_total = size_x_total, size_z_total
    world_voxels = tile_voxels(orig_x_total, size_y, orig_z_total)
    if size_y > 0 and cfg.max_tile_voxels > 0:
        prod_min = ceil(world_voxels / cfg.max_tile_voxels)
    else:
        prod_min = 1  # relief nol -> volume nol -> tak dibatasi voxel
    prod_min = max(prod_min, tx_min * tz_min, 1)

    # Loop: pilih grid, hitung & align Size X/Z, cek budget. Bila voxel-align
    # membulatkan KE ATAS hingga melebihi budget (edge case tile mepet), naikkan
    # jumlah tile lalu ulang. Dijamin berhenti (lebih banyak tile -> voxel turun).
    tiles_x = tiles_z = 0
    size_x_tile = size_z_tile = 0.0
    voxels_per_tile = 0.0
    for _ in range(256):
        tiles_x, tiles_z = _choose_grid(orig_x_total, orig_z_total, tx_min, tz_min, prod_min)
        size_x_tile = orig_x_total / tiles_x
        size_z_tile = orig_z_total / tiles_z
        if cfg.voxel_align:
            a = ALIGN_STUDS
            size_x_tile = max(a, round(size_x_tile / a) * a)
            size_z_tile = max(a, round(size_z_tile / a) * a)
        voxels_per_tile = tile_voxels(size_x_tile, size_y, size_z_tile)
        if cfg.max_tile_voxels <= 0 or voxels_per_tile <= cfg.max_tile_voxels:
            break
        prod_min += 1  # align mendorong over-budget -> butuh lebih banyak tile
    else:  # pragma: no cover - defensif
        raise TilingError(
            f"Tak bisa memenuhi budget voxel {cfg.max_tile_voxels:.4g} "
            f"(voxel/tile terkecil {voxels_per_tile:.4g})."
        )

    # Dunia efektif = tile (mungkin ter-align) * jumlah tile.
    size_x_total = size_x_tile * tiles_x
    size_z_total = size_z_tile * tiles_z

    if cfg.voxel_align and (
        abs(size_x_total - orig_x_total) > 1e-6
        or abs(size_z_total - orig_z_total) > 1e-6
        or abs(size_y - orig_size_y) > 1e-6
    ):
        warnings.append(
            f"voxel_align: Size disnap ke kelipatan {ALIGN_STUDS:g} studs; dunia "
            f"{orig_x_total:g}x{orig_z_total:g} -> {size_x_total:g}x{size_z_total:g}, "
            f"Size_Y {orig_size_y:g} -> {size_y:g} (geser <"
            f"{100 * abs(size_x_total - orig_x_total) / orig_x_total:.2f}%)."
        )

    # Catat alasan jumlah tile (transparansi).
    base_studs = ceil(orig_x_total / cfg.max_tile_studs) * ceil(orig_z_total / cfg.max_tile_studs)
    if tiles_x * tiles_z > base_studs:
        warnings.append(
            f"Grid dinaikkan ke {tiles_x}x{tiles_z}={tiles_x * tiles_z} tile agar "
            f"voxel/tile ({voxels_per_tile:.3g}) <= max_tile_voxels "
            f"({cfg.max_tile_voxels:.3g}). Batas studs saja hanya butuh {base_studs} tile."
        )

    layout = Layout(
        tiles_x=tiles_x,
        tiles_z=tiles_z,
        size_x_total=size_x_total,
        size_z_total=size_z_total,
        size_x_tile=size_x_tile,
        size_z_tile=size_z_tile,
        size_y=size_y,
        position_y=position_y,
        dem_w=dem_w,
        dem_h=dem_h,
        overlap_px=cfg.overlap_px,
        voxels_per_tile=voxels_per_tile,
        max_tile_voxels=cfg.max_tile_voxels,
        warnings=warnings,
    )

    # Batas piksel per sumbu dengan overlap.
    col_bounds = _split_axis(dem_w, tiles_x, cfg.overlap_px)  # sumbu X
    row_bounds = _split_axis(dem_h, tiles_z, cfg.overlap_px)  # sumbu Z

    # Laporkan sisa pembagian (jangan dibuang diam-diam — SPEC §5).
    if dem_w % tiles_x:
        warnings.append(
            f"Lebar DEM {dem_w}px tidak habis dibagi {tiles_x} tile; "
            f"sisa {dem_w % tiles_x}px diserap ke tile X terakhir."
        )
    if dem_h % tiles_z:
        warnings.append(
            f"Tinggi DEM {dem_h}px tidak habis dibagi {tiles_z} tile; "
            f"sisa {dem_h % tiles_z}px diserap ke tile Z terakhir."
        )

    for iz in range(tiles_z):
        z0, z1 = row_bounds[iz]
        # Position Z simetris terhadap origin (SPEC §4).
        position_z = (iz - (tiles_z - 1) / 2.0) * size_z_tile
        for ix in range(tiles_x):
            x0, x1 = col_bounds[ix]
            position_x = (ix - (tiles_x - 1) / 2.0) * size_x_tile

            px_w = x1 - x0
            px_h = z1 - z0

            # Validasi aturan emas #4 (defensif; mestinya sudah aman).
            if px_w > cfg.max_tile_px or px_h > cfg.max_tile_px:
                raise TilingError(
                    f"Tile (x{ix},z{iz}) berukuran {px_w}x{px_h}px melebihi "
                    f"max_tile_px={cfg.max_tile_px}. Naikkan jumlah tile atau "
                    f"turunkan resolusi/skala."
                )

            file_name = f"{cfg.output_prefix}_x{ix}_z{iz}.png"
            layout.tiles.append(
                TilePlan(
                    ix=ix, iz=iz, file=file_name,
                    x0=x0, x1=x1, z0=z0, z1=z1, px_w=px_w, px_h=px_h,
                    size_x=size_x_tile, size_y=size_y, size_z=size_z_tile,
                    position_x=position_x, position_y=position_y, position_z=position_z,
                    voxels=voxels_per_tile,
                )
            )

    return layout


def slice_tile(img16: np.ndarray, plan: TilePlan) -> np.ndarray:
    """Potong satu tile dari heightmap global ternormalisasi.

    PENTING: img16 sudah dinormalisasi GLOBAL sebelum dipotong (aturan emas #2).
    Tile = view/copy dari array global, BUKAN dinormalisasi ulang.
    """
    tile = img16[plan.z0:plan.z1, plan.x0:plan.x1]
    # Kembalikan copy uint16 agar tiap PNG independen & dtype terjamin.
    return np.ascontiguousarray(tile, dtype=np.uint16)
