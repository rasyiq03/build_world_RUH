--!strict
-- WorldProviders.lua — penyedia OBJEK DUNIA (Workspace) untuk mekanisme. Dipisah dari PlaceContext
-- agar memenuhi SRP: di sini SEMUA logika mencari/membuat Part & Folder (zona, kerikil, tugu, dll);
-- PlaceContext hanya MERAKIT ctx dari hasil di sini. Pemilik per-area sama dgn entri PlaceContext.
--
-- Pola tiap provider: ambil dari DUNIA HASIL BUILD (Workspace) bila ada; bila build belum dijalankan,
-- buat PLACEHOLDER deterministik supaya tetap bisa dimainkan/diuji. Semua hasil di-cache (idempoten).

local WorldProviders = {}

local ZONE_HEIGHT = 4000

-- Tinggi terrain di (x,z) via raycast ke bawah (terrain dibentuk Importer; lihat build scripts).
local function terrainY(x: number, z: number): number?
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local r = workspace:Raycast(Vector3.new(x, 9000, z), Vector3.new(0, -18000, 0), rp)
	return r and r.Position.Y or nil
end
WorldProviders.terrainY = terrainY

-- Cari BasePart bernama `name` di bawah `root` (rekursif; lewati Folder/Model bernama sama).
local function findPartNamed(root: Instance, name: string): BasePart?
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then
			return d
		end
	end
	return nil
end

-- ── Arafah: zona kehadiran Wukuf (AABB dari Workspace.C_Arafah.BatasArafah / build_arafah.lua) ──
local arafahZone: BasePart? = nil
function WorldProviders.arafahZone(): BasePart?
	if arafahZone and arafahZone.Parent then
		return arafahZone
	end
	local cArafah = workspace:FindFirstChild("C_Arafah")
	local batas = cArafah and cArafah:FindFirstChild("BatasArafah")
	if not batas then
		warn("[WorldProviders] Workspace.C_Arafah.BatasArafah tak ada — jalankan build_arafah.lua. Wukuf tanpa gating zona.")
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
	print(("[WorldProviders] ZonaArafah %dx%d studs dibuat dari BatasArafah."):format(zone.Size.X, zone.Size.Z))
	return zone
end

