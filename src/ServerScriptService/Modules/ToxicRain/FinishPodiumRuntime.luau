--!strict

-- Owns generated finish scenery, not the authored map or round rules.
local Podium = {}
Podium.__index = Podium

local function placeRoot(character: Model, root: BasePart, position: Vector3)
	local target = CFrame.lookAt(position, position - Vector3.new(0, 0, 1))
	-- Place the root exactly, even when a rig has a custom model pivot.
	character:PivotTo(target * root.CFrame:ToObjectSpace(character:GetPivot()))
end

function Podium.new(players: any, workspace: any)
	return setmetatable({ _players = players, _workspace = workspace, _model = nil :: Model?, _placed = {}, _departed = {}, _eliminated = {}, _eliminatedCount = 0 }, Podium)
end

function Podium:Clear()
	for _, player in self._players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if self._placed[player.UserId] and root and root:IsA("BasePart") then root.Anchored = false end
		player:SetAttribute("ToxicRainWaitingAtFinish", nil)
	end
	table.clear(self._placed)
	table.clear(self._departed)
	table.clear(self._eliminated)
	self._eliminatedCount = 0
	if self._model then self._model:Destroy() self._model = nil end
end

function Podium:RemovePlayer(playerId: number)
	self._departed[playerId] = true
	self._placed[playerId] = nil
	local results = self._model and self._model:FindFirstChild("Results")
	local record = results and results:FindFirstChild(tostring(playerId))
	if record then record:SetAttribute("Connected", false) end
end

function Podium:_ensure(): Model?
	if self._model then return self._model end
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local finish = map and map:FindFirstChild("FinishZone")
	if not finish or not finish:IsA("BasePart") then return nil end
	local model = Instance.new("Model")
	model.Name = "FinishPodiumRuntime"
	local center = Vector3.new(finish.Position.X, finish.Position.Y + finish.Size.Y / 2, finish.Position.Z + finish.Size.Z / 2 + 28)
	model:SetAttribute("Center", center)
	local function block(name: string, size: Vector3, position: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name part.Anchored = true part.Size = size part.Position = position
		part.Color = color part.Material = Enum.Material.SmoothPlastic part.Parent = model
		return part
	end
	block("Stage", Vector3.new(48, 1, 24), center - Vector3.new(0, 0.5, 0), Color3.fromRGB(95, 100, 105))
	for rank, definition in { {0, 6, Color3.fromRGB(255, 210, 70)}, {-9, 4, Color3.fromRGB(180, 200, 210)}, {9, 2, Color3.fromRGB(185, 116, 65)} } do
		local step = block(`Step{rank}`, Vector3.new(8, definition[2], 8), center + Vector3.new(definition[1], definition[2] / 2, 0), definition[3])
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui") gui.Face = face gui.CanvasSize = Vector2.new(200, 120) gui.Parent = step
			local text = Instance.new("TextLabel") text.Size = UDim2.fromScale(1, 1) text.BackgroundTransparency = 1
			text.Text = tostring(rank) text.Font = Enum.Font.GothamBlack text.TextScaled = true text.TextColor3 = Color3.fromRGB(20, 30, 25) text.Parent = gui
		end
	end
	local records = Instance.new("Folder") records.Name = "Results" records.Parent = model
	model.Parent = map self._model = model
	return model
end

function Podium:PlaceEliminated(player: any)
	if self._departed[player.UserId] or player:GetAttribute("ToxicRainResult") ~= "Lost" then return end
	local model = self:_ensure()
	if not model then return end
	if not self._eliminated[player.UserId] then
		self._eliminatedCount += 1
		self._eliminated[player.UserId] = self._eliminatedCount
	end
	local results = model:FindFirstChild("Results") :: Folder
	local record = results:FindFirstChild(tostring(player.UserId))
	if not record then
		record = Instance.new("Folder") record.Name = tostring(player.UserId)
		record:SetAttribute("DisplayName", player.DisplayName)
		record:SetAttribute("ToxicRainResult", "Lost")
		record:SetAttribute("ToxicRainFinishTime", -1)
		record:SetAttribute("ToxicRainFinishHealth", 0)
		record:SetAttribute("Connected", true) record.Parent = results
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- The death remains real. The normal character respawn becomes a display
	-- avatar at the finish, never a second chance to run or score.
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
	local center = model:GetAttribute("Center") :: Vector3
	local position = center + Vector3.new(-20.25 + (self._eliminated[player.UserId] - 1) * 4.5, 3, -9)
	root.AssemblyLinearVelocity = Vector3.zero root.AssemblyAngularVelocity = Vector3.zero
	placeRoot(character, root, position)
	root.Anchored = true
	self._placed[player.UserId] = "Lost"
	player:SetAttribute("ToxicRainWaitingAtFinish", true)
	player:SetAttribute("ToxicRainAutoRun", false)
end

function Podium:Update(standings: { any })
	if #standings == 0 then return end
	local model = self:_ensure()
	if not model then return end
	local results = model:FindFirstChild("Results") :: Folder
	local playersById = {}
	for _, player in self._players:GetPlayers() do
		if not self._departed[player.UserId] then playersById[player.UserId] = player end
	end
	for _, record in standings do
		local player = playersById[record.playerId]
		local row = results:FindFirstChild(tostring(record.playerId))
		if not row then
			row = Instance.new("Folder") row.Name = tostring(record.playerId)
			row:SetAttribute("DisplayName", if player then player.DisplayName else tostring(record.playerId))
			row:SetAttribute("ToxicRainFinishTime", record.time)
			row:SetAttribute("ToxicRainFinishHealth", record.health)
			row:SetAttribute("ToxicRainSpeedPoints", record.speed)
			row:SetAttribute("ToxicRainScore", record.score)
			row.Parent = results
		end
		row:SetAttribute("ToxicRainRank", record.rank)
		row:SetAttribute("Connected", player ~= nil)
		if not player then continue end
		player:SetAttribute("ToxicRainFinishTime", record.time)
		player:SetAttribute("ToxicRainFinishHealth", record.health)
		player:SetAttribute("ToxicRainSpeedPoints", record.speed)
		player:SetAttribute("ToxicRainScore", record.score)
		player:SetAttribute("ToxicRainRank", record.rank)
		player:SetAttribute("ToxicRainAutoRun", false)
		player:SetAttribute("ToxicRainWaitingAtFinish", true)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then continue end
		if self._placed[player.UserId] ~= record.rank or not root.Anchored then
			local step = model:FindFirstChild(`Step{record.rank}`)
			local center = model:GetAttribute("Center") :: Vector3
			local position = if step and step:IsA("BasePart") then step.Position + Vector3.new(0, step.Size.Y / 2 + 3, 0)
				else center + Vector3.new((record.rank - 4) * 5 - 15, 3, 9)
			root.AssemblyLinearVelocity = Vector3.zero root.AssemblyAngularVelocity = Vector3.zero
			placeRoot(character, root, position)
			root.Anchored = true
			self._placed[player.UserId] = record.rank
		end
	end
end

return Podium
