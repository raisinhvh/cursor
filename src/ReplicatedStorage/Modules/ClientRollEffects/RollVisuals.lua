-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.RollVisuals
--
-- Client-side rolling visuals sequence (Sol's RNG style — single display surface).
--
-- API:
--   RollVisuals.Play(chosenEffect: string, effectsList: {string}, onComplete: function?)
--
-- effectsList is a plain array of effect name keys that should appear in the roll pool,
-- e.g. { "Inferno", "Blizzard", "Thunder" }.  Odds and Rarity are read from EffectData.
--
-- Workspace.Cutscene must contain:
--   Anchor        BasePart  — camera origin
--   ImageSurface  BasePart  — display surface
--                              └ SurfaceGui  "ImageSurface"
--                                  └ ImageLabel "ImageSurface"
--   Sunburst      BasePart  — background decoration (rotates during roll)
--                              └ SurfaceGui  "Sunburst"
--                                  └ ImageLabel "Sunburst"
--   ParticleBlock BasePart  — position handed off to ParticlePlayer on landing
--
-- The whole Cutscene model is cloned from ReplicatedStorage for each roll and
-- destroyed on cleanup.

local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientRollEffects = script.Parent
local RarityData = require(ClientRollEffects:WaitForChild("RarityData"))
local EffectData = require(ClientRollEffects:WaitForChild("EffectData"))

-- ParticlePlayer is loaded lazily so a missing module never breaks rolls.
-- Hook: ReplicatedStorage.Modules.ParticlePlayer.Play(effectName, position)
local ParticlePlayer
pcall(function()
	ParticlePlayer = require(
		script.Parent.Parent:WaitForChild("ParticlePlayer", 2)
	)
end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------
local ROLL_DURATION    = 3       -- seconds for the full roll
local TICK_FAST        = 0.016   -- ~60 hz — "super fast" at the start
local TICK_SLOW        = 0.55    -- ~2 ticks/sec — "super slow" near landing
local FADE_DURATION    = 0.35    -- screen crossfade
local FOV_DEFAULT      = 70
local FOV_ROLL         = 60
local POST_LAND_PAUSE  = 2.0     -- seconds the result is held on screen
local SUNBURST_SPEED   = 25      -- degrees per second
local SOUND_ID         = "rbxassetid://0"  -- TODO: replace with CS:GO unboxing ID

-- TweenInfos
local TI_FADE    = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear)
local TI_FOV_IN  = TweenInfo.new(1.5,  Enum.EasingStyle.Quad,    Enum.EasingDirection.Out)
local TI_FOV_OUT = TweenInfo.new(0.55, Enum.EasingStyle.Elastic,  Enum.EasingDirection.Out)
local TI_CAM_IN  = TweenInfo.new(1.0,  Enum.EasingStyle.Elastic,  Enum.EasingDirection.Out)

------------------------------------------------------------------------
-- Weighted random pool
-- Each effect is added (odds × 1000) times so fractional weights resolve
-- to whole-number slot counts without bias.
-- effectsList is a plain array of effect name strings.
------------------------------------------------------------------------
local function buildPool(effectsList)
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

local function pickRandom(pool)
	return pool[math.random(1, #pool)]
end

------------------------------------------------------------------------
-- Odds → "1/X" string
------------------------------------------------------------------------
local function toFraction(odds)
	if not odds or odds <= 0 then return "1/???" end
	return "1/" .. tostring(math.round(1 / odds))
end

------------------------------------------------------------------------
-- Fade overlay (ScreenGui with a black Frame)
------------------------------------------------------------------------
local function makeFadeOverlay()
	local gui          = Instance.new("ScreenGui")
	gui.Name           = "RollFade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn   = false
	gui.DisplayOrder   = 999

	local frame                    = Instance.new("Frame")
	frame.Size                     = UDim2.fromScale(1, 1)
	frame.BackgroundColor3         = Color3.new(0, 0, 0)
	frame.BackgroundTransparency   = 1  -- invisible initially
	frame.BorderSizePixel          = 0
	frame.ZIndex                   = 100
	frame.Parent                   = gui

	gui.Parent = player.PlayerGui
	return gui, frame
end

-- Plays a tween and yields until it completes. Must be called inside a task.
local function awaitTween(tween)
	tween:Play()
	tween.Completed:Wait()
end

------------------------------------------------------------------------
-- Text labels on ImageSurface's SurfaceGui
-- Three stacked labels: effect name → odds fraction → rarity name
------------------------------------------------------------------------
local function buildTextLabels(surfaceGui)
	local function make(name, anchorY, height, z)
		local lbl                    = Instance.new("TextLabel")
		lbl.Name                     = name
		lbl.Size                     = UDim2.new(0.9, 0, height, 0)
		lbl.AnchorPoint              = Vector2.new(0.5, 0.5)
		lbl.Position                 = UDim2.new(0.5, 0, anchorY, 0)
		lbl.BackgroundTransparency   = 1
		lbl.TextColor3               = Color3.new(1, 1, 1)
		lbl.TextScaled               = true
		lbl.Font                     = Enum.Font.GothamBold
		lbl.Text                     = ""
		lbl.ZIndex                   = z
		lbl.Parent                   = surfaceGui
		return lbl
	end

	-- Lower third of the surface; each label sits below the previous
	local nameLabel   = make("EffectName",  0.68, 0.12, 3)
	local oddsLabel   = make("OddsLabel",   0.80, 0.08, 3)
	local rarityLabel = make("RarityLabel", 0.89, 0.09, 3)

	return nameLabel, oddsLabel, rarityLabel
end

------------------------------------------------------------------------
-- Refresh the display surface for a given effect name.
-- All metadata is sourced from EffectData and RarityData.
-- The image is ALWAYS silhouette-black (ImageColor3 = 0,0,0) —
-- the particle sequence handles the final reveal.
------------------------------------------------------------------------
local function refreshDisplay(effectName, imgLabel, nameL, oddsL, rarityL)
	local effect = EffectData[effectName]
	local rarity = effect and RarityData[effect.Rarity]

	if effect and effect.Image then
		imgLabel.Image = effect.Image
	end
	imgLabel.ImageColor3 = Color3.new(0, 0, 0)

	nameL.Text   = (effect and effect.DisplayName) or effectName
	oddsL.Text   = effect and toFraction(effect.Odds) or ""
	rarityL.Text = (effect and effect.Rarity) or ""

	local col          = rarity and rarity.Color or Color3.new(1, 1, 1)
	oddsL.TextColor3   = col
	rarityL.TextColor3 = col
	nameL.TextColor3   = Color3.new(1, 1, 1)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
local RollVisuals = {}
local isRolling   = false

function RollVisuals.Play(chosenEffect, effectsList, onComplete)
	if isRolling then
		warn("[RollVisuals] A roll is already in progress; call ignored.")
		return
	end
	if not EffectData[chosenEffect] then
		warn("[RollVisuals] chosenEffect not found in EffectData:", chosenEffect)
		if onComplete then onComplete() end
		return
	end

	isRolling = true

	task.spawn(function()
		local pool = buildPool(effectsList)

		--------------------------------------------------------------------
		-- 1. Fade to black
		--------------------------------------------------------------------
		local fadeGui, fadeFrame = makeFadeOverlay()
		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 0 }))

		--------------------------------------------------------------------
		-- 2. Clone cutscene while screen is black
		--------------------------------------------------------------------
		local scene         = ReplicatedStorage.ClientAssets:WaitForChild("Cutscene"):Clone()
		scene.Parent        = workspace

		local anchor        = scene:WaitForChild("Anchor")
		local imageSurface  = scene:WaitForChild("ImageSurface")
		local sunburst      = scene:WaitForChild("Sunburst")
		local particleBlock = scene:WaitForChild("ParticleBlock")

		-- ImageSurface Part → SurfaceGui "ImageSurface" → ImageLabel "ImageSurface"
		local imgGui   = imageSurface:WaitForChild("ImageSurface")
		local imgLabel = imgGui:WaitForChild("ImageSurface")

		-- Sunburst Part → SurfaceGui "Sunburst" → ImageLabel "Sunburst"
		local sunLabel = sunburst
			:WaitForChild("Sunburst")
			:WaitForChild("Sunburst")

		local nameL, oddsL, rarityL = buildTextLabels(imgGui)

		--------------------------------------------------------------------
		-- 3. Camera — position at Anchor, start looking straight down
		--------------------------------------------------------------------
		local prevCamType = camera.CameraType
		local prevFOV     = camera.FieldOfView

		camera.CameraType  = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV_DEFAULT

		-- Target: anchor position → looking at ImageSurface
		local targetCF = CFrame.lookAt(anchor.Position, imageSurface.Position)

		-- Down start: tiny forward bias prevents gimbal at exactly (0,-1,0)
		local downCF = CFrame.lookAt(
			anchor.Position,
			anchor.Position + Vector3.new(0.001, -1, 0.001)
		)
		camera.CFrame = downCF

		--------------------------------------------------------------------
		-- 4. Begin camera intro (elastic down→up) and FOV tween, then
		--    undarken the screen so the player sees the cutscene mid-sweep
		--------------------------------------------------------------------
		TweenService:Create(camera, TI_CAM_IN, { CFrame      = targetCF }):Play()
		TweenService:Create(camera, TI_FOV_IN, { FieldOfView = FOV_ROLL  }):Play()

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))

		--------------------------------------------------------------------
		-- 5. Unboxing sound (placeholder ID — swap in your CS:GO sound)
		--------------------------------------------------------------------
		local snd     = Instance.new("Sound")
		snd.SoundId   = SOUND_ID
		snd.Volume    = 1
		snd.Parent    = workspace
		snd:Play()

		--------------------------------------------------------------------
		-- 6. Sunburst spin (visual flair during the roll)
		--------------------------------------------------------------------
		local sunAngle = 0
		local sunConn  = RunService.Heartbeat:Connect(function(dt)
			sunAngle          = sunAngle + dt * SUNBURST_SPEED
			sunLabel.Rotation = sunAngle
		end)

		--------------------------------------------------------------------
		-- 7. Rolling heartbeat — exponential slowdown over ROLL_DURATION
		--
		--    interval(progress) = TICK_FAST × (TICK_SLOW/TICK_FAST)^progress
		--    At progress=0  →  TICK_FAST  (~60 hz, "super fast")
		--    At progress=1  →  TICK_SLOW  (~2 hz,  "super slow")
		--------------------------------------------------------------------
		refreshDisplay(pickRandom(pool), imgLabel, nameL, oddsL, rarityL)

		local signal    = Instance.new("BindableEvent")
		local startTime = os.clock()
		local lastTick  = startTime
		local landed    = false
		local rollConn

		rollConn = RunService.Heartbeat:Connect(function()
			if landed then return end

			local now      = os.clock()
			local progress = math.min((now - startTime) / ROLL_DURATION, 1)
			local interval = TICK_FAST * ((TICK_SLOW / TICK_FAST) ^ progress)

			if progress >= 1 then
				landed = true
				rollConn:Disconnect()
				refreshDisplay(chosenEffect, imgLabel, nameL, oddsL, rarityL)
				signal:Fire()
				return
			end

			if now - lastTick >= interval then
				lastTick = now
				refreshDisplay(pickRandom(pool), imgLabel, nameL, oddsL, rarityL)
			end
		end)

		signal.Event:Wait()
		signal:Destroy()

		--------------------------------------------------------------------
		-- 8. Landing
		--------------------------------------------------------------------
		-- FOV elastic snap back to 70 the instant the roll lands
		TweenService:Create(camera, TI_FOV_OUT, { FieldOfView = FOV_DEFAULT }):Play()

		-- Particle handoff — image stays silhouette-black, particles handle visuals
		if ParticlePlayer and ParticlePlayer.Play then
			ParticlePlayer.Play(chosenEffect, particleBlock.Position)
		end
		-- placeholder: wire up ReplicatedStorage.Modules.ParticlePlayer when ready

		--------------------------------------------------------------------
		-- 9. Hold result on screen
		--------------------------------------------------------------------
		task.wait(POST_LAND_PAUSE)

		--------------------------------------------------------------------
		-- 10. Tear down
		--------------------------------------------------------------------
		sunConn:Disconnect()
		snd:Stop()
		snd:Destroy()

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 0 }))

		camera.CameraType  = prevCamType
		camera.FieldOfView = prevFOV
		scene:Destroy()

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))

		fadeGui:Destroy()
		isRolling = false

		if onComplete then
			task.spawn(onComplete)
		end
	end)
end

return RollVisuals
