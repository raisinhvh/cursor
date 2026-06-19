local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientRollEffects = script.Parent
local RarityData = require(ClientRollEffects:WaitForChild("RarityData"))
local EffectData = require(ClientRollEffects:WaitForChild("EffectData"))
local RollChooser = require(ClientRollEffects:WaitForChild("RollChooser"))
local VfxCameraShake = require(ClientRollEffects:WaitForChild("VfxCameraShake"))

local ParticlePlayer = require(ReplicatedStorage.Modules:WaitForChild("ParticlePlayer", 2))

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
local EFFECT_LOOP_INTERVAL = 2.5  -- seconds between effect replays
local SUNBURST_SPEED     = 25     -- degrees per second
local BOUNCE_SCALE       = 1.05   -- how much the surface punches on each tick
local BILLBOARD_DROP     = 0.35   -- studs the billboard starts below its rest position
local TICK_TWEEN_FRACTION = 0.85  -- tween length as a fraction of time until the next tick
local CAMERA_START_PITCH   = -9
local CURSOR_FOLLOW_MAX    = 2.5  -- max camera rotation in degrees
local CURSOR_FOLLOW_SMOOTH = 10   -- lerp speed toward cursor target

-- Sounds — replace placeholder IDs with your real asset IDs
local SOUND_OPEN_START = "rbxassetid://101203249378987"                -- plays once when the roll sequence begins
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
local TI_DISPLAY_FADE  = TweenInfo.new(0.25, Enum.EasingStyle.Linear)

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
local function makeFadeOverlay(displayOrder)
	local gui           = Instance.new("ScreenGui")
	gui.Name            = "RollFade"
	gui.IgnoreGuiInset  = true
	gui.ResetOnSpawn    = false
	gui.DisplayOrder    = displayOrder or 999

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
local function buildBillboardGui(adorneePart, sceneParent)
	local bill              = Instance.new("BillboardGui")
	bill.Name               = "RollInfo"
	bill.Adornee            = adorneePart
	bill.Size               = UDim2.new(6, 0, 2.1, 0)
	bill.StudsOffset        = Vector3.new(0, adorneePart.Size.Y * 0.5 + 2.5, 0)
	bill.AlwaysOnTop        = false
	bill.LightInfluence     = 0
	bill.Parent             = sceneParent

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

		local textConstraint         = Instance.new("UITextSizeConstraint")
		textConstraint.MaxTextSize   = 48
		textConstraint.MinTextSize   = 12
		textConstraint.Parent        = lbl

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
-- Inspect overlay — placeholder close button in the bottom right
------------------------------------------------------------------------
local function buildInspectGui(onClose)
	local gui           = Instance.new("ScreenGui")
	gui.Name            = "InspectVisuals"
	gui.IgnoreGuiInset  = true
	gui.ResetOnSpawn    = false
	gui.DisplayOrder    = 100
	gui.Parent          = player.PlayerGui

	local closeBtn                    = Instance.new("TextButton")
	closeBtn.Name                     = "Close"
	closeBtn.AnchorPoint              = Vector2.new(1, 1)
	closeBtn.Position                 = UDim2.new(1, -16, 1, -16)
	closeBtn.Size                     = UDim2.fromOffset(120, 44)
	closeBtn.BackgroundColor3         = Color3.fromRGB(40, 40, 40)
	closeBtn.BackgroundTransparency   = 0.2
	closeBtn.BorderSizePixel          = 0
	closeBtn.Text                     = "Close"
	closeBtn.TextColor3               = Color3.new(1, 1, 1)
	closeBtn.TextScaled               = true
	closeBtn.FontFace                 = RUBIK_EB
	closeBtn.Parent                   = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(onClose)

	return gui
end

------------------------------------------------------------------------
-- Tick pacing — fast at the start, slow near the end
------------------------------------------------------------------------
local function getTickInterval(progress)
	return TICK_FAST * ((TICK_SLOW / TICK_FAST) ^ (progress ^ 2))