-- ── Muzdalifah: hamparan kerikil tak-habis (Masy'aril Haram). Lihat catatan non-konsumtif di ──
-- PebbleCollect: part TIDAK dihapus saat dipungut, jadi selalu tersedia berapa pun pemain.
local PEBBLE_FIELD = 60 -- jumlah part hiasan di tanah (tak habis); target pungut diatur PlaceContext
local GOLDEN = math.pi * (3 - math.sqrt(5)) -- ~2.399963 rad, sebaran alami
local muzPebbles: { BasePart }? = nil
function WorldProviders.muzdalifahPebbles(): { BasePart }
	if muzPebbles and muzPebbles[1] and muzPebbles[1].Parent then
		return muzPebbles
	end
	-- Pusat & jangkauan dari region NYATA hasil build (D_Muzdalifah.AreaKerikil / build_muzdalifah.lua);
	-- bila build belum dijalankan, sebar placeholder di origin.
	local cx, cz, extent = 0, 0, 80
	local dz = workspace:FindFirstChild("D_Muzdalifah")
	local area = dz and dz:FindFirstChild("AreaKerikil")
	if area and area:IsA("BasePart") then
		cx, cz = area.Position.X, area.Position.Z
		extent = math.max(area.Size.X, area.Size.Z) / 2
		print("[WorldProviders] Area kerikil dari D_Muzdalifah.AreaKerikil (hasil build_muzdalifah.lua).")
	else
		warn("[WorldProviders] D_Muzdalifah.AreaKerikil tak ada — sebar kerikil di origin (jalankan build_muzdalifah.lua).")
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
		-- Spiral Fermat: radius ∝ √i, sudut kelipatan sudut emas → sebaran merata dalam region.
		local r = math.sqrt(i / PEBBLE_FIELD) * extent
		local ang = i * GOLDEN
		local x = cx + math.cos(ang) * r
		local z = cz + math.sin(ang) * r
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
	print(("[WorldProviders] %d kerikil Muzdalifah disebar (hamparan tak-habis, r=%d)."):format(PEBBLE_FIELD, extent))
	return list
end

-- ── Mina: 3 tugu Jumrah (Workspace.Jamarat.Jamratul_* / build_mina.lua), ejaan "Wusta" dari build ──
local JUMRAH_NAMES = { "Ula", "Wustha", "Aqabah" }
local BUILT_NAME = { Ula = "Jamratul_Ula", Wustha = "Jamratul_Wusta", Aqabah = "Jamratul_Aqabah" }
local minaPillars: { [string]: BasePart }? = nil
function WorldProviders.minaPillars(): { [string]: BasePart }
	if minaPillars then
		return minaPillars
	end
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
		print("[WorldProviders] Tugu Jumrah diambil dari Workspace.Jamarat (hasil build_mina.lua).")
		return found
	end

	-- Placeholder: 3 tugu sepanjang sumbu X, jarak kasar (Ula–Wustha ~150m, Wustha–Aqabah ~250m).
	warn("[WorldProviders] Workspace.Jamarat tak lengkap — pakai placeholder tugu Jumrah (jalankan B_Mina/build_mina.lua).")
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
	print("[WorldProviders] 3 tugu Jumrah placeholder dibuat (Ula/Wustha/Aqabah).")
	return pillars
end

-- ── Mina: tempat sembelih qurban (Workspace.TempatQurban / build_mina.lua) ──
local minaQurbanStation: BasePart? = nil
function WorldProviders.qurbanStation(): BasePart
	if minaQurbanStation and minaQurbanStation.Parent then
		return minaQurbanStation
	end
	local node = workspace:FindFirstChild("TempatQurban")
	if node and node:IsA("BasePart") then
		minaQurbanStation = node
		print("[WorldProviders] Tempat qurban diambil dari Workspace.TempatQurban.")
		return node
	end
	warn("[WorldProviders] Workspace.TempatQurban tak ada — pakai placeholder area qurban (jalankan B_Mina/build_mina.lua).")
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
	print("[WorldProviders] Tempat qurban placeholder dibuat.")
	return part
end

-- ── Makkah: landmark Ka'bah (pusat Tawaf) + bukit Safa/Marwah (ujung Sa'i) dari A_Makkah build ──
-- Nama part mengikuti build_makkah.lua: A_Makkah.Kaaba.Kaaba, A_Makkah.Masaa.Bukit_Safa/Bukit_Marwah.
local BUILT_PART = { Kabah = "Kaaba", Shafa = "Bukit_Safa", Marwah = "Bukit_Marwah" }
local makkahMarks: { [string]: BasePart }? = nil
function WorldProviders.makkahMarks(): { [string]: BasePart }
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
		print("[WorldProviders] Landmark Makkah diambil dari Workspace.A_Makkah (hasil build_makkah.lua).")
		return found
	end

	warn("[WorldProviders] Landmark Makkah tak lengkap — pakai placeholder (jalankan A_Makkah/build_makkah.lua).")
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
	print("[WorldProviders] Landmark Makkah placeholder dibuat (Kabah/Shafa/Marwah).")
	return marks
end

-- ── Miqat: bus miqat→Makkah (Workspace.Bus / common/build_miqat.lua) ──
local miqatBus: BasePart? = nil
function WorldProviders.miqatBus(): BasePart
	if miqatBus and miqatBus.Parent then
		return miqatBus
	end
	local node = workspace:FindFirstChild("Bus")
	if node and node:IsA("BasePart") then
		miqatBus = node
		return node
	end
	warn("[WorldProviders] Workspace.Bus tak ada — pakai placeholder bus (jalankan common/build_miqat.lua).")
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

return WorldProviders
