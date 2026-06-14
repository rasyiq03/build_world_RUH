--[[ place_tents.lua — Command Bar Studio
  Sebar ribuan tenda Mina dari mina_tents.json (hasil generate_tents.py) dengan
  meng-CLONE satu "TentMaster" ke tiap titik, via raycast ke terrain.

  TentMaster boleh berupa:
    - 1 MeshPart (paling ringan), ATAU
    - Model berisi beberapa MeshPart (mis. kain + baja). Tetap di-clone utuh.

  PRASYARAT:
    1. Terrain zona Mina sudah di-generate.
    2. Ada "TentMaster" (MeshPart atau Model) di ReplicatedStorage ATAU workspace.
       Pastikan ukurannya ~16 studs (≈ 8 m pada skala 2).

  CARA PAKAI:
    1. Salin isi output/B_Mina/mina_tents.json, tempel di TENTS_JSON di bawah.
    2. Tempel skrip ini ke Command Bar, Enter.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local terrain = workspace.Terrain

-- ===== TEMPEL ISI mina_tents.json DI SINI (di antara [[ ]]) =====
local TENTS_JSON = [[
{ "tents": [], "tent_size_studs": 16 }
]]
-- ===============================================================

local RAY_TOP = 5000
local SINK = 0.5   -- benamkan sedikit ke tanah agar tak melayang

local function findMaster()
	return ReplicatedStorage:FindFirstChild("TentMaster")
		or workspace:FindFirstChild("TentMaster")
end

local function terrainY(x, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local res = workspace:Raycast(Vector3.new(x, RAY_TOP, z), Vector3.new(0, -RAY_TOP * 2, 0), params)
	return res and res.Position.Y or nil
end

local master = findMaster()
if not master or not (master:IsA("BasePart") or master:IsA("Model")) then
	warn("[Tenda] Tak ada 'TentMaster' (MeshPart/Model) di ReplicatedStorage/workspace. "
		.. "Impor mesh tenda, beri nama TentMaster, lalu jalankan ulang.")
	return
end

-- Tinggi & offset pivot->pusat (agar penempatan benar untuk Part maupun Model).
local masterSize, pivotToCenter
if master:IsA("Model") then
	local bbCF, size = master:GetBoundingBox()
	masterSize = size
	pivotToCenter = master:GetPivot():ToObjectSpace(bbCF).Position  -- offset pusat di ruang pivot
else
	masterSize = master.Size
	pivotToCenter = Vector3.zero
end
local halfY = masterSize.Y / 2

local data = HttpService:JSONDecode(TENTS_JSON)
local tents = data.tents or {}

local folder = workspace:FindFirstChild("Mina_Tents")
if folder then folder:Destroy() end
folder = Instance.new("Folder")
folder.Name = "Mina_Tents"
folder.Parent = workspace

local placed, skipped = 0, 0
for _, t in ipairs(tents) do
	local y = terrainY(t.x, t.z)
	if y then
		local clone = master:Clone()
		-- Target: PUSAT bbox di (x, ground + halfY - SINK), diputar rot di Y.
		local center = CFrame.new(t.x, y + halfY - SINK, t.z) * CFrame.Angles(0, math.rad(t.rot or 0), 0)
		local pivotCF = center * CFrame.new(-pivotToCenter)  -- balik offset -> set pivot
		if clone:IsA("Model") then
			clone:PivotTo(pivotCF)
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true end
			end
		else
			clone.Anchored = true
			clone.CFrame = pivotCF
		end
		clone.Parent = folder
		placed += 1
	else
		skipped += 1
	end
end

print(("[Tenda] %d tenda disebar (clone dari TentMaster), %d dilewati (tanpa terrain)."):format(placed, skipped))
print("Ini instance dari mesh yang sama -> geometri tak menambah .rbxl, hanya instance.")
print("Jika berat: kurangi --max-tents di generate_tents.py, atau gabung tenda jadi 1 MeshPart.")
