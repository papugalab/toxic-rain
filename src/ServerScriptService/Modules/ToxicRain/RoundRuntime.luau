--!strict

local RunService = game:GetService("RunService")

local RoundConfig = require(script.Parent.RoundConfig)
local RoundStateMachine = require(script.Parent.RoundStateMachine)

local RoundRuntime = {}
RoundRuntime.__index = RoundRuntime

local SHELTER_AVAILABLE_ATTRIBUTE = "ToxicRainShelterAvailable"

local function containsPoint(zone: BasePart, point: Vector3): boolean
	local localPoint = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size * 0.5
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function containsHorizontal(zone: BasePart, point: Vector3): boolean
	local localPoint = zone.CFrame:PointToObjectSpace(point)
	local half = zone.Size * 0.5
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z
end

local function findRoadContainer(map: Instance): Instance?
	return map:FindFirstChild("RoadZones") or map:FindFirstChild("RoadParts")
end

local function isPointOnRoad(map: Instance, point: Vector3): boolean
	local roadContainer = findRoadContainer(map)
	if not roadContainer then return false end
	for _, descendant in roadContainer:GetDescendants() do
		if descendant:IsA("BasePart") then
			local localPoint = descendant.CFrame:PointToObjectSpace(point)
			local half = descendant.Size * 0.5
			if RoundConfig.IsInsideHorizontalZone(
				localPoint.X,
				localPoint.Z,
				half.X,
				half.Z,
				RoundConfig.RoadEdgeToleranceStuds
			) then
				return true
			end
		end
	end
	return false
end

local function isPointOnCentralRoad(map: Instance, point: Vector3): boolean
	local roadContainer = findRoadContainer(map)
	if not roadContainer then return false end
	for _, descendant in roadContainer:GetDescendants() do
		if descendant:IsA("BasePart") and RoundConfig.IsCentralRoadPartName(descendant.Name) then
			local localPoint = descendant.CFrame:PointToObjectSpace(point)
			local half = descendant.Size * 0.5
			if RoundConfig.IsInsideHorizontalZone(localPoint.X, localPoint.Z, half.X, half.Z, RoundConfig.RoadEdgeToleranceStuds) then
				return true
			end
		end
	end
	return false
end

local function findShelterModel(shelters: Instance, descendant: Instance): Model?
	local current = descendant.Parent
	while current and current ~= shelters do
		if current:IsA("Model") and current.Parent == shelters then return current end
		current = current.Parent
	end
	return nil
end

local function worldHorizontalHalfExtents(part: BasePart): (number, number)
	local half = part.Size * 0.5
	local right = part.CFrame.RightVector
	local up = part.CFrame.UpVector
	local look = part.CFrame.LookVector
	local halfX = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z
	local halfZ = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	return halfX, halfZ
end

local function findStartingRoadPart(map: Instance): BasePart?
	local roadContainer = findRoadContainer(map)
	if not roadContainer then return nil end
	local startingRoad = nil :: BasePart?
	local minimumZ = math.huge
	for _, descendant in roadContainer:GetDescendants() do
		if descendant:IsA("BasePart") then
			local _, halfZ = worldHorizontalHalfExtents(descendant)
			local startZ = descendant.Position.Z - halfZ
			if startZ < minimumZ then
				minimumZ = startZ
				startingRoad = descendant
			end
		end
	end
	return startingRoad
end

