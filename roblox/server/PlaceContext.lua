--!strict
-- PlaceContext.lua — penyedia ctx mekanisme PER-PLACE untuk ManasikRunner.buildContext.
-- Tiap place memetakan tahap→ctx yang dibutuhkan mekanismenya (mis. Arafah: zona kehadiran
-- Wukuf). Diturunkan dari DUNIA HASIL BUILD (Workspace), bukan hardcode / bukan baca output/*.json
-- saat runtime (aturan §8.3). Pemilik area = pemilik entri di sini (Arafah = Nabil).

local WUKUF_CONFIG = { wukufSeconds = 180 } -- dipercepat; sesuaikan ritme game.
local ZONE_HEIGHT = 4000

local PlaceContext = {}

-- Zona kehadiran Arafah: AABB X/Z dari Workspace.C_Arafah.BatasArafah (build_arafah.lua). Di-cache.
local arafahZone: BasePart? = nil
local function getArafahZone(): BasePart?
	if arafahZone and arafahZone.Parent then
		return arafahZone
	end
	local cArafah = workspace:FindFirstChild("C_Arafah")
	local batas = cArafah and cArafah:FindFirstChild("BatasArafah")
	if not batas then
		warn("[PlaceContext] Workspace.C_Arafah.BatasArafah tak ada — jalankan build_arafah.lua. Wukuf tanpa gating zona.")
		return nil
	end
	local minX, maxX, minZ, maxZ, minY, maxY
	for _, d in ipairs(batas:GetDescendants()) do
		if d:IsA("BasePart") then
			local p = d.Position
			minX = math.min(minX or p.X, p.X)
			maxX = math.max(maxX or p.X, p.X)
			minZ = math.min(minZ or p.Z, p.Z)
			maxZ = math.max(maxZ or p.Z, p.Z)
			minY = math.min(minY or p.Y, p.Y)
			maxY = math.max(maxY or p.Y, p.Y)
		end
	end
	if not minX then
		return nil
	end
	local zone = Instance.new("Part")
	zone.Name = "ZonaArafah"
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.Transparency = 1
	zone.Size = Vector3.new((maxX - minX) + 200, ZONE_HEIGHT, (maxZ - minZ) + 200)
	zone.Position = Vector3.new((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
	zone.Parent = workspace
	arafahZone = zone
	print(("[PlaceContext] ZonaArafah %dx%d studs dibuat dari BatasArafah."):format(zone.Size.X, zone.Size.Z))
	return zone
end

-- Tinggi terrain di (x,z) via raycast ke bawah (terrain dibentuk Importer; lihat build scripts).
local function terrainY(x: number, z: number): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local r = workspace:Raycast(Vector3.new(x, 9000, z), Vector3.new(0, -18000, 0), rp)
	return r and r.Position.Y or nil
end

-- Kerikil Muzdalifah (Masy'aril Haram). Target FIKIH = 7 kerikil/pemain; tapi tanah Muzdalifah
-- BERLAPIS kerikil tak habis — jadi kita sebar HAMPARAN PADAT (PEBBLE_FIELD part) yang TIDAK pernah
-- dikonsumsi: PebbleCollect hanya menambah counter, tak menghapus part (lihat PebbleCollect). Dengan
-- begitu kerikil SELALU ADA berapa pun pemain yang memungut. Posisi deterministik (bukan acak) agar
-- reprodusibel; disebar di beberapa cincin konsentris memakai sudut emas. Dibuat sekali (cache).
local PEBBLE_TARGET = 7 -- jumlah yang perlu dipungut tiap pemain
local PEBBLE_FIELD = 60 -- jumlah part hiasan di tanah (tak habis)
local GOLDEN = math.pi * (3 - math.sqrt(5)) -- ~2.399963 rad, sebaran alami
local muzPebbles: { BasePart }? = nil
local function getMuzdalifahPebbles(): { BasePart }
	if muzPebbles and muzPebbles[1] and muzPebbles[1].Parent then
		return muzPebbles
	end
	local folder = workspace:FindFirstChild("Kerikil_Muzdalifah")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Kerikil_Muzdalifah"
	folder.Parent = workspace

	local list = {}
	for i = 1, PEBBLE_FIELD do
		-- Spiral Fermat: radius ∝ √i, sudut kelipatan sudut emas → sebaran merata 0..~95 studs.
		local r = 14 + math.sqrt(i / PEBBLE_FIELD) * 80
		local ang = i * GOLDEN
		local x = math.cos(ang) * r
		local z = math.sin(ang) * r
		local y = (terrainY(x, z) or 0) + 0.6
		local peb = Instance.new("Part")
		peb.Name = "Kerikil" .. i
		peb.Shape = Enum.PartType.Ball
		peb.Size = Vector3.new(1.6, 1.6, 1.6)
		peb.Anchored = true
		peb.CanCollide = false -- hanya hiasan + target Touched; tak menghalangi gerak
		peb.Material = Enum.Material.Slate
		peb.Color = Color3.fromRGB(90, 88, 84)
		peb.Position = Vector3.new(x, y, z)
		peb.Parent = folder
		list[i] = peb
	end
	muzPebbles = list
	print(("[PlaceContext] %d kerikil Muzdalifah disebar (hamparan tak-habis; target pungut %d)."):format(PEBBLE_FIELD, PEBBLE_TARGET))
	return list
end

function PlaceContext.Muzdalifah(stage: any, _state: any, player: Player): any
	if stage.ritual == "PebbleCollect" then
		return { player = player, place = "Muzdalifah", pebbles = getMuzdalifahPebbles(), config = { target = PEBBLE_TARGET } }
	end
	return { player = player, place = "Muzdalifah" }
end

-- Mina — pemilik: Praditama. Tiga tugu jumrah (Ula/Wustha/Aqabah) sebagai target lempar.
-- Sumber sebenarnya = Workspace.Jamarat.<Jamratul_*> yang DIBUAT oleh B_Mina/build_mina.lua
-- (folder top-level "Jamarat", part bernama Jamratul_Ula/Jamratul_Wusta/Jamratul_Aqabah, ejaan
-- "Wusta"). Sampai build dijalankan di Studio, pakai placeholder deterministik agar bisa diuji.
local JUMRAH_NAMES = { "Ula", "Wustha", "Aqabah" }
-- Pemetaan nama internal → nama part hasil build_mina.lua.
local BUILT_NAME = { Ula = "Jamratul_Ula", Wustha = "Jamratul_Wusta", Aqabah = "Jamratul_Aqabah" }
local minaPillars: { [string]: BasePart }? = nil
local function getMinaPillars(): { [string]: BasePart }
	if minaPillars then
		return minaPillars
	end
	-- Ambil dari dunia hasil build (Workspace.Jamarat) bila build_mina.lua sudah dijalankan.
	local jamarat = workspace:FindFirstChild("Jamarat")
	local found: { [string]: BasePart } = {}
	if jamarat then
		for _, name in ipairs(JUMRAH_NAMES) do
			local node = jamarat:FindFirstChild(BUILT_NAME[name])
			if node and node:IsA("BasePart") then
				found[name] = node
			end
		end
	end
	if found.Ula and found.Wustha and found.Aqabah then
		minaPillars = found
		print("[PlaceContext] Tugu Jumrah diambil dari Workspace.Jamarat (hasil build_mina.lua).")
		return found
	end

	-- Placeholder: 3 tugu sepanjang sumbu X, jarak kasar (Ula–Wustha ~150m, Wustha–Aqabah ~250m).
	warn("[PlaceContext] Workspace.Jamarat tak lengkap — pakai placeholder tugu Jumrah (jalankan B_Mina/build_mina.lua di Studio).")
	local folder = workspace:FindFirstChild("Jamarat_Placeholder")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Jamarat_Placeholder"
	folder.Parent = workspace

	local offsets = { Ula = 0, Wustha = 150, Aqabah = 400 }
	local pillars: { [string]: BasePart } = {}
	for _, name in ipairs(JUMRAH_NAMES) do
		local x = offsets[name]
		local y = (terrainY(x, 0) or 0) + 8
		local tugu = Instance.new("Part")
		tugu.Name = "Jamrah_" .. name
		tugu.Anchored = true
		tugu.Size = Vector3.new(8, 16, 8)
		tugu.Material = Enum.Material.Concrete
		tugu.Color = Color3.fromRGB(200, 198, 190)
		tugu.Position = Vector3.new(x, y, 0)
		tugu.Parent = folder
		pillars[name] = tugu
	end
	minaPillars = pillars
	print("[PlaceContext] 3 tugu Jumrah placeholder dibuat (Ula/Wustha/Aqabah).")
	return pillars
end

-- Tempat sembelih qurban (hadyu). Dibuat B_Mina/build_mina.lua sebagai Workspace.TempatQurban
-- (top-level, konsisten dgn Jamarat). Bila build belum dijalankan, pakai placeholder deterministik.
local minaQurbanStation: BasePart? = nil
local function getQurbanStation(): BasePart
	if minaQurbanStation and minaQurbanStation.Parent then
		return minaQurbanStation
	end
	local node = workspace:FindFirstChild("TempatQurban")
	if node and node:IsA("BasePart") then
		minaQurbanStation = node
		print("[PlaceContext] Tempat qurban diambil dari Workspace.TempatQurban.")
		return node
	end
	warn("[PlaceContext] Workspace.TempatQurban tak ada — pakai placeholder area qurban (tambahkan ke build_mina.lua saat siap).")
	local x, z = 250, 120
	local y = (terrainY(x, z) or 0) + 2
	local part = Instance.new("Part")
	part.Name = "TempatQurban_Placeholder"
	part.Anchored = true
	part.Size = Vector3.new(20, 4, 20)
	part.Material = Enum.Material.WoodPlanks
	part.Color = Color3.fromRGB(150, 120, 90)
	part.Position = Vector3.new(x, y, z)
	part.Parent = workspace
	minaQurbanStation = part
	print("[PlaceContext] Tempat qurban placeholder dibuat.")
	return part
end

-- Dam (hadyu) wajib pada Tamattu' & Qiran; Ifrad tanpa dam (lihat GAME_DESIGN §5.6).
local DAM_REQUIRED = { HajiTamattu = true, HajiQiran = true }

function PlaceContext.Mina(stage: any, state: any, player: Player): any
	if stage.ritual == "JumrahThrow" then
		-- Mode dari tahap: hari 10 (JUMRAH_AQABAH) = hanya Aqabah; hari 11-13 (MABIT_MINA_2) = 3 pilar.
		local mode = (stage.id == "MABIT_MINA_2") and "three_pillars" or "aqabah_only"
		return {
			player = player,
			place = "Mina",
			mode = mode,
			pillars = getMinaPillars(),
			config = { throwsPerPillar = 7 },
		}
	elseif stage.ritual == "Qurban" then
		return {
			player = player,
			place = "Mina",
			damRequired = DAM_REQUIRED[state and state.ibadahType] == true,
			station = getQurbanStation(),
		}
	end
	-- Mabit/Tahallul di Mina: ctx minimal (mekanisme masing-masing pemilik) — disempurnakan
	-- saat build Mina (zona mabit, sub-lokasi tahallul) jadi.
	return { player = player, place = "Mina" }
end

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- MAKKAH & MIQAT — pemilik: Devi. ctx untuk TawafCounter/SaiCounter/Tahallul/IhramHaji (Makkah)
-- dan IhramChange/BusRide (miqat). Posisi pemain via HumanoidRootPart (Tawaf/Sai berbasis posisi).
-- ════════════════════════════════════════════════════════════════════════════════════════════

-- Pembaca posisi pemain (untuk mekanisme berbasis posisi Devi). Dipanggil tiap Heartbeat oleh mech.
local function makeGetPosition(player: Player): () -> Vector3
	return function(): Vector3
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		return (hrp and (hrp :: BasePart).Position) or Vector3.new(0, 0, 0)
	end
end

-- Landmark Makkah (Ka'bah = pusat Tawaf, bukit Safa & Marwah = ujung Sa'i). Sumber sebenarnya =
-- dunia hasil A_Makkah/build_makkah.lua: Workspace.A_Makkah.Kaaba.Kaaba, Workspace.A_Makkah.Masaa.
-- Bukit_Safa / Bukit_Marwah. Sampai build dijalankan, pakai placeholder deterministik. Di-cache.
-- Pemetaan nama internal → nama part hasil build (ejaan "Safa"/"Kaaba" mengikuti build_makkah.lua).
local BUILT_PART = { Kabah = "Kaaba", Shafa = "Bukit_Safa", Marwah = "Bukit_Marwah" }
local makkahMarks: { [string]: BasePart }? = nil

-- Cari BasePart bernama `name` di bawah `root` (rekursif; lewati Folder/Model bernama sama).
local function findPartNamed(root: Instance, name: string): BasePart?
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

local function getMakkahMarks(): { [string]: BasePart }
	if makkahMarks then
		return makkahMarks
	end
	local root = workspace:FindFirstChild("A_Makkah") or workspace:FindFirstChild("Makkah")
	local found: { [string]: BasePart } = {}
	if root then
		for name, builtName in pairs(BUILT_PART) do
			local node = findPartNamed(root, builtName)
			if node then
				found[name] = node
			end
		end
	end
	if found.Kabah and found.Shafa and found.Marwah then
		makkahMarks = found
		print("[PlaceContext] Landmark Makkah diambil dari Workspace.A_Makkah (hasil build_makkah.lua).")
		return found
	end

	warn("[PlaceContext] Landmark Makkah tak lengkap — pakai placeholder (jalankan A_Makkah/build_makkah.lua di Studio).")
	local fallback = { Kabah = Vector3.new(0, 0, 0), Shafa = Vector3.new(0, 0, 120), Marwah = Vector3.new(0, 0, 420) }
	local folder = workspace:FindFirstChild("Makkah_Placeholder")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Makkah_Placeholder"
	folder.Parent = workspace
	local marks: { [string]: BasePart } = {}
	for name, p in pairs(fallback) do
		if found[name] then
			marks[name] = found[name]
		else
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.CanCollide = false
			if name == "Kabah" then
				part.Size = Vector3.new(12, 15, 12)
				part.Material = Enum.Material.Granite
				part.Color = Color3.fromRGB(20, 20, 20)
			else
				part.Size = Vector3.new(8, 10, 8)
				part.Material = Enum.Material.Limestone
				part.Color = Color3.fromRGB(170, 150, 120)
			end
			local y = (terrainY(p.X, p.Z) or 0) + part.Size.Y / 2
			part.Position = Vector3.new(p.X, y, p.Z)
			part.Parent = folder
			marks[name] = part
		end
	end
	makkahMarks = marks
	print("[PlaceContext] Landmark Makkah placeholder dibuat (Kabah/Shafa/Marwah).")
	return marks
end

-- Bus miqat→Makkah (target ProximityPrompt BusRide). Sumber sebenarnya = Workspace.Bus hasil
-- common/build_miqat.lua. Placeholder bila build belum dijalankan.
local miqatBus: BasePart? = nil
local function getMiqatBus(): BasePart
	if miqatBus and miqatBus.Parent then
		return miqatBus
	end
	local node = workspace:FindFirstChild("Bus")
	if node and node:IsA("BasePart") then
		miqatBus = node
		return node
	end
	warn("[PlaceContext] Workspace.Bus tak ada — pakai placeholder bus (jalankan common/build_miqat.lua).")
	local x, z = 40, 0
	local part = Instance.new("Part")
	part.Name = "Bus_Placeholder"
	part.Anchored = true
	part.Size = Vector3.new(12, 8, 30)
	part.Material = Enum.Material.Metal
	part.Color = Color3.fromRGB(60, 120, 90)
	part.Position = Vector3.new(x, (terrainY(x, z) or 0) + 4, z)
	part.Parent = workspace
	miqatBus = part
	return part
end

local TAWAF_TARGET = 7
local SAI_TARGET = 7

function PlaceContext.Makkah(stage: any, state: any, player: Player): any
	local r = stage.ritual
	if r == "TawafCounter" then
		local marks = getMakkahMarks()
		return {
			player = player,
			place = "Makkah",
			center = marks.Kabah.Position,
			getPosition = makeGetPosition(player),
			config = { target = TAWAF_TARGET, maxRadius = 60 },
		}
	elseif r == "SaiCounter" then
		local marks = getMakkahMarks()
		return {
			player = player,
			place = "Makkah",
			shafa = marks.Shafa,
			marwah = marks.Marwah,
			getPosition = makeGetPosition(player),
			config = { target = SAI_TARGET, reachRadius = 12 },
		}
	elseif r == "Tahallul" then
		-- Di Makkah hanya tahallul UMRAH (tahallul awal haji = Mina). station nil → aksi via UI Panduan.
		return { player = player, place = "Makkah", mode = "umrah" }
	elseif r == "IhramHaji" then
		-- Niat haji 8 Dzulhijjah (Tamattu', setelah tahallul umrah). station nil → langsung.
		return { player = player, place = "Makkah" }
	end
	return { player = player, place = "Makkah" }
end

-- Generik untuk kelima place miqat (Bir Ali, Juhfah, dst). `state` membawa ibadahType (niat) &
-- chosenMiqat. Dipakai bootstrap saat PLACE_NAME berawalan "Miqat_".
function PlaceContext.Miqat(stage: any, state: any, player: Player): any
	local r = stage.ritual
	local placeName = (state and state.chosenMiqat) or "Miqat"
	if r == "IhramChange" then
		return { player = player, place = placeName, ibadahType = state and state.ibadahType }
	elseif r == "BusRide" then
		return { player = player, place = placeName, busPart = getMiqatBus(), destinationLabel = "Makkah" }
	end
	return { player = player, place = placeName }
end

function PlaceContext.Arafah(stage: any, _state: any, player: Player): any
	if stage.ritual == "Wukuf" then
		return {
			player = player,
			place = "Arafah",
			zonePart = getArafahZone(),
			config = WUKUF_CONFIG,
			startPresent = true, -- pemain spawn/teleport masuk Arafah → dianggap hadir saat mulai.
		}
	end
	return { player = player, place = "Arafah" }
end

return PlaceContext
