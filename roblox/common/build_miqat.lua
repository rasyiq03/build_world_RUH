--[[ build_miqat.lua — Command Bar Studio  (GENERIK untuk kelima place Miqat)

  Membangun struktur dasar sebuah miqat: PERON niat + papan nama + BUS (untuk transisi ke Makkah).
  Skrip yang SAMA dipakai di tiap place miqat (Bir Ali, Juhfah, Dzatu 'Irq, Qarnul Manazil,
  Yalamlam) — label diambil dari atribut Workspace "PlaceName".

  Output (top-level Workspace):
    - Folder "Miqat" > { Peron, Papan }   (penanda area + nama miqat)
    - Part   "Bus"                         ← dibaca PlaceContext.Miqat (BusRide pasang ProximityPrompt)

  Prasyarat: terrain miqat sudah di-generate, atribut Workspace.PlaceName terisi (mis. "Miqat_BirAli").
  Jalankan: tempel skrip ini ke Command Bar, Enter.
]]

local terrain = workspace.Terrain

local function terrainY(x, z)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	local r = workspace:Raycast(Vector3.new(x, 8000, z), Vector3.new(0, -16000, 0), rp)
	return r and r.Position.Y or nil
end

local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- Label miqat dari PlaceName (mis. "Miqat_BirAli" -> "Bir Ali").
local placeName = workspace:GetAttribute("PlaceName") or "Miqat"
local label = tostring(placeName):gsub("^Miqat_", ""):gsub("(%l)(%u)", "%1 %2")

-- Bersihkan hasil build sebelumnya.
for _, n in ipairs({ "Miqat", "Bus" }) do
	local old = workspace:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

local root = Instance.new("Folder")
root.Name = "Miqat"
root.Parent = workspace

-- ===== PERON NIAT (pelataran tempat berihram & niat) di origin =====
local px, pz = 0, 0
local py = terrainY(px, pz) or 0
part({
	Name = "Peron",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(3, 90, 90),
	CFrame = CFrame.new(px, py + 1.5, pz) * CFrame.Angles(0, 0, math.rad(90)),
	Material = Enum.Material.Marble,
	Color = Color3.fromRGB(232, 230, 224),
}, root)

-- Papan nama miqat.
part({
	Name = "Papan",
	Size = Vector3.new(28, 12, 2),
	Position = Vector3.new(px, py + 12, pz - 40),
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(40, 90, 60),
}, root)

-- ===== BUS (transisi miqat -> Makkah; dibaca PlaceContext.Miqat / BusRide) =====
local bx, bz = 60, -10
local by = terrainY(bx, bz) or 0
local bus = part({
	Name = "Bus",
	Size = Vector3.new(12, 9, 32),
	Position = Vector3.new(bx, by + 4.5, bz),
	Material = Enum.Material.Metal,
	Color = Color3.fromRGB(60, 120, 90),
}, workspace)
-- kaca depan (penanda arah; anak bus, BusRide tetap baca BasePart "Bus")
part({
	Name = "Kaca",
	Size = Vector3.new(11, 4, 1),
	Position = Vector3.new(bx, by + 7, bz - 16),
	Material = Enum.Material.Glass,
	Color = Color3.fromRGB(150, 200, 220),
	Transparency = 0.3,
}, bus)

print(("[Miqat] Selesai utk '%s' (%s). Workspace: Miqat{Peron,Papan} + Bus."):format(tostring(placeName), label))