function RoundRuntime:_rainLossFor(player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return 0 end
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local zones = map and (map:FindFirstChild("Shelters") or map:FindFirstChild("ShelterZones"))
	if not zones then player:SetAttribute("ToxicRainProtection", "Open") return RoundConfig.RainXpLossPerSecond end
	for _, child in zones:GetDescendants() do
		if child:IsA("BasePart") and containsPoint(child, root.Position) then
			local shelter = findShelterModel(zones, child)
			if shelter and shelter:GetAttribute(SHELTER_AVAILABLE_ATTRIBUTE) == false then continue end
			local protection = child:GetAttribute("ProtectionClass")
			if protection == "Normal" or protection == "Large" then
				if shelter then self._furthestUsedShelterZ = math.max(self._furthestUsedShelterZ or -math.huge, child.Position.Z) end
				player:SetAttribute("ToxicRainProtection", "Full")
				return 0
			end
			if protection == "Weak" then
				if shelter then self._furthestUsedShelterZ = math.max(self._furthestUsedShelterZ or -math.huge, child.Position.Z) end
				player:SetAttribute("ToxicRainProtection", "Weak")
				return RoundConfig.RainXpLossPerSecond * RoundConfig.WeakShelterDamageMultiplier
			end
		end
	end
	player:SetAttribute("ToxicRainProtection", "Open")
	return RoundConfig.RainXpLossPerSecond
end

function RoundRuntime:_setShelterAvailable(shelter: Model, available: boolean)
	shelter:SetAttribute(SHELTER_AVAILABLE_ATTRIBUTE, available)
	for _, descendant in shelter:GetDescendants() do
		if descendant:IsA("BasePart") then
			local state = self._shelterPartStates[descendant]
			if state == nil then
				state = {
					Transparency = descendant.Transparency,
					CanCollide = descendant.CanCollide,
					CanTouch = descendant.CanTouch,
					CanQuery = descendant.CanQuery,
				}
				self._shelterPartStates[descendant] = state
			end
			if available then
				descendant.Transparency = state.Transparency
				descendant.CanCollide = state.CanCollide
				descendant.CanTouch = state.CanTouch
				descendant.CanQuery = state.CanQuery
			else
				descendant.Transparency = 1
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if self._shelterVisualStates[descendant] == nil then self._shelterVisualStates[descendant] = descendant.Transparency end
			descendant.Transparency = if available then self._shelterVisualStates[descendant] else 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
			if self._shelterVisualStates[descendant] == nil then self._shelterVisualStates[descendant] = descendant.Enabled end
			descendant.Enabled = if available then self._shelterVisualStates[descendant] else false
		end
	end
end

function RoundRuntime:_retireUsedShelters()
	local cutoffZ = self._furthestUsedShelterZ
	self._furthestUsedShelterZ = nil
	if cutoffZ == nil then return end
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local shelters = map and map:FindFirstChild("Shelters")
	if shelters == nil then return end
	for _, shelter in shelters:GetChildren() do
		if not shelter:IsA("Model") then continue end
		local zone = shelter:FindFirstChild("ProtectionZone")
		if zone and zone:IsA("BasePart") and zone.Position.Z <= cutoffZ + 0.01 then
			self:_setShelterAvailable(shelter, false)
		end
	end
end

function RoundRuntime:_restoreShelters()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local shelters = map and map:FindFirstChild("Shelters")
	if shelters == nil then return end
	for _, shelter in shelters:GetChildren() do
		if shelter:IsA("Model") then self:_setShelterAvailable(shelter, true) end
	end
	self._furthestUsedShelterZ = nil
end

function RoundRuntime:_frontLossFor(player: Player): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local frontZ = self._workspace:GetAttribute("ToxicRainFrontZ")
	if root and root:IsA("BasePart") and typeof(frontZ) == "number" and root.Position.Z <= frontZ then
		player:SetAttribute("ToxicRainHazard", "Front")
		return RoundConfig.StormFrontXpLossPerSecond
	end
	return 0
end

function RoundRuntime:_hazardLossFor(player: Player): number
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return 0 end
	for _, zone in self._puddleZones do
		if zone.Parent and containsHorizontal(zone, root.Position) then
			player:SetAttribute("ToxicRainHazard", "Puddle")
			return RoundConfig.HazardXpLossPerSecond
		end
	end
	for _, fountain in self._fountains do
		if fountain.Model.Parent and fountain.Model:GetAttribute("ToxicRainFountainState") == "Active"
			and containsHorizontal(fountain.Zone, root.Position)
		then
			player:SetAttribute("ToxicRainHazard", "Fountain")
			return RoundConfig.HazardXpLossPerSecond
		end
	end
	return 0
end


function RoundRuntime:_applyEnvironmentalTick(includeRain: boolean)
	local snapshot = self._round:GetSnapshot()
	for _, player in self._players:GetPlayers() do
		if snapshot.results[player.UserId] ~= "Active" then continue end
		player:SetAttribute("ToxicRainHazard", "None")
		local loss = math.max(self:_frontLossFor(player), self:_hazardLossFor(player))
		if includeRain then loss = math.max(loss, self:_rainLossFor(player)) end
		local xp = player:GetAttribute("ToxicRainXP")
		if typeof(xp) ~= "number" or xp <= 0 or loss <= 0 then continue end
		local nextXp = math.clamp(math.round(xp - loss), 0, 100)
		player:SetAttribute("ToxicRainXP", nextXp)
		if nextXp == 0 and player.Character then
			self._round:Eliminate(player.UserId)
			player:SetAttribute("ToxicRainFinishTime", -1)
			player:SetAttribute("ToxicRainFinishHealth", 0)
			player:SetAttribute("ToxicRainResult", "Lost")
			player.Character:BreakJoints()
			self:_publish()
			if self._round:GetSnapshot().activeCount == 0 then self:_scheduleRestart() end
		end
	end
end

function RoundRuntime:_applyRainTick()
	self:_applyEnvironmentalTick(true)
end

function RoundRuntime:_runRainSchedule(generation: number)
	local scheduleStartedAt = self._workspace:GetServerTimeNow()
	local firstWarningStart = RoundConfig.RainWarningStartSeconds[1]
	self._workspace:SetAttribute("ToxicRainNextRainAt", if firstWarningStart then scheduleStartedAt + firstWarningStart + RoundConfig.RainWarningSeconds else nil)
	for eventIndex, startSecond in RoundConfig.RainWarningStartSeconds do
		task.spawn(function()
			task.wait(startSecond)
			if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
			for remaining = RoundConfig.RainWarningSeconds, 1, -1 do
				self._workspace:SetAttribute("ToxicRainWeather", "Warning")
				self._workspace:SetAttribute("ToxicRainWeatherTimer", remaining)
				task.wait(1)
			end
			self._furthestUsedShelterZ = nil
			for remaining = RoundConfig.RainDurationSeconds, 1, -1 do
				if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
				self._workspace:SetAttribute("ToxicRainWeather", "ToxicRain")
				self._workspace:SetAttribute("ToxicRainWeatherTimer", remaining)
				self._workspace:SetAttribute("ToxicRainNextRainAt", nil)
				self._workspace:SetAttribute("ToxicRainRainEndsAt", self._workspace:GetServerTimeNow() + remaining)
				self:_applyRainTick()
				task.wait(1)
			end
			self:_retireUsedShelters()
			self._workspace:SetAttribute("ToxicRainWeather", "Clear")
			self._workspace:SetAttribute("ToxicRainWeatherTimer", 0)
			self._workspace:SetAttribute("ToxicRainRainEndsAt", nil)
			local nextWarningStart = RoundConfig.RainWarningStartSeconds[eventIndex + 1]
			self._workspace:SetAttribute("ToxicRainNextRainAt", if nextWarningStart then scheduleStartedAt + nextWarningStart + RoundConfig.RainWarningSeconds else nil)
		end)
	end
end

function RoundRuntime:_giveApple(player: Player, marker: BasePart)
	if marker:GetAttribute("Taken") then return end
	marker:SetAttribute("Taken", true)
	marker.Transparency = 1
	marker.CanTouch = false
	local tool = Instance.new("Tool")
	tool.Name = "Apple"
	tool:SetAttribute("ToxicRainApple", true)
	tool.CanBeDropped = false
	local handle = marker:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Transparency = 0
	handle.Parent = tool
	local generation = self._generation
	local activatedConnection = tool.Activated:Connect(function()
		if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
		if tool.Parent ~= player.Character and tool.Parent ~= player:FindFirstChildOfClass("Backpack") then return end
		player:SetAttribute("ToxicRainXP", 100)
		player:SetAttribute("ToxicRainAppleCount", math.max(0, (player:GetAttribute("ToxicRainAppleCount") or 1) - 1))
		tool:Destroy()
	end)
	table.insert(self._roundConnections, activatedConnection)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		tool.Parent = backpack
		player:SetAttribute("ToxicRainAppleCount", (player:GetAttribute("ToxicRainAppleCount") or 0) + 1)
	else tool:Destroy() end
end

function RoundRuntime:_clearRoundConnections()
	for _, connection in self._roundConnections do connection:Disconnect() end
	table.clear(self._roundConnections)
end

function RoundRuntime:_spawnApples()
	self:_clearRoundConnections()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local folder = map and map:FindFirstChild("AppleSpawnPoints")
	if not folder then return end
	local bySection = { {}, {}, {} }
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 1 child.CanTouch = false child:SetAttribute("Taken", false)
			local section = child:GetAttribute("SectionIndex")
			if typeof(section) == "number" and bySection[section] then table.insert(bySection[section], child) end
		end
	end
	local activePlayers = self._round:GetSnapshot().startedCount
	local count = math.min(4, math.max(2, math.ceil(activePlayers * 0.5)))
	local quotas = if count == 2 then {1,1,0} elseif count == 3 then {2,1,0} else {2,1,1}
	for section, quota in quotas do
		local candidates = bySection[section]
		for _ = 1, quota do
			if #candidates == 0 then break end
			local marker = table.remove(candidates, math.random(1, #candidates))
			marker.Transparency = 0 marker.CanTouch = true
			local generation = self._generation
			local touchedConnection = marker.Touched:Connect(function(hit)
				if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
				local character = hit:FindFirstAncestorOfClass("Model")
				local player = character and self._players:GetPlayerFromCharacter(character)
				if player then self:_giveApple(player, marker) end
			end)
			table.insert(self._roundConnections, touchedConnection)
		end
	end
end

local function roadSurfaceYAt(map: Instance, x: number, z: number): number
	local bestY = 0
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart")
			and (string.match(descendant.Name, "^RoadSection") or string.match(descendant.Name, "^Shoulder_"))
		then
			local localPoint = descendant.CFrame:PointToObjectSpace(Vector3.new(x, descendant.Position.Y, z))
			local half = descendant.Size * 0.5
			if math.abs(localPoint.X) <= half.X + 2 and math.abs(localPoint.Z) <= half.Z + 2 then
				bestY = math.max(bestY, descendant.Position.Y + half.Y)
			end
		end
	end
	return bestY
end

local function makeHazardZone(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local zone = Instance.new("Part")
	zone.Name = name
	zone.Size = size
	zone.CFrame = cframe
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	zone.Transparency = 1
	zone.Parent = parent
	return zone
end

function RoundRuntime:_setFountainState(fountain: any, state: string)
	fountain.Model:SetAttribute("ToxicRainFountainState", state)
	fountain.Warning.Transparency = if state == "Warning" then 0.35 elseif state == "Active" then 0.12 else 0.78
	fountain.Warning.Color = if state == "Warning" then Color3.fromRGB(210, 255, 65) else Color3.fromRGB(45, 255, 85)
	fountain.Emitter.Enabled = state == "Active"
end

function RoundRuntime:_runFountain(fountain: any, generation: number, phaseOffset: number)
	task.spawn(function()
		task.wait(phaseOffset)
		while generation == self._generation and self._round:GetSnapshot().state == "Running" do
			self:_setFountainState(fountain, "Warning")
			task.wait(RoundConfig.FountainWarningSeconds)
			if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
			self:_setFountainState(fountain, "Active")
			task.wait(RoundConfig.FountainActiveSeconds)
			if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
			self:_setFountainState(fountain, "Idle")
			task.wait(RoundConfig.FountainIdleSeconds)
		end
	end)
end

function RoundRuntime:_clearHazards()
	if self._hazardFolder then self._hazardFolder:Destroy(); self._hazardFolder = nil end
	table.clear(self._puddleZones)
	table.clear(self._fountains)
	self._workspace:SetAttribute("ToxicRainHazardSeed", nil)
end

function RoundRuntime:_spawnHazards(generation: number)
	self:_clearHazards()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	if map == nil then return end
	local shelters = map:FindFirstChild("Shelters")
	local shelterZones = {}
	if shelters then
		for _, shelter in shelters:GetChildren() do
			local zone = shelter:IsA("Model") and shelter:FindFirstChild("ProtectionZone") or nil
			if zone and zone:IsA("BasePart") then table.insert(shelterZones, zone) end
		end
	end
	table.sort(shelterZones, function(a, b) return a.Position.Z < b.Position.Z end)
	if #shelterZones < 3 then return end
	local finish = map:FindFirstChild("FinishZone")
	if not finish or not finish:IsA("BasePart") then return end
	local startZ = shelterZones[3].Position.Z + shelterZones[3].Size.Z * 0.5 + 14
	local _, finishHalfZ = worldHorizontalHalfExtents(finish)
	local endZ = finish.Position.Z - finishHalfZ - 10
	if endZ - startZ < 80 then return end
	local seed = Random.new():NextInteger(1, 2147483646)
	if seed == self._lastHazardSeed then seed = seed % 2147483646 + 1 end
	self._lastHazardSeed = seed
	local layout = RoundConfig.GenerateHazardLayout(seed, startZ, endZ)
	local folder = Instance.new("Folder")
	folder.Name = "RuntimeToxicHazards"
	folder:SetAttribute("Seed", seed)
	folder.Parent = map
	self._hazardFolder = folder
	self._workspace:SetAttribute("ToxicRainHazardSeed", seed)
	for index, definition in layout.Puddles do
		local model = Instance.new("Model")
		model.Name = `ToxicPuddle_{index}`
		model:SetAttribute("Band", definition.Band)
		model.Parent = folder
		local y = roadSurfaceYAt(map, definition.X, definition.Z)
		local frame = CFrame.new(definition.X, y + 0.55, definition.Z) * CFrame.Angles(0, math.rad(definition.Rotation), 0)
		local zone = makeHazardZone(model, "DamageZone", Vector3.new(definition.RadiusX * 2, 4, definition.RadiusZ * 2), frame)
		local shapeRandom = Random.new(definition.ShapeSeed)
		local lobeCount = shapeRandom:NextInteger(6, 9)
		for layer = 1, lobeCount do
			local isCenter = layer == 1
			local angle = shapeRandom:NextNumber(0, math.pi * 2)
			local distance = if isCenter then 0 else shapeRandom:NextNumber(0.42, 0.82)
			local scaleX = if isCenter then shapeRandom:NextNumber(0.76, 0.96) else shapeRandom:NextNumber(0.28, 0.58)
			local scaleZ = if isCenter then shapeRandom:NextNumber(0.68, 0.9) else shapeRandom:NextNumber(0.25, 0.54)
			local lobeFrame = frame
				* CFrame.new(
					math.cos(angle) * definition.RadiusX * distance,
					0,
					math.sin(angle) * definition.RadiusZ * distance
				)
				* CFrame.Angles(0, math.rad(shapeRandom:NextNumber(-38, 38)), 0)
			local liquid = Instance.new("Part")
			liquid.Name = `Liquid_{layer}`
			liquid.Shape = Enum.PartType.Cylinder
			liquid.Size = Vector3.new(0.14 + layer * 0.008, definition.RadiusX * 2 * scaleX, definition.RadiusZ * 2 * scaleZ)
			liquid.CFrame = lobeFrame * CFrame.new(0, -0.47 + layer * 0.012, 0) * CFrame.Angles(0, 0, math.rad(90))
			liquid.Anchored = true
			liquid.CanCollide = false
			liquid.CanTouch = false
			liquid.CanQuery = false
			liquid.Material = Enum.Material.Glass
			liquid.Color = Color3.fromRGB(28 + (layer % 3) * 8, 190 + (layer % 4) * 10, 45 + (layer % 2) * 10)
			liquid.Transparency = if isCenter then 0.12 else 0.18 + (layer % 3) * 0.04
			liquid.Parent = model
			local lobeZone = makeHazardZone(
				model,
				`LobeDamage_{layer}`,
				Vector3.new(definition.RadiusX * 2 * scaleX, 4, definition.RadiusZ * 2 * scaleZ),
				lobeFrame
			)
			table.insert(self._puddleZones, lobeZone)
		end
		local bulgeRandom = Random.new((definition.ShapeSeed + 104729) % 2147483647)
		for bulgeIndex = 1, bulgeRandom:NextInteger(2, 5) do
			local radius = bulgeRandom:NextNumber(0.75, 1.7)
			local bulge = Instance.new("Part")
			bulge.Name = `ToxicBulge_{bulgeIndex}`
			bulge.Shape = Enum.PartType.Ball
			bulge.Size = Vector3.new(radius * 2, radius * bulgeRandom:NextNumber(0.38, 0.7), radius * 2)
			bulge.CFrame = frame * CFrame.new(
				bulgeRandom:NextNumber(-definition.RadiusX * 0.58, definition.RadiusX * 0.58),
				-0.28 + bulge.Size.Y * 0.42,
				bulgeRandom:NextNumber(-definition.RadiusZ * 0.58, definition.RadiusZ * 0.58)
			)
			bulge.Anchored = true
			bulge.CanCollide = false
			bulge.CanTouch = false
			bulge.CanQuery = false
			bulge.Material = Enum.Material.Glass
			bulge.Color = Color3.fromRGB(75, 235, 70)
			bulge.Transparency = 0.08 + bulgeIndex * 0.025
			bulge.Parent = model
		end
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Name = "BiohazardWarnings"
		local isLargeWarning = (index + seed) % 10 == 0
		bubbles:SetAttribute("SizeVariant", if isLargeWarning then "Large" else "Small")
		bubbles.Texture = RoundConfig.HazardParticleTexture
		bubbles.Color = ColorSequence.new(Color3.fromRGB(80, 255, 75), Color3.fromRGB(20, 120, 35))
		bubbles.LightEmission = 1
		bubbles.LightInfluence = 0
		bubbles.Brightness = 3
		bubbles.Lifetime = NumberRange.new(1.1, 2)
		bubbles.Rate = 12 + definition.Band * 3
		bubbles.Speed = NumberRange.new(2, 5)
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.Shape = Enum.ParticleEmitterShape.Box
		bubbles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		bubbles.SpreadAngle = Vector2.new(55, 55)
		local warningScale = if isLargeWarning then 1 else 0.5
		bubbles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9 * warningScale),
			NumberSequenceKeypoint.new(0.55, 1.4 * warningScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		bubbles.Rotation = NumberRange.new(-180, 180)
		bubbles.RotSpeed = NumberRange.new(-35, 35)
		bubbles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.75, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		bubbles.Parent = zone
	end
	for index, definition in layout.Fountains do
		local model = Instance.new("Model")
		model.Name = `ToxicFountain_{index}`
		model:SetAttribute("Band", definition.Band)
		model.Parent = folder
		local y = roadSurfaceYAt(map, definition.X, definition.Z)
		local frame = CFrame.new(definition.X, y + 1.5, definition.Z)
		local zone = makeHazardZone(model, "SplashZone", Vector3.new(definition.Radius * 2, 8, definition.Radius * 2), frame)
		local warning = Instance.new("Part")
		warning.Name = "WarningPool"
		warning.Shape = Enum.PartType.Cylinder
		warning.Size = Vector3.new(0.22, definition.Radius * 2, definition.Radius * 2)
		warning.CFrame = CFrame.new(definition.X, y + 0.12, definition.Z) * CFrame.Angles(0, 0, math.rad(90))
		warning.Anchored = true
		warning.CanCollide = false
		warning.CanTouch = false
		warning.CanQuery = false
		warning.Material = Enum.Material.Neon
		warning.Parent = model
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "ToxicSpray"
		emitter.Color = ColorSequence.new(Color3.fromRGB(120, 255, 80), Color3.fromRGB(25, 150, 45))
		emitter.LightEmission = 0.8
		emitter.Lifetime = NumberRange.new(0.8, 1.3)
		emitter.Rate = 80
		emitter.Speed = NumberRange.new(14, 22)
		emitter.Acceleration = Vector3.new(0, -32, 0)
		emitter.SpreadAngle = Vector2.new(55, 55)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.18) })
		emitter.Enabled = false
		emitter.Parent = zone
		local fountain = { Model = model, Zone = zone, Warning = warning, Emitter = emitter }
		table.insert(self._fountains, fountain)
		self:_setFountainState(fountain, "Idle")
		self:_runFountain(fountain, generation, definition.PhaseOffset)
	end
end

function RoundRuntime.new(playersModule: any, workspace: Workspace)
	return setmetatable({
		_players = playersModule,
		_workspace = workspace,
		_round = RoundStateMachine.new(RoundConfig.GetMinimumPlayers(), RoundConfig.MaximumPlayers),
		_generation = 0,
		_disconnectPlayers = nil,
		_heartbeat = nil,
		_front = nil :: BasePart?,
		_frontFlood = nil :: BasePart?,
		_frontZ = -45,
		_hazardFolder = nil :: Folder?,
		_puddleZones = {} :: { BasePart },
		_fountains = {} :: { any },
		_hazardTickAccumulator = 0,
		_lastHazardSeed = nil :: number?,
		_baseWalkSpeedByUserId = {} :: { [number]: number },
		_runStartedAt = 0,
		_restartScheduled = false,
		_roundConnections = {} :: { RBXScriptConnection },
		_lobbyConnections = {} :: { RBXScriptConnection },
		_countdownRunning = false,
		_furthestProgressByUserId = {} :: { [number]: number },
		_furthestUsedShelterZ = nil :: number?,
		_shelterPartStates = {} :: { [BasePart]: any },
		_shelterVisualStates = {} :: { [Instance]: any },
		_startLocked = false,
		_startAnchoredRoots = {} :: { [number]: { Root: BasePart, WasAnchored: boolean } },
	}, RoundRuntime)
end

function RoundRuntime:_queuePlayer(player: Player, mode: string)
	local snapshot = self._round:GetSnapshot()
	if snapshot.state == "Running" or snapshot.state == "Completed" then return end
	if mode == "Solo" then
		if self._countdownRunning then return end
		if snapshot.readyCount > 0 and player:GetAttribute("ToxicRainQueueMode") ~= "Group" then return end
		if player:GetAttribute("ToxicRainQueueMode") == "Group" then self._round:SetReady(player.UserId, false) end
		self._round:SetReady(player.UserId, true)
		player:SetAttribute("ToxicRainQueueMode", "Solo")
		self._workspace:SetAttribute("ToxicRainRoundMode", "Solo")
		self:_publish()
		self:_beginCountdown(0, 1)
		return
	end
	if mode == "Group" then
		if player:GetAttribute("ToxicRainQueueMode") == "Group" then return end
		self._round:SetReady(player.UserId, true)
		player:SetAttribute("ToxicRainQueueMode", "Group")
		self._workspace:SetAttribute("ToxicRainRoundMode", "Group")
		self:_publish()
		if self._round:GetSnapshot().state == "Countdown" then self:_beginCountdown(RoundConfig.CountdownSeconds, nil) end
	end
end

function RoundRuntime:_bindLobbyPads()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local lobby = map and map:FindFirstChild("Lobby")
	assert(lobby ~= nil, "ToxicRainMap.Lobby is required")
	for _, padName in { "SoloPad", "GroupPad" } do
		local pad = lobby:FindFirstChild(padName)
		assert(pad ~= nil and pad:IsA("BasePart"), `ToxicRainMap.Lobby.{padName} must be a BasePart`)
		local mode = if padName == "SoloPad" then "Solo" else "Group"
		table.insert(self._lobbyConnections, pad.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and self._players:GetPlayerFromCharacter(character)
			if player then self:_queuePlayer(player, mode) end
		end))
	end
