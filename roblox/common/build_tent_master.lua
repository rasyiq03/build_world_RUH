--[[ build_tent_master.lua — Command Bar Studio
  Membuat 1 mesh tenda "TentMaster" TANPA software 3D luar: bangun dari Part +
  WedgePart (atap pelana), lalu Union -> SATU objek (UnionOperation). Hasilnya
  ditaruh di ReplicatedStorage, siap di-Clone per titik oleh build_mina.lua (via MinaTerraces)
  atau place_from_modules.lua (via MinaTents).

  Cara: tempel skrip ini ke Command Bar (View > Command Bar), Enter.
  Lalu jalankan build_mina.lua / place_from_modules.lua (yang menyebar tenda).

  Ukuran dalam studs (skala 4 = 4 m/studs). Ubah konstanta sesuai selera.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local S = 16          -- lebar/panjang dasar tenda (studs)
local WALL_H = 5      -- tinggi dinding
local ROOF_H = 6      -- tinggi atap (puncak pelana)
local TENT_COLOR = Color3.fromRGB(235, 235, 230)  -- putih khas tenda Mina

-- Badan (kotak dinding rendah).
local body = Instance.new("Part")
body.Anchored = true
body.Size = Vector3.new(S, WALL_H, S)
body.CFrame = CFrame.new(0, WALL_H / 2, 0)

-- Atap pelana = dua WedgePart bertemu di bubungan (ridge) tengah.
-- Tiap wedge menutup separuh kedalaman (S/2), miring turun ke sisi luar.
local wedgeA = Instance.new("WedgePart")
wedgeA.Anchored = true
wedgeA.Size = Vector3.new(S, ROOF_H, S / 2)
wedgeA.CFrame = CFrame.new(0, WALL_H + ROOF_H / 2, S / 4)

local wedgeB = Instance.new("WedgePart")
wedgeB.Anchored = true
wedgeB.Size = Vector3.new(S, ROOF_H, S / 2)
-- diputar 180° di Y supaya kemiringannya cermin (membentuk pelana simetris).
wedgeB.CFrame = CFrame.new(0, WALL_H + ROOF_H / 2, -S / 4) * CFrame.Angles(0, math.rad(180), 0)

-- Satukan jadi satu objek (CSG). UnionAsync = method BasePart.
local parts = { wedgeA, wedgeB }
local ok, tent = pcall(function()
	return body:UnionAsync(parts)
end)
if not ok or not tent then
	warn("[Tenda] UnionAsync gagal: " .. tostring(tent) ..
		". Pastikan ketiga part valid; coba lagi. (Atau pakai jalur EditableMesh.)")
	body:Destroy(); wedgeA:Destroy(); wedgeB:Destroy()
	return
end

body:Destroy(); wedgeA:Destroy(); wedgeB:Destroy()

tent.Name = "TentMaster"
tent.Anchored = true
tent.Material = Enum.Material.Fabric
tent.Color = TENT_COLOR
tent.UsePartColor = true
-- Origin di center (penyebar tenda di build_mina/place_from_modules sudah menghitung offset pivot).
tent.Parent = ReplicatedStorage

print(("[Tenda] TentMaster dibuat (Union) di ReplicatedStorage. Size = %s. "):format(tostring(tent.Size))
	.. "Lanjut: jalankan build_mina.lua / place_from_modules.lua (yang menyebar tenda).")
print("Jika atap terbalik, tukar tanda Z kedua wedge atau putar 180° lalu jalankan ulang.")
