#!/usr/bin/env python3
"""convert_terrain.py — RUH Main Place terrain pipeline (entry point CLI).

GeoTIFF SRTM  ->  tile PNG 16-bit + import_manifest.json + IMPORT_GUIDE.md
untuk Roblox Studio Terrain Importer.

Pemakaian:
    python convert_terrain.py --config config.json
    python convert_terrain.py --input data/x.tif --box 26 16 --scale 2
    python convert_terrain.py --config config.json --dry-run

Aturan emas (AGENTS §3) ditegakkan di modul terrain/*. Lihat SPEC.md & PIPELINE.md.
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np

from terrain.config import load_config, ConfigError
from terrain import io as tio
from terrain.io import TiffReadError
from terrain.normalize import clean_and_normalize, NormalizeError
from terrain.tiling import compute_layout, slice_tile, TilingError
from terrain.geo import GeoError
from terrain import manifest as tmanifest


def log(msg: str) -> None:
    print(msg, flush=True)


def parse_args(argv=None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="convert_terrain.py",
        description="GeoTIFF SRTM -> tile PNG 16-bit + manifest impor Roblox.",
    )
    p.add_argument("--config", default=None, help="Path config.json.")
    p.add_argument("--input", default=None, help="Override input_tif (path GeoTIFF).")
    p.add_argument(
        "--box", nargs=2, type=float, metavar=("WIDTH_KM", "HEIGHT_KM"),
        default=None, help="Override box_width_km box_height_km.",
    )
    p.add_argument("--scale", type=float, default=None, help="Override scale_studs_per_m.")
    p.add_argument("--output", default=None, help="Override output_dir.")
    p.add_argument(
        "--dry-run", action="store_true",
        help="Hitung & cetak rencana tile TANPA membaca berat / menulis PNG.",
    )
    p.add_argument(
        "--only-tile", nargs=2, type=int, metavar=("IX", "IZ"), default=None,
        help="Tulis HANYA tile (ix, iz) ini (de-risk/uji), normalisasi tetap GLOBAL. "
             "Tidak menulis manifest 8-tile penuh.",
    )
    return p.parse_args(argv)


def build_overrides(args: argparse.Namespace) -> dict:
    overrides: dict = {}
    if args.input is not None:
        overrides["input_tif"] = args.input
    if args.box is not None:
        overrides["box_width_km"] = args.box[0]
        overrides["box_height_km"] = args.box[1]
    if args.scale is not None:
        overrides["scale_studs_per_m"] = args.scale
    if args.output is not None:
        overrides["output_dir"] = args.output
    return overrides


def _fmt(v: float) -> str:
    """Format angka studs ringkas (buang .0 yang tidak perlu)."""
    return f"{v:g}"


def print_plan(cfg, layout, elev_min_m, elev_max_m, *, dry_run: bool) -> None:
    """Cetak rencana tile + ringkasan (dipakai dry-run & run nyata)."""
    log("")
    log("=== RENCANA TILE ===")
    log(f"  Skala            : {cfg.scale_studs_per_m} studs/m")
    log(f"  Box              : {cfg.box_width_km} x {cfg.box_height_km} km")
    log(f"  DEM (piksel)     : {layout.dem_w} x {layout.dem_h}")
    log(f"  Elevasi          : {elev_min_m:.2f} .. {elev_max_m:.2f} m "
        f"(delta {elev_max_m - elev_min_m:.2f} m)")
    log(f"  Ukuran dunia     : {_fmt(layout.size_x_total)} x {_fmt(layout.size_z_total)} studs")
    log(f"  Grid tile        : {layout.tiles_x} x {layout.tiles_z} "
        f"= {layout.tiles_x * layout.tiles_z} tile")
    log(f"  Size per tile    : X={_fmt(layout.size_x_tile)}  Z={_fmt(layout.size_z_tile)} studs")
    log(f"  Size Y (relief)  : {_fmt(layout.size_y)} studs")
    log(f"  Position Y       : {_fmt(layout.position_y)} studs  (= -Size_Y/2)")
    log(f"  Overlap          : {layout.overlap_px} px")
    log(f"  Voxel/tile       : {layout.voxels_per_tile:.4g}  "
        f"(budget {layout.max_tile_voxels:.4g}, "
        f"{100.0 * layout.voxels_per_tile / layout.max_tile_voxels:.0f}% terpakai)")

    for w in layout.warnings:
        log(f"  [!] {w}")

    log("")
    log("  Tile     | px(w x h) |   Size (x, y, z)            |   Position (x, y, z)")
    log("  ---------+-----------+-----------------------------+----------------------------")
    for t in layout.tiles:
        log(
            f"  x{t.ix} z{t.iz}   | {t.px_w:4d}x{t.px_h:<4d} | "
            f"({_fmt(t.size_x):>7},{_fmt(t.size_y):>7},{_fmt(t.size_z):>7}) | "
            f"({_fmt(t.position_x):>8},{_fmt(t.position_y):>7},{_fmt(t.position_z):>8})"
        )

    # Cek simetri Position X & Z (SPEC §7): jumlah ~ 0.
    sum_x = sum(t.position_x for t in layout.tiles)
    sum_z = sum(t.position_z for t in layout.tiles)
    log("")
    log(f"  Cek simetri: sum(position_x)={sum_x:.6g}  sum(position_z)={sum_z:.6g}  "
        f"(harus ~0)")
    if dry_run:
        log("")
        log("  [DRY-RUN] Tidak ada PNG/manifest yang ditulis.")


def _clean_stale_tiles(cfg, out_dir: str) -> int:
    """Hapus PNG tile lama ({prefix}_x*_z*.png) di out_dir sebelum build baru.

    Mencegah tile BASI tertinggal saat grid berubah (mis. dari run sebelumnya
    dengan jumlah tile berbeda). Hanya menyentuh file pola tile tool ini.
    """
    import re
    if not os.path.isdir(out_dir):
        return 0
    pat = re.compile(rf"^{re.escape(cfg.output_prefix)}_x\d+_z\d+\.png$")
    removed = 0
    for fname in os.listdir(out_dir):
        if pat.match(fname):
            os.remove(os.path.join(out_dir, fname))
            removed += 1
    return removed


def _write_single_tile(cfg, layout, img16, only_tile) -> int:
    """Tulis satu tile (ix, iz) + parameter impornya (mode de-risk)."""
    want_ix, want_iz = int(only_tile[0]), int(only_tile[1])
    match = next(
        (t for t in layout.tiles if t.ix == want_ix and t.iz == want_iz), None
    )
    if match is None:
        log(f"\nERROR: tile (x{want_ix}, z{want_iz}) di luar grid "
            f"{layout.tiles_x} x {layout.tiles_z} (ix 0..{layout.tiles_x - 1}, "
            f"iz 0..{layout.tiles_z - 1}).")
        return 6

    os.makedirs(cfg.output_dir, exist_ok=True)
    tile = slice_tile(img16, match)
    out_path = os.path.join(cfg.output_dir, match.file)
    tio.write_png16(out_path, tile)

    # Tepi luar tile (jarak terjauh dari origin) — yang diuji terhadap batas terrain.
    edge_x = match.position_x + (match.size_x / 2.0) * (1 if match.position_x >= 0 else -1)
    edge_z = match.position_z + (match.size_z / 2.0) * (1 if match.position_z >= 0 else -1)

    log("")
    log("=== TILE UJI (ONLY-TILE) ===")
    log(f"  File        : {os.path.abspath(out_path)}  ({tile.shape[1]}x{tile.shape[0]} px, {tile.dtype})")
    log(f"  Ketik di Terrain Importer Studio:")
    log(f"    Size      X = {_fmt(match.size_x)}   Y = {_fmt(match.size_y)}   Z = {_fmt(match.size_z)}")
    log(f"    Position  X = {_fmt(match.position_x)}   Y = {_fmt(match.position_y)}   Z = {_fmt(match.position_z)}")
    log(f"  Tepi luar tile (jarak terjauh dari origin): X={_fmt(edge_x)}  Z={_fmt(edge_z)}")
    log("")
    log("  CARA UJI:")
    log("    1. Import PNG ini dengan Size/Position di atas, material non-Water.")
    log(f"    2. Play, jalan ke arah tepi luar (X ~ {_fmt(edge_x)}, Z ~ {_fmt(edge_z)}).")
    log("    3. Cek: terrain ADA, padat, bisa dijalani sampai tepi?")
    log("       PASS -> skala aman, build semua tile penuh.")
    log("       FAIL/bolong -> turunkan scale (Jalan B), rerun.")
    return 0


def _process_region(cfg, region_img, gmin, gmax, out_dir, label, args, geo_bounds=None) -> int:
    """Proses SATU region (full atau crop zona) -> rencana + (tulis tile + manifest).

    cfg.box_width_km/height_km harus sudah diset untuk region ini oleh pemanggil.
    Normalisasi sudah GLOBAL sebelum region ini diiris (gmin/gmax global).
    geo_bounds: extent lon/lat aktual region (untuk pemetaan OSM->studs di manifest).
    """
    h, w = region_img.shape
    tag = f"[{label}] " if label else ""

    layout = compute_layout(cfg, gmin, gmax, h, w)
    log(f"      {tag}Grid {layout.tiles_x} x {layout.tiles_z} = "
        f"{layout.tiles_x * layout.tiles_z} tile.")
    print_plan(cfg, layout, gmin, gmax, dry_run=args.dry_run)

    if args.dry_run:
        return 0

    # flip_z diterapkan pada PIKSEL region saat output (geo-crop di atas memakai
    # orientasi asli supaya konversi lon/lat benar).
    img = np.flipud(region_img) if cfg.flip_z else region_img
    if cfg.flip_z:
        log(f"      {tag}flip_z=True -> heightmap dibalik Utara-Selatan.")

    if args.only_tile is not None and not cfg.zones:
        cfg.output_dir = out_dir
        return _write_single_tile(cfg, layout, img, args.only_tile)

    os.makedirs(out_dir, exist_ok=True)
    n_removed = _clean_stale_tiles(cfg, out_dir)
    if n_removed:
        log(f"      {tag}(dibersihkan {n_removed} PNG tile lama)")
    log(f"      {tag}Menulis {layout.tiles_x * layout.tiles_z} PNG 16-bit ...")
    for t in layout.tiles:
        tile = slice_tile(img, t)
        tio.write_png16(os.path.join(out_dir, t.file), tile)

    manifest = tmanifest.build_manifest_dict(cfg, layout, gmin, gmax, geo_bounds=geo_bounds)
    if label:
        manifest["zone"] = label
    manifest_path = os.path.join(out_dir, "import_manifest.json")
    guide_path = os.path.join(out_dir, "IMPORT_GUIDE.md")
    tmanifest.write_manifest_json(manifest_path, manifest)
    tmanifest.write_import_guide(guide_path, cfg, layout, manifest)

    n_png = sum(
        1 for f in os.listdir(out_dir)
        if f.startswith(cfg.output_prefix) and f.endswith(".png")
    )
    n_exp = layout.tiles_x * layout.tiles_z
    log(f"      {tag}PNG: {n_png}/{n_exp} | dunia {_fmt(layout.size_x_total)}x"
        f"{_fmt(layout.size_z_total)} studs | {os.path.abspath(out_dir)}")
    return 0 if n_png == n_exp else 1


def _run_zones(cfg, img16, norm, geo, args) -> int:
    """Mode multi-place: crop tiap zona dari img16 (norm GLOBAL) -> output per-zona."""
    from terrain.geo import geo_box_to_pixels, pixels_to_km, pixel_bounds_to_lonlat

    log(f"[5/9] Mode ZONES: {len(cfg.zones)} zona (norm global, Size_Y konsisten).")
    rc = 0
    base_out = cfg.output_dir
    for z in cfg.zones:
        name, box = z["name"], z["box"]
        x0, x1, y0, y1 = geo_box_to_pixels(geo, *box)
        bw, bh = pixels_to_km(geo, x0, x1, y0, y1)
        lon_min, lat_min, lon_max, lat_max = pixel_bounds_to_lonlat(geo, x0, x1, y0, y1)
        gb = {"lon_min": lon_min, "lat_min": lat_min, "lon_max": lon_max, "lat_max": lat_max}
        region = np.ascontiguousarray(img16[y0:y1, x0:x1])
        out_dir = os.path.join(base_out, name)
        log("")
        log(f"=== ZONA: {name} ===")
        log(f"      box lon/lat {box} -> piksel X[{x0}:{x1}] Y[{y0}:{y1}] "
            f"({x1 - x0}x{y1 - y0}px)")
        log(f"      ukuran fisik ~ {bw:.3f} x {bh:.3f} km")
        # Set box region untuk perhitungan layout (Size_Y tetap global via gmin/gmax).
        cfg.box_width_km, cfg.box_height_km = bw, bh
        rc |= _process_region(cfg, region, norm.elev_min_m, norm.elev_max_m,
                              out_dir, name, args, geo_bounds=gb)
    log("")
    log("=== RINGKASAN ZONES ===")
    log(f"  {len(cfg.zones)} zona diproses -> {os.path.abspath(base_out)}/<nama>/")
    log(f"  Elevasi global (konsisten lintas zona): "
        f"{norm.elev_min_m:.2f} .. {norm.elev_max_m:.2f} m")
    return rc


def run(args: argparse.Namespace) -> int:
    # 1) Load & validasi config (gagal-aman).
    overrides = build_overrides(args)
    use_config_path = args.config
    if use_config_path is None and not overrides:
        log("ERROR: tidak ada --config maupun flag CLI (--input/--box/--scale).")
        log("       Lihat: python convert_terrain.py --help")
        return 2
    cfg = load_config(use_config_path, overrides)

    log("[1/9] Config OK.")
    log(f"      input_tif = {cfg.input_tif}")
    log(f"      output_dir = {cfg.output_dir}")

    # 2) Baca GeoTIFF -> float32 (band 1) + georeferensi.
    log(f"[2/9] Membaca GeoTIFF: {cfg.input_tif}")
    dem, geo = tio.read_geotiff_band1_with_geo(cfg.input_tif)
    dem_h, dem_w = dem.shape
    log(f"      DEM shape = {dem_w} x {dem_h} px, dtype={dem.dtype}")
    if geo is not None:
        log(f"      Geo: lon {geo.lon0:.5f}..{geo.lon1:.5f}, "
            f"lat {geo.lat1:.5f}..{geo.lat0:.5f}")
    if cfg.zones and geo is None:
        raise ConfigError(
            "Mode 'zones' butuh GeoTIFF ber-georeferensi (tag ModelPixelScale/"
            "ModelTiepoint tak ditemukan). Pakai box manual atau TIFF ber-geotag."
        )

    # 3-4) NoData cleanup + normalisasi GLOBAL 16-bit (SEBELUM tiling/crop).
    log("[3/9] Membersihkan NoData...")
    log("[4/9] Normalisasi GLOBAL -> uint16 (aturan emas #2)...")
    norm = clean_and_normalize(dem, cfg.nodata_threshold)
    log(f"      Elevasi global: {norm.elev_min_m:.2f} .. {norm.elev_max_m:.2f} m")
    log(f"      Piksel NoData di-clamp: {norm.nodata_count}")
    if norm.is_flat:
        log("      [!] WARNING: DEM datar total (gmax==gmin). Heightmap flat valid dibuat.")

    img16 = norm.img16  # crop/flip ditangani di hilir; normalisasi sudah global.

    # 5-9) Multi-place (zones) atau dunia tunggal (full box).
    if cfg.zones:
        return _run_zones(cfg, img16, norm, geo, args)

    log("[5/9] Menghitung tata letak tile (dunia tunggal)...")
    full_gb = None
    if geo is not None:
        from terrain.geo import pixel_bounds_to_lonlat
        lo, la, lo2, la2 = pixel_bounds_to_lonlat(geo, 0, dem_w, 0, dem_h)
        full_gb = {"lon_min": lo, "lat_min": la, "lon_max": lo2, "lat_max": la2}
    return _process_region(cfg, img16, norm.elev_min_m, norm.elev_max_m,
                           cfg.output_dir, None, args, geo_bounds=full_gb)


def main(argv=None) -> int:
    args = parse_args(argv)
    try:
        return run(args)
    except ConfigError as e:
        log(f"\nERROR konfigurasi: {e}")
        return 2
    except TiffReadError as e:
        log(f"\nERROR baca GeoTIFF: {e}")
        return 3
    except NormalizeError as e:
        log(f"\nERROR normalisasi: {e}")
        return 4
    except TilingError as e:
        log(f"\nERROR tiling: {e}")
        return 5
    except GeoError as e:
        log(f"\nERROR geo/crop: {e}")
        return 6


if __name__ == "__main__":
    sys.exit(main())
