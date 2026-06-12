#!/usr/bin/env python3
"""test_pipeline.py — smoke test TANPA file SRTM asli (PIPELINE §6).

Membuktikan dua invarian paling kritis:
  - Normalisasi GLOBAL (bukan per-tile)  -> kolom/baris overlap antar tile IDENTIK.
  - Overlap 1 px antar tile bersebelahan.

Plus: jumlah tile benar, tiap PNG uint16 & <= max_px, manifest valid,
Position simetris (sum ~ 0), Position Y = -Size_Y/2.

Jalankan:  python test_pipeline.py
"""

from __future__ import annotations

import json
import os
import tempfile

import numpy as np

from terrain.config import Config
from terrain.normalize import clean_and_normalize
from terrain.tiling import compute_layout, slice_tile
from terrain import io as tio
from terrain import manifest as tmanifest


# --- DEM sintetis: gradient Barat-Timur + bukit sin + patch NoData ---
def make_synthetic_dem(h: int = 260, w: int = 400) -> np.ndarray:
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grad = xx / (w - 1) * 500.0                          # 0..500 m, naik ke timur
    hill = 300.0 * np.sin(xx / w * np.pi) * np.sin(yy / h * np.pi)
    dem = (200.0 + grad + hill).astype(np.float32)
    dem[5:15, 5:15] = -9999.0                            # patch NoData (SRTM-style)
    return dem


def make_cfg(out_dir: str) -> Config:
    # box dipilih agar grid = 4 x 2 (mirip contoh kerja default).
    return Config(
        input_tif="<synthetic>",
        box_width_km=26.0,
        box_height_km=16.0,
        output_dir=out_dir,
        scale_studs_per_m=2.0,
        nodata_threshold=-500.0,
        overlap_px=1,
        max_tile_studs=16384,
        max_tile_px=4096,
        output_prefix="RUH_tile",
        flip_z=False,
    )


class Checker:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, label: str, cond: bool):
        mark = "PASS" if cond else "FAIL"
        print(f"  [{mark}] {label}")
        if cond:
            self.passed += 1
        else:
            self.failed += 1

    def summary(self) -> bool:
        print(f"\n  Total: {self.passed} PASS, {self.failed} FAIL")
        return self.failed == 0