end

function RoundRuntime:_containNonParticipants(map: Instance)
	local spawnLocation = self._workspace:FindFirstChildOfClass("SpawnLocation")
	local lobby = map:FindFirstChild("Lobby")
	local lobbyFloor = lobby and lobby:FindFirstChild("LobbyFloor")
	local returnFrame = if spawnLocation
		then spawnLocation.CFrame * CFrame.new(0, 4, 0)
		elseif lobbyFloor and lobbyFloor:IsA("BasePart")
		then lobbyFloor.CFrame * CFrame.new(0, lobbyFloor.Size.Y * 0.5 + 4, 0)
		else nil
	if returnFrame == nil then return end
	for _, player in self._players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and RoundConfig.ShouldContainNonParticipant(player:GetAttribute("ToxicRainQueueMode"), isPointOnRoad(map, root.Position)) then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(returnFrame)
		end
	end
end

function RoundRuntime:_createCourseBoundaries()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	assert(map ~= nil, "ToxicRainMap is required")
	local roadContainer = findRoadContainer(map)
	assert(roadContainer ~= nil, "ToxicRainMap.RoadZones or RoadParts is required")

	local minimumZ = math.huge
	local maximumZ = -math.huge
	local surfaceY = -math.huge
	local function includePart(part: BasePart)
		local _, halfZ = worldHorizontalHalfExtents(part)
		minimumZ = math.min(minimumZ, part.Position.Z - halfZ)
		maximumZ = math.max(maximumZ, part.Position.Z + halfZ)
		surfaceY = math.max(surfaceY, part.Position.Y + part.Size.Y * 0.5)
	end

	for _, descendant in roadContainer:GetDescendants() do
		if descendant:IsA("BasePart") then includePart(descendant) end
	end
	local finish = map:FindFirstChild("FinishZone")
	if finish and finish:IsA("BasePart") then includePart(finish) end
	local lobby = map:FindFirstChild("Lobby")
	local lobbyFloor = lobby and lobby:FindFirstChild("LobbyFloor")
	if lobbyFloor and lobbyFloor:IsA("BasePart") then includePart(lobbyFloor) end
	assert(minimumZ < math.huge and maximumZ > -math.huge, "ToxicRain road bounds are required")

	local oldBoundaries = map:FindFirstChild("RuntimeCourseBoundaries")
	if oldBoundaries then oldBoundaries:Destroy() end
	local boundaries = Instance.new("Folder")
	boundaries.Name = "RuntimeCourseBoundaries"
	boundaries.Parent = map

	local halfWidth = RoundConfig.CourseBoundaryHalfWidthStuds
	local height = RoundConfig.CourseBoundaryHeightStuds
	local thickness = RoundConfig.CourseBoundaryThicknessStuds
	local padding = RoundConfig.CourseBoundaryEndPaddingStuds
	local startZ = minimumZ - padding
	local endZ = maximumZ + padding
	local length = endZ - startZ + thickness * 2
	local centerY = surfaceY + height * 0.5

	local function createWall(name: string, size: Vector3, position: Vector3)
		local wall = Instance.new("Part")
		wall.Name = name
		wall.Size = size
		wall.Position = position
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanTouch = false
		wall.CanQuery = false
		wall.Transparency = 1
		wall.Parent = boundaries
	end

	local centerZ = (startZ + endZ) * 0.5
	createWall("LeftBoundary", Vector3.new(thickness, height, length), Vector3.new(-halfWidth - thickness * 0.5, centerY, centerZ))
	createWall("RightBoundary", Vector3.new(thickness, height, length), Vector3.new(halfWidth + thickness * 0.5, centerY, centerZ))
	createWall("FinishBoundary", Vector3.new(halfWidth * 2 + thickness * 2, height, thickness), Vector3.new(0, centerY, endZ + thickness * 0.5))
