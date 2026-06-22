--!strict
-- LobbyClient.client.lua — UI Panduan & pemilih ibadah/miqat di Lobby (Devi). STUB minimal.
-- Di Studio: ganti dengan GUI sesungguhnya (kartu 4 jenis ibadah + deskripsi, pilihan miqat per
-- gelombang, tombol "Mulai"). Saat pemain menekan "Mulai", fire StartManasik(ibadahType, chosenMiqat).
--
-- Nilai pilihan HARUS dari daftar valid:
--   ibadahType : "Umrah" | "HajiTamattu" | "HajiIfrad" | "HajiQiran"  (kunci Flows)
--   chosenMiqat: salah satu LobbyStart.MIQATS (mis. "Miqat_BirAli")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("StartManasik") :: RemoteEvent

-- API lokal yang dipanggil GUI saat tombol "Mulai" ditekan.
local LobbyClient = {}

function LobbyClient.start(ibadahType: string, chosenMiqat: string)
	remote:FireServer(ibadahType, chosenMiqat)
end

-- TODO(Studio): bangun ScreenGui — kartu jenis ibadah + pilihan miqat (gelombang I → Bir Ali;
-- gelombang II → Yalamlam/Qarnul Manazil) → panggil LobbyClient.start(pilihan).
-- Contoh dev (hapus saat GUI siap):
--   LobbyClient.start("Umrah", "Miqat_BirAli")

return LobbyClient
