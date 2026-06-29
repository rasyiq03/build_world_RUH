--!strict
-- TimeOfDay.server.lua — DRIVER runtime ManasikClock per place (SYSTEMS_DESIGN §1). Configure +
-- start jam kontinu (Lighting.ClockTime ikut otomatis di Clock.tick) + adzan via onPrayer→SoundManager.
-- Jam awal per zona mencerminkan fase khas ritualnya (wukuf=dzuhur, mabit=malam, dst). Hari manasik
-- nyata bisa dibawa lintas-place via TeleportData (refinemen; kini start per-zona).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clock = require(Shared:WaitForChild("ManasikClock"))
local SoundManager = require(Shared:WaitForChild("SoundManager"))
local Teleport = require(Shared:WaitForChild("Teleport"))

-- Jam awal per place (hari Dzulhijjah + jam). Sesuaikan ritme game.
local START: { [string]: { day: number, hour: number } } = {
	Makkah = { day = 8, hour = 9.0 },
	Arafah = { day = 9, hour = 12.0 }, -- wukuf dzuhur
	Muzdalifah = { day = 9, hour = 21.0 }, -- mabit malam
	Mina = { day = 10, hour = 7.0 }, -- pagi jumrah
	Lobby = { day = 8, hour = 8.0 },
}

local place = Teleport.resolvePlaceName("Makkah")
local s = START[place] or (place:sub(1, 6) == "Miqat_" and { day = 8, hour = 6.5 }) or { day = 8, hour = 7.0 }
Clock.configure({ dayLengthSeconds = 1200, startDay = s.day, startHour = s.hour }) -- 1 hari = 20 menit

-- Adzan: isi rbxassetid suara adzan; kosong = hanya log (aset = kerja Studio).
local ADZAN_ID = ""
Clock.onPrayer(function(name: string, day: number)
	if ADZAN_ID ~= "" then
		SoundManager.play(ADZAN_ID)
	end
	workspace:SetAttribute("ManasikDay", day) -- HUD client baca hari berjalan
	print(("[TimeOfDay] Adzan %s (hari %d)."):format(name, day))
end)

workspace:SetAttribute("ManasikDay", Clock.now().day)
Clock.start()
print(("[TimeOfDay] '%s' — jam mulai: %s (1 hari = 20 menit)."):format(place, Clock.label()))
