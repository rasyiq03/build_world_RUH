--!strict
-- ManasikClock.lua — JAM dunia kontinu terkompresi (SYSTEMS_DESIGN §1). Jantung waktu: gerakkan
-- Lighting.ClockTime, picu adzan (5 waktu) via callback, suplai jam HUD. Mendukung TIME-SKIP
-- (advanceTo) untuk ritual-tunggu — pemain boleh ikut waktu nyata-terkompresi atau lompat.
--
-- Headless: jam VIRTUAL — panggil Clock.tick(realDt) manual (skenario). Real game: Clock.start()
-- menyambung RunService.Heartbeat. Lighting & RunService dibungkus pcall (logika tetap teruji).
--
-- KONTRAK BERSAMA. Tunable: dayLengthSeconds (detik nyata per 24 jam game).

local ManasikClock = {}

-- 5 waktu salat (jam desimal) — pemicu adzan & penanda fase.
local PRAYERS = {
	{ name = "Subuh", h = 5.0 },
	{ name = "Dzuhur", h = 12.0 },
	{ name = "Ashar", h = 15.5 },
	{ name = "Maghrib", h = 18.25 },
	{ name = "Isya", h = 19.5 },
}
ManasikClock.PRAYERS = PRAYERS

-- state
local day = 8 -- hari Dzulhijjah (default mulai 8)
local hour = 6.0 -- jam desimal 0..24
local hoursPerSec = 24 / 1200 -- default: 1 hari = 1200 dtk (20 mnt)
local running = false
local heartbeatConn: any = nil
local prayerCbs: { any } = {}

local function applyLighting()
	pcall(function()
		game:GetService("Lighting").ClockTime = hour
	end)
end

-- Fase waktu dari jam (untuk HUD, lighting mood, pencocokan ritual).
function ManasikClock.phaseFor(h: number): string
	if h < 4.5 or h >= 20.5 then return "malam"
	elseif h < 6.5 then return "subuh"
	elseif h < 11.5 then return "pagi"
	elseif h < 15.0 then return "dzuhur"
	elseif h < 17.5 then return "ashar"
	elseif h < 19.0 then return "maghrib"
	else return "isya" end
end

-- Picu adzan untuk tiap waktu salat yang DILEWATI antara oldAbs..newAbs (jam absolut = day*24+hour).
local function fireCrossings(oldAbs: number, newAbs: number)
	for _, p in ipairs(PRAYERS) do
		for d = math.floor(oldAbs / 24), math.floor(newAbs / 24) do
			local pt = d * 24 + p.h
			if pt > oldAbs and pt <= newAbs then
				for _, cb in ipairs(prayerCbs) do
					pcall(cb, p.name, d)
				end
			end
		end
	end
end

-- Maju `deltaHours` jam-game (internal). Picu adzan yang terlewati + update Lighting.
local function advance(deltaHours: number)
	if deltaHours <= 0 then return end
	local oldAbs = day * 24 + hour
	local newAbs = oldAbs + deltaHours
	fireCrossings(oldAbs, newAbs)
	day = math.floor(newAbs / 24)
	hour = newAbs - day * 24
	applyLighting()
end

-- ── API publik ──
function ManasikClock.configure(opts: any?)
	opts = opts or {}
	if opts.dayLengthSeconds and opts.dayLengthSeconds > 0 then
		hoursPerSec = 24 / opts.dayLengthSeconds
	end
	if opts.startDay then day = opts.startDay end
	if opts.startHour then hour = opts.startHour end
	applyLighting()
end

-- Maju jam berdasar waktu NYATA (dt detik). Dipanggil tiap Heartbeat (atau manual headless).
function ManasikClock.tick(realDt: number)
	advance(realDt * hoursPerSec)
end

-- TIME-SKIP: lompat ke `targetHour` berikutnya (boleh menyeberang hari). Memicu adzan yang terlewati.
-- Dipakai ritual-tunggu (mabit→subuh, wukuf→maghrib) atas pilihan pemain.
function ManasikClock.advanceTo(targetHour: number)
	local delta = targetHour - hour
	if delta <= 0 then delta += 24 end
	advance(delta)
end

function ManasikClock.now(): any
	return { day = day, hour = hour, phase = ManasikClock.phaseFor(hour) }
end

function ManasikClock.phase(): string
	return ManasikClock.phaseFor(hour)
end

-- Format jam HUD: "9 Dzulhijjah · 18:15 (maghrib)".
function ManasikClock.label(): string
	local hh = math.floor(hour)
	local mm = math.floor((hour - hh) * 60)
	return ("%d Dzulhijjah · %02d:%02d (%s)"):format(day, hh, mm, ManasikClock.phaseFor(hour))
end

-- Daftar callback adzan: cb(prayerName, day).
function ManasikClock.onPrayer(cb: any)
	prayerCbs[#prayerCbs + 1] = cb
end

-- Jalankan jam otomatis (real game). Headless: jangan dipakai; pakai tick() manual.
function ManasikClock.start()
	if running then return end
	running = true
	pcall(function()
		local RunService = game:GetService("RunService")
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			ManasikClock.tick(dt)
		end)
	end)
end

function ManasikClock.stop()
	running = false
	if heartbeatConn then
		pcall(function() heartbeatConn:Disconnect() end)
		heartbeatConn = nil
	end
end

-- Reset (uji).
function ManasikClock.reset(d: number?, h: number?)
	day = d or 8
	hour = h or 6.0
	prayerCbs = {}
end

return ManasikClock
