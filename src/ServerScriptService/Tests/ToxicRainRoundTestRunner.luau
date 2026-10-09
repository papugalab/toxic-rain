--!strict

local TestHarness = require(script.Parent.TestHarness)
local RoundConfig = require(script.Parent.Parent.Modules.ToxicRain.RoundConfig)
local RoundRuntime = require(script.Parent.Parent.Modules.ToxicRain.RoundRuntime)
local RoundStateMachine = require(script.Parent.Parent.Modules.ToxicRain.RoundStateMachine)
local ShelterCombatRuntime = require(script.Parent.Parent.Modules.ToxicRain.ShelterCombatRuntime)
local ShelterCombatConfig = require(game.ReplicatedStorage.Shared.ToxicRain.ShelterCombatConfig)
local ShelterCombatProtocol = require(game.ReplicatedStorage.Shared.ToxicRain.ShelterCombatProtocol)
local WeatherController = require(game.ReplicatedStorage.Project.Client.ToxicRain.WeatherController)

local tests = {
	{ Name = "shelter combat uses five decreasing grip capacities", Callback = function()
		assert(#ShelterCombatConfig.GripCapacities == 5)
		local expected = { 3, 2, 1, 1, 0 }
		for index, capacity in expected do assert(ShelterCombatConfig.GripCapacities[index] == capacity) end
		assert(ShelterCombatConfig.GripDurationSeconds == 10)
		assert(ShelterCombatConfig.IsCombatWeather("Warning"))
		assert(ShelterCombatConfig.IsCombatWeather("ToxicRain"))
		assert(not ShelterCombatConfig.IsCombatWeather("Clear"))
		-- A player who grabs during warning must remain attached through the rain.
		assert(not ShelterCombatConfig.ShouldReleaseAllGrips("Running", "Warning"))
		assert(not ShelterCombatConfig.ShouldReleaseAllGrips("Running", "ToxicRain"))
		assert(ShelterCombatConfig.ShouldReleaseAllGrips("Running", "Clear"))
		assert(ShelterCombatConfig.ShouldReleaseAllGrips("Waiting", "ToxicRain"))
	end },
	{ Name = "push validates input and targets only the facing arc", Callback = function()
		local valid, sanitized = ShelterCombatProtocol.ValidatePushIntent({ Direction = Vector3.new(0, 0, 3) })
		assert(valid and sanitized.Direction == Vector3.new(0, 0, 1))
		assert(not ShelterCombatProtocol.ValidatePushIntent({ Direction = Vector3.zero }))
		assert(not ShelterCombatProtocol.ValidatePushIntent({}))
		assert(ShelterCombatConfig.IsWithinPushRange(Vector3.zero, Vector3.new(0, 0, 5)))
		assert(ShelterCombatConfig.IsWithinPushRange(Vector3.zero, Vector3.new(5, 0, 0)))
		assert(ShelterCombatConfig.IsWithinPushRange(Vector3.zero, Vector3.new(0, 0, 10)))
		assert(not ShelterCombatConfig.IsWithinPushRange(Vector3.zero, Vector3.new(0, 0, 10.1)))
		assert(ShelterCombatConfig.IsWithinPushArc(Vector3.zero, Vector3.new(0, 0, 8), Vector3.new(0, 0, 1)))
		assert(not ShelterCombatConfig.IsWithinPushArc(Vector3.zero, Vector3.new(0, 0, -3), Vector3.new(0, 0, 1)))
		assert(not ShelterCombatConfig.IsWithinPushArc(Vector3.zero, Vector3.new(11, 0, 0), Vector3.new(1, 0, 0)))
	end },
	{ Name = "grip intent requires one bounded slot id", Callback = function()
		local valid, sanitized = ShelterCombatProtocol.ValidateGripIntent({ SlotId = "GripHook_1_1" })
		assert(valid and sanitized.SlotId == "GripHook_1_1")
		assert(not ShelterCombatProtocol.ValidateGripIntent({ SlotId = "" }))
		assert(not ShelterCombatProtocol.ValidateGripIntent({}))
	end },
	{ Name = "push tool hits a real player-shaped target in front and ignores one behind", Callback = function()
		local function makePlayer(userId: number, position: Vector3): (any, BasePart)
			local attributes = {
				ToxicRainQueueMode = "Running",
				ToxicRainXP = 100,
			}
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Position = position
			root.Anchored = false
			root.Parent = character
			character.Parent = workspace
			local player = {
				UserId = userId,
				Character = character,
				GetAttribute = function(_self, name) return attributes[name] end,
				SetAttribute = function(_self, name, value) attributes[name] = value end,
			}
			return player, root
		end
		local attacker, _attackerRoot = makePlayer(1, Vector3.new(0, 100, 0))
		local frontTarget, frontRoot = makePlayer(2, Vector3.new(0, 100, 5))
		local behindTarget, behindRoot = makePlayer(3, Vector3.new(0, 100, -3))
		local fakeWorkspace = {
			GetAttribute = function(_self, name)
				if name == "ToxicRainRoundState" then return "Running" end
				if name == "ToxicRainStartLocked" then return false end
				return nil
			end,
			GetServerTimeNow = function() return os.clock() end,
			Raycast = function() return nil end,
		}
		local runtime = ShelterCombatRuntime.new({
			PlayersModule = { GetPlayers = function() return { attacker, frontTarget, behindTarget } end },
			Communication = {},
			Workspace = fakeWorkspace,
			Clock = function() return 100 end,
		})
		local selectedRoot, selectedPlayer = runtime:_findPushTarget(attacker, Vector3.new(0, 0, 1))
		assert(selectedRoot == frontRoot and selectedPlayer == frontTarget)
		runtime:_tryPush(attacker, Vector3.new(0, 0, 1))
		assert(attacker:GetAttribute("ToxicRainPushOutcome") == "Hit")
		assert(runtime._victimImmuneUntil[frontTarget] == 100 + ShelterCombatConfig.PushVictimImmunitySeconds)
		assert(runtime._victimImmuneUntil[behindTarget] == nil)
		attacker.Character:Destroy()
		frontTarget.Character:Destroy()
		behindTarget.Character:Destroy()
	end },
	{ Name = "level one schedules exactly two rain events", Callback = function()
		assert(RoundConfig.MaximumPlayers == 10)
		assert(RoundConfig.RainDurationSeconds == ShelterCombatConfig.GripDurationSeconds)
		assert(#RoundConfig.RainWarningStartSeconds == 2)
		assert(RoundConfig.RainWarningStartSeconds[1] == 8)
		assert(RoundConfig.RainWarningStartSeconds[2] == 26)
		assert(RoundConfig.CourseEndZ == 745)
	end },
	{ Name = "thunder plays only once for warning and once for rain start", Callback = function()
		assert(WeatherController.ShouldPlayThunder("Clear", "Warning"))
		assert(not WeatherController.ShouldPlayThunder("Warning", "Warning"))
		assert(WeatherController.ShouldPlayThunder("Warning", "ToxicRain"))
		assert(not WeatherController.ShouldPlayThunder("ToxicRain", "ToxicRain"))
		assert(not WeatherController.ShouldPlayThunder("ToxicRain", "Clear"))
		assert(not WeatherController.ShouldPlayThunder("Clear", "Clear"))
	end },
	{ Name = "autorun and course containment distinguish participants", Callback = function()
		assert(RoundConfig.IsCentralRoadPartName("RoadSection1"))
		assert(RoundConfig.IsCentralRoadPartName("RoadSection_Upper"))
		assert(not RoundConfig.IsCentralRoadPartName("Shoulder_1_Left"))
		assert(RoundConfig.ShouldContainNonParticipant("None", true))
		assert(RoundConfig.ShouldContainNonParticipant("Group", true))
		assert(not RoundConfig.ShouldContainNonParticipant("Running", true))
		assert(not RoundConfig.ShouldContainNonParticipant("None", false))
		local velocity = RoundConfig.ApplyAutoRunVelocity(Vector3.new(-11, 4, 3))
		assert(velocity.X == -11 and velocity.Y == 4)
		assert(velocity.Z == RoundConfig.RoadSpeedStudsPerSecond)
		local fasterVelocity = RoundConfig.ApplyAutoRunVelocity(Vector3.new(7, -2, 40))
		assert(fasterVelocity == Vector3.new(7, -2, 40))
		assert(RoundConfig.CanApplyAutoRun(true, 100, Enum.Material.Asphalt, 0))
		assert(not RoundConfig.CanApplyAutoRun(true, 100, Enum.Material.Air, 0))
		assert(not RoundConfig.CanApplyAutoRun(true, 100, Enum.Material.Asphalt, 4))
		assert(not RoundConfig.CanApplyAutoRun(true, 100, Enum.Material.Asphalt, -4))
		assert(not RoundConfig.CanApplyAutoRun(false, 100, Enum.Material.Asphalt, 0))
	end },
	{ Name = "one group player cannot start", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		round:SetReady(1, true)
		assert(round:GetSnapshot().state == "Waiting" and not round:Start())
	end },
	{ Name = "solo lobby pad can start immediately with explicit override", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		round:SetReady(1, true)
		assert(round:GetSnapshot().state == "Waiting")
		assert(round:Start(1))
		assert(round:GetSnapshot().startedCount == 1)
	end },
	{ Name = "countdown cancels below minimum", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		round:SetReady(1, true) round:SetReady(2, true)
		assert(round:GetSnapshot().state == "Countdown")
		round:SetReady(2, false)
		assert(round:GetSnapshot().state == "Waiting")
	end },
	{ Name = "every supported group size from two through ten starts every player", Callback = function()
		for groupSize = 2, 10 do
			local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
			for playerId = 1, groupSize do round:SetReady(playerId, true) end
			assert(round:Start())
			local snapshot = round:GetSnapshot()
			assert(snapshot.startedCount == groupSize and snapshot.activeCount == groupSize)
			for playerId = 1, groupSize do assert(snapshot.results[playerId] == "Active") end
		end
	end },
	{ Name = "ten group players joining during countdown all start active with real full XP", Callback = function()
		local workspaceAttributes = {}
		local map = Instance.new("Folder")
		map.Name = "ToxicRainMap"
		local roads = Instance.new("Folder")
		roads.Name = "RoadParts"
		roads.Parent = map
		local startingRoad = Instance.new("Part")
		startingRoad.Name = "RoadSection1"
		startingRoad.Size = Vector3.new(34, 1, 260)
		startingRoad.Position = Vector3.new(-8, 0.5, 175)
		startingRoad.Parent = roads
		local fakeWorkspace = {
			SetAttribute = function(_self, name, value)
				workspaceAttributes[name] = value
			end,
			GetAttribute = function(_self, name)
				return workspaceAttributes[name]
			end,
			FindFirstChild = function(_self, name)
				return if name == "ToxicRainMap" then map else nil
			end,
		}
		local players = {}
		for playerId = 1, 10 do
			local attributes = { ToxicRainQueueMode = "None" }
			local character = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = character
			local player = {
				UserId = playerId,
				Character = character,
				GetAttribute = function(_self, name)
					return attributes[name]
				end,
				SetAttribute = function(_self, name, value)
					attributes[name] = value
				end,
			}
			players[playerId] = { Player = player, Attributes = attributes }
		end
		local fakePlayersModule = {
			GetPlayers = function()
				local result = {}
				for playerId = 1, 10 do table.insert(result, players[playerId].Player) end
				return result
			end,
		}
		local runtime = RoundRuntime.new(fakePlayersModule :: any, fakeWorkspace :: any)
		runtime._countdownRunning = true
		for playerId = 1, 10 do
			local player = players[playerId].Player
			runtime:_queuePlayer(player :: any, "Group")
		end

		assert(runtime._round:GetSnapshot().readyCount == 10)
		assert(workspaceAttributes.ToxicRainReadyPlayers == 10)
		assert(runtime._round:Start())
		runtime._startLocked = true
		runtime:_initializeStartedPlayers()
		local snapshot = runtime._round:GetSnapshot()
		assert(snapshot.startedCount == 10 and snapshot.activeCount == 10)
		for playerId = 1, 10 do
			assert(snapshot.results[playerId] == "Active")
			assert(players[playerId].Attributes.ToxicRainQueueMode == "Running")
			assert(players[playerId].Attributes.ToxicRainXP == 100)
			local position = players[playerId].Player.Character.HumanoidRootPart.Position
			local expectedRowZ = if playerId <= 5 then 53 else 60
			assert(math.abs(position.Z - expectedRowZ) < 0.01)
			assert(position.X >= -20.01 and position.X <= 4.01)
			assert(players[playerId].Player.Character.HumanoidRootPart.Anchored)
		end
		runtime:_releaseStartLock()
		for playerId = 1, 10 do
			assert(not players[playerId].Player.Character.HumanoidRootPart.Anchored)
		end
		runtime:_applyRainTick()
		for playerId = 1, 10 do
			assert(players[playerId].Attributes.ToxicRainXP == 82)
			players[playerId].Player.Character:Destroy()
		end
		map:Destroy()
	end },
	{ Name = "first finisher is the only winner", Callback = function()
		local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
		for playerId = 1, 3 do round:SetReady(playerId, true) end
		assert(round:Start() and round:Finish(2) and not round:Finish(1))
		local snapshot = round:GetSnapshot()
		assert(snapshot.winnerPlayerId == 2 and snapshot.results[2] == "Won")
		assert(snapshot.results[1] == "Lost" and snapshot.results[3] == "Lost")
		assert(snapshot.activeCount == 1)
	end },
	{ Name = "storm front follows the lagging player but never retreats", Callback = function()
		assert(RoundConfig.AdvanceStormFrontZ(0, 100, 1) == 28)
		assert(RoundConfig.AdvanceStormFrontZ(28, 50, 1) == 28)
		assert(RoundConfig.AdvanceStormFrontZ(28, 100, 0.25) == 35)
		assert(RoundConfig.AdvanceStormFrontZ(35, 100, -1) == 35)
	end },
	{ Name = "hazards are deterministic per seed and preserve a changing safe lane", Callback = function()
		local first = RoundConfig.GenerateHazardLayout(12345, 300, 700)
		local repeatLayout = RoundConfig.GenerateHazardLayout(12345, 300, 700)
		local other = RoundConfig.GenerateHazardLayout(54321, 300, 700)
		local expectedPuddles = 0
		for _, count in RoundConfig.HazardPuddlesPerBlockedLaneByBand do
			expectedPuddles += (#RoundConfig.HazardLaneCenters - 1) * count
		end
		assert(#first.Puddles == expectedPuddles)
		assert(#first.Fountains == RoundConfig.HazardBandCount - 2)
		assert(#first.SafeLanes == RoundConfig.HazardBandCount)
		assert(first.Puddles[1].X == repeatLayout.Puddles[1].X)
		assert(first.Puddles[1].Z == repeatLayout.Puddles[1].Z)
		assert(first.Puddles[1].X ~= other.Puddles[1].X or first.Puddles[1].Z ~= other.Puddles[1].Z)
		for bandIndex = 2, #first.SafeLanes do
			assert(math.abs(first.SafeLanes[bandIndex] - first.SafeLanes[bandIndex - 1]) <= 1)
		end
		local puddlesByBand = {}
		local minimumX, maximumX = math.huge, -math.huge
		for _, puddle in first.Puddles do
			puddlesByBand[puddle.Band] = (puddlesByBand[puddle.Band] or 0) + 1
			minimumX = math.min(minimumX, puddle.X)
			maximumX = math.max(maximumX, puddle.X)
		end
		for bandIndex = 2, RoundConfig.HazardBandCount do
			assert(puddlesByBand[bandIndex] > puddlesByBand[bandIndex - 1])
		end
		assert(minimumX < -25 and maximumX > 8)
		assert(first.Puddles[#first.Puddles].RadiusX > first.Puddles[1].RadiusX)
	end },
	{ Name = "road classification covers the full road part and not the shoulder", Callback = function()
		assert(RoundConfig.IsInsideHorizontalZone(0, 120, 17, 130, RoundConfig.RoadEdgeToleranceStuds))
		assert(RoundConfig.IsInsideHorizontalZone(17.75, 0, 17, 130, RoundConfig.RoadEdgeToleranceStuds))
		assert(not RoundConfig.IsInsideHorizontalZone(20, 0, 17, 130, RoundConfig.RoadEdgeToleranceStuds))
		assert(not RoundConfig.IsInsideHorizontalZone(0, 132, 17, 130, RoundConfig.RoadEdgeToleranceStuds))
	end },
	{ Name = "completed rain removes the used shelter and every shelter behind it", Callback = function()
		local map = Instance.new("Folder")
		map.Name = "ToxicRainMap"
		local shelters = Instance.new("Folder")
		shelters.Name = "Shelters"
		shelters.Parent = map
		local stops = {}
		for index, z in { 100, 200, 300 } do
			local stop = Instance.new("Model")
			stop.Name = `Stop{index}`
			stop.Parent = shelters
			local zone = Instance.new("Part")
			zone.Name = "ProtectionZone"
			zone.Position = Vector3.new(0, 5, z)
			zone.Size = Vector3.new(20, 10, 20)
			zone.Transparency = 0.6
			zone.CanCollide = true
			zone:SetAttribute("ProtectionClass", "Normal")
			zone.Parent = stop
			stops[index] = { Model = stop, Zone = zone }
		end
		local fakeWorkspace = {
			FindFirstChild = function(_self, name) return if name == "ToxicRainMap" then map else nil end,
		}
		local runtime = RoundRuntime.new({} :: any, fakeWorkspace :: any)
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(0, 5, 200)
		root.Parent = character
		local playerAttributes = {}
		local player = {
			Character = character,
			SetAttribute = function(_self, name, value) playerAttributes[name] = value end,
		}
		assert(runtime:_rainLossFor(player :: any) == 0)
		assert(runtime._furthestUsedShelterZ == 200)
		runtime:_retireUsedShelters()
		assert(stops[1].Model:GetAttribute("ToxicRainShelterAvailable") == false)
		assert(stops[2].Model:GetAttribute("ToxicRainShelterAvailable") == false)
		assert(stops[1].Zone.Transparency == 1 and not stops[1].Zone.CanCollide)
		assert(stops[2].Zone.Transparency == 1 and not stops[2].Zone.CanCollide)
		assert(stops[3].Model:GetAttribute("ToxicRainShelterAvailable") == nil)
		assert(math.abs(stops[3].Zone.Transparency - 0.6) < 0.001 and stops[3].Zone.CanCollide)
		runtime:_restoreShelters()
		for _, stop in stops do
			assert(stop.Model:GetAttribute("ToxicRainShelterAvailable") == true)
			assert(math.abs(stop.Zone.Transparency - 0.6) < 0.001 and stop.Zone.CanCollide)
		end
		character:Destroy()
		map:Destroy()
	end },
}

local Runner = {}
function Runner.runAll()
	return TestHarness.runAll("ToxicRainRound", tests)
end
return Runner