end

function RoundRuntime:_clearRoundObjects()
	self:_clearRoundConnections()
	table.clear(self._furthestProgressByUserId)
	self:_restoreShelters()
	self:_clearHazards()
	for _, player in self._players:GetPlayers() do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local baseWalkSpeed = self._baseWalkSpeedByUserId[player.UserId]
		if humanoid and baseWalkSpeed then humanoid.WalkSpeed = baseWalkSpeed end
		self._baseWalkSpeedByUserId[player.UserId] = nil
		for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("ToxicRainApple") then child:Destroy() end
				end
			end
		end
		player:SetAttribute("ToxicRainXP", nil)
		player:SetAttribute("ToxicRainResult", nil)
		player:SetAttribute("ToxicRainFinishTime", nil)
		player:SetAttribute("ToxicRainFinishHealth", nil)
		player:SetAttribute("ToxicRainAutoRun", false)
		player:SetAttribute("ToxicRainProtection", "Open")
		player:SetAttribute("ToxicRainAppleCount", 0)
		player:SetAttribute("ToxicRainHazard", nil)
	end
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local apples = map and map:FindFirstChild("AppleSpawnPoints")
	if apples then
		for _, child in apples:GetChildren() do
			if child:IsA("BasePart") then child.Transparency = 1 child.CanTouch = false child:SetAttribute("Taken", false) end
		end
	end
	if self._front then self._front:Destroy() self._front = nil end
	if self._frontFlood then self._frontFlood:Destroy() self._frontFlood = nil end
	self._frontZ = -45
	self._workspace:SetAttribute("ToxicRainFrontZ", nil)
