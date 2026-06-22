--!strict
-- _MechanismKit.lua — utilitas KECIL bersama untuk mekanisme (shared/mechanisms/*). Berawalan "_"
-- agar TIDAK dimuat MechanismRegistry sebagai ritual (lihat MechanismRegistry.load).
--
-- Tujuan: hapus duplikasi identik yang tersebar di banyak mekanisme — (1) pemutusan koneksi saat
-- deactivate, (2) pemasangan ProximityPrompt yang aman headless. BUKAN framework; hanya dua helper.
-- Mekanisme tetap memegang state, tabel `conns`, & kontraknya sendiri (_TEMPLATE.lua).

local Kit = {}

-- Putuskan semua RBXScriptConnection di `conns` lalu kosongkan tabelnya. Dipanggil di M.deactivate().
-- (Menggantikan fungsi `disconnectAll` lokal yang dulu byte-identik di 8 mekanisme.)
function Kit.disconnectAll(conns: { any })
	for _, c in ipairs(conns) do
		if c and c.Disconnect then
			c:Disconnect()
		end
	end
	table.clear(conns)
end

-- Pasang ProximityPrompt di `part` (game asli) lalu sambung Triggered → onTrigger(player). Aman
-- headless: kelas mungkin tak tersedia → dibungkus pcall, kembalikan nil. Mengembalikan koneksi
-- Triggered (atau nil) supaya pemanggil melacaknya: `conns[#conns + 1] = Kit.attachPrompt(...)`.
function Kit.attachPrompt(
	part: BasePart,
	actionText: string,
	objectText: string,
	maxDistance: number,
	onTrigger: (Player) -> ()
): any?
	local conn: any = nil
	local ok = pcall(function()
		local p = Instance.new("ProximityPrompt")
		p.ActionText = actionText
		p.ObjectText = objectText
		p.MaxActivationDistance = maxDistance
		p.Parent = part
		conn = p.Triggered:Connect(onTrigger)
	end)
	if not ok then
		warn(("[MechanismKit] ProximityPrompt tak tersedia (headless) — %s pakai API langsung."):format(objectText))
	end
	return conn
end

return Kit
