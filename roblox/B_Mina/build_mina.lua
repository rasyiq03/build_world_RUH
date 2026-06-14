--[[ build_mina.lua — Command Bar Studio  (baca data dari ModuleScript)

  Membangun Mina: TERAS (ratakan terrain per-blok) + sebar TENDA di atasnya,
  + pembatas + penanda Jamarat + lampu (opsional). Data dibaca dari ModuleScript
  di ReplicatedStorage (hindari limit 100k Command Bar).

  PRASYARAT di ReplicatedStorage (isi via to_roblox_module.py):
    - ModuleScript "MinaTerraces"  (wajib: blok teras + tenda)
    - ModuleScript "MinaBarriers"  (opsional: guardline)
    - ModuleScript "MinaJamarat"   (opsional: penanda Jamarat)
    - ModuleScript "MinaLamps"     (opsional: lampu)
  + "TentMaster" (MeshPart/Model) untuk tenda; "LampMaster" untuk lampu (opsional).
  Terrain Mina HARUS sudah di-generate.

  Jalankan: tempel skrip ini ke Command Bar, Enter. (Bisa makan beberapa detik.)
]]

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local terrain = workspace.Terrain

local RAY_TOP = 8000
local PLATFORM_FILL = 80     -- isi solid di bawah platform (studs)
local PLATFORM_CARVE = 200   -- buang terrain di atas platform (ratakan)
local TENT_SINK = 0.5

local function loadData(name)
	local m = RS:FindFirstChild(name)
	if not m or not m:IsA("ModuleScript") then return nil end
	local ok, raw = pcall(require, m)
	if not ok then warn("[load] gagal " .. name); return nil end
	local ok2, dec = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok2 and dec or nil
end

