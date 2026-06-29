--!strict
-- GuideContent.lua — KONTEN buku panduan ibadah portable (SYSTEMS_DESIGN §3). Data per-KELUARGA
-- tahap (id Flows → keluarga via prefix), supaya tak perlu entri tiap varian. UI client (GuideHud)
-- membaca ini berdasar atribut pemain "ManasikStage". KONTRAK BERSAMA (konten, bukan logika).

local GuideContent = {}

export type Entry = { title: string, steps: { string }, niat: string?, dua: string?, donts: { string }? }

-- Keluarga ritual dari id tahap Flows.
local function family(id: string): string
	if id:find("^IHRAM") then return "ihram" end
	if id:find("^KE_MAKKAH") then return "bus" end
	if id:find("^TAWAF") then return "tawaf" end
	if id:find("^SAI") then return "sai" end
	if id:find("^TAHALLUL") then return "tahallul" end
	if id:find("^WUKUF") then return "wukuf" end
	if id:find("^MABIT_MUZDALIFAH") then return "muzdalifah" end
	if id:find("^MABIT_MINA") then return "mabit_mina" end
	if id:find("^JUMRAH") then return "jumrah" end
	if id:find("^QURBAN") then return "qurban" end
	return "umum"
end
GuideContent.family = family

local byFamily: { [string]: Entry } = {
	ihram = {
		title = "Ihram & Niat (di Miqat)",
		steps = { "Kenakan 2 helai kain ihram putih (pria: tanpa jahitan, kepala terbuka).", "Berniat sesuai jenis ibadah.", "Mulai talbiyah." },
		niat = "Labbaika Allahumma … (ucapkan niat umrah/haji sesuai jenis).",
		donts = { "Jangan pakai wewangian", "Jangan potong rambut/kuku", "Jangan menutup kepala (pria)" },
	},
	bus = {
		title = "Menuju Makkah",
		steps = { "Naik bus dari miqat.", "Perbanyak talbiyah selama perjalanan." },
	},
	tawaf = {
		title = "Tawaf (7 putaran)",
		steps = { "Mulai dari sudut Hajar Aswad.", "Kelilingi Ka'bah 7× berlawanan arah jarum jam (Ka'bah di kiri).", "Perbanyak doa." },
		dua = "Rabbana atina fid-dunya hasanah…",
	},
	sai = {
		title = "Sa'i (7 perjalanan)",
		steps = { "Mulai di bukit Shafa, menghadap Ka'bah.", "Berjalan ke Marwah (=1), bolak-balik hingga 7, berakhir di Marwah." },
	},
	tahallul = {
		title = "Tahallul (cukur)",
		steps = { "Cukur/pendekkan rambut.", "Tahallul awal: larangan ihram halal KECUALI jima.", "Tahallul penuh setelah Tawaf Ifadah." },
	},
	wukuf = {
		title = "Wukuf di Arafah (rukun)",
		steps = { "Hadir di Arafah sejak dzuhur hingga maghrib.", "Perbanyak doa, dzikir, taubat.", "(Boleh time-skip ke maghrib bila tetap hadir.)" },
		dua = "Doa terbaik adalah doa hari Arafah.",
	},
	muzdalifah = {
		title = "Mabit & Ambil Kerikil (Muzdalifah)",
		steps = { "Bermalam di Muzdalifah (Masy'aril Haram).", "Kumpulkan 7 kerikil untuk Jumrah.", "(Boleh time-skip ke subuh.)" },
	},
	mabit_mina = {
		title = "Mabit di Mina",
		steps = { "Bermalam di Mina.", "Hari 11–13: lempar 3 jumrah/hari (Ula→Wustha→Aqabah)." },
	},
	jumrah = {
		title = "Lempar Jumrah",
		steps = { "Lempar 7 kerikil ke tugu (hari 10: Aqabah).", "Bertakbir tiap lemparan." },
	},
	qurban = {
		title = "Qurban (Hadyu)",
		steps = { "Sembelih hadyu (wajib bagi Tamattu' & Qiran).", "Dilakukan setelah Jumrah Aqabah, sebelum tahallul." },
	},
	umum = {
		title = "Panduan Manasik",
		steps = { "Ikuti panduan tahap berjalan.", "Tetap di jalur & ikuti arahan petugas." },
	},
}

-- Konten untuk id tahap (atau fallback "umum").
function GuideContent.forStage(stageId: string?): Entry
	if not stageId then return byFamily.umum end
	return byFamily[family(stageId)] or byFamily.umum
end

-- Validasi: tiap entri punya title + minimal 1 langkah. (Uji.)
function GuideContent.validate(): (boolean, string?)
	for fam, e in pairs(byFamily) do
		if type(e.title) ~= "string" or e.title == "" then return false, fam .. ": title kosong" end
		if type(e.steps) ~= "table" or #e.steps == 0 then return false, fam .. ": steps kosong" end
	end
	return true
end

return GuideContent
