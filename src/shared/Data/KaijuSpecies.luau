--!strict
-- Kaiju species definitions. SOURCE OF TRUTH: Docs/Kaju game.pdf (one page per species).
-- Names, traits, stats, threat ratings and dimension texts are copied exactly as documented,
-- including unusual spellings. Do not "fix" them here; record questions in
-- Docs/IMPLEMENTATION_DECISIONS.md instead.
--
-- `visual` is NOT documented data: it is placeholder presentation (colors sampled from each PDF page,
-- a rough body plan) used until real models exist.

local Types = require("../Types")

type KaijuSpecies = Types.KaijuSpecies

local list: { KaijuSpecies } = {
	-- ───────────────────────────── KL 1 ─────────────────────────────
	{
		id = "kragmor",
		displayName = "Kragmor",
		kl = 1,
		threatRating = 1.2,
		traits = { "Vibration Sense", "Razor Claws", "Armored Carapace" },
		stats = { durability = 30, damage = 20, mobility = 30, stamina = 10, intelligence = 10 },
		documentedTotal = 100,
		dimensions = {
			{ kind = "height", text = "Height 2,5m", meters = 2.5 },
		},
		visual = {
			archetype = "crawler",
			primary = { 105, 108, 122 },
			secondary = { 60, 60, 68 },
			accent = { 196, 28, 64 },
			scale = 1,
		},
	},
	{
		id = "chomp_chomp",
		displayName = "Chomp Chomp",
		kl = 1,
		threatRating = 1.4,
		traits = { "Big chomps", "Night Raid", "Turbo Roll" },
		stats = { durability = 20, damage = 50, mobility = 40, stamina = 10, intelligence = 30 },
		documentedTotal = 150,
		dimensions = {
			{ kind = "height", text = "Height 3m", meters = 3 },
		},
		visual = { archetype = "blob", primary = { 38, 38, 42 }, secondary = { 70, 70, 76 }, accent = { 240, 240, 240 }, scale = 0.9 },
	},
	{
		id = "popcorn",
		displayName = "Popcorn",
		kl = 1,
		threatRating = 0.8,
		traits = { "Lays big eggs", "Heating", "Cutsie" },
		stats = { durability = 30, damage = 5, mobility = 5, stamina = 50, intelligence = 80 },
		documentedTotal = 170,
		dimensions = {
			{ kind = "height", text = "Height 10m", meters = 10 },
		},
		notes = { 'Page shows a small unexplained label "supergiant star" above the name.' },
		visual = { archetype = "blob", primary = { 246, 244, 236 }, secondary = { 180, 22, 36 }, accent = { 242, 140, 40 }, scale = 1.1 },
	},
	{
		id = "eye_bat",
		displayName = "Eye bat",
		nameVariants = { "Eye Bat" },
		kl = 1,
		threatRating = 1.5,
		traits = { "Night vision", "Comp", "Shlorp" },
		stats = { durability = 50, damage = 40, mobility = 30, stamina = 30, intelligence = 40 },
		documentedTotal = 190,
		dimensions = {
			{ kind = "height", text = "Height 6m", meters = 6 },
			{ kind = "wingspan", text = "Wingspan: ~14m", meters = 14 },
		},
		visual = { archetype = "flyer", primary = { 122, 52, 84 }, secondary = { 80, 36, 60 }, accent = { 220, 30, 40 }, scale = 1 },
	},

	-- ───────────────────────────── KL 2 ─────────────────────────────
	{
		id = "great_tusk",
		displayName = "Great tusk",
		nameVariants = { "Great Tusk" },
		kl = 2,
		threatRating = 1.6,
		traits = { "Ram", "Speed boost", "See in dark" },
		stats = { durability = 70, damage = 60, mobility = 40, stamina = 40, intelligence = 10 },
		documentedTotal = 220,
		dimensions = {
			{ kind = "length", text = "Length: 118m", meters = 118 },
		},
		visual = { archetype = "fish", primary = { 150, 122, 112 }, secondary = { 92, 70, 66 }, accent = { 120, 24, 40 }, scale = 1 },
	},
	{
		id = "jellqouia",
		displayName = "Jellqouia",
		kl = 2,
		threatRating = 2.0,
		traits = { "Glide", "Ooze (+plant, -animal)", "Boing! (bouncy)" },
		stats = { durability = 120, damage = 50, mobility = 40, stamina = 30, intelligence = 5 },
		documentedTotal = 245,
		dimensions = {
			{ kind = "length", text = "Length: 67 m", meters = 67 },
		},
		visual = { archetype = "jelly", primary = { 232, 44, 168 }, secondary = { 160, 20, 120 }, accent = { 255, 150, 220 }, scale = 1 },
	},
	{
		id = "killerspotts",
		displayName = "KillerSpotts",
		kl = 2,
		threatRating = 2.0,
		traits = { "Bite", "Telepathic(hive mind)", "Horne tackel" },
		stats = { durability = 40, damage = 50, mobility = 90, stamina = 50, intelligence = 30 },
		documentedTotal = 260,
		dimensions = {
			{ kind = "length", text = "Length: 42 m", meters = 42 },
		},
		visual = { archetype = "quadruped", primary = { 200, 200, 204 }, secondary = { 40, 40, 44 }, accent = { 196, 30, 40 }, scale = 1 },
	},

	-- ───────────────────────────── KL 3 ─────────────────────────────
	{
		id = "wormhole",
		displayName = "Wormhole",
		kl = 3,
		threatRating = 4.2,
		traits = { "Corrosion", "Distance Traveling*", "Excavation" },
		stats = { durability = 70, damage = 130, mobility = 50, stamina = 60, intelligence = 50 },
		statAnnotations = { mobility = "50 (150)" },
		documentedTotal = 360,
		dimensions = {
			{ kind = "length", text = "Length: ~326m (head to tail, stretched)", meters = 326 },
		},
		notes = {
			'Mobility is written "50 (150)". The documented Total (360) uses 50; meaning of 150 is unexplained.',
			'Trait "Distance Traveling*" has an asterisk with no footnote.',
		},
		visual = { archetype = "serpent", primary = { 92, 52, 30 }, secondary = { 60, 34, 20 }, accent = { 214, 120, 44 }, scale = 1 },
	},
	{
		id = "obio_16",
		displayName = "Obio 16",
		kl = 3,
		threatRating = 4.8,
		traits = { "Sword slash", "Het detector", "Infect" },
		stats = { durability = 150, damage = 140, mobility = 20, stamina = 50, intelligence = 20 },
		documentedTotal = 380,
		dimensions = {
			{ kind = "height", text = "Height: ~ 70 m", meters = 70 },
		},
		notes = { "A biohazard symbol is shown next to the name." },
		visual = { archetype = "biped", primary = { 132, 132, 138 }, secondary = { 70, 70, 76 }, accent = { 246, 214, 40 }, scale = 1 },
	},

	-- ───────────────────────────── KL 4 ─────────────────────────────
	{
		id = "leazorn",
		displayName = "Leazorn",
		kl = 4,
		threatRating = 5.0,
		traits = { "Tung trap", "Crunch", "Camo" },
		stats = { durability = 70, damage = 100, mobility = 110, stamina = 60, intelligence = 80 },
		documentedTotal = 420,
		dimensions = {
			{ kind = "length", text = "Length: ~100m (head to tail, stretched)", meters = 100 },
		},
		visual = { archetype = "quadruped", primary = { 58, 160, 104 }, secondary = { 34, 100, 64 }, accent = { 180, 30, 40 }, scale = 1 },
	},
	{
		id = "hornet",
		displayName = "Hornet",
		kl = 4,
		threatRating = 5.7,
		traits = { "Hed stab", "Arme slash", "Tail swing" },
		stats = { durability = 170, damage = 100, mobility = 100, stamina = 70, intelligence = 10 },
		documentedTotal = 450,
		dimensions = {
			{ kind = "length", text = "Length: ~130m (head to tail, stretched)", meters = 130 },
			{ kind = "wingspan", text = "Wingspan: ~150m", meters = 150 },
		},
		visual = { archetype = "quadruped", primary = { 24, 24, 48 }, secondary = { 210, 210, 220 }, accent = { 120, 60, 255 }, scale = 1 },
	},
	{
		id = "night_angel",
		displayName = "Night Angel",
		kl = 4,
		threatRating = 5.3,
		traits = { "Flight", "Intimidation", "Illusions" },
		stats = { durability = 30, damage = 90, mobility = 150, stamina = 70, intelligence = 120 },
		documentedTotal = 460,
		dimensions = {
			{ kind = "bodyLength", text = "Body: ~17m", meters = 17 },
			{ kind = "tailLength", text = "Tail: ~15m", meters = 15 },
			{ kind = "wingspan", text = "Wingspan: ~50m", meters = 50 },
		},
		visual = { archetype = "flyer", primary = { 28, 28, 34 }, secondary = { 60, 56, 64 }, accent = { 236, 122, 30 }, scale = 1 },
	},
	{
		id = "cataboulder",
		displayName = "Cataboulder",
		kl = 4,
		threatRating = 4.2,
		traits = { "Color storm", "Roll", "Crunch" },
		stats = { durability = 210, damage = 60, mobility = 60, stamina = 110, intelligence = 30 },
		documentedTotal = 470,
		dimensions = {
			{ kind = "length", text = "Length: ~360m (head to tail, stretched)", meters = 360 },
			{ kind = "height", text = "Height: ~170m", meters = 170 },
		},
		visual = { archetype = "quadruped", primary = { 140, 150, 168 }, secondary = { 60, 170, 70 }, accent = { 70, 210, 240 }, scale = 1.15 },
	},
	{
		id = "korand",
		displayName = "Korand",
		kl = 4,
		threatRating = 5.9,
		traits = { "Atomic breathe", "Shock tail", "Scretche" },
		stats = { durability = 110, damage = 130, mobility = 80, stamina = 70, intelligence = 100 },
		documentedTotal = 490,
		dimensions = {
			{ kind = "height", text = "Height: ~110 m", meters = 110 },
		},
		visual = { archetype = "biped", primary = { 64, 236, 96 }, secondary = { 200, 255, 210 }, accent = { 250, 240, 60 }, scale = 1 },
	},

	-- ───────────────────────────── KL 5 ─────────────────────────────
	{
		id = "cagn",
		displayName = "Cagn",
		kl = 5,
		threatRating = 6.0,
		traits = { "Tusk Strike", "Shell Shock", "Glow Burst" },
		stats = { durability = 130, damage = 140, mobility = 80, stamina = 90, intelligence = 80 },
		documentedTotal = 520,
		dimensions = {
			{ kind = "height", text = "Height: ~100m", meters = 100 },
		},
		visual = { archetype = "quadruped", primary = { 36, 72, 92 }, secondary = { 24, 44, 56 }, accent = { 90, 230, 170 }, scale = 1 },
	},
	{
		id = "doubt",
		displayName = "Doubt",
		kl = 5,
		threatRating = 6.2,
		traits = { "Crushing hand", "Horn slam", "Mega punch" },
		stats = { durability = 180, damage = 130, mobility = 80, stamina = 80, intelligence = 60 },
		documentedTotal = 530,
		dimensions = {
			{ kind = "height", text = "Height: ~120m", meters = 120 },
		},
		visual = { archetype = "biped", primary = { 40, 146, 140 }, secondary = { 200, 200, 196 }, accent = { 236, 120, 128 }, scale = 1 },
	},
	{
		id = "yumir",
		displayName = "Yumir",
		kl = 5,
		threatRating = 6.3,
		traits = { "Fist slam", "Scalding water beam", "Pinche" },
		stats = { durability = 160, damage = 120, mobility = 100, stamina = 70, intelligence = 100 },
		documentedTotal = 550,
		dimensions = {
			{ kind = "height", text = "Height: ~105m", meters = 105 },
		},
		visual = { archetype = "biped", primary = { 40, 50, 62 }, secondary = { 214, 176, 90 }, accent = { 80, 226, 236 }, scale = 1 },
	},
	{
		id = "emperor",
		displayName = "Emperor",
		kl = 5,
		threatRating = 6.9,
		traits = { "Flight", "Fire breath", "Hurricane" },
		stats = { durability = 130, damage = 80, mobility = 160, stamina = 50, intelligence = 160 },
		documentedTotal = 580,
		dimensions = {
			{ kind = "length", text = "Length: ~270m (head to tail, stretched)", meters = 270 },
			{ kind = "wingspan", text = "Wingspan: ~140m", meters = 140 },
		},
		visual = { archetype = "flyer", primary = { 204, 30, 30 }, secondary = { 120, 14, 20 }, accent = { 244, 194, 40 }, scale = 1.1 },
	},
}

return list
