--!strict
-- Wardrobe.lua — sistem GANTI BAJU (SYSTEMS_DESIGN, lanjutan). Outfit: "ihram" & "normal". Ganti via
-- STASIUN (ProximityPrompt) — Miqat→ihram, Lobby/Makkah→normal pasca-tahallul. Gating EDUKATIF:
-- ganti ke ihram selalu boleh; ganti ke NORMAL hanya setelah tahallul COMPLETE (sebelum itu ditolak
-- + pesan — bukan blokir progres ritual, tapi mencegah "buka ihram" yang keliru).
--
-- Visual = HumanoidDescription / Shirt+Pants (aset diisi di Studio) — dibungkus pcall, logika tetap
-- teruji headless. State outfit disimpan di PlayerState ("outfit") + atribut karakter. KONTRAK BERSAMA.

local PlayerState = require(script.Parent.PlayerState)
local Notify = require(script.Parent.Notify)

local Wardrobe = {}

-- Registry outfit. shirt/pants/descId = aset Roblox (diisi di Studio); kosong = hanya atribut+warna.
export type Outfit = { label: string, shirt: string?, pants: string?, descId: string?, color: any? }
Wardrobe.OUTFITS = {
	ihram = { label = "Kain Ihram", color = Color3.fromRGB(245, 245, 240) },
	normal = { label = "Baju Normal" },
} :: { [string]: Outfit }

function Wardrobe.current(player: any): string
	return PlayerState.get(player).outfit or "normal"
end

-- Boleh ganti ke `outfit` sekarang? (ok, alasan). ihram = selalu; normal = hanya pasca tahallul COMPLETE.
function Wardrobe.canWear(player: any, outfit: string): (boolean, string?)
	if outfit == "ihram" then
		return true
	end
	if PlayerState.inIhram(player) and PlayerState.tahallulState(player) ~= "COMPLETE" then
		return false, "Anda masih dalam ihram — selesaikan ibadah & tahallul dulu sebelum ganti baju."
	end
	return true
end

-- Terapkan penampilan outfit. Hormati gating (tolak + warn bila tak boleh). Visual pcall (aset Studio).
function Wardrobe.apply(player: any, outfit: string): boolean
	local def = Wardrobe.OUTFITS[outfit]
	if not def then
		return false
	end
	local ok, reason = Wardrobe.canWear(player, outfit)
	if not ok then
		PlayerState.addWarning(player, reason :: string)
		Notify.toPlayer(player, "⚠ " .. (reason :: string))
		return false
	end

	PlayerState.set(player, "outfit", outfit)
	pcall(function()
		local char = player.Character
		if not char then return end
		char:SetAttribute("Outfit", outfit)
		char:SetAttribute("Ihram", outfit == "ihram")
		-- Shirt/Pants bila aset diberi (paling sederhana di Roblox).
		if def.shirt then
			local s = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
			s.ShirtTemplate = def.shirt
			s.Parent = char
		end
		if def.pants then
			local p = char:FindFirstChildOfClass("Pants") or Instance.new("Pants")
			p.PantsTemplate = def.pants
			p.Parent = char
		end
		-- (Alternatif lengkap: Humanoid:ApplyDescription dgn def.descId — diisi di Studio.)
	end)
	Notify.toPlayer(player, ("Mengenakan: %s."):format(def.label))
	return true
end

-- Pasang STASIUN ganti baju di `part` (ProximityPrompt → apply(targetOutfit)). Aman headless (pcall).
function Wardrobe.attachStation(part: any, targetOutfit: string, opts: any?): any
	opts = opts or {}
	local conn: any = nil
	pcall(function()
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = opts.actionText or ("Ganti: " .. (Wardrobe.OUTFITS[targetOutfit] and Wardrobe.OUTFITS[targetOutfit].label or targetOutfit))
		prompt.ObjectText = opts.objectText or "Ganti Baju"
		prompt.MaxActivationDistance = opts.dist or 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		conn = prompt.Triggered:Connect(function(plr)
			Wardrobe.apply(plr, targetOutfit)
		end)
	end)
	return conn
end

return Wardrobe
