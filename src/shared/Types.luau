--!strict
-- Shared type definitions for Kaiju Park.
-- Species = static, documented data (Docs/Kaju game.pdf). OwnedKaiju = a player's individual instance.

export type KL = number -- Kaiju Level classification, 1..5. NOT the progression level.

export type KaijuStats = {
	durability: number,
	damage: number,
	mobility: number,
	stamina: number,
	intelligence: number,
}

export type Dimension = {
	kind: string, -- "height" | "length" | "wingspan" | "bodyLength" | "tailLength"
	text: string, -- exactly as written in the reference document
	meters: number?, -- parsed approximate value, informational only (never drives in-game scale)
	note: string?,
}

export type RGB = { number } -- {r, g, b} 0..255; kept engine-free so data can be tested outside Roblox

export type KaijuVisual = {
	-- placeholder body plan: "crawler" | "blob" | "flyer" | "fish" | "jelly" | "quadruped" | "serpent" | "biped"
	archetype: string,
	primary: RGB,
	secondary: RGB,
	accent: RGB,
	scale: number, -- placeholder size multiplier on top of the per-KL base (independent from real dimensions)
}

export type KaijuSpecies = {
	id: string, -- stable internal id
	displayName: string, -- exactly as written in the reference PDF
	nameVariants: { string }?, -- other spellings found in the docs
	kl: KL,
	threatRating: number,
	traits: { string }, -- exactly three, as documented
	stats: KaijuStats,
	statAnnotations: { [string]: string }?, -- raw stat text when the document shows more than a number
	documentedTotal: number,
	dimensions: { Dimension },
	notes: { string }?, -- documented ambiguities preserved for review
	visual: KaijuVisual,
}

export type OwnedKaiju = {
	instanceId: string,
	speciesId: string,
	level: number, -- progression level 1..40 (separate from KL)
	capturedAt: number,
	nickname: string?,
}

export type PlacedEnclosure = {
	enclosureId: string,
	sizeId: string, -- "Small" | "Medium" | "Large"
	slot: number, -- park grid slot index
	kaijuInstanceId: string?,
}

export type PlayerData = {
	schemaVersion: number,
	money: number,
	kaijuCells: number,
	chainTier: number,
	kaijus: { [string]: OwnedKaiju },
	enclosures: { [string]: PlacedEnclosure },
	nextId: number,
	starterGranted: boolean,
	stats: { battlesWon: number, battlesLost: number, captures: number },
}

-- Roblox ModuleScripts must return a non-nil value.
return {}
