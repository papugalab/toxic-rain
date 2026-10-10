--!strict

local RoundConfig = {
	ProductionMinimumPlayers = 2,
	MaximumPlayers = 16,
	AppleSections = 3,
	ApplesPerPlayer = 0.5,
	MinimumRoundApples = 2,
	CountdownSeconds = 10,
	RoundEndPresentationSeconds = 10,
	RoadSpeedStudsPerSecond = 32,
	AutoRunMaximumGroundVerticalSpeed = 3,
	RoadHalfWidthStuds = 17,
	CourseStartZ = 20,
	CourseEndZ = 745,
	RoadEdgeToleranceStuds = 1,
	CourseBoundaryHalfWidthStuds = 54,
	CourseBoundaryHeightStuds = 50,
	CourseBoundaryThicknessStuds = 2,
	CourseBoundaryEndPaddingStuds = 8,
	RainWarningSeconds = 5,
	RainDurationSeconds = 10,
	RainXpLossPerSecond = 18,
	WeakShelterDamageMultiplier = 0.15,
	-- Level 1 has two rain events. Warnings begin at seconds 8 and 26,
	-- so toxic rain itself begins at seconds 13 and 31.
	RainWarningStartSeconds = { 8, 26 },
	StormFrontSpeedStudsPerSecond = 28,
	StormFrontTrackingGapStuds = 120,
	StormFrontCreepStudsPerSecond = 2,
	StormFrontChaseStudsPerSecond = 18,
	StormFrontMinimumPlayerGapStuds = 40,
	StormFrontXpLossPerSecond = 18,
	HazardXpLossPerSecond = 18,
	HazardBandCount = 5,
	HazardLaneCenters = { -47, -35, -23, -9, 4, 17, 30 },
	HazardPuddlesPerBlockedLaneByBand = { 1, 2, 3, 4, 5 },
	HazardParticleTexture = "rbxassetid://117777689607250",
	-- The current first course uses green puddles only. Fountain hazards and
	-- their yellow warning pools are reserved for a future second course.
	FountainsEnabled = false,
	FountainWarningSeconds = 1.5,
	FountainActiveSeconds = 1.25,
	FountainIdleSeconds = 2.5,
}

function RoundConfig.GetMinimumPlayers(): number
	return RoundConfig.ProductionMinimumPlayers
end

function RoundConfig.GetAppleSpawnQuotas(startedCount: number): { number }
	local players = math.clamp(math.floor(startedCount), 0, RoundConfig.MaximumPlayers)
	if players == 0 then return { 0, 0, 0 } end
	-- Round the whole-course budget once so a fifth player adds one apple,
	-- rather than independently rounding three sections and adding three.
	local total = math.max(RoundConfig.MinimumRoundApples,
		math.ceil(players * RoundConfig.ApplesPerPlayer))
	local perSection = math.floor(total / RoundConfig.AppleSections)
	local remainder = total % RoundConfig.AppleSections
	local quotas = {}
	for section = 1, RoundConfig.AppleSections do
		quotas[section] = perSection + (if section <= remainder then 1 else 0)
	end
	return quotas
end

function RoundConfig.AdvanceStormFrontZ(currentZ: number, laggingPlayerZ: number, deltaTime: number, chasing: boolean?): number
	local dt = math.max(0, deltaTime)
	if chasing then
		local finishZ = RoundConfig.CourseEndZ + RoundConfig.CourseBoundaryEndPaddingStuds
		return math.max(currentZ, math.min(finishZ, currentZ + RoundConfig.StormFrontChaseStudsPerSecond * dt))
	end
	local safeLimitZ = laggingPlayerZ - RoundConfig.StormFrontMinimumPlayerGapStuds
	local trackingZ = laggingPlayerZ - RoundConfig.StormFrontTrackingGapStuds
	local catchUpZ = math.min(trackingZ, currentZ + RoundConfig.StormFrontSpeedStudsPerSecond * dt)
	local creepZ = currentZ + RoundConfig.StormFrontCreepStudsPerSecond * dt
	-- Catch up to runners, then slowly loom closer during shelter stops without
	-- crossing the safety gap. Never retreat when a player runs backwards.
	return math.max(currentZ, math.min(safeLimitZ, math.max(catchUpZ, creepZ)))
