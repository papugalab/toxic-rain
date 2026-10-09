--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.ToxicRain.ShelterCombatConfig)
local Protocol = require(ReplicatedStorage.Shared.ToxicRain.ShelterCombatProtocol)

type GripSlot = {
	Id: string,
	StopIndex: number,
	Shelter: Model,
	Model: Model,
	Point: BasePart,
	Prompt: ProximityPrompt,
	StandCFrame: CFrame,
	Occupant: Player?,
}

type GripRecord = {
	Slot: GripSlot,
	Root: BasePart,
	WasAnchored: boolean,
	PoseCleanup: () -> (),
}

local Runtime = {}
Runtime.__index = Runtime

local SHELTER_AVAILABLE_ATTRIBUTE = "ToxicRainShelterAvailable"
local PUSH_TOOL_ATTRIBUTE = "ToxicRainPushTool"

local function isStopAvailable(stop: any): boolean
	return stop.Model:GetAttribute(SHELTER_AVAILABLE_ATTRIBUTE) ~= false
end

local function horizontalDistance(first: Vector3, second: Vector3): number
	return (Vector3.new(first.X, 0, first.Z) - Vector3.new(second.X, 0, second.Z)).Magnitude
end

local function getRoot(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function startGripPose(character: Model, targetPart: BasePart): () -> ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local upperArm = character:FindFirstChild("RightUpperArm")
	local hand = character:FindFirstChild("RightHand")
	if humanoid and upperArm and upperArm:IsA("BasePart") and hand and hand:IsA("BasePart") then
		local target = Instance.new("Attachment")
		target.Name = "ToxicRainGripTarget"
		target.Parent = targetPart
		local control = Instance.new("IKControl")
		control.Name = "ToxicRainRightHandGrip"
		control.Type = Enum.IKControlType.Position
		control.ChainRoot = upperArm
		control.EndEffector = hand
		control.Target = target
		control.SmoothTime = 0.18
		control.Weight = 1
		control.Parent = humanoid
		return function()
			if control.Parent then control:Destroy() end
			if target.Parent then target:Destroy() end
		end
	end

	local torso = character:FindFirstChild("Torso")
	local shoulder = torso and torso:FindFirstChild("Right Shoulder")
	if shoulder and shoulder:IsA("Motor6D") then
		local originalC0 = shoulder.C0
		TweenService:Create(
			shoulder,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ C0 = originalC0 * CFrame.Angles(math.rad(-105), 0, 0) }
		):Play()
		return function()
			if shoulder.Parent then shoulder.C0 = originalC0 end
		end
	end

	return function() end
end

