--!strict
-- PlaceContext.lua — penyedia ctx mekanisme PER-PLACE untuk ManasikRunner.buildContext.
-- Tiap place memetakan tahap→ctx yang dibutuhkan mekanismenya (mis. Arafah: zona kehadiran Wukuf).
-- Pemilik area = pemilik entri di sini (Arafah = Nabil, Makkah/Miqat = Devi, Mina = Praditama).
--
-- SRP: modul ini HANYA MERAKIT ctx. Pencarian/pembuatan objek dunia (Workspace) ada di
-- WorldProviders (aturan §8.3: turunkan dari dunia hasil build, bukan hardcode). PlaceContext
-- memanggil WorldProviders.* lalu menyusun tabel ctx.
--
-- PRODUSEN ctx. Bentuk tiap ctx HARUS sesuai kontrak tipe shared/Ctx.lua (Ctx.Tawaf, Ctx.Sai, …);
-- konsumen mechanisms/*.activate sudah bertipe Ctx.*. Anotasi tipe-return di sini = langkah lanjut
-- (perlu luau-analyze utk memvalidasi varians properti tabel) — sengaja dibiarkan `any` dulu.

local WorldProviders = require(script.Parent.WorldProviders)

-- Konfigurasi ctx (bukan objek dunia → tetap di sini).
local WUKUF_CONFIG = { wukufSeconds = 180 } -- dipercepat; sesuaikan ritme game.
local PEBBLE_TARGET = 7 -- kerikil yang perlu dipungut tiap pemain (hamparan tak-habis di WorldProviders)
local TAWAF_TARGET = 7
local SAI_TARGET = 7
-- Dam (hadyu) wajib pada Tamattu' & Qiran; Ifrad tanpa dam (lihat GAME_DESIGN §5.6).
local DAM_REQUIRED = { HajiTamattu = true, HajiQiran = true }

local PlaceContext = {}

-- Pembaca posisi pemain (untuk mekanisme berbasis posisi Devi: Tawaf/Sai). Dipanggil tiap Heartbeat
-- oleh mekanisme. Bukan objek dunia (player-spesifik) → helper ctx, tetap di sini.
local function makeGetPosition(player: Player): () -> Vector3
	return function(): Vector3
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		return (hrp and (hrp :: BasePart).Position) or Vector3.new(0, 0, 0)
	end
end

-- ── Muzdalifah (Nabil) ──
function PlaceContext.Muzdalifah(stage: any, _state: any, player: Player): any
	if stage.ritual == "PebbleCollect" then
		return {
			player = player,
			place = "Muzdalifah",
			pebbles = WorldProviders.muzdalifahPebbles(),
			config = { target = PEBBLE_TARGET },
		}
	end
	return { player = player, place = "Muzdalifah" }
end

-- ── Mina (Praditama) ──
function PlaceContext.Mina(stage: any, state: any, player: Player): any
	if stage.ritual == "JumrahThrow" then
		-- Mode dari tahap: hari 10 (JUMRAH_AQABAH) = hanya Aqabah; hari 11-13 (MABIT_MINA_2) = 3 pilar.
		local mode = (stage.id == "MABIT_MINA_2") and "three_pillars" or "aqabah_only"
		return {
			player = player,
			place = "Mina",
			mode = mode,
			pillars = WorldProviders.minaPillars(),
			config = { throwsPerPillar = 7 },
		}
	elseif stage.ritual == "Qurban" then
		return {
			player = player,
			place = "Mina",
			damRequired = DAM_REQUIRED[state and state.ibadahType] == true,
			station = WorldProviders.qurbanStation(),
		}
	end
	-- Mabit/Tahallul di Mina: ctx minimal (disempurnakan saat zona mabit / sub-lokasi tahallul jadi).
	return { player = player, place = "Mina" }
end

-- ── Makkah (Devi) ──
function PlaceContext.Makkah(stage: any, _state: any, player: Player): any
	local r = stage.ritual
	if r == "TawafCounter" then
		local marks = WorldProviders.makkahMarks()
		return {
			player = player,
			place = "Makkah",
			center = marks.Kabah.Position,
			getPosition = makeGetPosition(player),
			config = { target = TAWAF_TARGET, maxRadius = 60 },
		}
	elseif r == "SaiCounter" then
		local marks = WorldProviders.makkahMarks()
		return {
			player = player,
			place = "Makkah",
			shafa = marks.Shafa,
			marwah = marks.Marwah,
			getPosition = makeGetPosition(player),
			config = { target = SAI_TARGET, reachRadius = 12 },
		}
	elseif r == "Tahallul" then
		-- Di Makkah hanya tahallul UMRAH (tahallul awal haji = Mina). viaUI → tunggu tombol "Cukur".
		return { player = player, place = "Makkah", mode = "umrah", viaUI = true }
	elseif r == "IhramHaji" then
		-- Niat haji 8 Dzulhijjah (Tamattu', setelah tahallul umrah). station nil → langsung.
		return { player = player, place = "Makkah" }
	end
	return { player = player, place = "Makkah" }
end

-- ── Miqat (Devi) — generik kelima place miqat. `state` membawa ibadahType (niat) & chosenMiqat. ──
function PlaceContext.Miqat(stage: any, state: any, player: Player): any
	local r = stage.ritual
	local placeName = (state and state.chosenMiqat) or "Miqat"
	if r == "IhramChange" then
		return { player = player, place = placeName, ibadahType = state and state.ibadahType }
	elseif r == "BusRide" then
		return { player = player, place = placeName, busPart = WorldProviders.miqatBus(), destinationLabel = "Makkah" }
	end
	return { player = player, place = placeName }
end

-- ── Arafah (Nabil) ──
function PlaceContext.Arafah(stage: any, _state: any, player: Player): any
	if stage.ritual == "Wukuf" then
		return {
			player = player,
			place = "Arafah",
			zonePart = WorldProviders.arafahZone(),
			config = WUKUF_CONFIG,
			startPresent = true, -- pemain spawn/teleport masuk Arafah → dianggap hadir saat mulai.
		}
	end
	return { player = player, place = "Arafah" }
end

return PlaceContext