end

function RoundRuntime:_scheduleRestart()
	if self._restartScheduled then return end
	self._restartScheduled = true
	self._generation += 1
	local generation = self._generation
	task.spawn(function()
		task.wait(RoundConfig.RoundEndPresentationSeconds)
		if generation ~= self._generation then return end
		self:_clearRoundObjects()
		self._workspace:SetAttribute("ToxicRainWeather", "Clear")
		self._workspace:SetAttribute("ToxicRainWeatherTimer", 0)
		self._workspace:SetAttribute("ToxicRainWinnerUserId", nil)
		self._workspace:SetAttribute("ToxicRainWinnerName", nil)
		self._workspace:SetAttribute("ToxicRainRoundStartedAt", nil)
		self._workspace:SetAttribute("ToxicRainNextRainAt", nil)
		self._workspace:SetAttribute("ToxicRainRainEndsAt", nil)
		self._workspace:SetAttribute("ToxicRainRoundMode", "None")
		self._round = RoundStateMachine.new(RoundConfig.GetMinimumPlayers(), RoundConfig.MaximumPlayers)
		for _, player in self._players:GetPlayers() do
			local spawnLocation = self._workspace:FindFirstChildOfClass("SpawnLocation")
			if spawnLocation then player.RespawnLocation = spawnLocation end
			player:LoadCharacter()
			if spawnLocation and player.Character then
				player.Character:PivotTo(spawnLocation.CFrame * CFrame.new(0, 4, 0))
			end
			player:SetAttribute("ToxicRainQueueMode", "None")
		end
		self._restartScheduled = false
		self:_publish()
	end)
