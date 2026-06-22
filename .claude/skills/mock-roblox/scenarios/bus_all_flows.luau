--!nocheck
-- Uji STRUKTURAL Flows — pastikan tiap alur (Umrah + 3 haji) punya tahap BusRide (place "Miqat",
-- ritual "BusRide") yang berada SESUDAH ihram dan SEBELUM tahap Makkah pertama. Membuktikan
-- konsistensi transisi miqat→Makkah lewat bus di semua alur. Global: `h`, `meta`.

meta("mechanism", "Flows (struktural)")
meta("title", "BusRide miqat→Makkah konsisten di semua alur")

local Flows = h.require("Flows")

local function check(flowName)
	local flow = Flows[flowName]
	if not flow then
		h.event("note", { text = flowName .. ": ALUR TAK ADA ❌" })
		return
	end
	local ihramIdx, busIdx, makkahIdx
	for i, stage in ipairs(flow) do
		if not ihramIdx and stage.ritual == "IhramChange" then
			ihramIdx = i
		end
		if not busIdx and stage.place == "Miqat" and stage.ritual == "BusRide" then
			busIdx = i
		end
		if not makkahIdx and stage.place == "Makkah" then
			makkahIdx = i
		end
	end
	local ok = busIdx ~= nil
		and (not ihramIdx or ihramIdx < busIdx)
		and (not makkahIdx or busIdx < makkahIdx)
	h.event("note", {
		text = ("%s: ihram=%s bus=%s makkah1=%s → %s"):format(
			flowName, tostring(ihramIdx), tostring(busIdx), tostring(makkahIdx), ok and "OK ✅" or "GAGAL ❌"
		),
	})
end

check("Umrah")
check("HajiTamattu")
check("HajiIfrad")
check("HajiQiran")