def run_tests() -> bool:
    c = Checker()
    dem = make_synthetic_dem()
    h, w = dem.shape
    print(f"DEM sintetis: {w} x {h} px (termasuk patch NoData)\n")

    # --- Normalisasi global ---
    print("[A] Normalisasi GLOBAL -> uint16")
    norm = clean_and_normalize(dem, nodata_threshold=-500.0)
    img16 = norm.img16
    c.check("dtype output uint16", img16.dtype == np.uint16)
    c.check("min global == 0", int(img16.min()) == 0)
    c.check("max global == 65535", int(img16.max()) == 65535)
    c.check("tidak ada NaN/inf (uint16)", np.isfinite(img16.astype(np.float64)).all())
    c.check("NoData ter-clamp (count > 0)", norm.nodata_count > 0)
    c.check("0 <= img16 <= 65535", img16.min() >= 0 and img16.max() <= 65535)

    # --- Layout ---
    print("\n[B] Layout tile (SPEC §4)")
    with tempfile.TemporaryDirectory() as tmp:
        cfg = make_cfg(tmp)
        layout = compute_layout(cfg, norm.elev_min_m, norm.elev_max_m, h, w)
        n_expected = layout.tiles_x * layout.tiles_z
        c.check(f"grid {layout.tiles_x}x{layout.tiles_z} valid (tx,tz >= 1)",
                layout.tiles_x >= 1 and layout.tiles_z >= 1)
        c.check("jumlah TilePlan == tiles_x*tiles_z", len(layout.tiles) == n_expected)

        # Invarian volume impor: tiap tile <= max_tile_voxels (temuan uji Studio).
        from terrain.tiling import tile_voxels
        vox_ok = all(
            tile_voxels(t.size_x, t.size_y, t.size_z) <= cfg.max_tile_voxels + 1
            for t in layout.tiles
        )
        c.check(f"voxel/tile <= max_tile_voxels ({layout.voxels_per_tile:.3g} <= "
                f"{cfg.max_tile_voxels:.3g})", vox_ok)

        # Budget lebih ketat -> grid HARUS bertambah & tetap di bawah budget.
        cfg_tight = make_cfg(tmp)
        cfg_tight.max_tile_voxels = layout.voxels_per_tile / 3.0  # paksa ~3x lebih banyak
        lay2 = compute_layout(cfg_tight, norm.elev_min_m, norm.elev_max_m, h, w)
        c.check(f"budget 1/3 -> grid naik ({layout.tiles_x*layout.tiles_z} -> "
                f"{lay2.tiles_x*lay2.tiles_z} tile)",
                lay2.tiles_x * lay2.tiles_z > n_expected)
        c.check("grid ketat tetap <= budget ketat",
                all(tile_voxels(t.size_x, t.size_y, t.size_z) <= cfg_tight.max_tile_voxels + 1
                    for t in lay2.tiles))

        # Position Y = -Size_Y/2 untuk semua tile (aturan emas #7).
        py_ok = all(abs(t.position_y - (-(t.size_y / 2.0))) < 1e-9 for t in layout.tiles)
        c.check("Position Y == -(Size_Y/2) semua tile", py_ok)

        # Simetri Position X & Z (SPEC §7): sum ~ 0.
        sum_x = sum(t.position_x for t in layout.tiles)
        sum_z = sum(t.position_z for t in layout.tiles)
        c.check(f"sum(position_x) ~ 0 (={sum_x:.3g})", abs(sum_x) < 1e-6)
        c.check(f"sum(position_z) ~ 0 (={sum_z:.3g})", abs(sum_z) < 1e-6)

        # Size seragam antar tile (aturan emas #5).
        sx = {round(t.size_x, 6) for t in layout.tiles}
        sz = {round(t.size_z, 6) for t in layout.tiles}
        c.check("Size X seragam semua tile", len(sx) == 1)
        c.check("Size Z seragam semua tile", len(sz) == 1)

        # voxel_align: semua Size & Position kelipatan VOXEL_STUDS (4) -> tile
        # menempel pas di grid voxel (Snap to Voxels tak menggeser sambungan).
        from terrain.tiling import VOXEL_STUDS
        def aligned(v):
            return abs(v / VOXEL_STUDS - round(v / VOXEL_STUDS)) < 1e-6
        align_ok = all(
            aligned(t.size_x) and aligned(t.size_y) and aligned(t.size_z)
            and aligned(t.position_x) and aligned(t.position_y) and aligned(t.position_z)
            for t in layout.tiles
        )
        c.check("voxel_align: semua Size & Position kelipatan 4", align_ok)

        # --- Slice + cek invarian overlap (INTI) ---
        print("\n[C] Overlap 1 px antar-tile bersebelahan (bukti normalisasi global)")
        tiles = {(t.ix, t.iz): slice_tile(img16, t) for t in layout.tiles}

        # Tiap tile <= max_px.
        ok_px = all(
            tl.shape[0] <= cfg.max_tile_px and tl.shape[1] <= cfg.max_tile_px
            for tl in tiles.values()
        )
        c.check("tiap tile <= max_tile_px", ok_px)
        c.check("tiap tile dtype uint16", all(tl.dtype == np.uint16 for tl in tiles.values()))

        # Overlap X: kolom terakhir tile (ix) == kolom pertama tile (ix+1).
        x_ok = True
        for iz in range(layout.tiles_z):
            for ix in range(layout.tiles_x - 1):
                a = tiles[(ix, iz)]
                b = tiles[(ix + 1, iz)]
                if not np.array_equal(a[:, -1], b[:, 0]):
                    x_ok = False
        c.check("kolom overlap X identik (tile ix vs ix+1)", x_ok)

        # Overlap Z: baris terakhir tile (iz) == baris pertama tile (iz+1).
        z_ok = True
        for ix in range(layout.tiles_x):
            for iz in range(layout.tiles_z - 1):
                a = tiles[(ix, iz)]
                b = tiles[(ix, iz + 1)]
                if not np.array_equal(a[-1, :], b[0, :]):
                    z_ok = False
        c.check("baris overlap Z identik (tile iz vs iz+1)", z_ok)

        # Kontra-bukti: kalau normalisasi per-tile, kolom overlap TIDAK akan identik
        # karena tiap tile punya min/max sendiri. Identik => global terbukti.
        # Tambahan: nilai kolom sambung harus dari SUMBER yang sama (uji eksplisit).
        mid_ix = layout.tiles_x // 2
        a = tiles[(mid_ix - 1, 0)]
        b = tiles[(mid_ix, 0)]
        c.check("nilai sambung tidak konstan (relief nyata)", np.ptp(a[:, -1]) > 0)

        # --- Tulis PNG & baca balik untuk verifikasi 16-bit on-disk ---
        print("\n[D] PNG 16-bit on-disk")
        wrote = 0
        for t in layout.tiles:
            tio.write_png16(os.path.join(tmp, t.file), tiles[(t.ix, t.iz)])
            wrote += 1
        c.check(f"PNG ditulis == jumlah tile ({wrote})", wrote == n_expected)

        # Baca balik 1 PNG, pastikan uint16 & dimensi cocok.
        import imageio.v3 as iio
        sample = layout.tiles[0]
        back = iio.imread(os.path.join(tmp, sample.file))
        c.check("PNG terbaca uint16", back.dtype == np.uint16)
        c.check("PNG dimensi cocok dengan rencana",
                back.shape == (sample.px_h, sample.px_w))
        # Nilai on-disk identik dengan tile in-memory (tanpa loss).
        c.check("PNG round-trip identik (16-bit utuh)",
                np.array_equal(back, tiles[(sample.ix, sample.iz)]))

        # --- Manifest ---
        print("\n[E] Manifest")
        manifest = tmanifest.build_manifest_dict(cfg, layout, norm.elev_min_m, norm.elev_max_m)
        mpath = os.path.join(tmp, "import_manifest.json")
        tmanifest.write_manifest_json(mpath, manifest)
        tmanifest.write_import_guide(os.path.join(tmp, "IMPORT_GUIDE.md"), cfg, layout, manifest)
        with open(mpath, encoding="utf-8") as f:
            reloaded = json.load(f)
        c.check("manifest entri == jumlah tile", len(reloaded["tiles"]) == n_expected)
        c.check("manifest tiles_x/z cocok",
                reloaded["tiles_x"] == layout.tiles_x and reloaded["tiles_z"] == layout.tiles_z)
        c.check("manifest material non-Water",
                all(t["material"] != "Water" for t in reloaded["tiles"]))

    # --- Geo crop (multi-place) ---
    print("\n[F] Geo crop (konversi lon/lat <-> piksel <-> km)")
    from terrain.geo import GeoRef, geo_box_to_pixels, pixels_to_km, GeoError
    g = GeoRef(lon0=39.0, lat0=21.5, sx=0.001, sy=0.001, width=1000, height=500)
    x0, x1, y0, y1 = geo_box_to_pixels(g, 39.1, 21.2, 39.3, 21.4)
    c.check("lon->kolom benar (X)", x0 == 100 and x1 == 300)
    c.check("lat->baris benar (Y terbalik: utara=atas)", y0 == 100 and y1 == 300)
    cx0, cx1, cy0, cy1 = geo_box_to_pixels(g, 38.0, 20.0, 39.3, 21.4)
    c.check("kotak keluar batas -> ter-clamp", cx0 == 0 and cy1 == 500)
    wkm, hkm = pixels_to_km(g, 0, g.width, 0, g.height)
    c.check(f"pixels_to_km masuk akal (~{wkm:.1f}x{hkm:.1f} km)", wkm > 0 and hkm > 0)
    try:
        geo_box_to_pixels(g, 39.3, 21.2, 39.1, 21.4)  # lon_min>lon_max
        bad = False
    except GeoError:
        bad = True
    c.check("kotak terbalik -> GeoError", bad)

    return c.summary()


if __name__ == "__main__":
    ok = run_tests()
    raise SystemExit(0 if ok else 1)