end

function RoundRuntime:_publish()
	local snapshot = self._round:GetSnapshot()
	self._workspace:SetAttribute("ToxicRainRoundState", snapshot.state)
	self._workspace:SetAttribute("ToxicRainReadyPlayers", snapshot.readyCount)
	self._workspace:SetAttribute("ToxicRainMinimumPlayers", RoundConfig.GetMinimumPlayers())
	self._workspace:SetAttribute("ToxicRainActivePlayers", snapshot.activeCount)
	self._workspace:SetAttribute("ToxicRainStartedPlayers", snapshot.startedCount)
end

function RoundRuntime:_releaseStartLock()
	self._startLocked = false
	self._workspace:SetAttribute("ToxicRainStartLocked", false)
	for playerId, record in self._startAnchoredRoots do
		if record.Root.Parent then record.Root.Anchored = record.WasAnchored end
		self._startAnchoredRoots[playerId] = nil
	end
end

function RoundRuntime:_initializeStartedPlayers()
	local laneIndex = 0
	local startedSnapshot = self._round:GetSnapshot()
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	assert(map ~= nil, "ToxicRainMap is required")
	local startingRoad = findStartingRoadPart(map)
	assert(startingRoad ~= nil, "ToxicRain starting road is required")
	local halfX, halfZ = worldHorizontalHalfExtents(startingRoad)
	local roadStartZ = startingRoad.Position.Z - halfZ
	local columnSpacing = math.min(6, math.max(3, (halfX * 2 - 6) / 4))
	local spawnY = startingRoad.Position.Y + startingRoad.Size.Y * 0.5 + 3
	for _, player in self._players:GetPlayers() do
		if startedSnapshot.results[player.UserId] ~= "Active" then continue end
		laneIndex += 1
		player:SetAttribute("ToxicRainXP", 100)
		player:SetAttribute("ToxicRainProtection", "Open")
		player:SetAttribute("ToxicRainResult", nil)
		player:SetAttribute("ToxicRainFinishTime", nil)
		player:SetAttribute("ToxicRainFinishHealth", nil)
		player:SetAttribute("ToxicRainAutoRun", false)
		player:SetAttribute("ToxicRainAppleCount", 0)
		player:SetAttribute("ToxicRainQueueMode", "Running")
		local character = player.Character
		if character then
			local rowIndex = math.floor((laneIndex - 1) / 5)
			local columnIndex = (laneIndex - 1) % 5
			local playersInRow = math.min(5, startedSnapshot.startedCount - rowIndex * 5)
			local xOffset = (columnIndex - (playersInRow - 1) * 0.5) * columnSpacing
			local position = Vector3.new(
				startingRoad.Position.X + xOffset,
				spawnY,
				roadStartZ + 8 + rowIndex * 7
			)
			character:PivotTo(CFrame.lookAt(position, position + Vector3.new(0, 0, 1)))
			local root = character:FindFirstChild("HumanoidRootPart")
			if self._startLocked and root and root:IsA("BasePart") then
				self._startAnchoredRoots[player.UserId] = { Root = root, WasAnchored = root.Anchored }
				root.Anchored = true
			end
			self._furthestProgressByUserId[player.UserId] = position.Z
		end
	end
