"""NoData cleanup + normalisasi GLOBAL elevasi -> uint16 (SPEC §3).

ATURAN EMAS #2: normalisasi WAJIB pakai min/max SELURUH DEM, SEBELUM tiling.
Normalisasi per-tile = sambungan jadi tebing patah. Fungsi di sini sengaja
bekerja pada DEM penuh; tiling dilakukan SETELAH ini, di modul tiling.
"""

from __future__ import annotations

from dataclasses import dataclass
import numpy as np


class NormalizeError(ValueError):
    pass


@dataclass
class NormResult:
    img16: np.ndarray        # uint16 (H, W), heightmap global ternormalisasi
    elev_min_m: float        # gmin (meter) — elevasi valid minimum
    elev_max_m: float        # gmax (meter)
    nodata_count: int        # jumlah piksel yang di-flag NoData & di-clamp
    is_flat: bool            # True bila gmax == gmin (relief nol)


def clean_and_normalize(dem: np.ndarray, nodata_threshold: float) -> NormResult:
    """SPEC §3 langkah 2-6: bersihkan NoData lalu normalisasi GLOBAL ke uint16.

    1. valid_mask = dem > nodata_threshold
    2. clamp NoData -> elevasi valid minimum
    3. gmin/gmax GLOBAL (seluruh DEM, sebelum tiling)
    4. norm = (dem - gmin) / (gmax - gmin)
    5. img16 = round(norm * 65535) as uint16
    """
    dem = np.asarray(dem, dtype=np.float32)
    if dem.ndim != 2:
        raise NormalizeError(f"DEM harus 2D, dapat shape {dem.shape}.")

    # Buang NaN/inf lebih dulu agar tidak mencemari min/max.
    finite_mask = np.isfinite(dem)

    # (1) Piksel valid = di atas ambang NoData DAN finite.
    valid_mask = finite_mask & (dem > nodata_threshold)

    if not valid_mask.any():
        raise NormalizeError(
            "Seluruh DEM ter-flag NoData (tidak ada piksel valid). "
            f"Apakah nodata_threshold={nodata_threshold} terlalu tinggi? "
            "SRTM valid biasanya jauh di atas -500 m."
        )

    valid_min = float(dem[valid_mask].min())

    # (2) Clamp semua piksel tidak-valid ke elevasi valid minimum.
    nodata_count = int((~valid_mask).sum())
    if nodata_count:
        dem = dem.copy()
        dem[~valid_mask] = valid_min

    # (3) GLOBAL min/max — sebelum tiling. Inilah inti aturan emas #2.
    gmin = float(dem.min())
    gmax = float(dem.max())

    # (4-5) Normalisasi ke 0..1 lalu skala ke 16-bit.
    if gmax > gmin:
        norm = (dem - gmin) / (gmax - gmin)
        is_flat = False
    else:
        # Datar total (SPEC: warning + heightmap flat valid). Pakai 0.0 semua.
        norm = np.zeros_like(dem)
        is_flat = True

    img16 = np.clip(np.rint(norm * 65535.0), 0, 65535).astype(np.uint16)

    # Validasi akhir nilai (SPEC §7).
    if np.isnan(img16).any():  # pragma: no cover - uint16 tak punya NaN
        raise NormalizeError("Output mengandung NaN (tidak seharusnya terjadi).")

    return NormResult(
        img16=img16,
        elev_min_m=gmin,
        elev_max_m=gmax,
        nodata_count=nodata_count,
        is_flat=is_flat,
    )
