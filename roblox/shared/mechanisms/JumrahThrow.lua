--!strict
-- JumrahThrow.lua — melempar Jumrah di Mina. Pemilik: Praditama. Kontrak: mechanisms/_TEMPLATE.lua.
--
-- Dua MODE (dipilih PlaceContext.Mina dari tahap Flows):
--   • "aqabah_only"  (hari 10, tahap JUMRAH_AQABAH): hanya Jumrah Aqabah, 7 lemparan → selesai.
--   • "three_pillars"(hari 11-13, tahap MABIT_MINA_2): tiap hari lempar 3 pilar BERURUTAN
--       Ula → Wustha → Aqabah, 7 lemparan/pilar (21/hari). Setelah hari 12 pemain memilih:
--         - NAFAR AWWAL  → tinggalkan Mina, lewati hari 13 (selesai).
--         - NAFAR TSANI  → tetap, lempar lagi hari 13 (lalu selesai).
--
-- Interaksi (proximity + klik): tiap pilar punya ProximityPrompt yang memanggil M.throw(nama).
-- Umpan balik kena/meleset per lemparan; counter per pilar per hari. Hit ditentukan peluang
-- (ctx.config.hitChance) — meleset = ulangi (tidak menambah hitungan).
--
-- ctx (disusun server/PlaceContext.Mina):
--   ctx.player  : Player
--   ctx.mode    : "aqabah_only" | "three_pillars"   (default "aqabah_only")
--   ctx.pillars : { [name]: BasePart }?   part target tiap jumrah (untuk ProximityPrompt).
--   ctx.config  : {
--       throwsPerPillar : number?  default 7
--       hitChance       : number?  default 0.8 (1 = selalu kena, untuk uji deterministik)
--       nafar           : string?  "awwal"|"tsani" pra-pilih (lewati prompt; default tunggu pemain)
--   }?

local Players = game:GetService("Players")
local Notify = require(script.Parent.Parent.Notify)
local Kit = require(script.Parent._MechanismKit)

local Ctx = require(script.Parent.Parent.Ctx)

local M = {}
M.id = "JumrahThrow"

local DEFAULT_THROWS = 7
local DEFAULT_HIT_CHANCE = 0.8

-- Urutan pilar per mode (sunnah hari 11-13: Ula dulu, lalu Wustha, lalu Aqabah).
local SEQ_AQABAH = { "Aqabah" }
local SEQ_THREE = { "Ula", "Wustha", "Aqabah" }

local PILLAR_LABEL = {
	Ula = "Jumrah Ula",
	Wustha = "Jumrah Wustha",
	Aqabah = "Jumrah Aqabah",
}

-- state
local active = false
local done = false
local mode = "aqabah_only"
local player: Player? = nil
local throwsTarget = DEFAULT_THROWS
local hitChance = DEFAULT_HIT_CHANCE
local seq: { string } = SEQ_AQABAH
local seqIdx = 1 -- pilar yang sedang aktif dalam urutan hari ini
local counts: { [string]: number } = {}
local day = 10 -- 10 utk aqabah_only; 11..13 utk three_pillars
local nafarChoice: string? = nil
local awaitingNafar = false
local conns: { any } = {}

local function notify(msg: string)
	if player then
		Notify.toPlayer(player, msg)
	end
end

local function resetDay()
	seqIdx = 1
	counts = { Ula = 0, Wustha = 0, Aqabah = 0 }
end

-- Dipanggil saat seluruh pilar hari ini tuntas. Mengatur transisi hari / nafar / selesai.
local function onDayComplete()
	if mode == "aqabah_only" then
		done = true
		notify("Jumrah Aqabah selesai (7 lemparan). Lanjut tahallul awal.")
		return
	end

	if day == 11 then
		day = 12
		resetDay()
		notify("Hari 11 selesai. Hari 12: lempar 3 jumrah lagi (Ula → Wustha → Aqabah).")
	elseif day == 12 then
		if nafarChoice == "awwal" then
			done = true
			notify("Nafar awwal: meninggalkan Mina pada 12 Dzulhijjah. Jumrah selesai.")
		elseif nafarChoice == "tsani" then
			day = 13
			resetDay()
			notify("Nafar tsani: tetap di Mina. Hari 13: lempar 3 jumrah terakhir.")
		else
			awaitingNafar = true
			notify("Hari 12 selesai. Pilih NAFAR: AWWAL (pulang sekarang) atau TSANI (tinggal s.d. 13).")
		end
	elseif day == 13 then
		done = true
		notify("Hari 13 selesai. Seluruh Jumrah tuntas (nafar tsani). Semoga mabrur.")
	end
