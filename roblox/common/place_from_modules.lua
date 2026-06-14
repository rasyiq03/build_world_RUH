--[[ place_from_modules.lua — Command Bar Studio (KECIL, baca data dari ModuleScript)

  Membangun bangunan fasad + pembatas + tenda Mina dengan membaca data dari
  ModuleScript di ReplicatedStorage (hindari batas 100.000 karakter Command Bar).

  PRASYARAT (buat dulu di ReplicatedStorage, isi via to_roblox_module.py):
    - ModuleScript "MinaBuildings"  (wajib untuk bangunan)
    - ModuleScript "MinaBarriers"   (opsional, pembatas)
    - ModuleScript "MinaTents"      (opsional, tenda) + MeshPart/Model "TentMaster"
  Terrain Mina HARUS sudah di-generate (semua pakai raycast ke terrain).

  Jalankan: tempel skrip ini ke Command Bar, Enter.
]]

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local terrain = workspace.Terrain

local WALL_HEIGHT, WALL_THICKNESS = 24, 2
local BARRIER_HEIGHT, BARRIER_TRANSP = 60, 1
local RAY_TOP, SINK = 5000, 0.5

local function loadData(name)
	local m = RS:FindFirstChild(name)
	if not m or not m:IsA("ModuleScript") then return nil end
	local ok, raw = pcall(require, m)
	if not ok then warn("[load] gagal require " .. name .. ": " .. tostring(raw)); return nil end
	local ok2, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok2 then warn("[load] JSON rusak di " .. name); return nil end
	return decoded
end

local function terrainY(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	local r = workspace:Raycast(Vector3.new(x, RAY_TOP, z), Vector3.new(0, -RAY_TOP * 2, 0), rp)
	return r and r.Position.Y or nil
end

local function freshFolder(name)
	local f = workspace:FindFirstChild(name)
	if f then f:Destroy() end
	f = Instance.new("Folder"); f.Name = name; f.Parent = workspace
	return f
end

-- ---------- Bangunan (dinding keliling) ----------
local bData = loadData("MinaBuildings")
if bData then
	local folder = freshFolder("OSM_Buildings")
	local built, skipped = 0, 0
	for _, b in ipairs(bData.buildings or {}) do
		local poly = b.polygon
		if poly and #poly >= 3 then
			local sumY, n = 0, 0
			for _, p in ipairs(poly) do
				local y = terrainY(p.x, p.z)
				if y then sumY += y; n += 1 end
			end
			if n > 0 then
				local baseY = sumY / n
				local model = Instance.new("Model")
				model.Name = (b.name ~= "" and b.name) or "Bangunan"
				model.Parent = folder
				for i = 1, #poly do
					local a, c = poly[i], poly[(i % #poly) + 1]
					local va = Vector3.new(a.x, baseY + WALL_HEIGHT / 2, a.z)
					local vb = Vector3.new(c.x, baseY + WALL_HEIGHT / 2, c.z)
					local d = (va - vb).Magnitude
					if d > 0.05 then
						local w = Instance.new("Part")
						w.Anchored = true
						w.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, d)
						w.CFrame = CFrame.lookAt(va, vb) * CFrame.new(0, 0, -d / 2)
						w.Material = Enum.Material.Concrete
						w.Color = Color3.fromRGB(196, 184, 160)
						w.Parent = model
					end
				end
				built += 1
			else
				skipped += 1
			end
		end
	end
	print(("[Bangunan] %d dibangun, %d dilewati (tanpa terrain)."):format(built, skipped))
else
	warn("[Bangunan] ModuleScript 'MinaBuildings' tak ditemukan di ReplicatedStorage.")
end

-- ---------- Pembatas ----------
local xData = loadData("MinaBarriers")
if xData then
	local folder = freshFolder("OSM_Barriers")
	local nb = 0
	for _, seg in ipairs(xData.barriers or {}) do
		local path = seg.path
		if path and #path >= 2 then
			for i = 1, #path - 1 do
				local a, c = path[i], path[i + 1]
				local ya, yc = terrainY(a.x, a.z) or 0, terrainY(c.x, c.z) or 0
				local baseY = (ya + yc) / 2
				local va = Vector3.new(a.x, baseY + BARRIER_HEIGHT / 2, a.z)
				local vb = Vector3.new(c.x, baseY + BARRIER_HEIGHT / 2, c.z)
				local d = (va - vb).Magnitude
				if d > 0.05 then
					local w = Instance.new("Part")
					w.Anchored = true; w.CanCollide = true; w.Transparency = BARRIER_TRANSP
					w.Size = Vector3.new(WALL_THICKNESS, BARRIER_HEIGHT, d)
					w.CFrame = CFrame.lookAt(va, vb) * CFrame.new(0, 0, -d / 2)
					w.Material = Enum.Material.SmoothPlastic
					w.Color = Color3.fromRGB(120, 120, 120)
					w.Parent = folder
					nb += 1
				end
			end
		end
	end
	print(("[Pembatas] %d dinding dibangun."):format(nb))
end

-- ---------- Tenda (clone TentMaster) ----------
local tData = loadData("MinaTents")
if tData then
	local master = RS:FindFirstChild("TentMaster") or workspace:FindFirstChild("TentMaster")
	if not master or not (master:IsA("BasePart") or master:IsA("Model")) then
		warn("[Tenda] 'TentMaster' (MeshPart/Model) tak ada di ReplicatedStorage/workspace — tenda dilewati.")
	else
		local size, pivotToCenter
		if master:IsA("Model") then
			local cf, sz = master:GetBoundingBox()
			size = sz; pivotToCenter = master:GetPivot():ToObjectSpace(cf).Position
		else
			size = master.Size; pivotToCenter = Vector3.zero
		end
		local halfY = size.Y / 2
		local folder = freshFolder("Mina_Tents")
		local placed, skipped = 0, 0
		for _, t in ipairs(tData.tents or {}) do
			local y = terrainY(t.x, t.z)
			if y then
				local clone = master:Clone()
				local center = CFrame.new(t.x, y + halfY - SINK, t.z) * CFrame.Angles(0, math.rad(t.rot or 0), 0)
				local pivotCF = center * CFrame.new(-pivotToCenter)
				if clone:IsA("Model") then
					clone:PivotTo(pivotCF)
					for _, d in ipairs(clone:GetDescendants()) do
						if d:IsA("BasePart") then d.Anchored = true end
					end
				else
					clone.Anchored = true; clone.CFrame = pivotCF
				end
				clone.Parent = folder
				placed += 1
			else
				skipped += 1
			end
		end
		print(("[Tenda] %d disebar, %d dilewati (tanpa terrain)."):format(placed, skipped))
	end
end

print("[Selesai] Cek folder OSM_Buildings / OSM_Barriers / Mina_Tents di Workspace.")
