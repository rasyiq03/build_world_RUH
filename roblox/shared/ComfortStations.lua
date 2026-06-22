--!strict
-- ComfortStations.lua — amenitas AMBIENT (bukan ritual alur manasik): Zamzam, Kursi Roda,
-- Area Istirahat. Pemilik: Praditama. Dipasang skrip place (Mina; bisa dipakai ulang di Makkah,
-- miqat, dll) pada Part penanda dari dunia hasil build — TIDAK lewat ManasikRunner/Flows.
--
-- Interaksi (proximity + klik, berulang): tiap stasiun pasang ProximityPrompt. Tiap pabrik
-- mengembalikan handle { use(player), destroy() }; ProximityPrompt memanggil `use`, dan uji
-- headless memanggil `use` langsung (mock tak punya ProximityPrompt). Efek dijaga pcall agar
-- aman tanpa Humanoid/atribut (headless); umpan balik utama lewat Notify.

local Notify = require(script.Parent.Notify)

local ComfortStations = {}

-- Pasang ProximityPrompt (game asli) + sambung ke onUse. Aman headless (dibungkus pcall).
local function attachPrompt(part: BasePart, actionText: string, objectText: string, onUse: (Player) -> ()): any?
	local conn: any = nil
	local ok = pcall(function()
		local p = Instance.new("ProximityPrompt")
		p.ActionText = actionText
		p.ObjectText = objectText
		p.MaxActivationDistance = 12
		p.Parent = part
		conn = p.Triggered:Connect(function(plr)
			onUse(plr)
		end)
	end)
	if not ok then
		warn(("[ComfortStations] ProximityPrompt tak tersedia (headless) — %s pakai handle.use."):format(objectText))
	end
	return conn
end

local function findHumanoid(player: Player): any?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- ZAMZAM — minum air zamzam (berulang). Menyegarkan; setel atribut Thirst=0, hitung tegukan.
function ComfortStations.zamzam(part: BasePart, opts: any?): any
	local handle = {}
	function handle.use(player: Player)
		pcall(function()
			local n = (player:GetAttribute("ZamzamDrinks") or 0) + 1
			player:SetAttribute("ZamzamDrinks", n)
			player:SetAttribute("Thirst", 0)
		end)
		Notify.toPlayer(player, "Anda meminum air zamzam — segar dan berkah. Bismillah.")
	end
	handle._conn = attachPrompt(part, "Minum Zamzam", "Air Zamzam", handle.use)
	function handle.destroy()
		if handle._conn then handle._conn:Disconnect() end
	end
	return handle
end

-- KURSI RODA — ambil/kembalikan kursi roda (aksesibilitas). Toggle WalkSpeed + atribut.
function ComfortStations.wheelchair(part: BasePart, opts: any?): any
	local boost = (opts and opts.walkSpeed) or 24
	local using: { [Player]: boolean } = {}
	local handle = {}
	function handle.use(player: Player)
		if using[player] then
			using[player] = nil
			pcall(function()
				player:SetAttribute("UsingWheelchair", false)
				local h = findHumanoid(player)
				if h then h.WalkSpeed = 16 end
			end)
			Notify.toPlayer(player, "Kursi roda dikembalikan. Semoga lancar ibadahnya.")
		else
			using[player] = true
			pcall(function()
				player:SetAttribute("UsingWheelchair", true)
				local h = findHumanoid(player)
				if h then h.WalkSpeed = boost end
			end)
			Notify.toPlayer(player, "Anda memakai kursi roda — bergerak lebih ringan menyusuri jalur.")
		end
	end
	handle._conn = attachPrompt(part, "Kursi Roda", "Layanan Kursi Roda", handle.use)
	function handle.destroy()
		if handle._conn then handle._conn:Disconnect() end
	end
	return handle
end

-- AREA ISTIRAHAT — beristirahat di tenda; pulihkan stamina, tandai "rested".
function ComfortStations.restArea(part: BasePart, opts: any?): any
	local maxStamina = (opts and opts.maxStamina) or 100
	local handle = {}
	function handle.use(player: Player)
		pcall(function()
			player:SetAttribute("Stamina", maxStamina)
			player:SetAttribute("Rested", true)
		end)
		Notify.toPlayer(player, "Anda beristirahat sejenak — tenaga pulih, siap melanjutkan manasik.")
	end
	handle._conn = attachPrompt(part, "Istirahat", "Area Istirahat", handle.use)
	function handle.destroy()
		if handle._conn then handle._conn:Disconnect() end
	end
	return handle
end

return ComfortStations
