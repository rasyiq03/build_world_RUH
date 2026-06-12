--[[ build_makkah.lua — Command Bar Studio  (Zona A: Masjidil Haram)
  Bangun struktur inti Haram (PLACEHOLDER prosedural, diganti model OBJ nanti) dari
  ModuleScript: MakkahLandmarks, MakkahFacade. Semua berpusat Ka'bah.
  Output DIKELOMPOKKAN: Workspace > A_Makkah > {Kaaba, Mataf, MaqamIbrahim,
  HijrIsmail, Masaa, AbrajAlBait, Gerbang, Facade}.

  Prasyarat: terrain Makkah sudah di-generate. Jalankan via Command Bar.
]]

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local terrain = workspace.Terrain

local function loadData(n)
	local m = RS:FindFirstChild(n); if not m or not m:IsA("ModuleScript") then return nil end
	local ok, raw = pcall(require, m); if not ok then return nil end
	local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end); return ok2 and d or nil
end
local function tY(x, z)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { terrain }
	local r = workspace:Raycast(Vector3.new(x, 9000, z), Vector3.new(0, -18000, 0), rp)
	return r and r.Position.Y or nil
end
local root = workspace:FindFirstChild("A_Makkah"); if root then root:Destroy() end
root = Instance.new("Folder"); root.Name = "A_Makkah"; root.Parent = workspace
local function sub(n) local f = Instance.new("Folder"); f.Name = n; f.Parent = root; return f end
local function part(pr, parent) local p = Instance.new("Part"); p.Anchored = true
	for k, v in pairs(pr) do p[k] = v end; p.Parent = parent; return p end

local L = loadData("MakkahLandmarks")
if not L then warn("[Makkah] 'MakkahLandmarks' tak ada."); return end
local kx, kz = L.kaaba.center.x, L.kaaba.center.z
local baseY = tY(kx, kz) or 0

-- ===== MATAF (pelataran marmer putih) =====
do
	local f = sub("Mataf")
	part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, L.mataf.radius * 2, L.mataf.radius * 2),
		CFrame = CFrame.new(kx, baseY + 2, kz) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Marble, Color = Color3.fromRGB(238, 236, 230), Name = "LantaiMataf" }, f)
end

-- ===== KA'BAH (kubus hitam + kiswah emas + pintu + Hajar Aswad) =====
do
	local f = sub("Kaaba")
	local w, h, l = L.kaaba.size.w, L.kaaba.size.h, L.kaaba.size.l
	local cf = CFrame.new(kx, baseY + 4 + h / 2, kz) * CFrame.Angles(0, math.rad(L.kaaba.rot or 30), 0)
	part({ Size = Vector3.new(w, h, l), CFrame = cf, Material = Enum.Material.Fabric,
		Color = Color3.fromRGB(20, 20, 22), Name = "Kaaba" }, f)
	-- kiswah: sabuk kaligrafi emas dekat atas
	part({ Size = Vector3.new(w + 1, h * 0.14, l + 1), CFrame = cf * CFrame.new(0, h * 0.28, 0),
		Material = Enum.Material.Foil, Color = Color3.fromRGB(200, 170, 70), Name = "Sabuk_Kiswah" }, f)
	-- pintu emas (sisi +X), agak tinggi dari lantai
	part({ Size = Vector3.new(1.5, h * 0.5, l * 0.32), CFrame = cf * CFrame.new(w / 2, -h * 0.12, l * 0.12),
		Material = Enum.Material.Foil, Color = Color3.fromRGB(212, 175, 80), Name = "Pintu_Kaabah" }, f)
	-- Hajar Aswad: sudut perak (timur)
	part({ Size = Vector3.new(6, 9, 6), CFrame = cf * CFrame.new(w / 2, -h * 0.33, l / 2),
		Material = Enum.Material.Metal, Color = Color3.fromRGB(190, 190, 195), Name = "Hajar_Aswad" }, f)
end

-- ===== HIJR ISMAIL (tembok melengkung setengah lingkaran, sisi NW) =====
do
	local f = sub("HijrIsmail")
	local hi = L.hijr_ismail
	local cx, cz, r, wh = hi.center.x, hi.center.z, hi.radius, hi.wall_h
	local n = 16
	for i = 0, n do
		local a = math.rad(180) + (math.rad(180) * i / n)  -- setengah lingkaran
		local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		local y = tY(x, z) or baseY
		part({ Size = Vector3.new(6, wh + 6, 4), CFrame = CFrame.new(x, y + (wh + 6) / 2, z)
			* CFrame.Angles(0, a + math.rad(90), 0), Material = Enum.Material.Marble,
			Color = Color3.fromRGB(235, 232, 224), Name = "Hateem" }, f)
	end
end

-- ===== MAQAM IBRAHIM (kubah kecil kaca-emas) =====
do
	local f = sub("MaqamIbrahim")
	local mq = L.maqam_ibrahim
	local y = tY(mq.x, mq.z) or baseY
	part({ Size = Vector3.new(mq.dome_d, mq.dome_d, mq.dome_d), CFrame = CFrame.new(mq.x, y + mq.dome_d / 2 + 4, mq.z),
		Material = Enum.Material.Glass, Color = Color3.fromRGB(210, 190, 120), Transparency = 0.3, Name = "Maqam_Ibrahim" }, f)
