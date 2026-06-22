--[[ build_muzdalifah.lua — Command Bar Studio  (Zona D: Muzdalifah)
  Bangun landmark & area Muzdalifah dari ModuleScript di ReplicatedStorage:
    MuzdalifahMasyaril, MuzdalifahBoundary, MuzdalifahPebbleArea, MuzdalifahFacilities
  Output DIKELOMPOKKAN di Workspace > D_Muzdalifah > {MasyarilHaram, BatasMuzdalifah,
  AreaKerikil, Fasilitas}.

  PENTING: "AreaKerikil" (penanda region) DIBACA server/WorldProviders.muzdalifahPebbles untuk
  menyebar hamparan kerikil non-konsumtif TEPAT di area ini (bukan mengarang di origin).

  Prasyarat: terrain Muzdalifah sudah di-generate (semua pakai raycast).
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

local root = workspace:FindFirstChild("D_Muzdalifah"); if root then root:Destroy() end
root = Instance.new("Folder"); root.Name = "D_Muzdalifah"; root.Parent = workspace
local function sub(name)
	local f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f
end

local function part(props, parent)
	local p = Instance.new("Part"); p.Anchored = true
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent; return p
end

-- ===== MASY'ARIL HARAM: placeholder masjid (aula + 2 menara) =====
local mh = loadData("MuzdalifahMasyaril")
if mh and mh.center then
	local f = sub("MasyarilHaram")
	local cx, cz = mh.center.x, mh.center.z
	local y = terrainY(cx, cz) or 0
	local w = (mh.size and mh.size.w) or 240
	local l = (mh.size and mh.size.l) or 160
	local wallH = 60
	part({ Size = Vector3.new(w, wallH, l), Position = Vector3.new(cx, y + wallH / 2, cz),
		Material = Enum.Material.Marble, Color = Color3.fromRGB(228, 222, 206), Name = "Aula_Masyaril" }, f)
	-- 2 menara di tepi
	local mhH = wallH + 90
	for _, sgn in ipairs({ -1, 1 }) do
		part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(mhH, 14, 14),
			CFrame = CFrame.new(cx + sgn * w / 2, y + mhH / 2, cz) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Marble, Color = Color3.fromRGB(238, 232, 220), Name = "Menara" }, f)
	end
	print(("[Muzdalifah] Masy'aril Haram: aula %dx%d + 2 menara di (%.0f,%.0f)."):format(w, l, cx, cz))
end

-- ===== AREA KERIKIL: penanda region (dibaca WorldProviders) =====
local pa = loadData("MuzdalifahPebbleArea")
if pa and pa.center then
	local f = sub("AreaKerikil")
	local cx, cz = pa.center.x, pa.center.z
	local rad = pa.radius or 160
	local y = terrainY(cx, cz) or 0
	-- Penanda KOTAK datar 2r x 2r; WorldProviders baca Position + Size utk batas sebar kerikil.
	part({ Name = "AreaKerikil", Size = Vector3.new(rad * 2, 1, rad * 2),
		Position = Vector3.new(cx, y + 0.5, cz), Transparency = 0.7, CanCollide = false,
		Material = Enum.Material.Slate, Color = Color3.fromRGB(110, 108, 102) }, f)
	print(("[Muzdalifah] AreaKerikil: r=%.0f di (%.0f,%.0f) — dibaca WorldProviders."):format(rad, cx, cz))
end

-- ===== BATAS MUZDALIFAH: gapura keliling =====
local bd = loadData("MuzdalifahBoundary")
if bd then
	local f = sub("BatasMuzdalifah")
	local n = 0
	for _, g in ipairs(bd.gates or {}) do
		local y = terrainY(g.x, g.z) or 0
		part({ Size = Vector3.new(8, 110, 8), Position = Vector3.new(g.x, y + 55, g.z),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 150, 230), Name = "Gapura_Batas" }, f)
		part({ Size = Vector3.new(60, 22, 4), Position = Vector3.new(g.x, y + 100, g.z),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 150, 230), Name = "Papan_BatasMuzdalifah" }, f)
		n += 1
	end
	print(("[Muzdalifah] Batas Muzdalifah: %d gapura."):format(n))
end

-- ===== FASILITAS MCK: blok beton =====
local fac = loadData("MuzdalifahFacilities")
if fac then
	local f = sub("Fasilitas")
	local n = 0
	for _, b in ipairs(fac.blocks or {}) do
		local y = terrainY(b.x, b.z); if not y then continue end
		part({ Size = Vector3.new(b.w or 60, 24, b.l or 24), Position = Vector3.new(b.x, y + 12, b.z),
			Material = Enum.Material.Concrete, Color = Color3.fromRGB(200, 200, 195), Name = "MCK" }, f)
		n += 1
	end
	print(("[Muzdalifah] Fasilitas MCK: %d blok."):format(n))
end

print("[Muzdalifah] Selesai. Cek Workspace > D_Muzdalifah > {MasyarilHaram, AreaKerikil, BatasMuzdalifah, Fasilitas}.")