end

local function getTickTweenDuration(interval)
	return interval * TICK_TWEEN_FRACTION
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
-- Landed effect — particles and screen shake together
------------------------------------------------------------------------
local function playLandedEffect(effectName, particleBlock, rarityData)
	if ParticlePlayer and ParticlePlayer.Play then
		ParticlePlayer.Play(effectName, particleBlock.Position)
	end

	if rarityData and rarityData.CameraShakeConst then
		VfxCameraShake.Play(rarityData.CameraShakeConst)
	end
end

------------------------------------------------------------------------
-- Effect replay loop — play, wait, repeat until stopped
------------------------------------------------------------------------
local function runEffectReplayLoop(effectName, particleBlock, rarityData, shouldContinue, beforeEachPlay, afterEachPlay)
	task.spawn(function()
		while shouldContinue() do
			if beforeEachPlay then
				beforeEachPlay()
			end
			playLandedEffect(effectName, particleBlock, rarityData)
			if afterEachPlay then
				afterEachPlay()
			end

			local elapsed = 0
			while elapsed < EFFECT_LOOP_INTERVAL and shouldContinue() do
				elapsed += task.wait()
			end
		end
	end)
end

------------------------------------------------------------------------
-- Tick bounce: snap the ImageSurface part slightly large, tween back.
-- Duration scales with time until the next tick (fast early, slow late).
------------------------------------------------------------------------
local function makeBouncer(part, origSize)
	local activeTween = nil

	return function(duration)
		if activeTween then
			activeTween:Cancel()
		end
		part.Size = origSize * BOUNCE_SCALE
		activeTween = TweenService:Create(
			part,
			TweenInfo.new(duration, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
			{ Size = origSize }
		)
		activeTween:Play()
	end
end

------------------------------------------------------------------------
-- Billboard pop: start slightly lower, tween up to rest height each tick.
------------------------------------------------------------------------
local function makeBillboardPopper(bill, origStudsOffset)
	local activeTween = nil
	local dropOffset  = Vector3.new(0, BILLBOARD_DROP, 0)

	return function(duration)
		if activeTween then
			activeTween:Cancel()
		end
		bill.StudsOffset = origStudsOffset - dropOffset
		activeTween = TweenService:Create(
			bill,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ StudsOffset = origStudsOffset }
		)
		activeTween:Play()
	end
end

local function cframeAtPositionWithPitch(position, pitchDegrees)
	return CFrame.new(position) * CFrame.Angles(math.rad(pitchDegrees), 0, 0)
end

