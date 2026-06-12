"""RUH Main Place terrain pipeline package.

Modul:
- config    : load & validasi config (gagal-aman bila field wajib kosong)
- io        : baca GeoTIFF (band 1) -> float32, tulis PNG 16-bit
- normalize : NoData cleanup + normalisasi GLOBAL -> uint16
- tiling    : layout tile (size/position) + potong dengan overlap
- manifest  : tulis import_manifest.json + IMPORT_GUIDE.md
"""

__all__ = ["config", "io", "normalize", "tiling", "manifest"]
