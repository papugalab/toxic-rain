--!strict

local PodiumPresentation = {}
PodiumPresentation.__index = PodiumPresentation

function PodiumPresentation.OutcomeLabel(result: string?, rank: number?, demoted: boolean?): string
	if result == "Lost" then return "💀 Погиб в раунде" end
	if rank and rank > 3 then return if demoted then "👎 Смещён с пьедестала" else "👎 Вне пьедестала" end
	local medals = { "🥇", "🥈", "🥉" }
	return if rank and medals[rank] then `{medals[rank]} Место {rank}` else ""
end

function PodiumPresentation.CalculationText(health: number, speed: number, score: number, phase: number, seconds: number?): string
	if phase == 1 then return `❤️ Здоровье: {health}` end
	if phase == 2 then
		if seconds ~= nil then
			if seconds >= 100 then return `❤️ {health} + ⚡ {speed}\nПосле 100 с: скорость 0` end
			return `❤️ {health} + ⚡ {speed}\nСкорость: 100 − {math.floor(seconds)} с = {speed}`
		end
		return `❤️ {health} + ⚡ Скорость: {speed}`
	end
	return `❤️ {health} + ⚡ {speed} = 🏆 {score}`
end

function PodiumPresentation.new(ui: any, workspace: Workspace, players: any)
	return setmetatable({ _ui = ui, _workspace = workspace, _players = players, _heads = {}, _animated = {}, _rank = nil, _cameraOwned = false }, PodiumPresentation)
end

function PodiumPresentation:Initialize()
	local notice = Instance.new("TextLabel")
	notice.Name = "ToxicRainPodiumNotice" notice.AnchorPoint = Vector2.new(0.5, 1)
	notice.Position = UDim2.fromScale(0.5, 0.94) notice.Size = UDim2.new(0.9, 0, 0, 64)
	notice.BackgroundColor3 = Color3.fromRGB(16, 35, 26) notice.BackgroundTransparency = 0.15
	notice.TextColor3 = Color3.fromRGB(230, 255, 210) notice.TextWrapped = true
	notice.Font = Enum.Font.GothamBold notice.TextSize = 19 notice.Visible = false notice.ZIndex = 15
	notice.Parent = self._ui:GetHudHost() self._notice = notice
	self._host = self._ui:GetHudHost()
	local size = Instance.new("UISizeConstraint") size.MaxSize = Vector2.new(640, 64) size.Parent = notice
end

function PodiumPresentation:OwnsCamera(): boolean
	local player = self._players:GetLocalPlayer()
	local result = player:GetAttribute("ToxicRainResult")
	return ((result == "Finished" or result == "Won") and typeof(player:GetAttribute("ToxicRainRank")) == "number")
		or (result == "Lost" and player:GetAttribute("ToxicRainWaitingAtFinish") == true)
end

