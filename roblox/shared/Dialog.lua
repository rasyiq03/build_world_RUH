--!strict
-- Dialog.lua — sistem dialog NPC BERPILIHAN (branching). Data = pohon node; navigasi PURE (teruji
-- headless). Server: Dialog.open(player, tree) → kirim pohon ke client via RemoteEvent "NpcDialog";
-- client (client/DialogClient) merender panel + menangani pilihan LOKAL (tanpa round-trip per pilihan).
-- Pemilik UI: Devi (sejalur HajiGuideUI). KONTRAK BERSAMA.
--
-- Format pohon:
--   tree = {
--     speaker = "Askar",
--     start   = "root",
--     nodes   = { [id] = { text = "...", choices = { { text = "...", to = "<id>"|"close" } } } },
--   }

local UiBridge = require(script.Parent.UiBridge)

local Dialog = {}

export type Choice = { text: string, to: string }
export type Node = { text: string, choices: { Choice }? }
export type Tree = { speaker: string, start: string, nodes: { [string]: Node } }

-- Ambil node; default ke tree.start bila nodeId nil.
function Dialog.node(tree: any, nodeId: string?): any
	if not tree or not tree.nodes then return nil end
	return tree.nodes[nodeId or tree.start]
end

-- Resolusi pilihan: dari `nodeId`, pilih choice index → id node tujuan ("close" = tutup), atau nil.
function Dialog.choose(tree: any, nodeId: string, choiceIndex: number): string?
	local node = Dialog.node(tree, nodeId)
	local c = node and node.choices and node.choices[choiceIndex]
	return c and c.to or nil
end

-- Validasi pohon: start ada; tiap `to` menunjuk node yang ada atau "close". (Untuk uji & sanity.)
function Dialog.validate(tree: any): (boolean, string?)
	if not tree or not tree.nodes then return false, "tree.nodes kosong" end
	if not tree.nodes[tree.start] then return false, "start '" .. tostring(tree.start) .. "' tak ada" end
	for id, node in pairs(tree.nodes) do
		for _, c in ipairs(node.choices or {}) do
			if c.to ~= "close" and not tree.nodes[c.to] then
				return false, ("node '%s' choice → '%s' tak ada"):format(id, tostring(c.to))
			end
		end
	end
	return true
end

-- Buka dialog di client pemain (kirim seluruh pohon; navigasi lokal di client). Lewat UiBridge.
function Dialog.open(player: any, tree: any)
	local ok, err = Dialog.validate(tree)
	if not ok then
		warn("[Dialog] pohon tak valid: " .. tostring(err))
		return
	end
	UiBridge.fireTo(player, UiBridge.EVENTS.NpcDialog, tree)
end

return Dialog