local function getMouseNormalized()
	local mouse    = UserInputService:GetMouseLocation()
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return Vector2.zero
	end

	return Vector2.new(
		math.clamp((mouse.X / viewport.X - 0.5), -1, 1),
		math.clamp((mouse.Y / viewport.Y - 0.5), -1, 1)
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
	local paused = false

	local conn = RunService.RenderStepped:Connect(function(dt)
		if paused then
			return
		end

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

	local controller = {
		Reset = function(baseCF)
			angles = Vector2.zero
			if baseCF then
				camera.CFrame = baseCF
			end
		end,
		SetPaused = function(value)
			paused = value
		end,
	}

	return conn, controller
end

local function makeSound(id, volume)
	local s      = Instance.new("Sound")
	s.SoundId    = id
	s.Volume     = volume or 1
	s.Parent     = workspace
	return s
end

local function startSunburstSpin(sunLabel)
	local sunAngle = 0
	return RunService.Heartbeat:Connect(function(dt)
		sunAngle          = sunAngle + dt * SUNBURST_SPEED
		sunLabel.Rotation = sunAngle
	end)
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------
local RollVisuals = {}
local isRolling   = false
local isInspecting = false

function RollVisuals.Play(chosenEffect, effectsList, onComplete)
	if isRolling or isInspecting then
		warn("[RollVisuals] A roll or inspect is already in progress; call ignored.")
		return
	end
	if not EffectData[chosenEffect] then
		warn("[RollVisuals] chosenEffect not found in EffectData:", chosenEffect)
		if onComplete then onComplete() end
		return
	end

	isRolling = true

	task.spawn(function()
		local pool = RollChooser.BuildPool(effectsList)
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
		local bill, nameL, oddsL, rarityL = buildBillboardGui(imageSurface, scene)
		local origStudsOffset          = bill.StudsOffset
		local billboardPop             = makeBillboardPopper(bill, origStudsOffset)

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
		local downCF   = CFrame.lookAt(
			anchor.Position,
			anchor.Position + Vector3.new(0.001, -1, 0.001)
		)

		local camBase       = Instance.new("CFrameValue")
		camBase.Name        = "RollCameraBase"
		camBase.Value       = downCF
		camBase.Parent      = scene

		local cursorConn, cursorCtrl = makeCursorFollower(function()
			return camBase.Value
		end)
		camera.CFrame       = downCF

		--------------------------------------------------------------------
		-- 4. Camera intro (elastic down → up), then undarken
		-- 5. Sounds too
		--------------------------------------------------------------------
		TweenService:Create(camBase, TI_CAM_IN, { Value = targetCF }):Play()
		local startSound   = makeSound(SOUND_OPEN_START)
		startSound:Play()

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))

		local tickSound    = makeSound(SOUND_TICK)
		local preLandSound = makeSound(SOUND_PRE_LAND, 0.7)

		--------------------------------------------------------------------
		-- 6. Rolling heartbeat
		--
		--    interval(p) = TICK_FAST × (TICK_SLOW/TICK_FAST)^(p²)
		--    p² keeps ticks near-60 hz for the first ~70% of the roll and
		--    only decelerates visibly in the final stretch.
		--------------------------------------------------------------------
		local function playRollTick(progress)
			local tweenDuration = getTickTweenDuration(getTickInterval(progress))
			refreshDisplay(RollChooser.PickRandom(pool), imgLabel, nameL, oddsL, rarityL)
			bounce(tweenDuration)
			billboardPop(tweenDuration)
			tickSound:Play()
		end

		playRollTick(0)

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
			local interval = getTickInterval(progress)

			if progress >= 1 then
				landed = true
				rollConn:Disconnect()
				refreshDisplay(chosenEffect, imgLabel, nameL, oddsL, rarityL)
				signal:Fire()
				return
			end

			if now - lastTick >= interval then
				lastTick = now
				playRollTick(progress)
			end
		end)

		signal.Event:Wait()
		signal:Destroy()

		--------------------------------------------------------------------
		-- 8. Landing
		--    FOV: 55 → 85 fast (punch), then 85 → 70 elastic (settle)
		--    Sunburst pops in and spins; surface + billboard fade out
		--------------------------------------------------------------------
		cursorConn:Disconnect()
		camBase.Value = targetCF
		cursorCtrl.Reset(targetCF)

		task.spawn(function()
			awaitTween(TweenService:Create(camera, TI_FOV_PUNCH,  { FieldOfView = FOV_LAND    }))
			TweenService:Create(camera,           TI_FOV_SETTLE, { FieldOfView = FOV_DEFAULT }):Play()
		end)

		local openSound
		if chosenRarityData and chosenRarityData.OpenSound then
			openSound = makeSound(chosenRarityData.OpenSound)
			openSound:Play()
		end

		TweenService:Create(sunburst, TI_SUNBURST_IN, { Size = origSunburstSize }):Play()
		TweenService:Create(sunLabel, TI_SUNBURST_FADE, { ImageTransparency = origSunImageTransparency }):Play()

		local sunConn = startSunburstSpin(sunLabel)

		fadeOutRollDisplay(imgLabel, { nameL, oddsL, rarityL })

		-- Result popup
		local resultGui = buildResultGui(chosenEffect)

		-- Replay the landed effect until teardown
		local replayActive = true
		runEffectReplayLoop(chosenEffect, particleBlock, chosenRarityData, function()
			return replayActive
		end)

		--------------------------------------------------------------------
		-- 9. Hold result on screen
		--------------------------------------------------------------------
		task.wait(POST_LAND_PAUSE)
		replayActive = false

		--------------------------------------------------------------------
		-- 10. Tear down
		--------------------------------------------------------------------
		sunConn:Disconnect()
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

