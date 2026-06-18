local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalServiceClient = require(ReplicatedStorage.Modules.SignalServiceClient)

local ClientRollEffects = script.Parent
local RarityData = require(ClientRollEffects:WaitForChild("RarityData"))
local EffectData = require(ClientRollEffects:WaitForChild("EffectData"))

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
local ROLL_DURATION      = 5      -- seconds for the full roll
local TICK_FAST          = 0.085  -- "super fast" at the start
local TICK_SLOW          = 0.34   -- slowest tick rate (stays smooth)
local FADE_DURATION      = 0.15   -- screen crossfade
local FOV_DEFAULT        = 70
local FOV_ROLL           = 55     -- FOV during the roll
local FOV_LAND           = 85     -- FOV punch target on land
local POST_LAND_PAUSE    = 4      -- seconds the result is held on screen
local SUNBURST_SPEED     = 25     -- degrees per second
local BOUNCE_SCALE       = 1.05   -- how much the surface punches on each tick
local CAMERA_START_PITCH   = -9
local CAMERA_LAND_PITCH    = 9
local CAMERA_LAND_PULLBACK = 2    -- studs pulled back on landing tilt
local CURSOR_FOLLOW_MAX    = 2.5  -- max camera rotation in degrees
local CURSOR_FOLLOW_SMOOTH = 10   -- lerp speed toward cursor target

-- Sounds — replace placeholder IDs with your real asset IDs
local SOUND_OPEN_START = "rbxassetid://0"                -- plays once when the roll sequence begins
local SOUND_TICK       = "rbxassetid://135006148699863"  -- plays on every effect switch
local SOUND_PRE_LAND   = "rbxassetid://89841937506750"   -- plays 2s before the roll finishes

-- Shared font face
local RUBIK_EB = Font.new(
	"rbxasset://fonts/families/Rubik.json",
	Enum.FontWeight.ExtraBold
)

-- TweenInfos
local TI_FADE          = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Linear)
local TI_FOV_ROLL      = TweenInfo.new(ROLL_DURATION, Enum.EasingStyle.Quad,    Enum.EasingDirection.Out)
local TI_FOV_PUNCH     = TweenInfo.new(0.12, Enum.EasingStyle.Linear)
local TI_FOV_SETTLE    = TweenInfo.new(0.9,  Enum.EasingStyle.Elastic,  Enum.EasingDirection.Out)
local TI_CAM_IN        = TweenInfo.new(1.0,  Enum.EasingStyle.Elastic,  Enum.EasingDirection.Out)
local TI_SUNBURST_IN   = TweenInfo.new(1.0,  Enum.EasingStyle.Elastic,  Enum.EasingDirection.Out)
local TI_SUNBURST_FADE = TweenInfo.new(0.15, Enum.EasingStyle.Linear)
local TI_CAMERA_LAND   = TweenInfo.new(0.9,  Enum.EasingStyle.Elastic,  Enum.EasingDirection.Out)
local TI_BOUNCE        = TweenInfo.new(0.12, Enum.EasingStyle.Quad,     Enum.EasingDirection.Out)
local TI_DISPLAY_FADE  = TweenInfo.new(0.25, Enum.EasingStyle.Linear)

------------------------------------------------------------------------
-- Weighted random pool
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
-- Fade overlay
------------------------------------------------------------------------
local function makeFadeOverlay()
	local gui           = Instance.new("ScreenGui")
	gui.Name            = "RollFade"
	gui.IgnoreGuiInset  = true
	gui.ResetOnSpawn    = false
	gui.DisplayOrder    = 999

	local frame                    = Instance.new("Frame")
	frame.Size                     = UDim2.fromScale(1, 1)
	frame.BackgroundColor3         = Color3.new(0, 0, 0)
	frame.BackgroundTransparency   = 1
	frame.BorderSizePixel          = 0
	frame.ZIndex                   = 100
	frame.Parent                   = gui

	gui.Parent = player.PlayerGui
	return gui, frame
end

local function awaitTween(tween)
	tween:Play()
	tween.Completed:Wait()
end

local function addTextStroke(lbl)
	local stroke           = Instance.new("UIStroke")
	stroke.Thickness       = 1.5
	stroke.Color           = Color3.new(0, 0, 0)
	stroke.Parent          = lbl
end

local function fadeOutRollDisplay(imgLabel, labels)
	TweenService:Create(imgLabel, TI_DISPLAY_FADE, { ImageTransparency = 1 }):Play()
	for _, lbl in ipairs(labels) do
		TweenService:Create(lbl, TI_DISPLAY_FADE, { TextTransparency = 1 }):Play()
		local stroke = lbl:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TI_DISPLAY_FADE, { Transparency = 1 }):Play()
		end
	end
