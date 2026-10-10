--!strict

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Protocol = require(game.ReplicatedStorage.Shared.ToxicRain.AppleProtocol)

local Controller = {}
Controller.__index = Controller

function Controller.new(dependencies: any)
	return setmetatable({
		_players = dependencies.PlayersModule,
		_workspace = dependencies.Workspace,
		_communication = dependencies.Communication,
		_initialized = false,
	}, Controller)
end

function Controller:RequestConsume(): boolean
	local player = self._players:GetLocalPlayer()
	if self._workspace:GetAttribute("ToxicRainRoundState") ~= "Running"
		or (player:GetAttribute("ToxicRainAppleCount") or 0) <= 0 then return false end
	local queued = self._communication:Queue(Protocol.ConsumeIntent, {})
	return queued == true
end

function Controller:Initialize()
	if self._initialized then return end
	self._initialized = true
	ContextActionService:BindActionAtPriority("ToxicRainConsumeApple", function(_name, state)
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		local player = self._players:GetLocalPlayer()
		if self._workspace:GetAttribute("ToxicRainRoundState") ~= "Running"
			or (player:GetAttribute("ToxicRainAppleCount") or 0) <= 0 then return Enum.ContextActionResult.Pass end
		if state == Enum.UserInputState.Begin then self:RequestConsume() end
		-- Override the default slot-2 toggle while an apple can be consumed.
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Two, Enum.KeyCode.KeypadTwo)
end

return Controller