function PodiumPresentation:Update(deltaTime: number)
	local roundState = self._workspace:GetAttribute("ToxicRainRoundState")
	if roundState == "Waiting" or roundState == "Countdown" then table.clear(self._animated) end
	local present = {}
	local localPlayer = self._players:GetLocalPlayer()
	for _, player in self._players:GetPlayers() do
		local result = player:GetAttribute("ToxicRainResult")
		local lost = result == "Lost"
		local rank = player:GetAttribute("ToxicRainRank")
		local score = player:GetAttribute("ToxicRainScore")
		local health = player:GetAttribute("ToxicRainFinishHealth")
		local speed = player:GetAttribute("ToxicRainSpeedPoints")
		local head = player.Character and player.Character:FindFirstChild("Head")
		if not head or not head:IsA("BasePart") then continue end
		if not lost and (typeof(rank) ~= "number" or typeof(score) ~= "number"
			or typeof(health) ~= "number" or typeof(speed) ~= "number") then continue end
		present[player.UserId] = true
		local state = self._heads[player.UserId]
		if state and state.head ~= head then state.gui:Destroy() self._heads[player.UserId] = nil state = nil end
		if not state then
			-- World-aligned HUD projection keeps one UiRoot and works in captures
			-- as well as normal play. It has the same ownership as other HUD views.
			local gui = Instance.new("Frame") gui.Name = `ToxicRainFinishScore_{player.UserId}`
			gui.AnchorPoint = Vector2.new(0.5, 0.5) gui.Size = UDim2.fromOffset(280, 110)
			gui.BackgroundTransparency = 1 gui.ZIndex = 16 gui.Parent = self._host
			local text = Instance.new("TextLabel") text.Size = UDim2.fromScale(1, 1)
			text.BackgroundColor3 = Color3.fromRGB(10, 30, 20) text.BackgroundTransparency = 0.2
			text.TextColor3 = Color3.fromRGB(240, 255, 205) text.TextStrokeTransparency = 0.6
			text.Font = Enum.Font.GothamBold text.TextSize = 18 text.TextWrapped = true text.ZIndex = 16 text.Parent = gui
			state = { head = head, gui = gui, text = text, startedAt = os.clock(), played = self._animated[player.UserId] == true }
			self._animated[player.UserId] = true
			self._heads[player.UserId] = state
		end
		local elapsed = os.clock() - state.startedAt
		if typeof(rank) == "number" and typeof(state.rank) == "number" and state.rank <= 3 and rank > 3 then
			state.demotedUntil = os.clock() + 3
		end
		state.rank = rank
		local demoted = state.demotedUntil ~= nil and os.clock() < state.demotedUntil
		local outside = typeof(rank) == "number" and rank > 3
		if lost or outside then state.played = true end
		local calculation = `🏆 {score} очков`
		if not state.played and elapsed < 2.7 then
			calculation = PodiumPresentation.CalculationText(health, speed, score, math.min(3, math.floor(elapsed / 0.9) + 1), player:GetAttribute("ToxicRainFinishTime"))
			-- A small pulse emphasizes each newly revealed line, not the actual score.
			state.text.TextSize = 16 + math.floor(3 * (1 - (elapsed % 0.9) / 0.9))
		else state.played = true state.text.TextSize = 16 end
		state.gui.Size = if lost then UDim2.fromOffset(210, 70) elseif outside then UDim2.fromOffset(260, 92)
			elseif state.played then UDim2.fromOffset(180, 70) else UDim2.fromOffset(260, 110)
		local outcome = PodiumPresentation.OutcomeLabel(result, rank, demoted)
		state.text.Text = if lost then `{player.DisplayName}\n{outcome}\nОжидание на платформе`
			elseif outside then `{player.DisplayName}\n{calculation} • Место {rank}\n{outcome}`
			else `{player.DisplayName}\n{calculation}\n{outcome}`
		state.text.BackgroundColor3 = if lost then Color3.fromRGB(60, 18, 25)
			elseif outside then Color3.fromRGB(65, 43, 15) else Color3.fromRGB(10, 30, 20)
		state.text.TextColor3 = if lost then Color3.fromRGB(255, 205, 210)
			elseif outside then Color3.fromRGB(255, 225, 155) else Color3.fromRGB(240, 255, 205)
		-- Keep other waiting avatars' markers compact; own banner and table
		-- retain details without ten full death cards overlapping in one row.
		if player ~= localPlayer and lost then
			state.gui.Size = UDim2.fromOffset(46, 42) state.text.Text = "💀" state.text.TextSize = 30
		elseif player ~= localPlayer and outside and not demoted then
			state.gui.Size = UDim2.fromOffset(96, 52)
			state.text.Text = `👎 Место {rank}\n🏆 {score}` state.text.TextSize = 14
		end
		local camera = self._workspace.CurrentCamera
		if camera then
			local point, onScreen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, if rank == 1 then 6.5 else 4.5, 0))
			state.gui.Visible = onScreen and point.Z > 0 and (camera.CFrame.Position - head.Position).Magnitude <= 180
			state.gui.Position = UDim2.fromOffset(point.X - self._host.AbsolutePosition.X, point.Y - self._host.AbsolutePosition.Y)
		else state.gui.Visible = false end
	end
	for id, state in self._heads do
		if not present[id] then state.gui:Destroy() self._heads[id] = nil end
	end

	local ownsCamera = self:OwnsCamera()
	self._notice.Visible = ownsCamera
	if ownsCamera then
		local result = localPlayer:GetAttribute("ToxicRainResult")
		local lost = result == "Lost"
		local rank = localPlayer:GetAttribute("ToxicRainRank")
		local score = localPlayer:GetAttribute("ToxicRainScore")
		local map = self._workspace:FindFirstChild("ToxicRainMap")
		local podium = map and map:FindFirstChild("FinishPodiumRuntime")
		local center = podium and podium:GetAttribute("Center")
		local camera = self._workspace.CurrentCamera
		if self._rank ~= rank or self._result ~= result then
			self._rank = rank self._result = result self._rankChangedAt = os.clock()
		end
		local moved = os.clock() - self._rankChangedAt < 3
		local prefix = if moved then `ТВОЁ МЕСТО: {rank}` else `ФИНИШ • МЕСТО {rank}`
		local explanation = if roundState == "Completed" then "Раунд завершён. Скоро вернёмся в лобби."
			elseif lost then "Ждём финиша или выбытия остальных. Ты не участвуешь повторно."
			elseif rank > 3 then "Ты вне тройки, но результат сохранён." else "Место может измениться, когда финишируют другие."
		self._notice.Text = if lost then `💀 ТЫ ПОГИБ В РАУНДЕ\n{explanation}`
			else `{if rank > 3 then "👎 " else ""}{prefix} • 🏆 {score} очков\n{explanation}`
		self._notice.BackgroundColor3 = if lost then Color3.fromRGB(60, 18, 25)
			elseif rank > 3 then Color3.fromRGB(65, 43, 15) else Color3.fromRGB(16, 35, 26)
		if camera and typeof(center) == "Vector3" then
			local focus = center + Vector3.new(0, 4, -2)
			local frame = CFrame.lookAt(center + Vector3.new(0, 17, 30), focus)
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = camera.CFrame:Lerp(frame, 1 - math.exp(-deltaTime * 5))
			camera.Focus = CFrame.new(focus)
		end
	else self._rank = nil self._result = nil end
	self._cameraOwned = ownsCamera
end

return PodiumPresentation