end

------------------------------------------------------------------------
-- BillboardGui above the ImageSurface part — cycles info during the roll
------------------------------------------------------------------------
local function buildBillboardGui(part)
	local bill              = Instance.new("BillboardGui")
	bill.Name               = "RollInfo"
	bill.Size               = UDim2.fromOffset(500, 175)
	bill.StudsOffset        = Vector3.new(0, part.Size.Y * 0.5 + 2.5, 0)
	bill.AlwaysOnTop        = false
	bill.LightInfluence     = 0
	bill.Parent             = part

	local function make(name, y, h)
		local lbl                    = Instance.new("TextLabel")
		lbl.Name                     = name
		lbl.Size                     = UDim2.new(1, 0, h, 0)
		lbl.Position                 = UDim2.new(0, 0, y, 0)
		lbl.BackgroundTransparency   = 1
		lbl.TextColor3               = Color3.new(1, 1, 1)
		lbl.TextScaled               = true
		lbl.FontFace                 = RUBIK_EB
		lbl.Text                     = ""
		lbl.Parent                   = bill
		addTextStroke(lbl)
		return lbl
	end

	local nameLabel   = make("EffectName",  0,    0.44)
	local oddsLabel   = make("OddsLabel",   0.44, 0.28)
	local rarityLabel = make("RarityLabel", 0.72, 0.28)

	return bill, nameLabel, oddsLabel, rarityLabel
end