local function terrainY(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	local r = workspace:Raycast(Vector3.new(x, RAY_TOP, z), Vector3.new(0, -RAY_TOP * 2, 0), rp)
	return r and r.Position.Y or nil
end

local function freshFolder(n)
	local f = workspace:FindFirstChild(n); if f then f:Destroy() end
	f = Instance.new("Folder"); f.Name = n; f.Parent = workspace; return f
end

-- ---------- TERAS + TENDA ----------
local terr = loadData("MinaTerraces")
if not terr then
	warn("[Mina] ModuleScript 'MinaTerraces' tak ada — tak ada teras/tenda."); return
end
local master = RS:FindFirstChild("TentMaster") or workspace:FindFirstChild("TentMaster")
local hasMaster = master and (master:IsA("BasePart") or master:IsA("Model"))
local size, pivotToCenter
if hasMaster then
	if master:IsA("Model") then
		local cf, sz = master:GetBoundingBox(); size = sz
		pivotToCenter = master:GetPivot():ToObjectSpace(cf).Position
	else size = master.Size; pivotToCenter = Vector3.zero end
end

local tentFolder = freshFolder("Mina_Tents")
local platformFolder = nil  -- teras pakai terrain, bukan folder

local blocks = terr.blocks or {}
local leveled, placed = 0, 0
for _, b in ipairs(blocks) do
	local bb = b.bbox
	local cx, cz = b.center.x, b.center.z
	local y = terrainY(cx, cz)
	if y then
		local w = bb.x1 - bb.x0
		local l = bb.z1 - bb.z0
		-- Ratakan jadi teras: buang terrain di atas platform, isi solid di bawah.
		terrain:FillBlock(CFrame.new(cx, y + PLATFORM_CARVE / 2, cz),
			Vector3.new(w, PLATFORM_CARVE, l), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(cx, y - PLATFORM_FILL / 2, cz),
			Vector3.new(w, PLATFORM_FILL, l), Enum.Material.Sand)
		leveled += 1
		-- Sebar tenda di permukaan teras (y), clone TentMaster.
		if hasMaster then
			local halfY = size.Y / 2
			for _, t in ipairs(b.tents) do
				local clone = master:Clone()
				local center = CFrame.new(t.x, y + halfY - TENT_SINK, t.z) * CFrame.Angles(0, math.rad(t.rot or 0), 0)
				local pivotCF = center * CFrame.new(-pivotToCenter)
				if clone:IsA("Model") then
					clone:PivotTo(pivotCF)
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
					end
				else clone.Anchored = true; clone.CanCollide = false; clone.CFrame = pivotCF end
				clone.Parent = tentFolder
				placed += 1
			end
		end
	end
end
print(("[Mina] Teras: %d blok diratakan. Tenda: %d disebar.%s")
	:format(leveled, placed, hasMaster and "" or " (TentMaster tak ada -> hanya teras)"))

-- ---------- GUARDLINE (pembatas) ----------
local xData = loadData("MinaBarriers")
if xData then
	local f = freshFolder("Mina_Barriers")
	local nb = 0
	for _, seg in ipairs(xData.barriers or {}) do
		local path = seg.path
		for i = 1, #path - 1 do
			local a, c = path[i], path[i + 1]
			local ya, yc = terrainY(a.x, a.z) or 0, terrainY(c.x, c.z) or 0
			local va = Vector3.new(a.x, (ya + yc) / 2 + 60, a.z)
			local vb = Vector3.new(c.x, (ya + yc) / 2 + 60, c.z)
			local d = (va - vb).Magnitude
			if d > 0.05 then
				local w = Instance.new("Part")
				w.Anchored = true; w.CanCollide = true; w.Transparency = 1
				w.Size = Vector3.new(2, 120, d)
				w.CFrame = CFrame.lookAt(va, vb) * CFrame.new(0, 0, -d / 2)
				w.Parent = f; nb += 1
			end
		end
	end
	print(("[Mina] Pembatas: %d dinding."):format(nb))
end

-- ---------- PENANDA JAMARAT ----------
local jData = loadData("MinaJamarat")
if jData and jData.center then
	local f = freshFolder("Jamarat")
	local jx, jz = jData.center.x, jData.center.z
	local baseY = terrainY(jx, jz) or 0
	local levels = jData.levels or 5
	local floorH = jData.floor_height or 28
	local w = (jData.size and jData.size.w) or 400
	local l = (jData.size and jData.size.l) or 200
	-- DECK tiap lantai = jalan layang bertingkat (aspal).
	for i = 1, levels do
		local deck = Instance.new("Part")
		deck.Anchored = true
		deck.Size = Vector3.new(w, 5, l)
		deck.Position = Vector3.new(jx, baseY + 14 + (i - 1) * floorH, jz)
		deck.Material = Enum.Material.Asphalt
		deck.Color = Color3.fromRGB(70, 70, 78)
		deck.Name = "Lantai_" .. i
		deck.Parent = f
		-- pagar tepi tipis (biar terbaca sbg jembatan)
		for _, sgn in ipairs({ -1, 1 }) do
			local rail = Instance.new("Part")
			rail.Anchored = true; rail.CanCollide = true
			rail.Size = Vector3.new(w, 8, 3)
			rail.Position = Vector3.new(jx, deck.Position.Y + 6, jz + sgn * l / 2)
			rail.Color = Color3.fromRGB(180, 180, 185); rail.Parent = f
		end
	end
	-- 3 TUGU JAMARAT sepanjang sumbu panjang, menembus semua lantai.
	local topY = baseY + 14 + levels * floorH
	local alongX = (w >= l)
	local names = { "Jamratul_Ula", "Jamratul_Wusta", "Jamratul_Aqabah" }
	for k, frac in ipairs({ 0.25, 0.5, 0.75 }) do
		local px = alongX and (jx - w / 2 + w * frac) or jx
		local pz = alongX and jz or (jz - l / 2 + l * frac)
		local wl = (alongX and l or w) * 0.45
		local pil = Instance.new("Part")
		pil.Anchored = true
		pil.Size = alongX and Vector3.new(22, topY - baseY + 24, wl) or Vector3.new(wl, topY - baseY + 24, 22)
		pil.Position = Vector3.new(px, baseY + (topY - baseY + 24) / 2, pz)
		pil.Material = Enum.Material.Sandstone
		pil.Color = Color3.fromRGB(196, 180, 150)
		pil.Name = names[k]
		pil.Parent = f
	end
	print(("[Mina] Jamarat: %d lantai jalan layang + 3 tugu di (%.0f, %.0f), tinggi %.0f studs.")
		:format(levels, jx, jz, topY - baseY))
end

-- ---------- LAMPU (clone LampMaster) ----------
local lData = loadData("MinaLamps")
if lData then
	local lm = RS:FindFirstChild("LampMaster") or workspace:FindFirstChild("LampMaster")
	local f = freshFolder("Mina_Lamps")
	local n = 0
	for _, p in ipairs(lData.lamps or {}) do
		local y = terrainY(p.x, p.z)
		if y then
			local obj
			if lm and (lm:IsA("BasePart") or lm:IsA("Model")) then
				obj = lm:Clone()
				if obj:IsA("Model") then obj:PivotTo(CFrame.new(p.x, y, p.z))
				else obj.Anchored = true; obj.CFrame = CFrame.new(p.x, y + obj.Size.Y / 2, p.z) end
			else
				-- placeholder part lampu (ganti dgn LampMaster nanti)
				obj = Instance.new("Part")
				obj.Anchored = true; obj.Size = Vector3.new(2, 30, 2)
				obj.Position = Vector3.new(p.x, y + 15, p.z)
				obj.Material = Enum.Material.Metal; obj.Color = Color3.fromRGB(80, 80, 90)
				obj.Name = "Lamp"
			end
			obj.Parent = f; n += 1
		end
	end
	print(("[Mina] Lampu: %d (%s)."):format(n, (lm and "clone LampMaster") or "placeholder part"))
end

print("[Mina] Selesai. Cek Workspace: Mina_Tents / Mina_Barriers / Jamarat / Mina_Lamps.")
