#!/usr/bin/env python3
"""make_demo_dem.py — buat GeoTIFF SRTM SINTETIS untuk uji coba (tanpa data asli).

Bukan bagian pipeline; alat bantu agar bisa menjalankan convert_terrain.py
(termasuk --dry-run) tanpa file SRTM nyata. Elevasi & ukuran dipilih agar
mereproduksi contoh kerja SPEC §6 (elevasi 210..1014 m -> Size Y 1608 studs).

Jalankan:  python make_demo_dem.py
Output  :  data/demo_srtm.tif  (float32, 868 x 534)
"""

from __future__ import annotations

import os
import numpy as np
import tifffile


def main() -> None:
    h, w = 534, 868  # 4*217 x 2*267 -> mirip pixel contoh SPEC §6
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)

    grad = xx / (w - 1) * 600.0                                   # tren Barat->Timur
    hills = (
        200.0 * np.sin(xx / w * 3 * np.pi) * np.sin(yy / h * 2 * np.pi)
        + 120.0 * np.sin(xx / w * 7 * np.pi)
    )
    dem = (grad + hills).astype(np.float32)

    # Rentangkan tepat ke 210..1014 m (delta 804 -> Size Y = 804*2 = 1608 studs).
    dem = (dem - dem.min()) / (dem.max() - dem.min())
    dem = (dem * (1014.0 - 210.0) + 210.0).astype(np.float32)

    # Sisipkan sedikit NoData ala SRTM untuk menguji cleanup.
    dem[10:25, 10:25] = -32768.0

    os.makedirs("data", exist_ok=True)
    out = os.path.join("data", "demo_srtm.tif")
    tifffile.imwrite(out, dem)
    print(f"Ditulis {out}  shape={w}x{h}  elev~210..1014 m (+ patch NoData -32768)")


if __name__ == "__main__":
    main()
