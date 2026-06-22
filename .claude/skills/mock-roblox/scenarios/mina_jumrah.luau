--!nocheck
-- Skenario JumrahThrow (Praditama) — diuji langsung lewat MechanismRegistry (fokus logika, bukan
-- spine). Bagian A: hari 10, Jumrah Aqabah 7x → selesai. Bagian B: hari 11-13, 3 pilar berurutan
-- + uji urutan salah + pilihan NAFAR (tsani → lanjut hari 13). hitChance=1 agar deterministik.
-- Global: `h`, `Vector3`, `meta`. API ekstra mekanisme via h.mech("JumrahThrow").

meta("mechanism", "JumrahThrow")
meta("title", "Jumrah: Aqabah hari-10, lalu 3 pilar hari 11-13 + nafar")

local player = h.spawnPlayer("Praditama")
local jumrah = h.mech("JumrahThrow")

local function throw(name) jumrah.throw(name) end

----------------------------------------------------------------------------------------------------
-- BAGIAN A — hari 10: hanya Aqabah, 7 lemparan.
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN A — hari 10 (JUMRAH_AQABAH): Aqabah 7x" })
h.activate("JumrahThrow", { player = player, mode = "aqabah_only", config = { throwsPerPillar = 7, hitChance = 1 } })

-- Coba lempar ke Ula (salah hari ini) → harus ditolak.
throw("Ula")
h.event("note", { text = "Setelah coba Ula (ditolak), Aqabah = " .. tostring(jumrah.dayCounts().Aqabah) })

for _ = 1, 7 do throw("Aqabah") end
h.heartbeat(0.1)
h.event("note", { text = "Aqabah selesai? isDone=" .. tostring(h.isDone()) })
h.deactivate()

----------------------------------------------------------------------------------------------------
-- BAGIAN B — hari 11-13: 3 pilar berurutan/hari, lalu NAFAR TSANI.
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN B — hari 11-13 (MABIT_MINA_2): 3 pilar/hari + nafar" })
h.activate("JumrahThrow", { player = player, mode = "three_pillars", config = { throwsPerPillar = 7, hitChance = 1 } })

local function throwDay(label)
	-- Uji urutan: lempar Aqabah sebelum Ula/Wustha → ditolak.
	throw("Aqabah")
	for _, name in ipairs({ "Ula", "Wustha", "Aqabah" }) do
		for _ = 1, 7 do throw(name) end
	end
	h.event("note", { text = label .. " selesai → hari sekarang = " .. tostring(jumrah.currentDay()) })
end

throwDay("Hari 11")
throwDay("Hari 12") -- setelah ini menunggu pilihan nafar

h.event("note", { text = "Menunggu nafar? isDone=" .. tostring(h.isDone()) .. " (harus false)" })
jumrah.chooseNafar("tsani")
h.event("note", { text = "Pilih NAFAR TSANI → hari = " .. tostring(jumrah.currentDay()) })

throwDay("Hari 13")
h.heartbeat(0.1)
h.event("note", { text = "Seluruh jumrah selesai? isDone=" .. tostring(h.isDone()) })
h.deactivate()
