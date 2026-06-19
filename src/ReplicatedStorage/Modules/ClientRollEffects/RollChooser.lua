-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.RollChooser
--
-- Shared weighted-random effect selection. Safe to require from server or client.

local EffectData = require(script.Parent:WaitForChild("EffectData"))

local RollChooser = {}

function RollChooser.BuildPool(effectsList)
	local pool = {}
	for _, name in ipairs(effectsList) do
		local data  = EffectData[name]
		local slots = data and math.max(1, math.round((data.Odds or 0) * 1000)) or 1
		for _ = 1, slots do
			pool[#pool + 1] = name
		end
	end
	return pool
end

function RollChooser.PickRandom(pool)
	if #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

function RollChooser.Choose(effectsList)
	return RollChooser.PickRandom(RollChooser.BuildPool(effectsList))
end

return RollChooser
