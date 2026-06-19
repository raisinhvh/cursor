-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.EffectData
--
-- Single source of truth for every rollable effect.
-- All fields are read by RollVisuals and RollChooser — no need to pass Odds or Rarity separately.
--
-- Image   : rbxassetid of the 2D preview shown (as a black silhouette) during rolls.
-- Odds    : 0–1 probability weight.  0.1 = "1/10".  Used for weighted pool building.
-- Rarity  : must match a key in RarityData.

return {
	["Inferno"] = {
		DisplayName = "Inferno",
		Image       = "http://www.roblox.com/asset/?id=8508980527",
		Odds        = 0.40,
		Rarity      = "Common",
	},

	["Frostbite"] = {
		DisplayName = "Frostbite",
		Image       = "http://www.roblox.com/asset/?id=130218740",
		Odds        = 0.30,
		Rarity      = "Uncommon",
	},

	["Thunder"] = {
		DisplayName = "Thunder",
		Image       = "http://www.roblox.com/asset/?id=6673967738",
		Odds        = 0.15,
		Rarity      = "Rare",
	},

	["Void"] = {
		DisplayName = "Void",
		Image       = "http://www.roblox.com/asset/?id=6344756217",
		Odds        = 0.1,
		Rarity      = "Epic",
	},

	["Celestial"] = {
		DisplayName = "Celestial",
		Image       = "http://www.roblox.com/asset/?id=1177150746",
		Odds        = 0.05,
		Rarity      = "Legendary",
	},

	-- Add further effects following the same pattern:
	-- ["YourEffect"] = {
	--     DisplayName = "Your Effect",
	--     Image       = "rbxassetid://xxxxxxxxxxxxx",
	--     Odds        = 0.005,
	--     Rarity      = "Mythical",
	-- },
}
