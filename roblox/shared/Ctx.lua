--!strict
-- Ctx.lua — KONTRAK TIPE untuk `ctx` mekanisme (satu sumber kebenaran shape ctx). Produsen ctx =
-- server/PlaceContext (per place); konsumen = shared/mechanisms/* di M.activate(ctx). Dulu `ctx`
-- bertipe `any` di kedua sisi → salah-eja field (mis. `ctx.centre`) lolos diam-diam. Dengan tipe
-- ini, mengakses field yang TIDAK ada di kontrak = error analisis (luau-analyze di Studio/CI).
--
-- Catatan: tipe Luau DIHAPUS saat runtime — modul ini tak mengubah perilaku, hanya dokumentasi yang
-- bisa dicek statis. Semua field opsional (konservatif: konsumen sudah menjaga `ctx and ctx.x`).
-- Modul mengembalikan tabel kosong; yang berguna adalah tipe yang di-export.

export type Base = { player: Player?, place: string? }

-- Devi
export type IhramChange = Base & { ibadahType: string?, config: { auto: boolean? }? }
export type IhramRules = Base & { gender: string? }
export type Tawaf = Base & {
	center: Vector3?,
	getPosition: (() -> Vector3)?,
	direction: number?,
	config: { target: number?, maxRadius: number? }?,
}
export type Sai = Base & {
	shafa: (Vector3 | BasePart)?,
	marwah: (Vector3 | BasePart)?,
	getPosition: (() -> Vector3)?,
	config: { target: number?, reachRadius: number? }?,
}

-- Nabil
export type IhramHaji = Base & { station: BasePart? }
export type Wukuf = Base & { zonePart: BasePart?, startPresent: boolean?, config: { wukufSeconds: number? }? }
export type Mabit = Base & {
	zonePart: BasePart?,
	startPresent: boolean?,
	label: string?,
	config: { mabitSeconds: number? }?,
}
export type Pebble = Base & { pebbles: { BasePart }?, config: { target: number? }? }
export type Tahallul = Base & { mode: string?, station: BasePart? }

-- Praditama
export type Bus = Base & { busPart: BasePart?, destinationLabel: string?, config: { rideSeconds: number?, autoBoard: boolean? }? }
export type Jumrah = Base & {
	mode: string?,
	pillars: { [string]: BasePart }?,
	config: { throwsPerPillar: number?, hitChance: number?, nafar: string? }?,
}
export type Qurban = Base & {
	damRequired: boolean?,
	station: BasePart?,
	config: { processSeconds: number?, defaultAnimal: string? }?,
}

return {}
