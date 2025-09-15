--[[
	- Mobile Shiftlock -
	
	Uses the engine UserGameSettings.RotationType property to achieve physics parity with shiftlock on PC.
	
	Copyright (c) 2025 Nowoshire
	
	This software is released under the MIT License.
		https://github.com/Nowoshire/Roblox-Mobile-Shiftlock/blob/main/LICENSE
]]

--!nonstrict

local OFF_ICON_ASSETURL = "rbxasset://textures/ui/mouseLock_off@2x.png"
local ON_ICON_ASSETURL = "rbxasset://textures/ui/mouseLock_on@2x.png"
local DEFAULT_CAMERA_OFFSET = Vector3.new(1.75, 0, 0) -- value used by MouseLockController

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings().GameSettings

local localPlayer = Players.LocalPlayer :: Player
local playerScripts = localPlayer.PlayerScripts :: typeof(game:GetService("StarterPlayer").StarterPlayerScripts) -- allows typechecker to resolve the require if a fork exists in StarterPlayerScripts

local MouseLockController = select(2, xpcall(function()
	return require(playerScripts.PlayerModule.CameraModule.MouseLockController)
end, function()
	warn("Could not get PlayerModule.CameraModule.MouseLockController, camera offset will use the default defined in DEFAULT_CAMERA_OFFSET.")
end))

local gui = script.Parent
local shiftlockButton = gui.Button

local humanoid: Humanoid?

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

--[[
	Returns a boolean indicating whether shiftlock is available.
]]
local function isShiftLockAvailable()
	return localPlayer.DevEnableMouseLock
end

--[[
	Returns a boolean indicating whether shiftlock is active.
]]
local function isShiftLockActive()
	return UserGameSettings.RotationType == Enum.RotationType.CameraRelative
end

--[[
	Enables or disables shiftlock.
]]
local function enableShiftLock(enable: boolean?)
	if enable then
		UserGameSettings.RotationType = Enum.RotationType.CameraRelative

		if humanoid then
			humanoid.CameraOffset = if MouseLockController and MouseLockController.GetMouseLockOffset
				then MouseLockController:GetMouseLockOffset()
				else DEFAULT_CAMERA_OFFSET
		end
	else
		UserGameSettings.RotationType = Enum.RotationType.MovementRelative

		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	end
end

-- Change shiftlock state on button activation
shiftlockButton.Activated:Connect(function()
	-- Check if shiftlock is available
	if not isShiftLockAvailable() then
		return
	end
	
	-- Toggle shiftlock
	enableShiftLock(not isShiftLockActive())
end)

--[[
	Updates shiftlock button image based on RotationType.
]]
local function updateImage()
	shiftlockButton.Image = if isShiftLockActive() then ON_ICON_ASSETURL else OFF_ICON_ASSETURL
end

local rotationTypeChanged: RBXScriptConnection?

--[[
	Updates the gui visibility based on whether the user's PreferredInput is Touch and if shiftlock is available.
]]
local function updateGuiVisibility()
	local enableNow = isShiftLockAvailable() and UserInputService.PreferredInput == Enum.PreferredInput.Touch
	gui.Enabled = enableNow
	
	if enableNow then
		rotationTypeChanged = UserGameSettings:GetPropertyChangedSignal("RotationType"):Connect(updateImage)
		updateImage()
	else
		if rotationTypeChanged then
			-- Disconnect the RotationType PropertyChangedSignal connection when gui isn't visible
			rotationTypeChanged:Disconnect()
			rotationTypeChanged = nil
		end
		
		-- Prevent the player from getting stuck in shiftlock
		if isShiftLockActive() then
			enableShiftLock(false)
		end
	end
end

updateGuiVisibility()

-- Update gui visibility on PreferredInput change
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(updateGuiVisibility)

-- Update gui visibility and shiftlock on DevEnableMouseLock change
localPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(updateGuiVisibility)