end

-- API publik: pemain melempar ke pilar `name` (dipanggil ProximityPrompt / skenario uji).
function M.throw(name: string)
	if not active or done or awaitingNafar then
		return
	end
	if PILLAR_LABEL[name] == nil then
		notify("Pilar tidak dikenal: " .. tostring(name))
		return
	end

	local expected = seq[seqIdx]
	if name ~= expected then
		if mode == "three_pillars" then
			notify(("Lempar berurutan — selesaikan %s dulu (sekarang giliran %s)."):format(
				PILLAR_LABEL[expected], PILLAR_LABEL[expected]
			))
		else
			notify(("Hari ini hanya %s yang dilempar."):format(PILLAR_LABEL[expected]))
		end
		return
	end

	-- Lemparan: kena atau meleset.
	if math.random() <= hitChance then
		counts[name] += 1
		notify(("Kena! %s %d/%d."):format(PILLAR_LABEL[name], counts[name], throwsTarget))
		if counts[name] >= throwsTarget then
			notify(("%s selesai (%d lemparan)."):format(PILLAR_LABEL[name], throwsTarget))
			seqIdx += 1
			if seqIdx > #seq then
				onDayComplete()
			else
				notify(("Lanjut ke %s."):format(PILLAR_LABEL[seq[seqIdx]]))
			end
		end
	else
		notify(("Meleset — kerikil tidak masuk. Ulangi lemparan ke %s."):format(PILLAR_LABEL[name]))
	end
end

-- API publik: pilihan nafar setelah hari 12 (dipanggil UI / skenario).
function M.chooseNafar(choice: string)
	if choice ~= "awwal" and choice ~= "tsani" then
		return
	end
	nafarChoice = choice
	if awaitingNafar then
		awaitingNafar = false
		if choice == "awwal" then
			done = true
			notify("Nafar awwal: meninggalkan Mina pada 12 Dzulhijjah. Jumrah selesai.")
		else
			day = 13
			resetDay()
			notify("Nafar tsani: tetap di Mina. Hari 13: lempar 3 jumrah terakhir.")
		end
	end
end

-- Hitungan lemparan pilar hari ini (untuk debug/uji).
function M.dayCounts(): { [string]: number }
	return counts
end

function M.currentDay(): number
	return day
end

function M.init() end

function M.activate(ctx: Ctx.Jumrah?)
	active = true
	done = false
	awaitingNafar = false
	player = ctx and ctx.player or nil
	mode = (ctx and ctx.mode) or "aqabah_only"
	local config = ctx and ctx.config
	throwsTarget = (config and config.throwsPerPillar) or DEFAULT_THROWS
	hitChance = (config and config.hitChance) or DEFAULT_HIT_CHANCE
	nafarChoice = (config and config.nafar) or nil

	if mode == "three_pillars" then
		seq = SEQ_THREE
		day = 11
	else
		seq = SEQ_AQABAH
		day = 10
	end
	resetDay()

	-- Pasang ProximityPrompt di tiap pilar (game asli). Headless: ctx.pillars boleh nil — logika
	-- tetap diuji via M.throw. Pembuatan prompt dijaga pcall agar aman bila kelas tak tersedia.
	local pillars = ctx and ctx.pillars
	if not pillars then
		warn("[JumrahThrow] tanpa ctx.pillars — tanpa ProximityPrompt (logika tetap via M.throw).")
	else
		for name, part in pairs(pillars) do
			if PILLAR_LABEL[name] == nil then
				warn("[JumrahThrow] nama pilar tak dikenal di ctx.pillars: " .. tostring(name))
			else
				conns[#conns + 1] = Kit.attachPrompt(part, "Lempar " .. PILLAR_LABEL[name], PILLAR_LABEL[name], 18, function(plr)
					if not player or plr == player then
						M.throw(name)
					end
				end)
			end
		end
	end

	if mode == "three_pillars" then
		notify("Mina hari 11-13: lempar 3 jumrah/hari BERURUTAN — Ula → Wustha → Aqabah (7 tiap pilar).")
	else
		notify("Mina hari 10: lempar Jumrah Aqabah 7 kali.")
	end
end

function M.deactivate()
	active = false
	awaitingNafar = false
	Kit.disconnectAll(conns)
end

function M.isDone(): boolean
	return done
end

return M
