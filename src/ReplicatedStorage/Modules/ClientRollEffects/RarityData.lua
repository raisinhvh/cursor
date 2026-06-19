-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.RarityData
--
-- All rarity tiers used by the rolling system.
-- Add, remove, or recolor entries to match your game's rarity ladder.
-- The Tier field controls sort order (1 = most common).

return {
	Common = {
		Tier        = 1,
		DisplayName = "Common",
		Color       = Color3.fromRGB(176, 176, 176),
		OpenSound   = "rbxassetid://9085320874",
		CameraShakeConst = 8,
	},

	Uncommon = {
		Tier        = 2,
		DisplayName = "Uncommon",
		Color       = Color3.fromRGB(94, 196, 94),
		OpenSound   = "rbxassetid://9085320874",
		CameraShakeConst = 70,
	},

	Rare = {
		Tier        = 3,
		DisplayName = "Rare",
		Color       = Color3.fromRGB(73, 143, 225),
		OpenSound   = "rbxassetid://9085320874",
		CameraShakeConst = 25,
	},

	Epic = {
		Tier        = 4,
		DisplayName = "Epic",
		Color       = Color3.fromRGB(163, 73, 225),
		OpenSound   = "rbxassetid://9085320874",
		CameraShakeConst = 30,
	},

	Legendary = {
		Tier        = 5,
		DisplayName = "Legendary",
		Color       = Color3.fromRGB(255, 170, 0),
		OpenSound   = "rbxassetid://9085320874",
		CameraShakeConst = 35,
	},
}
