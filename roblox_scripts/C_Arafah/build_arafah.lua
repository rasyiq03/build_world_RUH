--[[ build_arafah.lua — Command Bar Studio  (Zona C: Arafah)
  Bangun landmark & area Arafah dari ModuleScript di ReplicatedStorage:
    ArafahJabalRahmah, ArafahNamirah, ArafahBoundary, ArafahFacilities, ArafahMist
  Output DIKELOMPOKKAN di Workspace > C_Arafah > {JabalRahmah, MasjidNamirah,
  BatasArafah, Fasilitas, Mist}.

  Prasyarat: terrain Arafah sudah di-generate (semua pakai raycast).
  Jalankan: tempel ke Command Bar, Enter.
]]

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local terrain = workspace.Terrain

local function loadData(name)
	local m = RS:FindFirstChild(name)
	if not m or not m:IsA("ModuleScript") then return nil end
	local ok, raw = pcall(require, m); if not ok then return nil end
	local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok2 and d or nil
end

local function terrainY(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	local r = workspace:Raycast(Vector3.new(x, 9000, z), Vector3.new(0, -18000, 0), rp)
	return r and r.Position.Y or nil
end

-- Folder lokasi utama + sub-folder.
local root = workspace:FindFirstChild("C_Arafah"); if root then root:Destroy() end
root = Instance.new("Folder"); root.Name = "C_Arafah"; root.Parent = workspace
local function sub(name)
	local f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f
end

local function part(props, parent)
	local p = Instance.new("Part"); p.Anchored = true
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent; return p
end

-- ===== JABAL AR-RAHMAH: bukit (terrain) + tugu putih ~8 m =====
local jr = loadData("ArafahJabalRahmah")
if jr and jr.center then
	local f = sub("JabalRahmah")
	local x, z = jr.center.x, jr.center.z
	local y = terrainY(x, z) or 0
	local h = jr.pillar_height or 32
	part({ Size = Vector3.new(6, h, 6), Position = Vector3.new(x, y + h / 2, z),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(240, 240, 240), Name = "Tugu_Rahmah" }, f)
	-- dasar bukit (penanda batu)
	part({ Size = Vector3.new(60, 20, 60), Position = Vector3.new(x, y + 10, z),
		Material = Enum.Material.Rock, Color = Color3.fromRGB(120, 110, 100), Name = "Bukit", Transparency = 0.1 }, f)
	print(("[Arafah] Jabal ar-Rahmah: tugu putih %d studs di (%.0f,%.0f)."):format(h, x, z))
end

-- ===== MASJID NAMIRAH: placeholder (aula + 6 menara + 3 kubah) =====
local nm = loadData("ArafahNamirah")
if nm and nm.center then
	local f = sub("MasjidNamirah")
	local cx, cz = nm.center.x, nm.center.z
	local y = terrainY(cx, cz) or 0
	local w = (nm.size and nm.size.w) or 800
	local l = (nm.size and nm.size.l) or 800
	local wallH = 90
	part({ Size = Vector3.new(w, wallH, l), Position = Vector3.new(cx, y + wallH / 2, cz),
		Material = Enum.Material.Marble, Color = Color3.fromRGB(232, 226, 210), Name = "Aula_Sholat" }, f)
	-- 3 kubah di garis tengah
	for i = -1, 1 do
		local d = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.22, w * 0.22, w * 0.22),
			Position = Vector3.new(cx + i * w * 0.28, y + wallH + w * 0.05, cz),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(210, 200, 150), Name = "Kubah" }, f)
	end
	-- 6 menara di tepi
	local mh = wallH + 120
	local mx = { -0.5, 0, 0.5 }
	for _, fx in ipairs(mx) do
		for _, sgn in ipairs({ -1, 1 }) do
			part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(mh, 16, 16),
				CFrame = CFrame.new(cx + fx * w, y + mh / 2, cz + sgn * l / 2) * CFrame.Angles(0, 0, math.rad(90)),
				Material = Enum.Material.Marble, Color = Color3.fromRGB(240, 235, 222), Name = "Menara" }, f)
		end
	end
	print(("[Arafah] Masjid Namirah: aula %dx%d + 3 kubah + 6 menara di (%.0f,%.0f)."):format(w, l, cx, cz))
end

-- ===== BATAS ARAFAH: gapura kuning keliling =====
local bd = loadData("ArafahBoundary")
if bd then
	local f = sub("BatasArafah")
	local n = 0
	for _, g in ipairs(bd.gates or {}) do
		local y = terrainY(g.x, g.z) or 0
		part({ Size = Vector3.new(8, 120, 8), Position = Vector3.new(g.x, y + 60, g.z),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 200, 40), Name = "Gapura_Batas" }, f)
		-- papan
		part({ Size = Vector3.new(60, 24, 4), Position = Vector3.new(g.x, y + 110, g.z),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(240, 200, 40), Name = "Papan_BatasArafah" }, f)
		n += 1
	end
	print(("[Arafah] Batas Arafah: %d gapura kuning."):format(n))
end

-- ===== FASILITAS MCK: blok beton =====
local fac = loadData("ArafahFacilities")
if fac then
	local f = sub("Fasilitas")
	local n = 0
	for _, b in ipairs(fac.blocks or {}) do
		local y = terrainY(b.x, b.z); if not y then continue end
		part({ Size = Vector3.new(b.w or 60, 24, b.l or 24), Position = Vector3.new(b.x, y + 12, b.z),
			Material = Enum.Material.Concrete, Color = Color3.fromRGB(200, 200, 195), Name = "MCK" }, f)
		n += 1
	end
	print(("[Arafah] Fasilitas MCK: %d blok."):format(n))
end

-- ===== MIST: tiang kuning + emitter kabut di sepanjang rute =====
local mist = loadData("ArafahMist")
if mist then
	local f = sub("Mist")
	local n = 0
	for _, p in ipairs(mist.poles or {}) do
		local y = terrainY(p.x, p.z); if not y then continue end
		local pole = part({ Size = Vector3.new(3, 40, 3), Position = Vector3.new(p.x, y + 20, p.z),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(235, 200, 50), Name = "TiangMist" }, f)
		local head = part({ Size = Vector3.new(8, 4, 8), Position = Vector3.new(p.x, y + 40, p.z),
			Material = Enum.Material.Metal, Color = Color3.fromRGB(120, 120, 130), Name = "Kepala", CanCollide = false }, f)
		local em = Instance.new("ParticleEmitter")
		em.Texture = "rbxassetid://243660364"; em.Rate = 12; em.Lifetime = NumberRange.new(2, 3)
		em.Size = NumberSequence.new(6); em.Transparency = NumberSequence.new(0.7)
		em.Speed = NumberRange.new(2); em.SpreadAngle = Vector2.new(40, 40); em.Parent = head
		n += 1
	end
	print(("[Arafah] Mist: %d tiang (kabut)."):format(n))
end

print("[Arafah] Selesai. Cek Workspace > C_Arafah > {JabalRahmah, MasjidNamirah, BatasArafah, Fasilitas, Mist}.")
