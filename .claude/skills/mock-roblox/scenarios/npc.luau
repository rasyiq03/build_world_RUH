--!nocheck
-- Skenario NPC (Devi/Nabil) — uji fondasi NpcFramework + Dialog + behavior. Verifikasi:
--   A. Dialog engine berpilihan: validate / node / choose (pure, branching).
--   B. Askar: patroli bergerak; saat pemain dekat → BERHENTI + near=true; talk tak error.
--   C. PetugasOB: patroli bergerak (ambient).
-- NpcFramework di-INJECT ke NPC via ctx.framework (DI). Global: `h`, `Vector3`, `meta`.

meta("mechanism", "NPC: NpcFramework + Dialog + Askar/OB")
meta("title", "NPC fondasi: dialog berpilihan, patroli, deteksi kedekatan")

local NpcFramework = h.require("NpcFramework")
local Dialog = h.require("Dialog")
local Askar = h.require("Askar")
local OB = h.require("PetugasOB")

----------------------------------------------------------------------------------------------------
-- BAGIAN A — Dialog engine (pure, headless).
----------------------------------------------------------------------------------------------------
local tree = {
	speaker = "Test", start = "root",
	nodes = {
		root = { text = "Halo", choices = { { text = "Info", to = "info" }, { text = "Tutup", to = "close" } } },
		info = { text = "Ini info", choices = { { text = "Kembali", to = "root" } } },
	},
}
local okV, errV = Dialog.validate(tree)
h.event("note", { text = "Dialog valid? " .. tostring(okV) .. (errV and (" ("..errV..")") or "") })
h.event("note", { text = "node start = '" .. tostring(Dialog.node(tree).text) .. "'" })
h.event("note", { text = "choose(root,1) → '" .. tostring(Dialog.choose(tree, "root", 1)) .. "' (harus info)" })
h.event("note", { text = "choose(root,2) → '" .. tostring(Dialog.choose(tree, "root", 2)) .. "' (harus close)" })
local badOk, badErr = Dialog.validate({ start = "x", nodes = { y = { text = "z" } } })
h.event("note", { text = "Pohon rusak ditolak? ok=" .. tostring(badOk) .. " (" .. tostring(badErr) .. ")" })

----------------------------------------------------------------------------------------------------
-- BAGIAN B — Askar: patroli + deteksi kedekatan.
----------------------------------------------------------------------------------------------------
local player = h.spawnPlayer("Tester")
player.Character.HumanoidRootPart.Position = Vector3.new(1000, 0, 1000) -- jauh dulu

local wps = { Vector3.new(0, 0, 0), Vector3.new(60, 0, 0) }
local askar = Askar.spawn({
	framework = NpcFramework,
	waypoints = wps,
	radius = 16,
	speed = 7,
	getPlayers = function() return { player } end,
})
local function askarX() return NpcFramework and askar.PrimaryPart.Position.X end
h.event("note", { text = "Askar mulai X=" .. string.format("%.1f", askarX()) })

-- Pemain jauh → Askar patroli (X bertambah menuju 60).
for _ = 1, 30 do
	h.heartbeat(0.2)
	Askar.update(askar, 0.2)
end
local movedX = askarX()
h.event("note", { text = "Setelah 30 langkah patroli (pemain jauh): X=" .. string.format("%.1f", movedX) .. " near=" .. tostring(Askar.isNearPlayer(askar)) })

-- Pemain mendekat ke posisi Askar → Askar berhenti & near=true.
player.Character.HumanoidRootPart.Position = Vector3.new(movedX + 4, 0, 0)
Askar.update(askar, 0.2) -- satu update utk deteksi
local nearX = askarX()
h.event("note", { text = "Pemain dekat → near=" .. tostring(Askar.isNearPlayer(askar)) .. " (harus true)" })
for _ = 1, 10 do
	h.heartbeat(0.2)
	Askar.update(askar, 0.2)
end
local afterNearX = askarX()
h.event("note", { text = "Saat pemain dekat, Askar BERHENTI? ΔX=" .. string.format("%.2f", afterNearX - nearX) .. " (harus ~0)" })

-- Talk tak error (Dialog.open via remote pcall headless).
local okTalk = pcall(function() NpcFramework.talk(askar, player) end)
h.event("note", { text = "Askar.talk tak error? " .. tostring(okTalk) })

----------------------------------------------------------------------------------------------------
-- BAGIAN C — PetugasOB patroli ambient.
----------------------------------------------------------------------------------------------------
local ob = OB.spawn({ framework = NpcFramework, waypoints = { Vector3.new(0, 0, 0), Vector3.new(0, 0, 40) }, speed = 5 })
local obZ0 = ob.PrimaryPart.Position.Z
for _ = 1, 20 do
	h.heartbeat(0.2)
	OB.update(ob, 0.2)
end
local obZ1 = ob.PrimaryPart.Position.Z
h.event("note", { text = "OB patroli: Z " .. string.format("%.1f→%.1f", obZ0, obZ1) .. " (harus bergerak)" })

----------------------------------------------------------------------------------------------------
-- BAGIAN D — Roster + Spawner (roster→spawn→updateAll) end-to-end.
----------------------------------------------------------------------------------------------------
local NpcRoster = h.require("NpcRoster")
local NpcSpawner = h.require("NpcSpawner")
local modules = {
	Askar = Askar, PetugasOB = OB,
	JamaahNegara = h.require("JamaahNegara"),
	JamaahTawaf = h.require("JamaahTawaf"),
	PendorongKursiRoda = h.require("PendorongKursiRoda"),
	PetugasMedis = h.require("PetugasMedis"),
	TNI = h.require("TNI"),
}

local rMakkah = NpcRoster.forPlace("Makkah")
h.event("note", { text = "Roster Makkah: " .. #rMakkah .. " spek (Askar/OB/KursiRoda/JamaahTawaf×12)" })
h.event("note", { text = "Roster Miqat_BirAli: " .. #NpcRoster.forPlace("Miqat_BirAli") .. " · Arafah: " .. #NpcRoster.forPlace("Arafah") })

local active = NpcSpawner.spawnRoster(rMakkah, {
	framework = NpcFramework,
	modules = modules,
	center = Vector3.new(100, 0, 100),
	getPlayers = function() return { player } end,
})
h.event("note", { text = "Makkah spawn: " .. #active .. " NPC aktif (harus 1+1+1+12 = 15)" })

for _ = 1, 40 do
	h.heartbeat(0.2)
	NpcSpawner.updateAll(active, 0.2)
end
-- Hitung jamaah tawaf yang sudah berputar (orbit jalan via updateAll).
local jt = modules.JamaahTawaf
local orbited = 0
for _, e in ipairs(active) do
	if e.module == jt and jt.angleOf(e.npc) ~= 0 then orbited += 1 end
end
h.event("note", { text = "Setelah updateAll: " .. orbited .. " JamaahTawaf berputar (harus 12)" })