end

function RoundConfig.IsInsideHorizontalZone(localX: number, localZ: number, halfX: number, halfZ: number, margin: number): boolean
	return math.abs(localX) <= halfX + margin and math.abs(localZ) <= halfZ + margin
end

function RoundConfig.IsCentralRoadPartName(partName: string): boolean
	return string.match(partName, "^RoadSection") ~= nil
end

function RoundConfig.ShouldContainNonParticipant(queueMode: any, isOnCourse: boolean): boolean
	return queueMode ~= "Running" and isOnCourse
end

function RoundConfig.ApplyAutoRunVelocity(currentVelocity: Vector3): Vector3
	return Vector3.new(currentVelocity.X, currentVelocity.Y, math.max(currentVelocity.Z, RoundConfig.RoadSpeedStudsPerSecond))
end

function RoundConfig.CanApplyAutoRun(isOnCentralRoad: boolean, health: number, floorMaterial: Enum.Material, verticalSpeed: number): boolean
	return isOnCentralRoad
		and health > 0
		and floorMaterial ~= Enum.Material.Air
		and math.abs(verticalSpeed) <= RoundConfig.AutoRunMaximumGroundVerticalSpeed
end

function RoundConfig.GenerateHazardLayout(seed: number, startZ: number, endZ: number): any
	local random = Random.new(seed)
	local puddles = {}
	local fountains = {}
	local safeLanes = {}
	local bandCount = RoundConfig.HazardBandCount
	local span = math.max(80, endZ - startZ)
	local safeLane = random:NextInteger(1, #RoundConfig.HazardLaneCenters)
	for bandIndex = 1, bandCount do
		if bandIndex > 1 then
			safeLane = math.clamp(safeLane + random:NextInteger(-1, 1), 1, #RoundConfig.HazardLaneCenters)
		end
		table.insert(safeLanes, safeLane)
		local difficulty = (bandIndex - 1) / math.max(1, bandCount - 1)
		local bandZ = startZ + span * ((bandIndex - 0.5) / bandCount)
		local puddlesInLane = RoundConfig.HazardPuddlesPerBlockedLaneByBand[bandIndex]
		for laneIndex, laneX in RoundConfig.HazardLaneCenters do
			if laneIndex == safeLane then continue end
			for puddleIndex = 1, puddlesInLane do
				local longitudinalOffset = (puddleIndex - (puddlesInLane + 1) * 0.5)
					* (span / bandCount * 0.72 / math.max(1, puddlesInLane - 1))
				table.insert(puddles, {
					X = laneX + random:NextNumber(-2.3, 2.3),
					Z = bandZ + longitudinalOffset + random:NextNumber(-2.5, 2.5),
					RadiusX = 3.8 + difficulty * 2.5 + random:NextNumber(-0.5, 0.5),
					RadiusZ = 5.2 + difficulty * 3.2 + random:NextNumber(-0.8, 0.8),
					Rotation = random:NextNumber(-32, 32),
					ShapeSeed = random:NextInteger(1, 2147483646),
					Band = bandIndex,
				})
			end
		end
		if RoundConfig.FountainsEnabled and bandIndex >= 3 then
			local fountainLane = if safeLane == 1 then 3 elseif safeLane == 3 then 1 else (if random:NextNumber() < 0.5 then 1 else 3)
			table.insert(fountains, {
				X = RoundConfig.HazardLaneCenters[fountainLane] + random:NextNumber(-1, 1),
				Z = bandZ + span / bandCount * 0.28,
				Radius = 7 + difficulty * 3,
				PhaseOffset = random:NextNumber(0, RoundConfig.FountainIdleSeconds),
				Band = bandIndex,
			})
		end
	end
	return { Seed = seed, Puddles = puddles, Fountains = fountains, SafeLanes = safeLanes }
end

return table.freeze(RoundConfig)
