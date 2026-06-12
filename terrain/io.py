"""I/O: baca GeoTIFF (band 1) -> float32, tulis PNG 16-bit (uint16).

Sengaja memakai tifffile + imageio (bukan rasterio/GDAL) agar mudah di Windows.
"""

from __future__ import annotations

import os
import numpy as np


class TiffReadError(RuntimeError):
    pass


def read_geotiff_band1(path: str) -> np.ndarray:
    """Baca GeoTIFF, kembalikan band pertama sebagai float32 2D (H, W)."""
    band, _ = read_geotiff_band1_with_geo(path)
    return band


def read_geotiff_band1_with_geo(path: str):
    """Baca GeoTIFF -> (float32 2D band1, GeoRef|None).

    GeoRef diisi bila tag geo (ModelPixelScale + ModelTiepoint) tersedia; None
    bila tidak (mis. TIFF biasa tanpa georeferensi).
    SRTM umumnya single-band; multi-band -> ambil band 1.
    """
    if not os.path.isfile(path):
        raise TiffReadError(
            f"File GeoTIFF tidak ditemukan: '{path}'.\n"
            f"  -> Periksa 'input_tif' di config / flag --input. "
            f"Path relatif dihitung dari direktori kerja saat ini."
        )

    try:
        import tifffile
    except ImportError as e:  # pragma: no cover - lingkungan
        raise TiffReadError(
            "Modul 'tifffile' belum terpasang. Jalankan: pip install -r requirements.txt"
        ) from e

    try:
        with tifffile.TiffFile(path) as tf:
            page = tf.pages[0]
            arr = page.asarray()
            tags = {t.name: t.value for t in page.tags}
    except Exception as e:
        # GeoTIFF terkompresi (LZW/Deflate) butuh imagecodecs.
        if "imagecodecs" in str(e) or "COMPRESSION" in str(e):
            raise TiffReadError(
                f"GeoTIFF '{path}' terkompresi dan butuh paket 'imagecodecs'. "
                f"Pasang: pip install imagecodecs  (atau pip install -r requirements.txt). "
                f"Detail: {e}"
            ) from e
        raise TiffReadError(f"Gagal membaca GeoTIFF '{path}': {e}") from e

    arr = np.asarray(arr)

    # Reduksi ke 2D (H, W), ambil band/channel pertama bila multi-dimensi.
    if arr.ndim == 2:
        band = arr
    elif arr.ndim == 3:
        band_axis = int(np.argmin(arr.shape))
        band = np.take(arr, 0, axis=band_axis)
    else:
        raise TiffReadError(
            f"Dimensi GeoTIFF tidak didukung: shape={arr.shape} (ndim={arr.ndim})."
        )

    if band.ndim != 2:
        raise TiffReadError(f"Band 1 bukan 2D setelah reduksi: shape={band.shape}.")

    band = band.astype(np.float32, copy=False)
    geo = _parse_georef(tags, band.shape[0], band.shape[1])
    return band, geo


def _parse_georef(tags: dict, height: int, width: int):
    """Susun GeoRef dari tag GeoTIFF (ModelPixelScale + ModelTiepoint)."""
    from .geo import GeoRef
    ps = tags.get("ModelPixelScaleTag")
    tp = tags.get("ModelTiepointTag")
    if not ps or not tp or len(ps) < 2 or len(tp) < 6:
        return None
    # Tiepoint: (i, j, k, x, y, z) -> piksel (i,j) memetakan ke (lon=x, lat=y).
    sx, sy = float(ps[0]), float(ps[1])
    i, j, lon, lat = float(tp[0]), float(tp[1]), float(tp[3]), float(tp[4])
    lon0 = lon - i * sx        # bujur di kolom 0
    lat0 = lat + j * sy        # lintang di baris 0 (atas)
    return GeoRef(lon0=lon0, lat0=lat0, sx=sx, sy=sy, width=width, height=height)


def write_png16(path: str, tile: np.ndarray) -> None:
    """Tulis array uint16 2D sebagai PNG 16-bit grayscale.

    ATURAN EMAS: output WAJIB 16-bit (uint16). 8-bit dilarang (terracing).
    """
    if tile.dtype != np.uint16:
        raise ValueError(
            f"write_png16 menerima dtype {tile.dtype}, harus uint16. "
            f"(Mencegah PNG 8-bit yang menimbulkan terracing.)"
        )
    if tile.ndim != 2:
        raise ValueError(f"PNG heightmap harus 2D grayscale, dapat shape {tile.shape}.")

    try:
        import imageio.v3 as iio
    except ImportError as e:  # pragma: no cover - lingkungan
        raise RuntimeError(
            "Modul 'imageio' belum terpasang. Jalankan: pip install -r requirements.txt"
        ) from e

    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    # imageio menulis uint16 2D sebagai PNG grayscale 16-bit (mode I;16).
    iio.imwrite(path, tile)
