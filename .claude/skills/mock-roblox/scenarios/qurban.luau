--!nocheck
-- Skenario Qurban (Praditama) via MechanismRegistry. Bagian A: Tamattu' (dam WAJIB) → pilih hewan
-- → proses sembelih (akumulasi Heartbeat) → selesai. Bagian B: Ifrad (TANPA dam) → langsung done.
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "Qurban")
meta("title", "Qurban/hadyu: Tamattu' (wajib dam) vs Ifrad (tanpa dam)")

local player = h.spawnPlayer("Praditama")
local qurban = h.mech("Qurban")
local station = h.newZone({ name = "TempatQurban", center = Vector3.new(0, 0, 0), size = Vector3.new(20, 4, 20) })

----------------------------------------------------------------------------------------------------
-- BAGIAN A — Haji Tamattu': dam wajib.
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN A — Tamattu' (damRequired=true)" })
h.activate("Qurban", { player = player, damRequired = true, station = station, config = { processSeconds = 4 } })
h.event("note", { text = "Belum disembelih → isDone=" .. tostring(h.isDone()) .. " (harus false)" })

-- Hewan tak dikenal → ditolak.
qurban.beginSacrifice("ayam")
-- Pilih sapi (hadyu berjamaah 1/7), proses 4 detik.
qurban.beginSacrifice("sapi")
h.advance(5, 1) -- majukan jam virtual melewati durasi proses
h.event("note", { text = "Setelah proses → isDone=" .. tostring(h.isDone()) .. " (harus true)" })
h.deactivate()

----------------------------------------------------------------------------------------------------
-- BAGIAN B — Haji Ifrad: tanpa dam → langsung selesai.
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN B — Ifrad (damRequired=false)" })
h.activate("Qurban", { player = player, damRequired = false, station = station })
h.heartbeat(0.1)
h.event("note", { text = "Ifrad tanpa dam → isDone=" .. tostring(h.isDone()) .. " (harus true)" })
h.deactivate()
