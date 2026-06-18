-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.RarityData
--
-- All rarity tiers used by the rolling system.
-- Add, remove, or recolor entries to match your game's rarity ladder.
-- The Tier field controls sort order (1 = most common).
--
-- OpenSound        : rbxassetid played when the lootbox lands on this rarity.
-- CameraShakeConst : ScreenShake magnitude on landing (5 = small, 35 = big).

return {
	Common = {
		Tier             = 1,
		DisplayName      = "Common",
		Color            = Color3.fromRGB(176, 176, 176),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 5,
	},

	Uncommon = {
		Tier             = 2,
		DisplayName      = "Uncommon",
		Color            = Color3.fromRGB(94, 196, 94),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 8,
	},

	Rare = {
		Tier             = 3,
		DisplayName      = "Rare",
		Color            = Color3.fromRGB(73, 143, 225),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 12,
	},

	Epic = {
		Tier             = 4,
		DisplayName      = "Epic",
		Color            = Color3.fromRGB(163, 73, 225),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 17,
	},

	Legendary = {
		Tier             = 5,
		DisplayName      = "Legendary",
		Color            = Color3.fromRGB(255, 170, 0),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 22,
	},

	Mythical = {
		Tier             = 6,
		DisplayName      = "Mythical",
		Color            = Color3.fromRGB(220, 50, 50),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 27,
	},

	Divine = {
		Tier             = 7,
		DisplayName      = "Divine",
		Color            = Color3.fromRGB(120, 220, 255),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 31,
	},

	Prismatic = {
		Tier             = 8,
		DisplayName      = "Prismatic",
		Color            = Color3.fromRGB(255, 100, 220),
		OpenSound        = "rbxassetid://0",
		CameraShakeConst = 35,
	},
}