function RollVisuals.Inspect(effectName, onClose)
	if isRolling or isInspecting then
		warn("[RollVisuals] A roll or inspect is already in progress; call ignored.")
		return
	end
	if not EffectData[effectName] then
		warn("[RollVisuals] effectName not found in EffectData:", effectName)
		return
	end

	isInspecting = true

	task.spawn(function()
		local effectData = EffectData[effectName]
		local rarityData = effectData and RarityData[effectData.Rarity]

		local fadeGui, fadeFrame = makeFadeOverlay()
		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 0 }))

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

		imgLabel.BackgroundTransparency = 1

		local origSunburstSize         = sunburst.Size
		local origSunImageTransparency = sunLabel.ImageTransparency
		local _, nameL, oddsL, rarityL = buildBillboardGui(imageSurface, scene)

		anchor.CFrame              = cframeAtPositionWithPitch(anchor.Position, CAMERA_START_PITCH)
		sunburst.Size              = origSunburstSize
		sunLabel.ImageTransparency = origSunImageTransparency

		refreshDisplay(effectName, imgLabel, nameL, oddsL, rarityL)
		fadeOutRollDisplay(imgLabel, { nameL, oddsL, rarityL })

		local prevCamType = camera.CameraType
		local prevFOV     = camera.FieldOfView

		camera.CameraType  = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV_DEFAULT

		local targetCF = CFrame.lookAt(anchor.Position, imageSurface.Position)

		local camBase  = Instance.new("CFrameValue")
		camBase.Name   = "InspectCameraBase"
		camBase.Value  = targetCF
		camBase.Parent = scene

		local cursorConn, cursorCtrl = makeCursorFollower(function()
			return camBase.Value
		end)
		camera.CFrame = targetCF

		local sunConn = startSunburstSpin(sunLabel)

		awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))

		local replayActive = true
		local inspectGui
		local closed = false
		local shakeResumeToken = 0

		local function prepareCameraForShake()
			shakeResumeToken += 1
			cursorCtrl.SetPaused(true)
			camBase.Value = targetCF
			cursorCtrl.Reset(targetCF)
		end

		local function scheduleCursorResume()
			local token = shakeResumeToken
			task.delay(VfxCameraShake.GetDuration(), function()
				if token ~= shakeResumeToken or closed or not replayActive then
					return
				end
				cursorCtrl.SetPaused(false)
			end)
		end

		local function closeInspect()
			if closed then
				return
			end
			closed = true
			replayActive = false
			shakeResumeToken += 1
			cursorCtrl.SetPaused(true)

			awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 0 }))

			sunConn:Disconnect()
			cursorConn:Disconnect()
			camera.CameraType  = prevCamType
			camera.FieldOfView = prevFOV
			scene:Destroy()
			if inspectGui then
				inspectGui:Destroy()
			end

			awaitTween(TweenService:Create(fadeFrame, TI_FADE, { BackgroundTransparency = 1 }))
			fadeGui:Destroy()

			isInspecting = false

			if onClose then
				task.spawn(onClose)
			end
		end

		inspectGui = buildInspectGui(closeInspect)

		runEffectReplayLoop(effectName, particleBlock, rarityData, function()
			return replayActive
		end, function()
			prepareCameraForShake()
		end, function()
			scheduleCursorResume()
		end)
	end)
end

return RollVisuals