end

function RoundRuntime:_beginCountdown(countdownSeconds: number, minimumPlayersOverride: number?)
	if self._countdownRunning then return end
	self._countdownRunning = true
	self._generation += 1
	local generation = self._generation
	task.spawn(function()
		for remaining = countdownSeconds, 1, -1 do
			if generation ~= self._generation or self._round:GetSnapshot().state ~= "Countdown" then self._countdownRunning = false return end
			self._workspace:SetAttribute("ToxicRainCountdown", remaining)
			task.wait(1)
		end
		if generation == self._generation and self._round:Start(minimumPlayersOverride) then
			self._countdownRunning = false
			self._startLocked = true
			self._workspace:SetAttribute("ToxicRainStartLocked", true)
			self._workspace:SetAttribute("ToxicRainStartCountdown", 3)
			self._workspace:SetAttribute("ToxicRainCountdown", 0)
			self:_publish()
			self:_initializeStartedPlayers()
			for remaining = 3, 1, -1 do
				if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then
					self:_releaseStartLock()
					return
				end
				self._workspace:SetAttribute("ToxicRainStartCountdown", remaining)
				task.wait(1)
			end
			self._workspace:SetAttribute("ToxicRainStartCountdown", 0)
			task.wait(0.5)
			self:_releaseStartLock()
			if generation ~= self._generation or self._round:GetSnapshot().state ~= "Running" then return end
			self._runStartedAt = os.clock()
			self._workspace:SetAttribute("ToxicRainRoundStartedAt", self._workspace:GetServerTimeNow())
			self:_spawnApples()
			self:_spawnHazards(generation)
			self:_runRainSchedule(generation)
		else
			self._countdownRunning = false
		end
	end)
end

