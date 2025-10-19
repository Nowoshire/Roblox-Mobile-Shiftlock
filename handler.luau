--[[
	- Mobile Shiftlock -
	
	Uses the engine UserGameSettings.RotationType property to achieve physics parity with shiftlock on PC.
	
	Copyright (c) 2025 Nowoshire
	
	This software is released under the MIT License.
		https://github.com/Nowoshire/Roblox-Mobile-Shiftlock/blob/main/LICENSE
]]

--!strict

-- Constants --
local FIRST_PERSON_DISTANCE_THRESHOLD = 1 -- Distance from subject that is considered first person, value from PlayerModule
local OFF_ICON_ASSETURL = "rbxasset://textures/ui/mouseLock_off@2x.png"
local ON_ICON_ASSETURL = "rbxasset://textures/ui/mouseLock_on@2x.png"
local DEFAULT_CAMERA_OFFSET = Vector3.new(1.75, 0, 0) -- Camera offset in Shiftlock, value from PlayerModule

-- Services --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings().GameSettings

local localPlayer = Players.LocalPlayer :: Player
local humanoid: Humanoid?
local currentCamera: Camera? = workspace.CurrentCamera

local gui = script.Parent
local shiftlockButton = gui.Button
local shiftlockAction = gui.ShiftlockAction

local isShiftlockActive: boolean = false
local inFirstPerson: boolean? = nil -- nil to allow first-time update

local function characterAdded(character: Model)
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
end

-- Update humanoid variable
if localPlayer.Character then
	characterAdded(localPlayer.Character)
end

localPlayer.CharacterAdded:Connect(characterAdded)
localPlayer.CharacterRemoving:Connect(function()
	humanoid = nil
end)

-- Update currentCamera variable
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	currentCamera = workspace.CurrentCamera
end)

--[[
	Returns the distance from the camera's CFrame and the camera's Focus.
	Returns 0 if there is no CurrentCamera.
]]
local function getZoomDistance()
	if not currentCamera then
		return 0
	end
	
	return (currentCamera.CFrame.Position - currentCamera.Focus.Position).Magnitude
end

--[[
	Returns a boolean indicating whether shiftlock is available.
]]
local function isShiftLockAvailable()
	return localPlayer.DevEnableMouseLock
end

--[[
	Updates shiftlock button image based on shiftlock state.
]]
local function updateImage()
	shiftlockButton.Image = if isShiftlockActive then ON_ICON_ASSETURL else OFF_ICON_ASSETURL
end

--[[
	Updates the Humanoid CameraOffset.
]]
local function updateCameraOffset()
	if not isShiftlockActive then
		inFirstPerson = nil
		
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
		
		return
	end
	
	local nowInFirstPerson = getZoomDistance() < FIRST_PERSON_DISTANCE_THRESHOLD
	
	-- Optimization: only update camera offset when first person changes
	if nowInFirstPerson ~= inFirstPerson and humanoid then
		humanoid.CameraOffset = if nowInFirstPerson then Vector3.zero else DEFAULT_CAMERA_OFFSET
	end
	
	inFirstPerson = nowInFirstPerson
end

local cameraOffsetUpdateConnection: RBXScriptConnection?

--[[
	Enables/disables shiftlock.
]]
local function enableShiftLock(enable: boolean)
	isShiftlockActive = enable
	
	if enable then
		UserGameSettings.RotationType = Enum.RotationType.CameraRelative
		
		-- Update camera offset every frame
		if not cameraOffsetUpdateConnection then
			cameraOffsetUpdateConnection = RunService.PreRender:Connect(updateCameraOffset)
		end
	else
		UserGameSettings.RotationType = Enum.RotationType.MovementRelative
		
		-- Stop updating camera offset
		if cameraOffsetUpdateConnection then
			cameraOffsetUpdateConnection:Disconnect()
			cameraOffsetUpdateConnection = nil
		end
		
		updateCameraOffset()
	end
	
	updateImage()
end

--[[
	Updates the gui visibility based on whether the user's PreferredInput is Touch and if shiftlock is available.
]]
local function updateGuiVisibility()
	local shouldBeVisible = isShiftLockAvailable() and UserInputService.PreferredInput ~= Enum.PreferredInput.KeyboardAndMouse
	gui.Enabled = shouldBeVisible
	
	if not shouldBeVisible and isShiftlockActive then
		-- Prevent the player from getting stuck in shiftlock
		enableShiftLock(false)
	end
end

-- Change shiftlock state on action trigger
shiftlockAction.StateChanged:Connect(function(value)
	-- Check if state is keydown
	if not value then
		return
	end
	
	-- Check if shiftlock is available
	if not isShiftLockAvailable() then
		return
	end
	
	-- Toggle shiftlock
	enableShiftLock(not isShiftlockActive)
end)

-- Update gui visibility on PreferredInput change
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateGuiVisibility)

-- Update gui visibility on DevEnableMouseLock change
localPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(updateGuiVisibility)

updateGuiVisibility() -- initial update
