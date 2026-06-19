-- ModuleScript: ReplicatedStorage.Modules.ClientRollEffects.VfxCameraShake
--
-- Local camera shake for scripted VFX sequences. Captures the camera CFrame
-- at shake start and always restores it exactly when the shake finishes.

local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera

local SHAKE_DURATION = 0.6

local activeConn = nil
local activeBaseCF = nil

local VfxCameraShake = {}

function VfxCameraShake.GetDuration()
	return SHAKE_DURATION
end

function VfxCameraShake.Play(magnitude)
	if typeof(magnitude) ~= "number" or magnitude <= 0 then
		return
	end

	if activeConn then
		activeConn:Disconnect()
		activeConn = nil
		if activeBaseCF then
			camera.CFrame = activeBaseCF
		end
	end

	local baseCF = camera.CFrame
	activeBaseCF = baseCF

	local startTime = os.clock()
	local rotScale = math.rad(magnitude * 0.12)
	local posScale = magnitude * 0.004

	activeConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / SHAKE_DURATION, 0, 1)

		if alpha >= 1 then
			camera.CFrame = baseCF
			activeConn:Disconnect()
			activeConn = nil
			activeBaseCF = nil
			return
		end

		-- sin(pi * alpha) is exactly 0 at the start and end of the shake.
		local envelope = math.sin(alpha * math.pi)
		local t = elapsed

		local pitch = math.sin(t * 55) * rotScale * envelope
		local yaw   = math.sin(t * 48 + 1.1) * rotScale * envelope
		local roll  = math.sin(t * 41 + 2.3) * rotScale * 0.5 * envelope

		local offsetX = math.sin(t * 62) * posScale * envelope
		local offsetY = math.sin(t * 54 + 0.7) * posScale * envelope

		camera.CFrame = baseCF
			* CFrame.new(offsetX, offsetY, 0)
			* CFrame.Angles(pitch, yaw, roll)
	end)
end

return VfxCameraShake