end

-- ===== MAS'A (lorong Safa-Marwah + zona lampu hijau) =====
do
	local f = sub("Masaa")
	local sa, mw = L.masaa.safa, L.masaa.marwah
	local mid = Vector3.new((sa.x + mw.x) / 2, 0, (sa.z + mw.z) / 2)
	local len = math.sqrt((sa.x - mw.x) ^ 2 + (sa.z - mw.z) ^ 2)
	local ya = tY(mid.X, mid.Z) or baseY
	-- lantai lorong
	part({ Size = Vector3.new(L.masaa.width, 3, len), CFrame = CFrame.new(mid.X, ya + 2, mid.Z),
		Material = Enum.Material.Marble, Color = Color3.fromRGB(232, 230, 224), Name = "Lantai_Masaa" }, f)
	-- bukit Safa & Marwah (batu)
	for _, h in ipairs({ { sa, "Safa" }, { mw, "Marwah" } }) do
		local pt, nm = h[1], h[2]; local y = tY(pt.x, pt.z) or baseY
		part({ Size = Vector3.new(40, 30, 40), Position = Vector3.new(pt.x, y + 15, pt.z),
			Material = Enum.Material.Rock, Color = Color3.fromRGB(150, 140, 125), Name = "Bukit_" .. nm }, f)
	end
	-- zona lampu hijau (di tengah, di atas)
	local g = L.masaa.green_zone
	part({ Size = Vector3.new(L.masaa.width, 2, g[2] - g[1]), CFrame = CFrame.new(mid.X, ya + 40, mid.Z),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(60, 240, 90), Name = "GreenLight_Zone" }, f)
end

-- ===== ABRAJ AL-BAIT (menara jam) =====
do
	local f = sub("AbrajAlBait")
	local c = L.clock_tower; local y = tY(c.x, c.z) or baseY
	local H = c.height
	part({ Size = Vector3.new(160, H, 160), Position = Vector3.new(c.x, y + H / 2, c.z),
		Material = Enum.Material.Concrete, Color = Color3.fromRGB(180, 170, 150), Name = "Menara_Abraj" }, f)
	-- jam hijau 4 sisi dekat puncak
	for _, d in ipairs({ Vector3.new(82, 0, 0), Vector3.new(-82, 0, 0), Vector3.new(0, 0, 82), Vector3.new(0, 0, -82) }) do
		part({ Size = Vector3.new(60, 60, 4), Position = Vector3.new(c.x, y + H * 0.86, c.z) + d,
			Material = Enum.Material.Neon, Color = Color3.fromRGB(c.clock_color[1], c.clock_color[2], c.clock_color[3]),
			Name = "Jam", CanCollide = false }, f)
	end
	part({ Size = Vector3.new(20, 120, 20), Position = Vector3.new(c.x, y + H + 60, c.z),
		Material = Enum.Material.Foil, Color = Color3.fromRGB(210, 180, 90), Name = "Puncak" }, f)
end

-- ===== GERBANG =====
do
	local f = sub("Gerbang")
	for _, g in ipairs(L.gates or {}) do
		local y = tY(g.x, g.z) or baseY
		for _, sgn in ipairs({ -1, 1 }) do
			part({ Size = Vector3.new(10, 90, 10), Position = Vector3.new(g.x + sgn * 30, y + 45, g.z),
				Material = Enum.Material.Marble, Color = Color3.fromRGB(235, 230, 220), Name = g.name .. "_Tiang" }, f)
		end
		part({ Size = Vector3.new(80, 16, 12), Position = Vector3.new(g.x, y + 96, g.z),
			Material = Enum.Material.Foil, Color = Color3.fromRGB(212, 180, 90), Name = g.name }, f)
	end
end

-- ===== FAÇADE (cincin bangunan luar = dinding pembatas) =====
local F = loadData("MakkahFacade")
if F then
	local f = sub("Facade")
	local H = 160
	for _, b in ipairs(F.buildings or {}) do
		local poly = b.polygon; if poly and #poly >= 3 then
			local sumY, n = 0, 0
			for _, p in ipairs(poly) do local y = tY(p.x, p.z); if y then sumY += y; n += 1 end end
			if n > 0 then
				local baseY2 = sumY / n
				local model = Instance.new("Model"); model.Name = (b.name ~= "" and b.name) or "Gedung"; model.Parent = f
				for i = 1, #poly do
					local a, c = poly[i], poly[(i % #poly) + 1]
					local va = Vector3.new(a.x, baseY2 + H / 2, a.z); local vb = Vector3.new(c.x, baseY2 + H / 2, c.z)
					local d = (va - vb).Magnitude
					if d > 0.1 then
						part({ Size = Vector3.new(3, H, d + 1), CFrame = CFrame.lookAt((va + vb) / 2, vb),
							Material = Enum.Material.Concrete, Color = Color3.fromRGB(205, 200, 190) }, model)
					end
				end
			end
		end
	end
	print(("[Makkah] Façade: %d gedung cincin."):format(#(F.buildings or {})))
end

print("[Makkah] Selesai. Workspace > A_Makkah > {Kaaba, Mataf, MaqamIbrahim, HijrIsmail, Masaa, AbrajAlBait, Gerbang, Facade}.")
