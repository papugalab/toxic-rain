--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = {}
Controller.__index = Controller

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addText(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(238, 247, 239)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function Controller.new(ui: any, workspace: Workspace, playersModule: any)
	return setmetatable({ _ui = ui, _workspace = workspace, _players = playersModule }, Controller)
end

function Controller:Initialize()
	local host = self._ui:GetHudHost()
	local player = self._players:GetLocalPlayer()
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local overlay = Instance.new("Frame")
	overlay.Name = "ToxicRainOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(50, 255, 65)
	overlay.BackgroundTransparency = 0.84
	overlay.Visible = false
	overlay.Parent = host

	local status = addText(host, "ToxicRainStatus", if isMobile then UDim2.new(0.54, 0, 0, 30) else UDim2.fromOffset(500, 30), if isMobile then UDim2.new(0.5, 0, 0, 0) else UDim2.new(0.5, 0, 0, -42), if isMobile then 10 else 13)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.BackgroundColor3 = Color3.fromRGB(12, 18, 18)
	status.BackgroundTransparency = 0.15
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextWrapped = true
	addCorner(status, 8)

	local healthPanel = Instance.new("Frame")
	healthPanel.Name = "ToxicRainHealthPanel"
	healthPanel.AnchorPoint = Vector2.new(0.5, 0)
	healthPanel.Size = if isMobile then UDim2.new(0.54, 0, 0, 78) else UDim2.fromOffset(420, 78)
	healthPanel.Position = if isMobile then UDim2.new(0.5, 0, 0, 36) else UDim2.new(0.5, 0, 0, -6)
	healthPanel.BackgroundColor3 = Color3.fromRGB(12, 18, 18)
	healthPanel.BackgroundTransparency = 0.12
	healthPanel.Parent = host
	addCorner(healthPanel, 10)

	local healthTitle = addText(healthPanel, "HealthTitle", UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 1), if isMobile then 11 else 14)
	healthTitle.TextXAlignment = Enum.TextXAlignment.Center
	local segmentsFrame = Instance.new("Frame")
	segmentsFrame.Name = "HealthSegments"
	segmentsFrame.Size = UDim2.new(1, -16, 0, 13)
	segmentsFrame.Position = UDim2.fromOffset(8, 18)
	segmentsFrame.BackgroundTransparency = 1
	segmentsFrame.Parent = healthPanel
	local segmentLayout = Instance.new("UIListLayout")
	segmentLayout.FillDirection = Enum.FillDirection.Horizontal
	segmentLayout.Padding = UDim.new(0, 3)
	segmentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	segmentLayout.Parent = segmentsFrame
	local segments = {} :: { Frame }
	for index = 1, 10 do
		local segment = Instance.new("Frame")
		segment.Name = `Segment{index}`
		segment.LayoutOrder = index
		segment.Size = UDim2.new(0.1, -3, 1, 0)
		segment.BorderSizePixel = 0
		segment.BackgroundColor3 = Color3.fromRGB(48, 58, 52)
		segment.BackgroundTransparency = 0.35
		segment.ClipsDescendants = true
		segment.Parent = segmentsFrame
		addCorner(segment, 3)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.Parent = segment
		addCorner(fill, 3)
		table.insert(segments, fill)
	end
	local shelterHint = addText(healthPanel, "ToxicRainShelterHint", UDim2.new(1, -12, 0, 13), UDim2.fromOffset(6, 33), if isMobile then 8 else 9)
	shelterHint.Text = "ПРЯЧЬТЕСЬ ПОД ОСТАНОВКАМИ"
	shelterHint.TextColor3 = Color3.fromRGB(205, 215, 210)
	shelterHint.TextXAlignment = Enum.TextXAlignment.Center
	local appleHint = addText(healthPanel, "ToxicRainAppleHint", UDim2.new(1, -12, 0, 13), UDim2.fromOffset(6, 47), if isMobile then 8 else 9)
	appleHint.TextColor3 = Color3.fromRGB(255, 215, 105)
	appleHint.TextXAlignment = Enum.TextXAlignment.Center
	local puddleHint = addText(healthPanel, "ToxicRainPuddleHint", UDim2.new(1, -12, 0, 13), UDim2.fromOffset(6, 61), if isMobile then 8 else 9)
	puddleHint.Text = "НЕ НАСТУПАЙТЕ НА ЛУЖИ"
	puddleHint.TextColor3 = Color3.fromRGB(130, 255, 145)
	puddleHint.TextXAlignment = Enum.TextXAlignment.Center

	local remaining = addText(host, "ToxicRainRemaining", UDim2.fromOffset(170, 28), if isMobile then UDim2.fromOffset(12, 116) else UDim2.fromOffset(12, 4), if isMobile then 11 else 13)
	remaining.BackgroundColor3 = Color3.fromRGB(12, 18, 18)
	remaining.BackgroundTransparency = 0.18
	remaining.TextXAlignment = Enum.TextXAlignment.Center
	addCorner(remaining, 9)

	local board = Instance.new("Frame")
	board.Name = "ToxicRainRoundLeaderboard"
	board.AnchorPoint = Vector2.new(1, 0)
	board.Size = if isMobile then UDim2.new(0.38, -6, 0, 116) else UDim2.fromOffset(230, 108)
	board.Position = if isMobile then UDim2.new(1, -10, 0, 116) else UDim2.new(1, -10, 0, -42)
	board.BackgroundColor3 = Color3.fromRGB(10, 16, 15)
	board.BackgroundTransparency = 0.1
	board.Visible = false
	board.Parent = host
	addCorner(board, 10)
	local boardTitle = addText(board, "Title", UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 3), if isMobile then 11 else 13)
	boardTitle.Text = "РЕЙТИНГ РАУНДА"
	boardTitle.TextColor3 = Color3.fromRGB(135, 255, 105)
	boardTitle.TextXAlignment = Enum.TextXAlignment.Center
	local boardHeader = addText(board, "Header", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 23), if isMobile then 8 else 9)
	boardHeader.Text = "ИГРОК  •  ВРЕМЯ  •  HP"
	boardHeader.TextColor3 = Color3.fromRGB(170, 185, 175)
	local rowsScroll = Instance.new("ScrollingFrame")
	rowsScroll.Name = "Rows"
	rowsScroll.Size = UDim2.new(1, -12, 0, 60)
	rowsScroll.Position = UDim2.fromOffset(6, 40)
	rowsScroll.BackgroundTransparency = 1
	rowsScroll.BorderSizePixel = 0
	rowsScroll.CanvasSize = UDim2.fromOffset(0, 0)
	rowsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rowsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	rowsScroll.ScrollBarThickness = 4
	rowsScroll.Active = true
	rowsScroll.Parent = board
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 2)
	rowsLayout.Parent = rowsScroll
	local rows = {} :: { TextLabel }
	for index = 1, 10 do
		local row = addText(rowsScroll, `Row{index}`, UDim2.new(1, -6, 0, 18), UDim2.fromOffset(0, 0), if isMobile then 9 else 10)
		row.Visible = false
		rows[index] = row
	end

	local function render()
		local state = self._workspace:GetAttribute("ToxicRainRoundState") or "Waiting"
		local countdown = self._workspace:GetAttribute("ToxicRainCountdown") or 0
		local ready = self._workspace:GetAttribute("ToxicRainReadyPlayers") or 0
		local minimum = self._workspace:GetAttribute("ToxicRainMinimumPlayers") or 2
		local active = self._workspace:GetAttribute("ToxicRainActivePlayers") or 0
		local started = self._workspace:GetAttribute("ToxicRainStartedPlayers") or 0
		local weather = self._workspace:GetAttribute("ToxicRainWeather") or "Clear"
		local timer = self._workspace:GetAttribute("ToxicRainWeatherTimer") or 0
		local nextRainAt = self._workspace:GetAttribute("ToxicRainNextRainAt")
		local nextRainSeconds = if typeof(nextRainAt) == "number" then math.max(0, math.ceil(nextRainAt - self._workspace:GetServerTimeNow())) else nil
		local result = player:GetAttribute("ToxicRainResult")
		local rawHealth = player:GetAttribute("ToxicRainXP")
		local health = if typeof(rawHealth) == "number" then math.clamp(math.round(rawHealth), 0, 100) else 0
		local rawApples = player:GetAttribute("ToxicRainAppleCount")
		local apples = if typeof(rawApples) == "number" then math.max(0, math.floor(rawApples)) else 0
		local healthColor = if health > 60 then Color3.fromRGB(70, 225, 95) elseif health > 30 then Color3.fromRGB(255, 205, 55) else Color3.fromRGB(245, 70, 65)
		for index, segmentFill in segments do
			local fillRatio = math.clamp((health - (index - 1) * 10) / 10, 0, 1)
			segmentFill.Size = UDim2.fromScale(fillRatio, 1)
			segmentFill.BackgroundColor3 = healthColor
			segmentFill.Visible = fillRatio > 0
		end
		healthTitle.Text = `ЗДОРОВЬЕ  {health}/100`
		appleHint.Text = `ИЩИТЕ ЯБЛОКИ И ВОССТАНАВЛИВАЙТЕ ЗДОРОВЬЕ  •  🍎 {apples}`
		healthPanel.Visible = state == "Running" or state == "Completed"
		remaining.Text = `ОСТАЛОСЬ: {active}/{started}`
		remaining.Visible = state == "Running" or state == "Completed"
		status.Text = if result == "Won"
			then "ПОБЕДА! ТЫ ПЕРВЫЙ НА ФИНИШЕ"
			elseif result == "Lost"
			then "РАУНД ЗАВЕРШЁН"
			elseif state == "Waiting"
			then `ВЫБЕРИ SOLO ИЛИ GROUP 2–10 • GROUP {ready}/{minimum}`
			elseif state == "Countdown"
			then `СТАРТ ЧЕРЕЗ: {countdown}`
			elseif weather == "Warning"
			then `ВПЕРЁД К ФИНИШУ!  •  ☢ ДОЖДЬ НАЧНЁТСЯ ЧЕРЕЗ {timer} С`
			elseif weather == "ToxicRain"
			then `ВПЕРЁД К ФИНИШУ!  •  ☢ ДОЖДЬ ЗАКОНЧИТСЯ ЧЕРЕЗ {timer} С`
			elseif state == "Running" and nextRainSeconds ~= nil
			then `ВПЕРЁД К ФИНИШУ!  •  ☢ ДОЖДЬ НАЧНЁТСЯ ЧЕРЕЗ {nextRainSeconds} С`
			elseif state == "Running"
			then "ВПЕРЁД К ФИНИШУ!"
			else ""
		status.Visible = status.Text ~= ""
		overlay.Visible = weather == "ToxicRain" and not isMobile

		local participants = {}
		for _, candidate in self._players:GetPlayers() do
			if candidate:GetAttribute("ToxicRainQueueMode") == "Running" or candidate:GetAttribute("ToxicRainResult") ~= nil then
				table.insert(participants, candidate)
			end
		end
		table.sort(participants, function(first, second)
			local firstTime = first:GetAttribute("ToxicRainFinishTime")
			local secondTime = second:GetAttribute("ToxicRainFinishTime")
			local firstFinished = typeof(firstTime) == "number" and firstTime >= 0
			local secondFinished = typeof(secondTime) == "number" and secondTime >= 0
			if firstFinished ~= secondFinished then return firstFinished end
			if firstFinished and secondFinished and firstTime ~= secondTime then return firstTime < secondTime end
			return first.DisplayName < second.DisplayName
		end)
		board.Visible = #participants > 0 and (state == "Running" or state == "Completed")
		local startedAt = self._workspace:GetAttribute("ToxicRainRoundStartedAt")
		for index, row in rows do
			local candidate = participants[index]
			if candidate == nil then row.Visible = false continue end
			local finishTime = candidate:GetAttribute("ToxicRainFinishTime")
			local finishHealth = candidate:GetAttribute("ToxicRainFinishHealth")
			local candidateHealth = candidate:GetAttribute("ToxicRainXP")
			local shownHealth = if typeof(finishHealth) == "number" then finishHealth elseif typeof(candidateHealth) == "number" then candidateHealth else 0
			local timeText = "—"
			if typeof(finishTime) == "number" and finishTime >= 0 then
				timeText = string.format("%.1fс", finishTime)
			elseif state == "Running" and typeof(startedAt) == "number" then
				timeText = string.format("%.1fс", math.max(0, self._workspace:GetServerTimeNow() - startedAt))
			end
			local name = candidate.DisplayName
			if #name > 13 then name = string.sub(name, 1, 12) .. "…" end
			row.Text = string.format("%d. %s  •  %s  •  %d", index, name, timeText, math.clamp(math.round(shownHealth), 0, 100))
			row.TextColor3 = if candidate:GetAttribute("ToxicRainResult") == "Won" then Color3.fromRGB(255, 225, 75) else Color3.fromRGB(238, 247, 239)
			row.Visible = true
		end
	end

	for _, name in { "ToxicRainRoundState", "ToxicRainCountdown", "ToxicRainReadyPlayers", "ToxicRainMinimumPlayers", "ToxicRainActivePlayers", "ToxicRainStartedPlayers", "ToxicRainWeather", "ToxicRainWeatherTimer", "ToxicRainRoundStartedAt", "ToxicRainNextRainAt", "ToxicRainRainEndsAt" } do
		self._workspace:GetAttributeChangedSignal(name):Connect(render)
	end
	for _, name in { "ToxicRainXP", "ToxicRainProtection", "ToxicRainResult", "ToxicRainAppleCount", "ToxicRainFinishTime", "ToxicRainFinishHealth" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	local accumulator = 0
	RunService.RenderStepped:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator >= 0.2 then accumulator = 0 render() end
	end)
	render()
end

return Controller