function RoundRuntime:Initialize()
	self._disconnectPlayers = self._players:ObservePlayers(function(player)
		player:SetAttribute("ToxicRainXP", nil)
		player:SetAttribute("ToxicRainQueueMode", "None")
		player:SetAttribute("ToxicRainAppleCount", 0)
		player:SetAttribute("ToxicRainFinishTime", nil)
		player:SetAttribute("ToxicRainFinishHealth", nil)
		self:_publish()
	end, function(player)
		self._furthestProgressByUserId[player.UserId] = nil
		self._baseWalkSpeedByUserId[player.UserId] = nil
		local stateBefore = self._round:GetSnapshot().state
		if stateBefore == "Running" then self._round:Eliminate(player.UserId) else self._round:SetReady(player.UserId, false) end
		if stateBefore == "Countdown" and self._round:GetSnapshot().state == "Waiting" then
			self._generation += 1
			self._countdownRunning = false
			self._workspace:SetAttribute("ToxicRainCountdown", 0)
		end
		self:_publish()
	end)
	local map = self._workspace:FindFirstChild("ToxicRainMap")
	local startZone = map and map:FindFirstChild("StartZone")
	if startZone and startZone:IsA("BasePart") then
		startZone.Transparency = 1
		startZone.CanCollide = false
		startZone.CanTouch = false
	end
	self:_createCourseBoundaries()
	self:_bindLobbyPads()
	self._heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		local roundSnapshot = self._round:GetSnapshot()
		local map = self._workspace:FindFirstChild("ToxicRainMap")
		if map then self:_containNonParticipants(map) end
		if roundSnapshot.state ~= "Running" or self._startLocked then return end
		if not self._front then
			local front = Instance.new("Part")
			front.Name = "ToxicStormFront"
			front.Anchored = true front.CanCollide = false front.CanTouch = false front.CanQuery = false
			front.Material = Enum.Material.Neon front.Color = Color3.fromRGB(55, 255, 70)
			front.Transparency = 0.52 front.Size = Vector3.new(110, 45, 5)
			front.Parent = self._workspace self._front = front
			local mist = Instance.new("ParticleEmitter")
			mist.Name = "ToxicStormMist"
			mist.Color = ColorSequence.new(Color3.fromRGB(120, 255, 105), Color3.fromRGB(20, 105, 40))
			mist.LightEmission = 0.45
			mist.Lifetime = NumberRange.new(1.5, 3)
			mist.Rate = 95
			mist.Speed = NumberRange.new(2, 7)
			mist.SpreadAngle = Vector2.new(35, 80)
			mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
			mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
			mist.Parent = front
			local flood = Instance.new("Part")
			flood.Name = "ToxicStormFlood"
			flood.Anchored = true flood.CanCollide = false flood.CanTouch = false flood.CanQuery = false
			flood.Material = Enum.Material.Neon flood.Color = Color3.fromRGB(35, 210, 55)
			flood.Transparency = 0.9 flood.Parent = self._workspace self._frontFlood = flood
			self._frontZ = -45
		end
		local minimumPlayerZ = math.huge
		for _, activePlayer in self._players:GetPlayers() do
			local activeRoot = activePlayer.Character and activePlayer.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = activePlayer.Character and activePlayer.Character:FindFirstChildOfClass("Humanoid")
			if roundSnapshot.results[activePlayer.UserId] == "Active" and activeRoot and activeRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				minimumPlayerZ = math.min(minimumPlayerZ, activeRoot.Position.Z)
			end
		end
		local frontZ = self._frontZ
		if minimumPlayerZ < math.huge then
			frontZ = RoundConfig.AdvanceStormFrontZ(frontZ, minimumPlayerZ, deltaTime)
		end
		self._frontZ = frontZ
		self._front.CFrame = CFrame.new(0, 18, frontZ)
		local floodStartZ = -120
		local floodLength = math.max(1, frontZ - floodStartZ)
		if self._frontFlood then
			self._frontFlood.Size = Vector3.new(110, 45, floodLength)
			self._frontFlood.CFrame = CFrame.new(0, 18, floodStartZ + floodLength * 0.5)
		end
		self._workspace:SetAttribute("ToxicRainFrontZ", frontZ)
		for _, player in self._players:GetPlayers() do
			if roundSnapshot.results[player.UserId] ~= "Active" then continue end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") then
				local p = root.Position
				local finish = map and map:FindFirstChild("FinishZone")
				if finish and finish:IsA("BasePart") and containsHorizontal(finish, p) and self._round:Finish(player.UserId) then
					self._generation += 1
					local finishTime = math.max(0, os.clock() - self._runStartedAt)
					local finishHealth = player:GetAttribute("ToxicRainXP")
					player:SetAttribute("ToxicRainFinishTime", finishTime)
					player:SetAttribute("ToxicRainFinishHealth", if typeof(finishHealth) == "number" then math.clamp(math.round(finishHealth), 0, 100) else 0)
					self._workspace:SetAttribute("ToxicRainWinnerUserId", player.UserId)
					self._workspace:SetAttribute("ToxicRainWinnerName", player.DisplayName)
					if self._front then self._front.Transparency = 1 end
					if self._frontFlood then self._frontFlood.Transparency = 1 end
					player:SetAttribute("ToxicRainResult", "Won")
					for _, other in self._players:GetPlayers() do
						if other ~= player then
							local otherHealth = other:GetAttribute("ToxicRainXP")
							other:SetAttribute("ToxicRainFinishTime", -1)
							other:SetAttribute("ToxicRainFinishHealth", if typeof(otherHealth) == "number" then math.clamp(math.round(otherHealth), 0, 100) else 0)
							other:SetAttribute("ToxicRainResult", "Lost")
							if other.Character then other.Character:BreakJoints() end
						end
					end
					self:_publish()
					self:_scheduleRestart()
					break
				end
				local isOnRoad = if map then isPointOnRoad(map, p) else false
				local isOnCentralRoad = if map then isPointOnCentralRoad(map, p) else false
				player:SetAttribute("ToxicRainAutoRun", isOnCentralRoad)
				if humanoid then
					local baseWalkSpeed = self._baseWalkSpeedByUserId[player.UserId]
					if baseWalkSpeed == nil then
						baseWalkSpeed = humanoid.WalkSpeed
						self._baseWalkSpeedByUserId[player.UserId] = baseWalkSpeed
					end
					humanoid.WalkSpeed = if isOnRoad then RoundConfig.RoadSpeedStudsPerSecond else baseWalkSpeed
					if RoundConfig.CanApplyAutoRun(isOnCentralRoad, humanoid.Health, humanoid.FloorMaterial, root.AssemblyLinearVelocity.Y) then
						root.AssemblyLinearVelocity = RoundConfig.ApplyAutoRunVelocity(root.AssemblyLinearVelocity)
					end
				end
			end
		end
		self._hazardTickAccumulator += deltaTime
		if self._hazardTickAccumulator >= 1 then
			self._hazardTickAccumulator -= 1
			if self._workspace:GetAttribute("ToxicRainWeather") ~= "ToxicRain" then
				self:_applyEnvironmentalTick(false)
			end
		end
	end)
	self:_publish()
	self._workspace:SetAttribute("ToxicRainStartLocked", false)
	self._workspace:SetAttribute("ToxicRainStartCountdown", 0)
	self._workspace:SetAttribute("ToxicRainWeather", "Clear")
	self._workspace:SetAttribute("ToxicRainWeatherTimer", 0)
	self._workspace:SetAttribute("ToxicRainRoundMode", "None")
	self._workspace:SetAttribute("ToxicRainRoundStartedAt", nil)
	self._workspace:SetAttribute("ToxicRainNextRainAt", nil)
	self._workspace:SetAttribute("ToxicRainRainEndsAt", nil)
end

return RoundRuntime
