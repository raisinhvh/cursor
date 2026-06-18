-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.EffectData
--
-- Maps every rollable effect name to its display name and 2D preview image.
-- The Image is shown (as a black silhouette) on the ImageSurface SurfaceGui
-- while the roll is cycling.  Replace every "rbxassetid://0" with the real ID.
--
-- The key MUST match the key used in the optionsTable passed to RollVisuals.Play.

return {
	["Inferno"] = {
		DisplayName = "Inferno",
		Image       = "http://www.roblox.com/asset/?id=8508980527",   -- TODO: replace with real asset ID
	},

	["Blizzard"] = {
		DisplayName = "Blizzard",
		Image       = "http://www.roblox.com/asset/?id=130218740",
	},

	["Thunder"] = {
		DisplayName = "Thunder",
		Image       = "http://www.roblox.com/asset/?id=6673967738",
	},

	["Void"] = {
		DisplayName = "Void",
		Image       = "http://www.roblox.com/asset/?id=6344756217",
	},

	["Celestial"] = {
		DisplayName = "Celestial",
		Image       = "http://www.roblox.com/asset/?id=1177150746",
	},

	-- Add further effects following the same pattern.
	-- ["YourEffect"] = {
	--     DisplayName = "Your Effect",
	--     Image       = "rbxassetid://xxxxxxxxxxxxx",
	-- },
}
