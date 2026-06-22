--!nocheck
-- Skenario IhramChange + IhramRules (Devi). Verifikasi:
--   (A) niat ditolak sebelum kenakan kain; wear→niat → isDone (per jenis ibadah).
--   (B) IhramRules: aksi terlarang ditolak & dicatat (dam); larangan khusus gender; di luar ihram bebas.
-- Global: `h`, `Vector3`, `meta`. Kedua modul diuji via h.mech (logika, bukan spine).

meta("mechanism", "IhramChange")
meta("title", "Ihram: kostum + niat per jenis, lalu penegakan larangan")

local player = h.spawnPlayer("Devi")
local ihram = h.mech("IhramChange")
local rules = h.mech("IhramRules")

----------------------------------------------------------------------------------------------------
-- BAGIAN A — IhramChange (Qiran: niat haji+umrah).
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN A — IhramChange (HajiQiran)" })
h.activate("IhramChange", { player = player, ibadahType = "HajiQiran" })

ihram.makeNiat() -- sebelum kenakan kain → ditolak
h.event("note", { text = "Niat sebelum kain → isDone=" .. tostring(h.isDone()) .. " (harus false)" })

ihram.wearIhram()
h.event("note", { text = "Setelah kenakan kain: isWorn=" .. tostring(ihram.isWorn()) })
ihram.makeNiat()
h.event("note", { text = "Setelah niat: isDone=" .. tostring(h.isDone()) .. " (harus true)" })
h.deactivate()

----------------------------------------------------------------------------------------------------
-- BAGIAN B — IhramRules (pria masuk ihram).
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN B — IhramRules (pria)" })

-- Sebelum activate: belum ihram → semua aksi bebas.
local r0 = rules.attempt("wewangian")
h.event("note", { text = "Sebelum ihram, wewangian allowed=" .. tostring(r0.allowed) .. " (harus true)" })

rules.activate({ player = player, gender = "male" })

local r1 = rules.attempt("tutup_kepala") -- larangan pria
h.event("violation", { text = "tutup_kepala allowed=" .. tostring(r1.allowed) .. " dam=" .. tostring(r1.dam) })
local r2 = rules.attempt("wewangian")
h.event("violation", { text = "wewangian allowed=" .. tostring(r2.allowed) .. " dam=" .. tostring(r2.dam) })
local r3 = rules.attempt("tutup_wajah") -- khusus wanita → pria TIDAK terkena
h.event("note", { text = "tutup_wajah (pria) allowed=" .. tostring(r3.allowed) .. " (harus true, khusus wanita)" })
local r4 = rules.attempt("jima")
h.event("violation", { text = "jima allowed=" .. tostring(r4.allowed) .. " severity=" .. tostring(r4.severity) })
local r5 = rules.attempt("makan") -- bukan larangan
h.event("note", { text = "makan allowed=" .. tostring(r5.allowed) .. " (harus true)" })

h.event("note", { text = "Total pelanggaran=" .. rules.violationCount() .. " butuh dam=" .. rules.damCount() })

rules.deactivate()
local r6 = rules.attempt("wewangian")
h.event("note", { text = "Setelah tahallul (deactivate), wewangian allowed=" .. tostring(r6.allowed) .. " (harus true)" })

----------------------------------------------------------------------------------------------------
-- BAGIAN C — integrasi tahallul (kontrak atribut "TahallulState" milik Tahallul/Nabil).
--   IHRAM → semua terlarang · AWAL → halal kecuali jima · COMPLETE → semua halal.
----------------------------------------------------------------------------------------------------
h.event("note", { text = "BAGIAN C — pelonggaran sesuai TahallulState" })
rules.activate({ player = player, gender = "male" })

player:SetAttribute("TahallulState", "AWAL")
local a1 = rules.attempt("wewangian")
h.event("note", { text = "AWAL: wewangian allowed=" .. tostring(a1.allowed) .. " (harus true, sudah halal)" })
local a2 = rules.attempt("jima")
h.event("violation", { text = "AWAL: jima allowed=" .. tostring(a2.allowed) .. " (harus false, satu-satunya tersisa)" })

player:SetAttribute("TahallulState", "COMPLETE")
local c1 = rules.attempt("jima")
h.event("note", { text = "COMPLETE: jima allowed=" .. tostring(c1.allowed) .. " (harus true, tahallul tsani)" })
rules.deactivate()
