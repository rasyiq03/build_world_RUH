"""Konversi geospasial: geotag GeoTIFF <-> indeks piksel <-> km.

Dipakai untuk crop per-zona (multi-place). Penting: crop hanya MENGIRIS array;
normalisasi tetap GLOBAL atas DEM penuh (lihat normalize.py) supaya elevasi antar
zona konsisten saat di-teleport.
"""

from __future__ import annotations

from dataclasses import dataclass
import math

# Perkiraan panjang 1 derajat lintang (km). Bujur dikali cos(lat).
KM_PER_DEG_LAT = 111.320


class GeoError(ValueError):
    pass


@dataclass
class GeoRef:
    """Referensi geospasial GeoTIFF (top-left origin, derajat per piksel)."""
    lon0: float   # bujur tepi kiri (kolom 0)
    lat0: float   # lintang tepi atas (baris 0)
    sx: float     # derajat per piksel arah bujur (kolom)
    sy: float     # derajat per piksel arah lintang (baris)
    width: int    # jumlah kolom (W)
    height: int   # jumlah baris (H)

    @property
    def lon1(self) -> float:
        return self.lon0 + self.width * self.sx

    @property
    def lat1(self) -> float:
        return self.lat0 - self.height * self.sy  # lintang turun ke bawah

    def bounds(self) -> tuple[float, float, float, float]:
        """(lon_min, lat_min, lon_max, lat_max)."""
        return (self.lon0, self.lat1, self.lon1, self.lat0)


def geo_box_to_pixels(
    geo: GeoRef, lon_min: float, lat_min: float, lon_max: float, lat_max: float
) -> tuple[int, int, int, int]:
    """Konversi kotak geografis -> indeks piksel (x0, x1, y0, y1), ter-clamp.

    Kolom (X) searah bujur (kiri=barat). Baris (Y) berlawanan lintang (atas=utara).
    Mengembalikan rentang setengah-terbuka [x0:x1), [y0:y1) untuk slicing numpy.
    """
    if lon_min >= lon_max or lat_min >= lat_max:
        raise GeoError(
            f"Kotak geografis tidak valid: lon[{lon_min},{lon_max}] lat[{lat_min},{lat_max}]."
        )

    x0 = int(round((lon_min - geo.lon0) / geo.sx))
    x1 = int(round((lon_max - geo.lon0) / geo.sx))
    # lat_max (utara) -> baris kecil; lat_min (selatan) -> baris besar.
    y0 = int(round((geo.lat0 - lat_max) / geo.sy))
    y1 = int(round((geo.lat0 - lat_min) / geo.sy))

    x0, x1 = max(0, min(x0, x1)), min(geo.width, max(x0, x1))
    y0, y1 = max(0, min(y0, y1)), min(geo.height, max(y0, y1))

    if x1 - x0 < 2 or y1 - y0 < 2:
        raise GeoError(
            f"Kotak geografis menghasilkan crop terlalu kecil/keluar batas: "
            f"piksel X[{x0}:{x1}] Y[{y0}:{y1}] dari DEM {geo.width}x{geo.height}. "
            f"Periksa apakah kotak berada di dalam bounds {geo.bounds()}."
        )
    return x0, x1, y0, y1


def pixel_bounds_to_lonlat(
    geo: GeoRef, x0: int, x1: int, y0: int, y1: int
) -> tuple[float, float, float, float]:
    """Batas geografis AKTUAL dari rentang piksel crop -> (lon_min, lat_min, lon_max, lat_max).

    Inilah extent sebenarnya yang ditempati terrain di Roblox (sesudah pembulatan
    piksel), jadi dipakai sebagai sumber kebenaran untuk memetakan OSM -> studs.
    """
    lon_min = geo.lon0 + x0 * geo.sx
    lon_max = geo.lon0 + x1 * geo.sx
    lat_max = geo.lat0 - y0 * geo.sy   # baris atas (y0) = utara = lat besar
    lat_min = geo.lat0 - y1 * geo.sy   # baris bawah (y1) = selatan = lat kecil
    return lon_min, lat_min, lon_max, lat_max


def pixels_to_km(geo: GeoRef, x0: int, x1: int, y0: int, y1: int) -> tuple[float, float]:
    """Ukuran fisik crop (width_km, height_km) — true-ground (bujur dikompres cos lat)."""
    lat_top = geo.lat0 - y0 * geo.sy
    lat_bot = geo.lat0 - y1 * geo.sy
    mean_lat = (lat_top + lat_bot) / 2.0
    width_km = (x1 - x0) * geo.sx * KM_PER_DEG_LAT * math.cos(math.radians(mean_lat))
    height_km = (y1 - y0) * geo.sy * KM_PER_DEG_LAT
    return width_km, height_km
