--!strict
-- Flows.lua — Data alur manasik per jenis ibadah (lihat docs/GAME_DESIGN.md §5).
-- Alur = DATA, bukan kode bercabang. ManasikState berjalan di atas tabel ini.
-- Menambah jenis ibadah = menambah satu entri di sini.
--
-- Stage = { id, place, ritual (= id mekanisme | nil), day (string | nil), notes }
--   place "Miqat" = token RUNTIME, di-resolve ke miqat pilihan pemain (lihat ManasikState).
--   place "...Tahallul" = cukur di sub-lokasi DALAM Mina/Makkah (bukan zona terpisah).

export type Stage = {
	id: string,
	place: string,
	ritual: string?,
	day: string?,
	notes: string?,
}

-- Refinemen fikih (berlaku semua alur haji; hasil verifikasi GAME_DESIGN §5.6):
--  • Tahallul AWAL = setelah Jumrah Aqabah (cukur) → semua larangan halal KECUALI hubungan
--    suami-istri. Tahallul TSANI (lengkap) = setelah Tawaf Ifadah (+Sa'i). Modul `Tahallul`
--    punya 2 state ini; `TAHALLUL_AWAL` di tabel = tahallul awal.
--  • NAFAR di Mina (hari 11-13): pemain memilih NAFAR AWWAL (tinggalkan Mina 12 Dz, lewati
--    jumrah hari 13) atau NAFAR TSANI (tetap s.d. 13 Dz). `MABIT_MINA_2` mewakili keduanya;
--    percabangan ditentukan saat implementasi (pilihan pemain di Mina).

local Flows: { [string]: { Stage } } = {}

-- ⚠️ DRAF mengikuti GAME_DESIGN §5 (sudah dikoreksi Nabil utk Ifrad/Qiran).
--    Verifikasi fikih sebelum dianggap final.

Flows.Umrah = {
	{ id = "IHRAM",     place = "Miqat",  ritual = "IhramChange",  notes = "niat umrah, pakai ihram" },
	{ id = "KE_MAKKAH", place = "Miqat",  ritual = "BusRide",      notes = "transisi ke Makkah" },
	{ id = "TAWAF",     place = "Makkah", ritual = "TawafCounter", notes = "7x mengelilingi Ka'bah" },
	{ id = "SAI",       place = "Makkah", ritual = "SaiCounter",   notes = "7x Shafa-Marwah" },
	{ id = "TAHALLUL",  place = "Makkah", ritual = "Tahallul",     notes = "cukur, selesai (lepas ihram)" },
}

Flows.HajiTamattu = {
	-- Fase umrah (sebelum 8 Dzulhijjah)
	{ id = "IHRAM_UMRAH",    place = "Miqat",  ritual = "IhramChange",  notes = "niat umrah" },
	{ id = "KE_MAKKAH",      place = "Miqat",  ritual = "BusRide",      notes = "transisi ke Makkah" },
	{ id = "TAWAF_UMRAH",    place = "Makkah", ritual = "TawafCounter" },
	{ id = "SAI_UMRAH",      place = "Makkah", ritual = "SaiCounter" },
	{ id = "TAHALLUL_UMRAH", place = "Makkah", ritual = "Tahallul",     notes = "tahallul umrah (lepas ihram)" },
	-- Fase haji
	{ id = "IHRAM_HAJI",       place = "Makkah",     ritual = "IhramHaji",     day = "8",     notes = "niat haji" },
	{ id = "MABIT_MINA_1",     place = "Mina",       ritual = "Mabit",         day = "8-9",   notes = "tarwiyah" },
	{ id = "WUKUF",            place = "Arafah",     ritual = "Wukuf",         day = "9",     notes = "dzuhur-maghrib + WukufIbadah" },
	{ id = "MABIT_MUZDALIFAH", place = "Muzdalifah", ritual = "PebbleCollect", day = "9-10",  notes = "mabit + ambil kerikil" },
	{ id = "JUMRAH_AQABAH",    place = "Mina",       ritual = "JumrahThrow",   day = "10",    notes = "jumrah aqabah (7 batu)" },
	{ id = "QURBAN",           place = "Mina",       ritual = "Qurban",        day = "10",    notes = "sembelih hadyu (dam wajib)" },
	{ id = "TAHALLUL_AWAL",    place = "Mina",       ritual = "Tahallul",      day = "10",    notes = "cukur (tahallul awal)" },
	{ id = "TAWAF_IFADAH",     place = "Makkah",     ritual = "TawafCounter",  day = "10+",   notes = "+ Sa'i (rukun)" },
	{ id = "MABIT_MINA_2",     place = "Mina",       ritual = "JumrahThrow",   day = "11-13", notes = "mabit + lempar 3 jumrah/hari" },
	{ id = "TAWAF_WADA",       place = "Makkah",     ritual = "TawafCounter",                 notes = "perpisahan" },
}

Flows.HajiIfrad = {
	{ id = "IHRAM_HAJI",       place = "Miqat",      ritual = "IhramChange",   day = "sblm/8", notes = "niat haji saja" },
	{ id = "KE_MAKKAH",        place = "Miqat",      ritual = "BusRide",                       notes = "transisi ke Makkah" },
	{ id = "TAWAF_QUDUM",      place = "Makkah",     ritual = "TawafCounter",                  notes = "tawaf kedatangan (sunnah)" },
	{ id = "SAI_HAJI_AWAL",    place = "Makkah",     ritual = "SaiCounter",                    notes = "sa'i haji; ihram DITAHAN (tidak tahallul)" },
	{ id = "MABIT_MINA_1",     place = "Mina",       ritual = "Mabit",         day = "8-9",    notes = "tarwiyah" },
	{ id = "WUKUF",            place = "Arafah",     ritual = "Wukuf",         day = "9" },
	{ id = "MABIT_MUZDALIFAH", place = "Muzdalifah", ritual = "PebbleCollect", day = "9-10" },
	{ id = "JUMRAH_AQABAH",    place = "Mina",       ritual = "JumrahThrow",   day = "10" },
	{ id = "TAHALLUL_AWAL",    place = "Mina",       ritual = "Tahallul",      day = "10",     notes = "TANPA qurban/dam" },
	{ id = "TAWAF_IFADAH",     place = "Makkah",     ritual = "TawafCounter",  day = "10+",    notes = "rukun (Sa'i jika belum)" },
	{ id = "MABIT_MINA_2",     place = "Mina",       ritual = "JumrahThrow",   day = "11-13" },
	{ id = "TAWAF_WADA",       place = "Makkah",     ritual = "TawafCounter" },
}

Flows.HajiQiran = {
	{ id = "IHRAM_QIRAN",      place = "Miqat",      ritual = "IhramChange",   day = "sblm/8", notes = "niat umrah & haji sekaligus" },
	{ id = "KE_MAKKAH",        place = "Miqat",      ritual = "BusRide",                       notes = "transisi ke Makkah" },
	{ id = "TAWAF_QUDUM",      place = "Makkah",     ritual = "TawafCounter",                  notes = "tawaf kedatangan" },
	{ id = "SAI_QIRAN",        place = "Makkah",     ritual = "SaiCounter",                    notes = "sa'i umrah+haji; ihram DITAHAN" },
	{ id = "MABIT_MINA_1",     place = "Mina",       ritual = "Mabit",         day = "8-9" },
	{ id = "WUKUF",            place = "Arafah",     ritual = "Wukuf",         day = "9" },
	{ id = "MABIT_MUZDALIFAH", place = "Muzdalifah", ritual = "PebbleCollect", day = "9-10" },
	{ id = "JUMRAH_AQABAH",    place = "Mina",       ritual = "JumrahThrow",   day = "10" },
	{ id = "QURBAN",           place = "Mina",       ritual = "Qurban",        day = "10",     notes = "sembelih hadyu (dam WAJIB)" },
	{ id = "TAHALLUL_AWAL",    place = "Mina",       ritual = "Tahallul",      day = "10",     notes = "cukur (tahallul awal)" },
	{ id = "TAWAF_IFADAH",     place = "Makkah",     ritual = "TawafCounter",  day = "10+",    notes = "rukun (Sa'i sudah terpenuhi)" },
	{ id = "MABIT_MINA_2",     place = "Mina",       ritual = "JumrahThrow",   day = "11-13" },
	{ id = "TAWAF_WADA",       place = "Makkah",     ritual = "TawafCounter" },
}

return Flows