local function makeVisualPart(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(80, 255, 125)
	part.Parent = parent
	return part
end

local function findStops(map: Instance): { { Model: Model, Zone: BasePart, Posts: { BasePart } } }
	local shelters = map:FindFirstChild("Shelters")
	local stops = {}
	if shelters == nil then return stops end
	for _, child in shelters:GetChildren() do
		if not child:IsA("Model") then continue end
		local zone = child:FindFirstChild("ProtectionZone")
		if not zone or not zone:IsA("BasePart") then continue end
		local posts = {}
		for _, part in child:GetChildren() do
			if part:IsA("BasePart") and string.find(string.lower(part.Name), "post", 1, true) then
				table.insert(posts, part)
			end
		end
		if #posts >= 4 then
			table.sort(posts, function(a, b)
				if a.Position.Z == b.Position.Z then return a.Position.X < b.Position.X end
				return a.Position.Z < b.Position.Z
			end)
			table.insert(stops, { Model = child, Zone = zone, Posts = posts })
		end
	end
	table.sort(stops, function(a, b) return a.Zone.Position.Z < b.Zone.Position.Z end)
	return stops
end

function Runtime.new(dependencies: any)
	return setmetatable({
		_players = dependencies.PlayersModule,
		_communication = dependencies.Communication,
		_workspace = dependencies.Workspace,
		_clock = dependencies.Clock or os.clock,
		_slots = {} :: { [string]: GripSlot },
		_grips = {} :: { [Player]: GripRecord },
		_reclaimUntil = {} :: { [Player]: { [number]: number } },
		_pushCooldownUntil = {} :: { [Player]: number },
		_victimImmuneUntil = {} :: { [Player]: number },
		_stops = {} :: { { Model: Model, Zone: BasePart, Posts: { BasePart } } },
		_runtimeFolder = nil :: Folder?,
		_dummy = nil :: Model?,
		_dummyResetToken = 0,
		_pushCueAccumulator = 0,
		_connections = {} :: { any },
		_deathConnections = {} :: { [Player]: any },
		_initialized = false,
	}, Runtime)
end

function Runtime:_isActivePlayer(player: Player): boolean
	return self._workspace:GetAttribute("ToxicRainRoundState") == "Running"
		and player:GetAttribute("ToxicRainQueueMode") == "Running"
		and typeof(player:GetAttribute("ToxicRainXP")) == "number"
		and (player:GetAttribute("ToxicRainXP") :: number) > 0
end

function Runtime:_isCombatActive(): boolean
	return self._workspace:GetAttribute("ToxicRainRoundState") == "Running"
		and Config.IsCombatWeather(self._workspace:GetAttribute("ToxicRainWeather"))
end

function Runtime:_isPushActive(): boolean
	return self._workspace:GetAttribute("ToxicRainRoundState") == "Running"
		and self._workspace:GetAttribute("ToxicRainStartLocked") ~= true
end

function Runtime:_setSlotAppearance(slot: GripSlot)
	local occupied = slot.Occupant ~= nil
	local available = slot.Shelter.Parent ~= nil and slot.Shelter:GetAttribute(SHELTER_AVAILABLE_ATTRIBUTE) ~= false
	local active = self:_isCombatActive() and available
	slot.Model:SetAttribute("OccupantUserId", if slot.Occupant then slot.Occupant.UserId else 0)
	slot.Prompt.Enabled = active and not occupied
	for _, child in slot.Model:GetChildren() do
		if child:IsA("BasePart") and child ~= slot.Point then
			child.Color = if occupied then Color3.fromRGB(255, 185, 45) elseif active then Color3.fromRGB(80, 255, 125) else Color3.fromRGB(70, 105, 82)
			child.Transparency = if not available then 1 elseif active or occupied then 0 else 0.45
		end
	end
end

function Runtime:_isInsideStop(position: Vector3): boolean
	for _, stop in self._stops do
		if not isStopAvailable(stop) then continue end
		local localPosition = stop.Zone.CFrame:PointToObjectSpace(position)
		if math.abs(localPosition.X) <= stop.Zone.Size.X * 0.5
			and math.abs(localPosition.Z) <= stop.Zone.Size.Z * 0.5
		then
			return true
		end
	end
	return false
end

function Runtime:_release(player: Player)
	local record = self._grips[player]
	if record == nil then return end
	self._grips[player] = nil
	record.Slot.Occupant = nil
	record.PoseCleanup()
	if record.Root.Parent then record.Root.Anchored = record.WasAnchored end
	local locks = self._reclaimUntil[player]
	if locks == nil then locks = {}; self._reclaimUntil[player] = locks end
	locks[record.Slot.StopIndex] = self._clock() + Config.GripReclaimLockSeconds
	player:SetAttribute("ToxicRainGripSlot", nil)
	player:SetAttribute("ToxicRainGripEndsAt", nil)
	self:_setSlotAppearance(record.Slot)
end

function Runtime:_releaseAll()
	local players = {}
	for player in self._grips do table.insert(players, player) end
	for _, player in players do self:_release(player) end
end

function Runtime:_tryGrip(player: Player, slotId: string)
	local current = self._grips[player]
	if current ~= nil then
		if current.Slot.Id == slotId then self:_release(player) end
		return
	end
	if not self:_isCombatActive() or not self:_isActivePlayer(player) then return end
	local slot = self._slots[slotId]
	if slot == nil or slot.Occupant ~= nil or slot.Shelter:GetAttribute(SHELTER_AVAILABLE_ATTRIBUTE) == false then return end
	local root = getRoot(player.Character)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then return end
	if (root.Position - slot.Point.Position).Magnitude > Config.GripActivationDistanceStuds then return end
	local locks = self._reclaimUntil[player]
	if locks and (locks[slot.StopIndex] or 0) > self._clock() then return end

	local wasAnchored = root.Anchored
	slot.Occupant = player
	root.CFrame = slot.StandCFrame
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	local poseCleanup = startGripPose(player.Character :: Model, slot.Point)
	self._grips[player] = {
		Slot = slot,
		Root = root,
		WasAnchored = wasAnchored,
		PoseCleanup = poseCleanup,
	}
	local weather = self._workspace:GetAttribute("ToxicRainWeather")
	local weatherRemaining = self._workspace:GetAttribute("ToxicRainWeatherTimer")
	local remaining = if typeof(weatherRemaining) == "number" then math.max(0, weatherRemaining) else 0
	local endsAt = self._workspace:GetServerTimeNow() + remaining
	if weather == "Warning" then endsAt += Config.GripDurationSeconds end
	player:SetAttribute("ToxicRainGripSlot", slot.Id)
	player:SetAttribute("ToxicRainGripEndsAt", endsAt)
	self:_setSlotAppearance(slot)
end

function Runtime:_hasLineOfSight(attackerCharacter: Model, targetModel: Model, origin: Vector3, target: Vector3): boolean
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { attackerCharacter, targetModel }
	parameters.IgnoreWater = true
	return self._workspace:Raycast(origin, target - origin, parameters) == nil
end

function Runtime:_findPushTarget(player: Player, direction: Vector3): (BasePart?, Player?, Model?)
	local root = getRoot(player.Character)
	if root == nil then return nil, nil, nil end
	local bestRoot = nil :: BasePart?
	local bestPlayer = nil :: Player?
	local bestModel = nil :: Model?
	local bestDistance = math.huge
	for _, targetPlayer in self._players:GetPlayers() do
		if targetPlayer == player or not self:_isActivePlayer(targetPlayer) then continue end
		local targetRoot = getRoot(targetPlayer.Character)
		if targetRoot and Config.IsWithinPushArc(root.Position, targetRoot.Position, direction) then
			local distance = horizontalDistance(root.Position, targetRoot.Position)
			if distance < bestDistance and self:_hasLineOfSight(player.Character :: Model, targetPlayer.Character :: Model, root.Position, targetRoot.Position) then
				bestRoot, bestPlayer, bestModel, bestDistance = targetRoot, targetPlayer, targetPlayer.Character, distance
			end
		end
	end
	local dummy = self._dummy
	local dummyRoot = getRoot(dummy)
	if dummy and dummyRoot and Config.IsWithinPushArc(root.Position, dummyRoot.Position, direction) then
		local distance = horizontalDistance(root.Position, dummyRoot.Position)
		if distance < bestDistance and self:_hasLineOfSight(player.Character :: Model, dummy, root.Position, dummyRoot.Position) then
			bestRoot, bestPlayer, bestModel = dummyRoot, nil, dummy
		end
	end
	return bestRoot, bestPlayer, bestModel
end

function Runtime:_publishPushOutcome(player: Player, outcome: string)
	player:SetAttribute("ToxicRainPushOutcome", outcome)
	player:SetAttribute("ToxicRainPushSerial", (player:GetAttribute("ToxicRainPushSerial") or 0) + 1)
end

function Runtime:_scheduleDummyReset(dummy: Model)
	self._dummyResetToken += 1
	local token = self._dummyResetToken
	task.delay(Config.SoloDummyResetSeconds, function()
		if token ~= self._dummyResetToken or self._dummy ~= dummy or not dummy.Parent then return end
		local firstStop = self._stops[1]
		local root = getRoot(dummy)
		if firstStop and root then
			dummy:PivotTo(CFrame.new(firstStop.Zone.Position.X, firstStop.Zone.Position.Y, firstStop.Zone.Position.Z))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

function Runtime:_tryPush(player: Player, direction: Vector3)
	if not self:_isPushActive() or not self:_isActivePlayer(player) then return end
	local root = getRoot(player.Character)
	if root == nil then return end
	local now = self._clock()
	if (self._pushCooldownUntil[player] or 0) > now then return end
	self._pushCooldownUntil[player] = now + Config.PushCooldownSeconds
	player:SetAttribute("ToxicRainPushCooldownEndsAt", self._workspace:GetServerTimeNow() + Config.PushCooldownSeconds)

	local targetRoot, targetPlayer, targetModel = self:_findPushTarget(player, direction)
	if targetRoot == nil then self:_publishPushOutcome(player, "Miss"); return end
	if targetPlayer and self._grips[targetPlayer] ~= nil then
		self:_publishPushOutcome(player, "Blocked")
		return
	end
	if targetPlayer and (self._victimImmuneUntil[targetPlayer] or 0) > now then
		self:_publishPushOutcome(player, "Immune")
		return
	end
	local flat = Vector3.new(targetRoot.Position.X - root.Position.X, 0, targetRoot.Position.Z - root.Position.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(direction.X, 0, direction.Z) end
	local desiredVelocity = flat.Unit * Config.PushHorizontalSpeed + Vector3.new(0, Config.PushVerticalSpeed, 0)
	local velocityDelta = desiredVelocity - targetRoot.AssemblyLinearVelocity
	targetRoot:ApplyImpulse(velocityDelta * targetRoot.AssemblyMass)
	if targetPlayer then
		self._victimImmuneUntil[targetPlayer] = now + Config.PushVictimImmunitySeconds
		targetPlayer:SetAttribute("ToxicRainPushImmuneEndsAt", self._workspace:GetServerTimeNow() + Config.PushVictimImmunitySeconds)
	elseif targetModel then
		self:_scheduleDummyReset(targetModel)
	end
	self:_publishPushOutcome(player, "Hit")
end

local function addToolPart(tool: Tool, handle: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = handle.CFrame * offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

function Runtime:_findPushTool(player: Player): Tool?
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(PUSH_TOOL_ATTRIBUTE) == true then return child end
			end
		end
	end
	return nil
end

function Runtime:_destroyPushTools(player: Player)
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(PUSH_TOOL_ATTRIBUTE) == true then child:Destroy() end
			end
		end
	end
end

function Runtime:_createPushTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil or self:_findPushTool(player) ~= nil then return end
	local tool = Instance.new("Tool")
	tool.Name = "РУКА-ТОЛЧОК"
	tool.ToolTip = "Повернись к игроку и нажми, чтобы толкнуть"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(PUSH_TOOL_ATTRIBUTE, true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.7, 0.7, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool
	local white = Color3.fromRGB(245, 245, 245)
	addToolPart(tool, handle, "LongArm", Vector3.new(1.05, 1.05, 5.8), CFrame.new(0, 0, -3.15), white)
	addToolPart(tool, handle, "Palm", Vector3.new(2.5, 0.75, 2.4), CFrame.new(0, 0, -6.9), white)
	for fingerIndex = 1, 4 do
		local x = (fingerIndex - 2.5) * 0.58
		addToolPart(tool, handle, `Finger{fingerIndex}`, Vector3.new(0.48, 0.55, 1.8), CFrame.new(x, 0, -8.75), white)
	end
	addToolPart(tool, handle, "Thumb", Vector3.new(0.65, 0.65, 1.5), CFrame.new(1.45, 0, -7.35) * CFrame.Angles(0, math.rad(-35), 0), white)
	addToolPart(tool, handle, "ToxicCuff", Vector3.new(1.35, 1.35, 0.9), CFrame.new(0, 0, -0.85), Color3.fromRGB(95, 255, 120))
	tool.Grip = CFrame.new(0, -0.15, -0.2) * CFrame.Angles(math.rad(-90), 0, 0)
	local activatedConnection = tool.Activated:Connect(function()
		if tool.Parent ~= player.Character then return end
		local root = getRoot(player.Character)
		if root then self:_tryPush(player, root.CFrame.LookVector) end
	end)
	tool.Destroying:Once(function() activatedConnection:Disconnect() end)
	tool.Parent = backpack
end

function Runtime:_syncPushTools()
	for _, player in self._players:GetPlayers() do
		if self:_isPushActive() and self:_isActivePlayer(player) then
			self:_createPushTool(player)
		else
			self:_destroyPushTools(player)
		end
	end
end

function Runtime:_createSlot(folder: Folder, stop: any, stopIndex: number, slotIndex: number, post: BasePart)
	local inward = Vector3.new(stop.Zone.Position.X - post.Position.X, 0, stop.Zone.Position.Z - post.Position.Z).Unit
	local floorY = stop.Zone.Position.Y - stop.Zone.Size.Y * 0.5
	local hookPosition = Vector3.new(post.Position.X, floorY + 5, post.Position.Z) + inward * 1.15
	local hookFrame = CFrame.lookAt(hookPosition, hookPosition + inward)
	local model = Instance.new("Model")
	model.Name = `GripHook_{stopIndex}_{slotIndex}`
	model:SetAttribute("SlotId", model.Name)
	model:SetAttribute("StopIndex", stopIndex)
	model.Parent = folder
	makeVisualPart(model, "Stem", Vector3.new(0.45, 1.5, 0.45), hookFrame)
	makeVisualPart(model, "Catch", Vector3.new(0.45, 0.45, 1.1), hookFrame * CFrame.new(0, -0.55, 0.45))
	local point = makeVisualPart(model, "GrabPoint", Vector3.new(0.25, 0.25, 0.25), hookFrame)
	point.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "GRAB"
	prompt.ObjectText = "SAFE GRIP"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Enabled = false
	prompt.Parent = point
	local standPosition = Vector3.new(hookPosition.X, floorY + 3, hookPosition.Z) + inward * 2.2
	local slot: GripSlot = {
		Id = model.Name,
		StopIndex = stopIndex,
		Shelter = stop.Model,
		Model = model,
		Point = point,
		Prompt = prompt,
		StandCFrame = CFrame.lookAt(standPosition, Vector3.new(hookPosition.X, standPosition.Y, hookPosition.Z)),
		Occupant = nil,
	}
	self._slots[slot.Id] = slot
	table.insert(self._connections, prompt.Triggered:Connect(function(player)
		self:_tryGrip(player, slot.Id)
	end))
	self:_setSlotAppearance(slot)
end

function Runtime:_createHooks()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	assert(map ~= nil, "ToxicRainMap is required")
	self._stops = findStops(map)
	assert(#self._stops == #Config.GripCapacities, "Toxic Rain requires exactly five full shelters")
	local old = map:FindFirstChild("ShelterCombatRuntime")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "ShelterCombatRuntime"
	folder.Parent = map
	self._runtimeFolder = folder
	for stopIndex, capacity in Config.GripCapacities do
		local stop = self._stops[stopIndex]
		for slotIndex = 1, capacity do
			self:_createSlot(folder, stop, stopIndex, slotIndex, stop.Posts[slotIndex])
		end
	end
end

function Runtime:_destroyDummy()
	self._dummyResetToken += 1
	if self._dummy then self._dummy:Destroy(); self._dummy = nil end
end

function Runtime:_createDummy()
	if self._dummy or self._runtimeFolder == nil then return end
	local stop = nil
	for _, candidate in self._stops do
		if isStopAvailable(candidate) then stop = candidate; break end
	end
	if stop == nil then return end
	local model = Instance.new("Model")
	model.Name = "SoloPushDummy"
	model:SetAttribute("ToxicRainSoloDummy", true)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 3, 1.5)
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = false
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.5, 3.5, 1.5)
	body.Color = Color3.fromRGB(255, 190, 55)
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2, 2, 2)
	head.Color = Color3.fromRGB(255, 225, 165)
	head.CanCollide = false
	head.Parent = model
	body.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 2.75, 0)
	for _, part in { body, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	model.PrimaryPart = root
	model.Parent = self._runtimeFolder
	model:PivotTo(CFrame.new(stop.Zone.Position.X, stop.Zone.Position.Y, stop.Zone.Position.Z))
	root:SetNetworkOwner(nil)
	self._dummy = model
end

function Runtime:_syncPhase()
	-- Warning transitions into rain without releasing; Clear marks the exact rain end.
	if Config.ShouldReleaseAllGrips(
		self._workspace:GetAttribute("ToxicRainRoundState"),
		self._workspace:GetAttribute("ToxicRainWeather")
	) then
		self:_releaseAll()
	end
	for _, slot in self._slots do self:_setSlotAppearance(slot) end
	if self._workspace:GetAttribute("ToxicRainRoundState") == "Running"
		and self._workspace:GetAttribute("ToxicRainRoundMode") == "Solo"
	then self:_createDummy() else self:_destroyDummy() end
	self:_syncPushTools()
end

function Runtime:_clearPlayer(player: Player)
	self:_release(player)
	self:_destroyPushTools(player)
	local deathConnection = self._deathConnections[player]
	if deathConnection then deathConnection:Disconnect(); self._deathConnections[player] = nil end
	self._reclaimUntil[player] = nil
	self._pushCooldownUntil[player] = nil
	self._victimImmuneUntil[player] = nil
	player:SetAttribute("ToxicRainGripSlot", nil)
	player:SetAttribute("ToxicRainGripEndsAt", nil)
	player:SetAttribute("ToxicRainPushCooldownEndsAt", nil)
	player:SetAttribute("ToxicRainPushImmuneEndsAt", nil)
end

function Runtime:_bindCharacter(player: Player, character: Model)
	local oldConnection = self._deathConnections[player]
	if oldConnection then oldConnection:Disconnect(); self._deathConnections[player] = nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		self._deathConnections[player] = humanoid.Died:Connect(function() self:_release(player) end)
	end
end

function Runtime:Initialize()
	if self._initialized then return end
	self:_createHooks()
	self._communication:RegisterHandler(Protocol.MessageTypes.GripIntent, Protocol.ValidateGripIntent, function(player, payload)
		self:_tryGrip(player, payload.SlotId)
	end)
	self._communication:RegisterHandler(Protocol.MessageTypes.PushIntent, Protocol.ValidatePushIntent, function(player, payload)
		self:_tryPush(player, payload.Direction)
	end)
	table.insert(self._connections, self._workspace:GetAttributeChangedSignal("ToxicRainWeather"):Connect(function() self:_syncPhase() end))
	table.insert(self._connections, self._workspace:GetAttributeChangedSignal("ToxicRainRoundState"):Connect(function() self:_syncPhase() end))
	table.insert(self._connections, self._workspace:GetAttributeChangedSignal("ToxicRainRoundMode"):Connect(function() self:_syncPhase() end))
	table.insert(self._connections, self._workspace:GetAttributeChangedSignal("ToxicRainStartLocked"):Connect(function() self:_syncPushTools() end))
	table.insert(self._connections, self._players.CharacterRemoving:Connect(function(player) self:_release(player) end))
	table.insert(self._connections, self._players.CharacterAdded:Connect(function(player, character) self:_bindCharacter(player, character) end))
	table.insert(self._connections, self._players.PlayerRemoving:Connect(function(player) self:_clearPlayer(player) end))
	table.insert(self._connections, RunService.Heartbeat:Connect(function(deltaTime)
		self._pushCueAccumulator += deltaTime
		if self._pushCueAccumulator < 0.15 then return end
		self._pushCueAccumulator = 0
		self:_syncPushTools()
	end))
	for _, player in self._players:GetPlayers() do
		if player.Character then self:_bindCharacter(player, player.Character) end
	end
	self._initialized = true
	self:_syncPhase()
end

return Runtime
