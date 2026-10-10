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
	healthPanel.Size = UDim2.new(1, -24, 0, 76)
	local panelSizeLimit = Instance.new("UISizeConstraint")
	panelSizeLimit.MaxSize = Vector2.new(660, 76)
	panelSizeLimit.Parent = healthPanel
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
	local function ruleRow(name: string, y: number): TextLabel
		local label = addText(healthPanel, name, UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, y), 12)
		label.RichText = true
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextScaled = true
		label.TextWrapped = false
		local textSizeLimit = Instance.new("UITextSizeConstraint")
		textSizeLimit.MinTextSize = 8
		textSizeLimit.MaxTextSize = 12
		textSizeLimit.Parent = label
		return label
	end
	local separator = '<font color="#AABAB2">  •  </font>'
	local shelterRule = if isMobile then "ПРЯЧЬТЕСЬ ПОД КРЫШЕЙ" else "ПРЯЧЬТЕСЬ ПОД ОСТАНОВКАМИ"
	local recoveryRules = ruleRow("ToxicRainRecoveryRules", 34)
	local safetyRules = ruleRow("ToxicRainSafetyRules", 54)
	safetyRules.Text = '<font color="#82FF91">'
		.. (if isMobile then "ОБХОДИТЕ ЛУЖИ" else "НЕ НАСТУПАЙТЕ НА ЛУЖИ")
		.. '</font>' .. separator .. '<font color="#9ED8FF">'
		.. (if isMobile then "ПОБЕДА: СКОРОСТЬ + ЗДОРОВЬЕ" else "ДЛЯ ПОБЕДЫ ВАЖНЫ СКОРОСТЬ И ЗДОРОВЬЕ") .. '</font>'

	local remaining = addText(host, "ToxicRainRemaining", UDim2.fromOffset(170, 28), if isMobile then UDim2.fromOffset(12, 114) else UDim2.fromOffset(12, 4), if isMobile then 11 else 13)
	remaining.BackgroundColor3 = Color3.fromRGB(12, 18, 18)
	remaining.BackgroundTransparency = 0.18
	remaining.TextXAlignment = Enum.TextXAlignment.Center
	addCorner(remaining, 9)

	local board = Instance.new("Frame")
	board.Name = "ToxicRainRoundLeaderboard"
	board.AnchorPoint = Vector2.new(1, 0)
	board.Size = if isMobile then UDim2.new(0.55, -6, 0, 116) else UDim2.fromOffset(270, 112)
	board.Position = if isMobile then UDim2.new(1, -10, 0, 114) else UDim2.new(1, -10, 0, -42)
	board.BackgroundColor3 = Color3.fromRGB(10, 16, 15)
	board.BackgroundTransparency = 0.1
	board.Visible = false
	board.Parent = host
	addCorner(board, 10)
	if not isMobile then
		local function fitTopPanels()
			-- Reserve the right corner for the leaderboard, with a gap to the centered HUD.
			local centerWidth = math.min(660, math.max(1, host.AbsoluteSize.X - 580))
			panelSizeLimit.MaxSize = Vector2.new(centerWidth, 76)
			status.Size = UDim2.fromOffset(math.min(500, centerWidth), 30)
		end
		host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTopPanels)
		fitTopPanels()
	end
	local boardTitle = addText(board, "Title", UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 3), if isMobile then 11 else 13)
	boardTitle.Text = "РЕЙТИНГ РАУНДА"
	boardTitle.TextColor3 = Color3.fromRGB(135, 255, 105)
	boardTitle.TextXAlignment = Enum.TextXAlignment.Center
	local boardHeader = addText(board, "Header", UDim2.new(1, -12, 0, 16), UDim2.fromOffset(6, 23), if isMobile then 8 else 9)
	boardHeader.Text = "МЕСТО • ИГРОК • ВРЕМЯ • ЗДОРОВЬЕ • ОЧКИ"
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
	for index = 1, 16 do
		local row = addText(rowsScroll, `Row{index}`, UDim2.new(1, -6, 0, 18), UDim2.fromOffset(0, 0), if isMobile then 9 else 10)
		row.TextScaled = true
		row.TextWrapped = false
		local rowTextSizeLimit = Instance.new("UITextSizeConstraint")
		rowTextSizeLimit.MinTextSize = 8
		rowTextSizeLimit.MaxTextSize = if isMobile then 9 else 10
		rowTextSizeLimit.Parent = row
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
		local appleRule = if apples > 0
			then if isMobile then `ЯБЛОКО ×{apples}: НАЖМИ НА НЕГО` else `ЯБЛОКО ×{apples}: НАЖМИ 2 ИЛИ КЛИК`
			else if isMobile then "ЯБЛОКИ ЛЕЧАТ" else "ИЩИТЕ ЯБЛОКИ И ВОССТАНАВЛИВАЙТЕСЬ"
		recoveryRules.Text = '<font color="#E2EBE6">' .. shelterRule .. '</font>'
			.. separator .. '<font color="#FFD769">' .. appleRule .. '</font>'
		healthPanel.Visible = state == "Running" or state == "Completed"
		remaining.Text = `ОСТАЛОСЬ: {active}/{started}`
		remaining.Visible = state == "Running" or state == "Completed"
		status.Text = if result == "Won"
			then "ПОБЕДА ПО ОЧКАМ! РАУНД ЗАВЕРШЁН"
			elseif result == "Finished"
			then if state == "Running" then "ТЫ ФИНИШИРОВАЛ! ОСТАЛЬНЫЕ ЕЩЁ БЕГУТ" else "РЕЗУЛЬТАТ СОХРАНЁН • РАУНД ЗАВЕРШЁН"
			elseif result == "Lost"
			then if state == "Running" then "💀 ТЫ ПОГИБ • ОСТАЛЬНЫЕ ЕЩЁ БЕГУТ" else "💀 ТЫ ПОГИБ • РАУНД ЗАВЕРШЁН"
			elseif state == "Waiting"
			then `ВЫБЕРИ SOLO ИЛИ GROUP 2–16 • GROUP {ready}/{minimum}`
			elseif state == "Countdown"
			then `СТАРТ ЧЕРЕЗ: {countdown}`
			elseif weather == "Warning"
			then `ВПЕРЁД К ФИНИШУ!  •  ☢ ДОЖДЬ НАЧНЁТСЯ ЧЕРЕЗ {timer} С`
			elseif weather == "ToxicRain"
			then `ВПЕРЁД К ФИНИШУ!  •  ☢ ДОЖДЬ ЗАКОНЧИТСЯ ЧЕРЕЗ {timer} С`
			elseif state == "Running" and nextRainSeconds ~= nil
			then `ВПЕРЁД К ФИНИШУ!  •  ☢ ДОЖДЬ НАЧНЁТСЯ ЧЕРЕЗ {nextRainSeconds} С`
			elseif state == "Running" and self._workspace:GetAttribute("ToxicRainStormChasing") == true
			then "☢ БУРЯ ДОГОНЯЕТ! БЕГИ К ФИНИШУ!"
			elseif state == "Running"
			then "ВПЕРЁД К ФИНИШУ!"
			else ""
		status.Visible = status.Text ~= ""

		local participants = {}
		local recorded = {}
		local map = self._workspace:FindFirstChild("ToxicRainMap")
		local podium = map and map:FindFirstChild("FinishPodiumRuntime")
		local results = podium and podium:FindFirstChild("Results")
		if results then
			for _, record in results:GetChildren() do
				local rank = record:GetAttribute("ToxicRainRank")
				if typeof(rank) == "number" or record:GetAttribute("ToxicRainResult") == "Lost" then
					recorded[tonumber(record.Name)] = true
					table.insert(participants, {node = record, name = record:GetAttribute("DisplayName"), rank = if typeof(rank) == "number" then rank else math.huge})
				end
			end
		end
		for _, candidate in self._players:GetPlayers() do
			if not recorded[candidate.UserId] and (candidate:GetAttribute("ToxicRainQueueMode") == "Running" or candidate:GetAttribute("ToxicRainResult") ~= nil) then
				table.insert(participants, {node = candidate, name = candidate.DisplayName, rank = math.huge})
			end
		end
		table.sort(participants, function(first, second)
			if first.rank ~= second.rank then return first.rank < second.rank end
			return first.name < second.name
		end)
		board.Visible = #participants > 0 and (state == "Running" or state == "Completed")
		local startedAt = self._workspace:GetAttribute("ToxicRainRoundStartedAt")
		for index, row in rows do
			local entry = participants[index]
			if entry == nil then row.Visible = false continue end
			local candidate = entry.node
			local finishTime = candidate:GetAttribute("ToxicRainFinishTime")
			local finishHealth = candidate:GetAttribute("ToxicRainFinishHealth")
			local candidateHealth = candidate:GetAttribute("ToxicRainXP")
			local shownHealth = if typeof(finishHealth) == "number" then finishHealth elseif typeof(candidateHealth) == "number" then candidateHealth else 0
			local timeText = "—"
			if typeof(finishTime) == "number" and finishTime >= 0 then
				timeText = string.format("%.1fс", finishTime)
			elseif state == "Running" and typeof(startedAt) == "number" and candidate:GetAttribute("ToxicRainResult") == nil then
				timeText = string.format("%.1fс", math.max(0, self._workspace:GetServerTimeNow() - startedAt))
			end
			local score = candidate:GetAttribute("ToxicRainScore")
			local lost = candidate:GetAttribute("ToxicRainResult") == "Lost"
			local place = if lost then "💀" elseif entry.rank > 3 and entry.rank < math.huge then `👎{entry.rank}`
				elseif entry.rank < math.huge then tostring(entry.rank) else "—"
			local scoreText = if typeof(score) == "number" then tostring(score) else "—"
			local shownTime = if lost then "погиб" else timeText
			row.Text = string.format("%s. %s • %s • ❤️ %d • 🏆 %s", place, entry.name, shownTime, math.clamp(math.round(shownHealth), 0, 100), scoreText)
			row.TextColor3 = if lost then Color3.fromRGB(255, 140, 155)
				elseif entry.rank > 3 and entry.rank < math.huge then Color3.fromRGB(255, 205, 130)
				elseif entry.rank == 1 then Color3.fromRGB(255, 225, 75) else Color3.fromRGB(238, 247, 239)
			row.Visible = true
		end
	end

	for _, name in { "ToxicRainRoundState", "ToxicRainCountdown", "ToxicRainReadyPlayers", "ToxicRainMinimumPlayers", "ToxicRainActivePlayers", "ToxicRainStartedPlayers", "ToxicRainWeather", "ToxicRainWeatherTimer", "ToxicRainRoundStartedAt", "ToxicRainNextRainAt", "ToxicRainRainEndsAt", "ToxicRainStormChasing" } do
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
