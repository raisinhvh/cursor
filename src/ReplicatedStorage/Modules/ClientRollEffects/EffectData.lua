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
		Image       = "rbxassetid://0",   -- TODO: replace with real asset ID
	},

	["Blizzard"] = {
		DisplayName = "Blizzard",
		Image       = "rbxassetid://0",
	},

	["Thunder"] = {
		DisplayName = "Thunder",
		Image       = "rbxassetid://0",
	},

	["Void"] = {
		DisplayName = "Void",
		Image       = "rbxassetid://0",
	},

	["Celestial"] = {
		DisplayName = "Celestial",
		Image       = "rbxassetid://0",
	},

	-- Add further effects following the same pattern.
	-- ["YourEffect"] = {
	--     DisplayName = "Your Effect",
	--     Image       = "rbxassetid://xxxxxxxxxxxxx",
	-- },
}
