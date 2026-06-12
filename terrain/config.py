"""Load & validasi konfigurasi pipeline.

Aturan emas terkait (AGENTS §3, PIPELINE §1):
- input_tif, box_width_km, box_height_km WAJIB. Kalau kosong/placeholder/null
  -> gagal dengan pesan jelas. JANGAN menebak nilainya.
- Field lain punya default.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, asdict, fields, field


class ConfigError(ValueError):
    """Config tidak valid / field wajib kosong. Pesan harus menunjuk field."""


# Default untuk field opsional (PIPELINE §1).
_DEFAULTS = {
    "output_dir": "output",
    "scale_studs_per_m": 2.0,
    "nodata_threshold": -500.0,
    "overlap_px": 1,
    "max_tile_studs": 16384,
    "max_tile_px": 4096,
    # Batas voxel (4x4x4 studs) per satu impor Terrain Importer. ~2^32 (4.295e9)
    # dengan margin tipis. Temuan uji lapangan: 4.18e9 DITERIMA, 5.23e9 DITOLAK.
    "max_tile_voxels": 4_200_000_000,
    # Snap Size & Position tile ke kelipatan 4 (voxel) supaya tile menempel pas
    # di grid voxel saat "Snap to Voxels" aktif (cegah celah ~4 stud antar-tile).
    "voxel_align": True,
    "output_prefix": "RUH_tile",
    "flip_z": False,
}

# Field wajib (tidak punya default; harus diisi user).
_REQUIRED = ("input_tif", "box_width_km", "box_height_km")

# String yang dianggap "belum diisi" (placeholder).
_PLACEHOLDERS = {"", "TODO", "FIXME", "path/to/your.tif", "data/output_srtm.tif"}


@dataclass
class Config:
    input_tif: str
    box_width_km: float
    box_height_km: float
    # Crop multi-place: daftar {name, box:[lon_min,lat_min,lon_max,lat_max]}.
    # Bila non-kosong, box_width/height per-zona DITURUNKAN dari geotag (bukan wajib).
    zones: list = field(default_factory=list)
    output_dir: str = "output"
    scale_studs_per_m: float = 2.0
    nodata_threshold: float = -500.0
    overlap_px: int = 1
    max_tile_studs: int = 16384
    max_tile_px: int = 4096
    max_tile_voxels: int = 4_200_000_000
    voxel_align: bool = True
    output_prefix: str = "RUH_tile"
    flip_z: bool = False

    def to_dict(self) -> dict:
        return asdict(self)


def _is_blank(value) -> bool:
    """True kalau nilai dianggap belum diisi (None, kosong, placeholder)."""
    if value is None:
        return True
    if isinstance(value, str) and value.strip() in _PLACEHOLDERS:
        return True
    return False


def _coerce_number(name: str, value, *, as_int: bool = False):
    try:
        return int(value) if as_int else float(value)
    except (TypeError, ValueError):
        raise ConfigError(f"Field '{name}' harus angka, dapat: {value!r}.")


def load_config(path: str | None, overrides: dict | None = None) -> Config:
    """Baca config.json (opsional) + terapkan override CLI, lalu validasi.

    overrides: dict dari flag CLI (mis. {'input_tif': ..., 'box_width_km': ...}).
    Nilai None di overrides diabaikan (artinya flag tidak dipakai).
    """
    raw: dict = {}

    if path is not None:
        if not os.path.isfile(path):
            raise ConfigError(
                f"Config tidak ditemukan: '{path}'. "
                f"Periksa path, atau pakai mode CLI cepat (--input/--box/--scale)."
            )
        try:
            with open(path, "r", encoding="utf-8") as f:
                raw = json.load(f)
        except json.JSONDecodeError as e:
            raise ConfigError(f"Config '{path}' bukan JSON valid: {e}")
        if not isinstance(raw, dict):
            raise ConfigError(f"Config '{path}' harus objek JSON (dict).")

    # Buang key komentar (mis. _comment) — bukan field config.
    raw = {k: v for k, v in raw.items() if not k.startswith("_")}

    # Terapkan override CLI (hanya yang bukan None).
    if overrides:
        for k, v in overrides.items():
            if v is not None:
                raw[k] = v

    # Tolak key tak dikenal supaya typo cepat ketahuan.
    known = {f.name for f in fields(Config)}
    unknown = set(raw) - known
    if unknown:
        raise ConfigError(
            f"Field config tidak dikenal: {sorted(unknown)}. "
            f"Field valid: {sorted(known)}."
        )

    # Parse zona (crop multi-place). Bila ada, box per-zona diturunkan dari geotag.
    zones = _parse_zones(raw.get("zones"))
    has_zones = len(zones) > 0

    # --- Validasi field WAJIB (gagal-aman) ---
    # input_tif selalu wajib; box wajib HANYA bila tidak pakai zones.
    required = ["input_tif"] if has_zones else list(_REQUIRED)
    missing = [name for name in required if _is_blank(raw.get(name))]
    if missing:
        raise ConfigError(
            "Field WAJIB belum diisi: "
            + ", ".join(missing)
            + ".\n  -> Isi di config.json atau lewat CLI:\n"
            "     input_tif      = path ke GeoTIFF SRTM (mis. data/output_srtm.tif)\n"
            "     box_width_km   = lebar bounding box rute (km, arah X Barat-Timur)\n"
            "     box_height_km  = tinggi bounding box (km, arah Z Utara-Selatan)\n"
            "  (box tidak wajib bila memakai 'zones' — diturunkan dari geotag.)\n"
            "  Tool tidak menebak nilai ini."
        )

    # --- Susun nilai final (default untuk yang opsional) ---
    merged = dict(_DEFAULTS)
    merged.update({k: v for k, v in raw.items() if k in known})

    # Box: 0.0 placeholder bila zones (diisi per-zona oleh orkestrator).
    bw = 0.0 if has_zones and _is_blank(raw.get("box_width_km")) else \
        _coerce_number("box_width_km", raw["box_width_km"])
    bh = 0.0 if has_zones and _is_blank(raw.get("box_height_km")) else \
        _coerce_number("box_height_km", raw["box_height_km"])

    cfg = Config(
        input_tif=str(raw["input_tif"]).strip(),
        box_width_km=bw,
        box_height_km=bh,
        zones=zones,
        output_dir=str(merged["output_dir"]),
        scale_studs_per_m=_coerce_number("scale_studs_per_m", merged["scale_studs_per_m"]),
        nodata_threshold=_coerce_number("nodata_threshold", merged["nodata_threshold"]),
        overlap_px=_coerce_number("overlap_px", merged["overlap_px"], as_int=True),
        max_tile_studs=_coerce_number("max_tile_studs", merged["max_tile_studs"], as_int=True),
        max_tile_px=_coerce_number("max_tile_px", merged["max_tile_px"], as_int=True),
        max_tile_voxels=_coerce_number("max_tile_voxels", merged["max_tile_voxels"], as_int=True),
        voxel_align=bool(merged["voxel_align"]),
        output_prefix=str(merged["output_prefix"]),
        flip_z=bool(merged["flip_z"]),
    )

    _validate_ranges(cfg)
    return cfg


def _parse_zones(raw_zones) -> list:
    """Validasi & normalisasi daftar zona crop.

    Tiap zona: {"name": str, "box": [lon_min, lat_min, lon_max, lat_max]}.
    """
    if raw_zones is None:
        return []
    if not isinstance(raw_zones, list):
        raise ConfigError("'zones' harus berupa list objek {name, box}.")
    out = []
    seen = set()
    for i, z in enumerate(raw_zones):
        if not isinstance(z, dict):
            raise ConfigError(f"zones[{i}] harus objek {{name, box}}.")
        name = str(z.get("name", "")).strip()
        if not name:
            raise ConfigError(f"zones[{i}] tidak punya 'name'.")
        if name in seen:
            raise ConfigError(f"Nama zona duplikat: '{name}'.")
        seen.add(name)
        box = z.get("box")
        if not isinstance(box, (list, tuple)) or len(box) != 4:
            raise ConfigError(
                f"zones[{i}] ('{name}') 'box' harus [lon_min, lat_min, lon_max, lat_max]."
            )
        try:
            box = [float(v) for v in box]
        except (TypeError, ValueError):
            raise ConfigError(f"zones[{i}] ('{name}') 'box' harus 4 angka.")
        if box[0] >= box[2] or box[1] >= box[3]:
            raise ConfigError(
                f"zones[{i}] ('{name}') box tidak valid: "
                f"butuh lon_min<lon_max & lat_min<lat_max, dapat {box}."
            )
        out.append({"name": name, "box": box})
    return out


def _validate_ranges(cfg: Config) -> None:
    """Validasi domain nilai (positif, dst.)."""
    # Box hanya divalidasi bila TIDAK pakai zones (di mode zones box diturunkan).
    if not cfg.zones and (cfg.box_width_km <= 0 or cfg.box_height_km <= 0):
        raise ConfigError(
            f"box_width_km & box_height_km harus > 0 "
            f"(dapat {cfg.box_width_km} x {cfg.box_height_km})."
        )
    if cfg.scale_studs_per_m <= 0:
        raise ConfigError(f"scale_studs_per_m harus > 0 (dapat {cfg.scale_studs_per_m}).")
    if cfg.overlap_px < 0:
        raise ConfigError(f"overlap_px tidak boleh negatif (dapat {cfg.overlap_px}).")
    if cfg.max_tile_px <= 1:
        raise ConfigError(f"max_tile_px harus > 1 (dapat {cfg.max_tile_px}).")
    if cfg.max_tile_studs <= 0:
        raise ConfigError(f"max_tile_studs harus > 0 (dapat {cfg.max_tile_studs}).")
    if cfg.max_tile_voxels <= 0:
        raise ConfigError(f"max_tile_voxels harus > 0 (dapat {cfg.max_tile_voxels}).")
