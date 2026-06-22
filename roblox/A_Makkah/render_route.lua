--[[ render_route.lua — Command Bar Studio
  Gambar JALAN manasik (final, aspal) dari ModuleScript "MakkahRoute".
  Tiap ruas di-SUBDIVIDE & raycast tiap ~STEP studs → jalan MENJUNTAI mengikuti
  terrain (tak terendam/melayang). Ruas TEROWONGAN aspal gelap. Penanda KELUAR kuning.

  Prasyarat: ModuleScript "MakkahRoute" di ReplicatedStorage; terrain Makkah sudah ada.
  Jalankan SETELAH build_makkah.lua (biar terrain & landmark sudah final).
]]

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local terrain = workspace.Terrain

local ROAD_W = 44        -- lebar jalan (studs ~11 m)
local STEP = 30          -- jarak subdivide (studs) — makin kecil makin menjuntai
local LIFT = 0.6         -- naik tipis di atas tanah
local COL_ROAD = Color3.fromRGB(58, 58, 64)
local COL_TUNNEL = Color3.fromRGB(34, 34, 42)
-- CARVE koridor: potong terrain agar jalan RATA & tak terbenam di lereng menyamping (tanpa ini,
-- jalan lebar ditaruh datar → separuh masuk bukit). FillBlock Air di atas + Sand roadbed di bawah.
local CARVE_ROAD = true  -- false = perilaku lama (drape saja, tanpa potong terrain)
local CARVE_UP = 40      -- buang terrain di ATAS permukaan jalan (sisi tanjakan), studs
local FILL_DOWN = 28     -- isi roadbed di BAWAH permukaan jalan (sisi lembah), studs

local m = RS:FindFirstChild("MakkahRoute")
if not m then warn("[Route] ModuleScript 'MakkahRoute' tak ada."); return end
local data = HttpService:JSONDecode(require(m))

local function terrainY(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	local r = workspace:Raycast(Vector3.new(x, 8000, z), Vector3.new(0, -16000, 0), rp)
	return r and r.Position.Y or nil
end

local folder = workspace:FindFirstChild("Makkah_Route")
if folder then folder:Destroy() end
folder = Instance.new("Folder"); folder.Name = "Makkah_Route"; folder.Parent = workspace

-- Bangun satu potongan jalan antara dua titik dunia (sudah ber-Y).
local function slab(va, vb, tunnel, parent)
	local d = (va - vb).Magnitude
	if d < 0.05 then return end
	local cf = CFrame.lookAt((va + vb) / 2, vb) -- sumbu Z = arah jalan, X = lebar
	-- CARVE koridor terrain mengikuti orientasi cf (dijaga pcall; FillBlock hanya ada di Studio).
	if CARVE_ROAD then
		pcall(function()
			terrain:FillBlock(cf * CFrame.new(0, CARVE_UP / 2, 0), Vector3.new(ROAD_W + 6, CARVE_UP, d + 1), Enum.Material.Air)
			terrain:FillBlock(cf * CFrame.new(0, -FILL_DOWN / 2, 0), Vector3.new(ROAD_W, FILL_DOWN, d + 1), Enum.Material.Sand)
		end)
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(ROAD_W, 2, d + 1)   -- +1 overlap antar-potongan biar mulus
	p.CFrame = cf
	p.Material = tunnel and Enum.Material.Slate or Enum.Material.Asphalt
	p.Color = tunnel and COL_TUNNEL or COL_ROAD
	p.Name = tunnel and "Tunnel" or "Road"
	p.Parent = parent
end

local total = 0
for _, seg in ipairs(data.segments or {}) do
	local sub = Instance.new("Folder"); sub.Name = seg.from .. "_ke_" .. seg.to; sub.Parent = folder
	local path = seg.path
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local tunnel = (b.tunnel == 1)
		local dx, dz = b.x - a.x, b.z - a.z
		local dist = math.sqrt(dx * dx + dz * dz)
		local n = math.max(1, math.floor(dist / STEP))
		-- titik-titik subdivide dengan Y dari raycast -> menjuntai
		local prev
		for k = 0, n do
			local t = k / n
			local x, z = a.x + dx * t, a.z + dz * t
			local y = terrainY(x, z)
			if y then
				local v = Vector3.new(x, y + LIFT, z)
				if prev then slab(prev, v, tunnel, sub); total += 1 end
				prev = v
			end
		end
	end
	-- penanda titik KELUAR (gate teleport)
	if seg.exit then
		local y = terrainY(seg.exit.x, seg.exit.z) or 0
		local mk = Instance.new("Part")
		mk.Anchored = true; mk.Size = Vector3.new(ROAD_W, 36, 6)
		mk.Position = Vector3.new(seg.exit.x, y + 18, seg.exit.z)
		mk.Color = Color3.fromRGB(235, 200, 60); mk.Transparency = 0.35; mk.CanCollide = false
		mk.Name = "GATE_ke_" .. seg.exit.to_zone
		mk.Parent = sub
	end
end
print(("[Route] %d potongan jalan (aspal, menjuntai terrain). Tunnel ditandai gelap."):format(total))
