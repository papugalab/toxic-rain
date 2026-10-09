--!strict

local Controller = {}
Controller.__index = Controller

function Controller.new(dependencies: any)
	return setmetatable({
		_ui = dependencies.UI,
		_players = dependencies.PlayersModule,
		_initialized = false,
	}, Controller)
end

function Controller:Initialize()
	if self._initialized then return end
	self._initialized = true
	local player = self._players:GetLocalPlayer()
	local host = self._ui:GetHudHost()
	local feedback = Instance.new("TextLabel")
	feedback.Name = "ToxicRainPushFeedback"
	feedback.AnchorPoint = Vector2.new(0.5, 0.5)
	feedback.Size = UDim2.fromOffset(360, 54)
	feedback.Position = UDim2.fromScale(0.5, 0.68)
	feedback.BackgroundTransparency = 1
	feedback.TextColor3 = Color3.fromRGB(255, 225, 80)
	feedback.TextStrokeTransparency = 0.25
	feedback.Font = Enum.Font.GothamBlack
	feedback.TextSize = 28
	feedback.Visible = false
	feedback.Parent = host

	local feedbackToken = 0
	player:GetAttributeChangedSignal("ToxicRainPushSerial"):Connect(function()
		feedbackToken += 1
		local token = feedbackToken
		local outcome = player:GetAttribute("ToxicRainPushOutcome")
		feedback.Text = if outcome == "Hit"
			then "ТОЛЧОК!"
			elseif outcome == "Blocked"
			then "СОПЕРНИК ДЕРЖИТСЯ!"
			elseif outcome == "Immune"
			then "КОРОТКАЯ ЗАЩИТА!"
			else "ПРОМАХ"
		feedback.Visible = true
		task.delay(0.8, function()
			if token == feedbackToken then feedback.Visible = false end
		end)
	end)
end

return Controller