------------------------------------------------------------------------
-- ScreenGui popup — shown when the chosen effect lands
------------------------------------------------------------------------
local function buildResultGui(effectName)
	local effect = EffectData[effectName]
	local rarity = effect and RarityData[effect.Rarity]
	local col    = rarity and rarity.Color or Color3.new(1, 1, 1)

	local gui           = Instance.new("ScreenGui")
	gui.Name            = "RollResult"
	gui.IgnoreGuiInset  = true
	gui.ResetOnSpawn    = false
	gui.DisplayOrder    = 50
	gui.Parent          = player.PlayerGui

	local container                  = Instance.new("Frame")
	container.Name                   = "Container"
	container.Size                   = UDim2.new(0.38, 0, 0.2, 0)
	container.AnchorPoint            = Vector2.new(0.5, 1)
	container.Position               = UDim2.new(0.5, 0, 0.96, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel        = 0
	container.Parent                 = gui

	-- UIScale drives the pop-in bounce
	local uiScale       = Instance.new("UIScale")
	uiScale.Scale       = 0
	uiScale.Parent      = container

	local function lbl(name, y, h, text, color)
		local l                    = Instance.new("TextLabel")
		l.Name                     = name
		l.Size                     = UDim2.new(1, 0, h, 0)
		l.Position                 = UDim2.new(0, 0, y, 0)
		l.BackgroundTransparency   = 1
		l.TextColor3               = color
		l.TextScaled               = true
		l.FontFace                 = RUBIK_EB
		l.Text                     = text
		l.Parent                   = container
		addTextStroke(l)
	end

	lbl("EffectName",  0,    0.44, (effect and effect.DisplayName) or effectName, Color3.new(1, 1, 1))
	lbl("OddsLabel",   0.44, 0.28, effect and toFraction(effect.Odds) or "",      col)
	lbl("RarityLabel", 0.72, 0.28, (effect and effect.Rarity) or "",              col)

	-- Pop-in: scale from 0 → 1 with a Back.Out bounce
	TweenService:Create(uiScale,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	return gui
end

------------------------------------------------------------------------
-- Per-tick display refresh
------------------------------------------------------------------------
local function refreshDisplay(effectName, imgLabel, nameL, oddsL, rarityL)
	local effect = EffectData[effectName]
	local rarity = effect and RarityData[effect.Rarity]

	if effect and effect.Image then
		imgLabel.Image = effect.Image
	end
	imgLabel.ImageColor3          = Color3.new(0, 0, 0)
	imgLabel.BackgroundTransparency = 1

	nameL.Text   = (effect and effect.DisplayName) or effectName
	oddsL.Text   = effect and toFraction(effect.Odds) or ""
	rarityL.Text = (effect and effect.Rarity) or ""

	local col          = rarity and rarity.Color or Color3.new(1, 1, 1)
	oddsL.TextColor3   = col
	rarityL.TextColor3 = col
	nameL.TextColor3   = Color3.new(1, 1, 1)
end

------------------------------------------------------------------------
-- Tick bounce: snap the ImageSurface part slightly large, tween back.
-- Skips if the previous bounce is still running so fast ticks don't jitter.
------------------------------------------------------------------------
local function makeBouncer(part, origSize)
	local activeTween = nil

	return function()
		if activeTween and activeTween.PlaybackState == Enum.PlaybackState.Playing then
			return
		end
		part.Size  = origSize * BOUNCE_SCALE
		activeTween = TweenService:Create(part, TI_BOUNCE, { Size = origSize })
		activeTween:Play()
	end
end

local function cframeAtPositionWithPitch(position, pitchDegrees)
	return CFrame.new(position) * CFrame.Angles(math.rad(pitchDegrees), 0, 0)
end

local function cameraCFrameWithPitchAndPullback(cameraCF, pitchDegrees, pullbackStuds)
	local pitched = cameraCF * CFrame.Angles(math.rad(pitchDegrees), 0, 0)
	return pitched * CFrame.new(0, 0, pullbackStuds)
end

local function getMouseNormalized()
	local mouse    = UserInputService:GetMouseLocation()
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return Vector2.zero
	end

	return Vector2.new(
		math.clamp((mouse.X / viewport.X - 0.5) * 2, -1, 1),
		math.clamp((mouse.Y / viewport.Y - 0.5) * 2, -1, 1)
	)
end

local function applyCursorFollow(baseCF, currentAngles, dt)
	local mouseNorm     = getMouseNormalized()
	local targetAngles  = Vector2.new(
		-mouseNorm.Y * CURSOR_FOLLOW_MAX,
		mouseNorm.X * CURSOR_FOLLOW_MAX
	)
	local blend         = math.min(1, CURSOR_FOLLOW_SMOOTH * dt)
	local nextAngles    = currentAngles:Lerp(targetAngles, blend)
	local followRot     = CFrame.Angles(math.rad(nextAngles.X), math.rad(nextAngles.Y), 0)

	return baseCF * followRot, nextAngles
end

local function makeCursorFollower(getBaseCF)
	local angles = Vector2.zero

	return RunService.RenderStepped:Connect(function(dt)
		local baseCF
		local ok, result = pcall(getBaseCF)
		if ok then
			baseCF = result
		end
		if not baseCF then
			return
		end

		local cf
		cf, angles = applyCursorFollow(baseCF, angles, dt)
		camera.CFrame = cf
	end)
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
		local chosenEffectData = EffectData[chosenEffect]
		local chosenRarityData = chosenEffectData and RarityData[chosenEffectData.Rarity]

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

		local imgGui   = imageSurface:WaitForChild("ImageSurface")
		local imgLabel = imgGui:WaitForChild("ImageSurface")

		local sunLabel = sunburst
			:WaitForChild("Sunburst")
			:WaitForChild("Sunburst")

		-- SurfaceGui shows only the image; background must be transparent
		imgLabel.BackgroundTransparency = 1

		local origSurfaceSize          = imageSurface.Size
		local origSunburstSize         = sunburst.Size
		local origSunImageTransparency = sunLabel.ImageTransparency
		local bounce                   = makeBouncer(imageSurface, origSurfaceSize)
		local _, nameL, oddsL, rarityL = buildBillboardGui(imageSurface)

		anchor.CFrame               = cframeAtPositionWithPitch(anchor.Position, CAMERA_START_PITCH)
		sunburst.Size               = Vector3.new(0,0,0)
		sunLabel.ImageTransparency  = 1

		--------------------------------------------------------------------
		-- 3. Camera — position at Anchor, start looking straight down
		--------------------------------------------------------------------
		local prevCamType = camera.CameraType
		local prevFOV     = camera.FieldOfView

		camera.CameraType  = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV_DEFAULT

		local targetCF = CFrame.lookAt(anchor.Position, imageSurface.Position)
		local landCF   = cameraCFrameWithPitchAndPullback(targetCF, CAMERA_LAND_PITCH, CAMERA_LAND_PULLBACK)
		local downCF   = CFrame.lookAt(
			anchor.Position,
			anchor.Position + Vector3.new(0.001, -1, 0.001)
		)

		local camBase       = Instance.new("CFrameValue")
		camBase.Name        = "RollCameraBase"
		camBase.Value       = downCF
		camBase.Parent      = scene

		local cursorConn = makeCursorFollower(function()
			return camBase.Value
		end)
		camera.CFrame       = downCF

		--------------------------------------------------------------------
		-- 4. Camera intro (elastic down → up), then undarken
		--------------------------------------------------------------------
		TweenService:Create(camBase, TI_CAM_IN, { Value = targetCF }):Play()
		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))

		--------------------------------------------------------------------
		-- 5. Sounds
		--------------------------------------------------------------------
		local function makeSound(id, volume)
			local s      = Instance.new("Sound")
			s.SoundId    = id
			s.Volume     = volume or 1
			s.Parent     = workspace
			return s
		end

		local startSound   = makeSound(SOUND_OPEN_START)
		local tickSound    = makeSound(SOUND_TICK)
		local preLandSound = makeSound(SOUND_PRE_LAND, 0.7)

		startSound:Play()

		--------------------------------------------------------------------
		-- 6. Rolling heartbeat
		--
		--    interval(p) = TICK_FAST × (TICK_SLOW/TICK_FAST)^(p²)
		--    p² keeps ticks near-60 hz for the first ~70% of the roll and
		--    only decelerates visibly in the final stretch.
		--------------------------------------------------------------------
		refreshDisplay(pickRandom(pool), imgLabel, nameL, oddsL, rarityL)
		bounce()
		tickSound:Play()

		TweenService:Create(camera, TI_FOV_ROLL, { FieldOfView = FOV_ROLL }):Play()

		local signal    = Instance.new("BindableEvent")
		local startTime = os.clock()
		local lastTick  = startTime
		local landed    = false
		local rollConn

		task.delay(ROLL_DURATION - 2, function()
			if not landed then
				preLandSound:Play()
			end
		end)

		rollConn = RunService.Heartbeat:Connect(function()
			if landed then return end

			local now      = os.clock()
			local progress = math.min((now - startTime) / ROLL_DURATION, 1)
			local interval = TICK_FAST * ((TICK_SLOW / TICK_FAST) ^ (progress ^ 2))

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
				bounce()
				tickSound:Play()
			end
		end)

		signal.Event:Wait()
		signal:Destroy()

		--------------------------------------------------------------------
		-- 8. Landing
		--    FOV: 55 → 85 fast (punch), then 85 → 70 elastic (settle)
		--    Sunburst pops in and spins; surface + billboard fade out
		--------------------------------------------------------------------
		TweenService:Create(camBase, TI_CAMERA_LAND, { Value = landCF }):Play()

		task.spawn(function()
			awaitTween(TweenService:Create(camera, TI_FOV_PUNCH,  { FieldOfView = FOV_LAND    }))
			TweenService:Create(camera,           TI_FOV_SETTLE, { FieldOfView = FOV_DEFAULT }):Play()
		end)

		local openSound
		if chosenRarityData and chosenRarityData.OpenSound then
			openSound = makeSound(chosenRarityData.OpenSound)
			openSound:Play()
		end

		if chosenRarityData and chosenRarityData.CameraShakeConst then
			SignalServiceClient.fireOnSignal("ScreenShake", "RemoteEvent", {{
				magnitude = chosenRarityData.CameraShakeConst,
				duration = 0.6,
				radius = 150,
			}})
		end

		TweenService:Create(sunburst, TI_SUNBURST_IN, { Size = origSunburstSize }):Play()
		TweenService:Create(sunLabel, TI_SUNBURST_FADE, { ImageTransparency = origSunImageTransparency }):Play()

		local sunAngle = 0
		local sunConn  = RunService.Heartbeat:Connect(function(dt)
			sunAngle          = sunAngle + dt * SUNBURST_SPEED
			sunLabel.Rotation = sunAngle
		end)

		fadeOutRollDisplay(imgLabel, { nameL, oddsL, rarityL })

		-- Particle handoff — surface fades out, particles handle visuals
		if ParticlePlayer and ParticlePlayer.Play then
			ParticlePlayer.Play(chosenEffect, particleBlock.Position)
		end
		-- placeholder: wire up ReplicatedStorage.Modules.ParticlePlayer when ready

		-- Result popup
		local resultGui = buildResultGui(chosenEffect)

		--------------------------------------------------------------------
		-- 9. Hold result on screen
		--------------------------------------------------------------------
		task.wait(POST_LAND_PAUSE)

		--------------------------------------------------------------------
		-- 10. Tear down
		--------------------------------------------------------------------
		sunConn:Disconnect()
		cursorConn:Disconnect()
		startSound:Destroy()
		tickSound:Destroy()
		preLandSound:Destroy()
		if openSound then
			openSound:Destroy()
		end

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 0 }))

		camera.CameraType  = prevCamType
		camera.FieldOfView = prevFOV
		scene:Destroy()
		resultGui:Destroy()

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))

		fadeGui:Destroy()
		isRolling = false

		if onComplete then
			task.spawn(onComplete)
		end
	end)
end

return RollVisuals
