--!nocheck
-- Skenario ComfortStations (Praditama) — amenitas ambient Mina. Bukan ritual alur, jadi di-uji
-- via h.require (bukan MechanismRegistry). ProximityPrompt tak ada headless → panggil handle.use.
-- Global: `h`, `Vector3`, `meta`.

meta("mechanism", "ComfortStations")
meta("title", "Amenitas Mina: Zamzam (berulang), Kursi Roda (toggle), Area Istirahat")

local ComfortStations = h.require("ComfortStations")
local player = h.spawnPlayer("Praditama")

local zamzamPart = h.newZone({ name = "DispenserZamzam", center = Vector3.new(0, 0, 0), size = Vector3.new(4, 4, 4) })
local wheelPart = h.newZone({ name = "PosKursiRoda", center = Vector3.new(20, 0, 0), size = Vector3.new(4, 4, 4) })
local restPart = h.newZone({ name = "TendaIstirahat", center = Vector3.new(40, 0, 0), size = Vector3.new(8, 4, 8) })

local zamzam = ComfortStations.zamzam(zamzamPart)
local wheelchair = ComfortStations.wheelchair(wheelPart)
local rest = ComfortStations.restArea(restPart)

-- ZAMZAM: minum 2x (berulang) → ZamzamDrinks harus 2.
h.event("note", { text = "Zamzam: minum dua kali" })
zamzam.use(player)
zamzam.use(player)
h.event("note", { text = "ZamzamDrinks = " .. tostring(player:GetAttribute("ZamzamDrinks")) .. " (harus 2)" })

-- KURSI RODA: toggle ambil → kembalikan.
h.event("note", { text = "Kursi roda: ambil lalu kembalikan (toggle)" })
wheelchair.use(player)
h.event("note", { text = "UsingWheelchair = " .. tostring(player:GetAttribute("UsingWheelchair")) .. " (harus true)" })
wheelchair.use(player)
h.event("note", { text = "UsingWheelchair = " .. tostring(player:GetAttribute("UsingWheelchair")) .. " (harus false)" })

-- AREA ISTIRAHAT: pulih stamina.
h.event("note", { text = "Area istirahat: beristirahat" })
rest.use(player)
h.event("note", { text = "Stamina = " .. tostring(player:GetAttribute("Stamina")) .. ", Rested = " .. tostring(player:GetAttribute("Rested")) })

zamzam.destroy()
wheelchair.destroy()
rest.destroy()
