--!nocheck
-- Skenario SISTEM (SYSTEMS_DESIGN) — fondasi ManasikClock + PlayerState. Verifikasi:
--   A. Clock: jam maju (tick), adzan terpicu saat melewati waktu salat, fase benar, TIME-SKIP
--      (advanceTo) + rollover hari.
--   B. PlayerState: default, set, kerikil, check() kekurangan→lengkap (lembut), inIhram, summary.
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "SISTEM: ManasikClock + PlayerState")
meta("title", "Fondasi waktu & state pemain")

local Clock = h.require("ManasikClock")
local PlayerState = h.require("PlayerState")

----------------------------------------------------------------------------------------------------
-- BAGIAN A — ManasikClock.
----------------------------------------------------------------------------------------------------
Clock.reset(8, 11.0)
Clock.configure({ dayLengthSeconds = 24 }) -- 1 game-jam per detik (uji)
local adzan = {}
Clock.onPrayer(function(name, day) adzan[#adzan + 1] = name .. "@" .. day end)

Clock.tick(1) -- 11→12: lewati Dzuhur
h.event("note", { text = "Setelah tick ke jam " .. string.format("%.1f", Clock.now().hour) .. " fase=" .. Clock.phase() .. " adzan=" .. table.concat(adzan, ",") })
Clock.tick(3.5) -- 12→15.5: lewati Ashar
h.event("note", { text = "Jam " .. string.format("%.1f", Clock.now().hour) .. " adzan=" .. table.concat(adzan, ",") })

-- TIME-SKIP ke maghrib (18.25)
Clock.advanceTo(18.25)
h.event("note", { text = "Time-skip→maghrib: jam=" .. string.format("%.2f", Clock.now().hour) .. " fase=" .. Clock.phase() .. " adzan=" .. table.concat(adzan, ",") })

-- Rollover hari: malam hari-9 → subuh hari-10
Clock.reset(9, 22.0)
adzan = {}
Clock.onPrayer(function(name, day) adzan[#adzan + 1] = name .. "@" .. day end)
Clock.advanceTo(5.0)
h.event("note", { text = "Mabit time-skip 22:00→subuh: " .. Clock.label() .. " adzan=" .. table.concat(adzan, ",") .. " (harus hari 10, Subuh)" })

----------------------------------------------------------------------------------------------------
-- BAGIAN B — PlayerState (lembut).
----------------------------------------------------------------------------------------------------
local p = h.spawnPlayer("Jamaah")
local c0 = PlayerState.check(p, "IHRAM")
h.event("note", { text = "Awal, check IHRAM: ok=" .. tostring(c0.ok) .. " kurang=[" .. table.concat(c0.missing, ", ") .. "]" })

PlayerState.set(p, "ihramWorn", true)
PlayerState.set(p, "niat", true)
local c1 = PlayerState.check(p, "IHRAM")
h.event("note", { text = "Setelah ihram+niat, check IHRAM: ok=" .. tostring(c1.ok) .. " · inIhram=" .. tostring(PlayerState.inIhram(p)) })

PlayerState.incPebbles(p, 7)
local c2 = PlayerState.check(p, "JUMRAH_AQABAH")
h.event("note", { text = "Setelah 7 kerikil, check JUMRAH_AQABAH: ok=" .. tostring(c2.ok) })

p:SetAttribute("TahallulState", "COMPLETE")
h.event("note", { text = "Setelah tahallul COMPLETE: inIhram=" .. tostring(PlayerState.inIhram(p)) .. " (harus false)" })

PlayerState.addWarning(p, "keluar zona Arafah")
h.event("note", { text = "Status: " .. PlayerState.summary(p) })

----------------------------------------------------------------------------------------------------
-- BAGIAN C — Wukuf TIME-SKIP (capaian kehadiran + lompat jam ke maghrib).
----------------------------------------------------------------------------------------------------
Clock.reset(9, 13.0) -- dzuhur hari 9
local Wukuf = h.mech("Wukuf")
local pl2 = h.spawnPlayer("Haji")
h.activate("Wukuf", { player = pl2, config = { wukufSeconds = 180 }, startPresent = true, clock = Clock })
h.event("note", { text = "Wukuf sebelum skip: isDone=" .. tostring(h.isDone()) .. " jam=" .. string.format("%.1f", Clock.now().hour) })
Wukuf.timeSkip()
h.event("note", { text = "Wukuf SETELAH time-skip: isDone=" .. tostring(h.isDone()) .. " · " .. Clock.label() .. " (harus done + maghrib)" })
h.deactivate()

----------------------------------------------------------------------------------------------------
-- BAGIAN D — IhramChange MENULIS ke PlayerState (backbone equipment).
----------------------------------------------------------------------------------------------------
local pl3 = h.spawnPlayer("Umrah")
h.activate("IhramChange", { player = pl3, ibadahType = "Umrah", config = { auto = true } }) -- auto wear+niat
local s3 = PlayerState.get(pl3)
h.event("note", { text = "Setelah IhramChange(auto): PlayerState ihramWorn=" .. tostring(s3.ihramWorn) .. " niat=" .. tostring(s3.niat) .. " (harus true,true)" })
h.event("note", { text = "check IHRAM utk pl3: ok=" .. tostring(PlayerState.check(pl3, "IHRAM").ok) .. " (harus true)" })
h.deactivate()

----------------------------------------------------------------------------------------------------
-- BAGIAN E — GuideContent (data buku panduan).
----------------------------------------------------------------------------------------------------
local Guide = h.require("GuideContent")
local okG, errG = Guide.validate()
h.event("note", { text = "GuideContent valid? " .. tostring(okG) .. (errG and (" ("..errG..")") or "") })
h.event("note", { text = "forStage(IHRAM_UMRAH).title = '" .. Guide.forStage("IHRAM_UMRAH").title .. "'" })
h.event("note", { text = "forStage(WUKUF).title = '" .. Guide.forStage("WUKUF").title .. "' · family=" .. Guide.family("WUKUF") })
h.event("note", { text = "forStage(TAWAF_WADA) family=" .. Guide.family("TAWAF_WADA") .. " · forStage(nil).title='" .. Guide.forStage(nil).title .. "'" })

----------------------------------------------------------------------------------------------------
-- BAGIAN F — Wardrobe (ganti baju, gating lembut).
----------------------------------------------------------------------------------------------------
local Wardrobe = h.require("Wardrobe")
local pw = h.spawnPlayer("GantiBaju")
h.event("note", { text = "Awal (belum ihram), canWear normal=" .. tostring(Wardrobe.canWear(pw, "normal")) .. " (true)" })

PlayerState.set(pw, "ihramWorn", true)
PlayerState.set(pw, "niat", true) -- kini dalam ihram (TahallulState IHRAM)
Wardrobe.apply(pw, "ihram")
h.event("note", { text = "Pakai ihram → current=" .. Wardrobe.current(pw) })
local okN, rN = Wardrobe.canWear(pw, "normal")
h.event("note", { text = "Saat ihram, canWear normal=" .. tostring(okN) .. " (false) — " .. tostring(rN) })
local applied = Wardrobe.apply(pw, "normal") -- harus ditolak
h.event("note", { text = "apply normal saat ihram → " .. tostring(applied) .. " (false), current tetap=" .. Wardrobe.current(pw) })

pw:SetAttribute("TahallulState", "COMPLETE")
Wardrobe.apply(pw, "normal")
h.event("note", { text = "Pasca tahallul COMPLETE → apply normal: current=" .. Wardrobe.current(pw) .. " (normal)" })

----------------------------------------------------------------------------------------------------
-- BAGIAN G — RitualAction dispatch (Registry.actionActive → metode mekanisme aktif).
----------------------------------------------------------------------------------------------------
local pA = h.spawnPlayer("Aksi")
h.activate("IhramChange", { player = pA, ibadahType = "Umrah" }) -- bukan auto: butuh aksi UI
h.event("note", { text = "IhramChange isDone awal=" .. tostring(h.isDone()) .. " (false)" })
h.registry.actionActive("wearIhram") -- simulasi tombol UI → RitualAction
h.registry.actionActive("makeNiat")
h.event("note", { text = "Setelah actionActive(wearIhram,makeNiat): isDone=" .. tostring(h.isDone()) .. " (harus true)" })
h.deactivate()

----------------------------------------------------------------------------------------------------
-- BAGIAN H — Tahallul via UI (viaUI: tunggu tombol cukur) vs default (auto).
----------------------------------------------------------------------------------------------------
local pT = h.spawnPlayer("Tahallul")
h.activate("Tahallul", { player = pT, mode = "umrah", viaUI = true }) -- tunggu tombol
h.event("note", { text = "viaUI: isDone sebelum cukur=" .. tostring(h.isDone()) .. " (false)" })
h.registry.actionActive("cukur") -- simulasi tombol UI
h.event("note", { text = "viaUI: setelah cukur isDone=" .. tostring(h.isDone()) .. " TahallulState=" .. tostring(pT:GetAttribute("TahallulState")) .. " (true, COMPLETE)" })
h.deactivate()

local pAuto = h.spawnPlayer("AutoTah")
h.activate("Tahallul", { player = pAuto, mode = "umrah" }) -- TANPA viaUI → auto (alur lama)
h.event("note", { text = "tanpa viaUI: isDone (auto)=" .. tostring(h.isDone()) .. " (harus true)" })
h.deactivate()
