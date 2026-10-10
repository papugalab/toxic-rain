--!strict

local TestHarness = require(script.Parent.TestHarness)
local RoundConfig = require(script.Parent.Parent.Modules.ToxicRain.RoundConfig)
local RoundRuntime = require(script.Parent.Parent.Modules.ToxicRain.RoundRuntime)
local RoundStateMachine = require(script.Parent.Parent.Modules.ToxicRain.RoundStateMachine)
local ShelterCombatRuntime = require(script.Parent.Parent.Modules.ToxicRain.ShelterCombatRuntime)
local ShelterCombatConfig = require(game.ReplicatedStorage.Shared.ToxicRain.ShelterCombatConfig)
local ShelterCombatProtocol = require(game.ReplicatedStorage.Shared.ToxicRain.ShelterCombatProtocol)
local WeatherController = require(game.ReplicatedStorage.Project.Client.ToxicRain.WeatherController)
local AppleController = require(game.ReplicatedStorage.Project.Client.ToxicRain.AppleController)
local AppleProtocol = require(game.ReplicatedStorage.Shared.ToxicRain.AppleProtocol)

local function withApplePlayer(callback: (any, any, any, BasePart, Backpack) -> ())
	local character = Instance.new("Model")
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	local backpack = Instance.new("Backpack")
	local marker = Instance.new("Part")
	local attributes = { ToxicRainXP = 40, ToxicRainAppleCount = 0 }
	local player = {
		UserId = 1, Character = character,
		GetAttribute = function(_self, name) return attributes[name] end,
		SetAttribute = function(_self, name, value) attributes[name] = value end,
		FindFirstChildOfClass = function(_self, class) return if class == "Backpack" then backpack else nil end,
	}
	local runtime = RoundRuntime.new({} :: any, {} :: any)
	runtime._round:SetReady(1, true)
	assert(runtime._round:Start(1))
	local ok, err = pcall(callback, runtime, player, attributes, marker, backpack)
	runtime:_clearRoundConnections()
	character:Destroy()
	backpack:Destroy()
	marker:Destroy()
	assert(ok, tostring(err))
end

local tests = {
	{ Name = "apple budget scales smoothly from solo through sixteen starters", Callback = function()
		local expected = { 2, 2, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8 }
		local empty = RoundConfig.GetAppleSpawnQuotas(0)
		assert(empty[1] + empty[2] + empty[3] == 0)
		for players, count in expected do
			local quotas = RoundConfig.GetAppleSpawnQuotas(players)
			assert(quotas[1] + quotas[2] + quotas[3] == count, `Wrong apple count for {players} starters`)
			assert(math.max(table.unpack(quotas)) - math.min(table.unpack(quotas)) <= 1)
			if count >= 3 then assert(quotas[1] > 0 and quotas[2] > 0 and quotas[3] > 0) end
		end
	end },
	{ Name = "actual apple spawn supports 2 to 16 players and clears generated markers on restart", Callback = function(scope)
		local world = scope:Track(Instance.new("Folder"))
		local map = Instance.new("Folder") map.Name = "ToxicRainMap" map.Parent = world
		local apples = Instance.new("Folder") apples.Name = "AppleSpawnPoints" apples.Parent = map
		for index, definition in {
			{1, -32, 87}, {1, 19, 137}, {1, -47, 195}, {1, 29, 250},
			{2, -37, 343}, {2, 28, 430}, {2, -46, 512},
			{3, -39, 625}, {3, 29, 705},
		} do
			local marker = Instance.new("Part")
			marker.Name = `Apple{index}` marker.Size = Vector3.new(2, 2, 2)
			marker.Position = Vector3.new(definition[2], 1.65, definition[3])
			marker.Anchored = true marker.CanCollide = false
			marker:SetAttribute("SectionIndex", definition[1]) marker.Parent = apples
		end
		local runtime = RoundRuntime.new({
			GetPlayers = function() return {} end,
			GetPlayerFromCharacter = function() return nil end,
		} :: any, world :: any)
		scope:Defer(function() runtime:_clearRoundObjects() end)
		for players = 1, 16 do
			runtime._round = RoundStateMachine.new(2, 16)
			for id = 1, players do runtime._round:SetReady(id, true) end
			assert(runtime._round:Start(if players == 1 then 1 else nil))
			local quotas = RoundConfig.GetAppleSpawnQuotas(players)
			runtime:_spawnApples()
			local actual = {0, 0, 0}
			local positions = {}
			for _, marker in apples:GetDescendants() do
				if not marker:IsA("BasePart") or marker.Transparency ~= 0 then continue end
				assert(marker.CanTouch and not marker:GetAttribute("Taken"))
				local section = marker:GetAttribute("SectionIndex")
				actual[section] += 1
				for _, position in positions do assert((position - marker.Position).Magnitude >= 4, "Overlapping apples") end
				table.insert(positions, marker.Position)
			end
			for section = 1, 3 do assert(actual[section] == quotas[section], `Section {section} for {players} players`) end
			assert(#runtime._roundConnections == #positions)
		end
		-- Shrinking the active group during a round cannot remove its original budget.
		runtime._round:Eliminate(1)
		runtime:_spawnApples()
		local count = 0
		for _, marker in apples:GetDescendants() do if marker:IsA("BasePart") and marker.Transparency == 0 then count += 1 end end
		assert(count == 8 and #runtime._roundConnections == 8)
		runtime:_clearRoundObjects()
		assert(runtime._generatedAppleSpawns == nil and not apples:FindFirstChild("ExtraAppleSpawns"))
		assert(#apples:GetChildren() == 9 and #runtime._roundConnections == 0)
		for _, marker in apples:GetChildren() do assert(marker.Transparency == 1 and not marker.CanTouch and not marker:GetAttribute("Taken")) end
	end },
	{ Name = "first course retains green puddles but never generates fountain warning pools", Callback = function()
		assert(not RoundConfig.FountainsEnabled)
		for _, seed in { 1, 12345, 54321, 2147483646 } do
			local layout = RoundConfig.GenerateHazardLayout(seed, 300, 700)
			assert(#layout.Fountains == 0)
			assert(#layout.Puddles == 90 and #layout.SafeLanes == 5)
		end
	end },
	{ Name = "inside storm presentation overrides clear weather, warning and toxic rain", Callback = function()
		for _, weather in { "Clear", "Warning", "ToxicRain" } do
			assert(WeatherController.ResolveVisualState(true, weather, 100, 110) == "Storm")
			assert(WeatherController.ResolveVisualState(true, weather, 110, 110) == "Storm")
		end
		assert(WeatherController.ResolveVisualState(true, "ToxicRain", 111, 110) == "Rain")
		assert(WeatherController.ResolveVisualState(true, "Warning", 111, 110) == "Warning")
	end },
	{ Name = "storm visual is cleared for lobby, eliminated players and missing characters", Callback = function()
		assert(WeatherController.ResolveVisualState(false, "ToxicRain", 100, 110) == "Inactive")
		assert(WeatherController.ResolveVisualState(true, "ToxicRain", nil, 110) == "Inactive")
		assert(WeatherController.ResolveVisualState(false, "Warning", nil, nil) == "Inactive")
	end },
	{ Name = "leaving the storm selects approaching, rain or clear instead of a sticky storm tint", Callback = function()
		assert(WeatherController.ResolveVisualState(true, "Clear", 110.1, 110) == "Approaching")
		assert(WeatherController.ResolveVisualState(true, "Clear", 170, 110) == "Approaching")
		assert(WeatherController.ResolveVisualState(true, "Clear", 170.1, 110) == "Clear")
		assert(WeatherController.ResolveVisualState(true, "Clear", 170, nil) == "Clear")
		assert(WeatherController.ResolveVisualState(true, "ToxicRain", 170, nil) == "Rain")
	end },
	{ Name = "yellow fountain pool is a warning before its damaging green eruption", Callback = function()
		local fixture = Instance.new("Folder")
		local model = Instance.new("Model")
		model.Parent = fixture
		local zone = Instance.new("Part")
		zone.Size = Vector3.new(10, 8, 10)
		zone.Parent = model
		local pool = Instance.new("Part")
		pool.Parent = model
		local emitter = Instance.new("ParticleEmitter")
		emitter.Parent = pool
		local character = Instance.new("Model")
		character.Parent = fixture
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = character
		local fountain = { Model = model, Zone = zone, Warning = pool, Emitter = emitter }
		local runtime = RoundRuntime.new({} :: any, {} :: any)
		runtime._fountains = { fountain }
		local player = { Character = character, SetAttribute = function() end }
		local ok, err = pcall(function()
			runtime:_setFountainState(fountain, "Warning")
			assert(pool.Color == Color3.fromRGB(210, 255, 65) and not emitter.Enabled)
			assert(runtime:_hazardLossFor(player :: any) == 0)
			runtime:_setFountainState(fountain, "Active")
			assert(pool.Color == Color3.fromRGB(45, 255, 85) and emitter.Enabled)
			assert(runtime:_hazardLossFor(player :: any) == RoundConfig.HazardXpLossPerSecond)
			runtime:_setFountainState(fountain, "Idle")
			assert(not emitter.Enabled and runtime:_hazardLossFor(player :: any) == 0)
			assert(RoundConfig.FountainWarningSeconds == 1.5)
		end)
		fixture:Destroy()
		assert(ok, tostring(err))
	end },
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
		assert(RoundConfig.MaximumPlayers == 16)
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
		local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
		round:SetReady(1, true)
		assert(round:GetSnapshot().state == "Waiting" and not round:Start())
	end },
	{ Name = "solo lobby pad can start immediately with explicit override", Callback = function()
		local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
		round:SetReady(1, true)
		assert(round:GetSnapshot().state == "Waiting")
		assert(round:Start(1))
		assert(round:GetSnapshot().startedCount == 1)
	end },
	{ Name = "countdown cancels below minimum", Callback = function()
		local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
		round:SetReady(1, true) round:SetReady(2, true)
		assert(round:GetSnapshot().state == "Countdown")
		round:SetReady(2, false)
		assert(round:GetSnapshot().state == "Waiting")
	end },
	{ Name = "every supported group size from two through sixteen starts every player", Callback = function()
		for groupSize = 2, 16 do
			local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
			for playerId = 1, groupSize do round:SetReady(playerId, true) end
			assert(round:Start())
			local snapshot = round:GetSnapshot()
			assert(snapshot.startedCount == groupSize and snapshot.activeCount == groupSize)
			for playerId = 1, groupSize do assert(snapshot.results[playerId] == "Active") end
		end
	end },
	{ Name = "sixteen group players start in two rows of eight with full XP", Callback = function()
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
		for playerId = 1, 16 do
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
				for playerId = 1, 16 do table.insert(result, players[playerId].Player) end
				return result
			end,
		}
		local runtime = RoundRuntime.new(fakePlayersModule :: any, fakeWorkspace :: any)
		runtime._countdownRunning = true
		for playerId = 1, 16 do
			local player = players[playerId].Player
			runtime:_queuePlayer(player :: any, "Group")
		end

		assert(runtime._round:GetSnapshot().readyCount == 16)
		assert(workspaceAttributes.ToxicRainReadyPlayers == 16)
		assert(runtime._round:Start())
		runtime._startLocked = true
		runtime:_initializeStartedPlayers()
		local snapshot = runtime._round:GetSnapshot()
		assert(snapshot.startedCount == 16 and snapshot.activeCount == 16)
		for playerId = 1, 16 do
			assert(snapshot.results[playerId] == "Active")
			assert(players[playerId].Attributes.ToxicRainQueueMode == "Running")
			assert(players[playerId].Attributes.ToxicRainXP == 100)
			local position = players[playerId].Player.Character.HumanoidRootPart.Position
			local expectedRowZ = if playerId <= 8 then 53 else 60
			assert(math.abs(position.Z - expectedRowZ) < 0.01)
			assert(position.X >= -22.01 and position.X <= 6.01)
			local expectedX = -22 + ((playerId - 1) % 8) * 4
			assert(math.abs(position.X - expectedX) < 0.01)
			assert(players[playerId].Player.Character.HumanoidRootPart.Anchored)
		end
		runtime:_releaseStartLock()
		for playerId = 1, 16 do
			assert(not players[playerId].Player.Character.HumanoidRootPart.Anchored)
		end
		runtime:_applyRainTick()
		for playerId = 1, 16 do
			assert(players[playerId].Attributes.ToxicRainXP == 82)
			players[playerId].Player.Character:Destroy()
		end
		map:Destroy()
	end },
	{ Name = "a group finisher leaves the other participants racing", Callback = function()
		local round = RoundStateMachine.new(2, RoundConfig.MaximumPlayers)
		for playerId = 1, 3 do round:SetReady(playerId, true) end
		assert(round:Start() and round:Finish(2, 40, 80) and not round:Finish(2))
		local snapshot = round:GetSnapshot()
		assert(snapshot.state == "Running" and snapshot.winnerPlayerId == nil and snapshot.results[2] == "Finished")
		assert(snapshot.results[1] == "Active" and snapshot.results[3] == "Active")
		assert(snapshot.activeCount == 2)
	end },
	{ Name = "storm front tracks runners and creeps towards stationary shelter players safely", Callback = function()
		assert(RoundConfig.AdvanceStormFrontZ(0, 200, 1) == 28)
		assert(RoundConfig.AdvanceStormFrontZ(80, 200, 1) == 82)
		assert(RoundConfig.AdvanceStormFrontZ(82, 200, 10) == 102)
		assert(RoundConfig.AdvanceStormFrontZ(159, 200, 1) == 160)
		assert(RoundConfig.AdvanceStormFrontZ(28, 50, 1) == 28)
		assert(RoundConfig.AdvanceStormFrontZ(28, 100, 0.25) == 28.5)
		assert(RoundConfig.AdvanceStormFrontZ(35, 100, -1) == 35)
	end },
	{ Name = "final storm overtakes campers independently and advances to the finish", Callback = function()
		assert(RoundConfig.AdvanceStormFrontZ(0, 0, 1, true) == 18)
		assert(RoundConfig.AdvanceStormFrontZ(0, 500, 1, true) == 18)
		assert(RoundConfig.AdvanceStormFrontZ(18, -100, 0.5, true) == 27)
		assert(RoundConfig.AdvanceStormFrontZ(18, -100, -1, true) == 18)
		assert(RoundConfig.AdvanceStormFrontZ(740, 500, 100, true) == 753)
	end },
	{ Name = "only the last completed rain starts chase and stale rain cannot restart it", Callback = function()
		local attributes = {}
		local fakeWorkspace = {
			SetAttribute = function(_self, name, value) attributes[name] = value end,
			FindFirstChild = function() return nil end,
		}
		local runtime = RoundRuntime.new({ GetPlayers = function() return {} end } :: any, fakeWorkspace :: any)
		runtime._round:SetReady(1, true)
		assert(runtime._round:Start(1))
		runtime:_completeRainEvent(0, 1, 100)
		assert(not runtime._stormChasing and attributes.ToxicRainNextRainAt == 131)
		runtime:_completeRainEvent(1, #RoundConfig.RainWarningStartSeconds, 100)
		assert(not runtime._stormChasing)
		runtime:_completeRainEvent(0, #RoundConfig.RainWarningStartSeconds, 100)
		assert(runtime._stormChasing and attributes.ToxicRainStormChasing == true)
		assert(attributes.ToxicRainWeather == "Clear" and attributes.ToxicRainNextRainAt == nil)
		runtime:_clearRoundObjects()
		assert(not runtime._stormChasing and attributes.ToxicRainStormChasing == false)
		runtime._round:Finish(1)
		runtime:_completeRainEvent(0, #RoundConfig.RainWarningStartSeconds, 100)
		assert(not runtime._stormChasing)
	end },
	{ Name = "apple pickup immediately equips and heals exactly once", Callback = function()
		withApplePlayer(function(runtime, player, attributes, marker, backpack)
			runtime:_giveApple(player, marker)
			local tool = player.Character:FindFirstChildOfClass("Tool")
			assert(tool and tool:GetAttribute("ToxicRainApple") == true, "Apple must be equipped at pickup")
			assert(backpack:FindFirstChildOfClass("Tool") == nil)
			assert(attributes.ToxicRainAppleCount == 1 and attributes.ToxicRainXP == 40)
			assert(marker:GetAttribute("Taken") and not tool.Handle.CanTouch and tool.Handle.Massless)
			runtime:_giveApple(player, marker)
			assert(attributes.ToxicRainAppleCount == 1)
			assert(runtime:ConsumeApple(player, tool))
			assert(attributes.ToxicRainXP == 100 and attributes.ToxicRainAppleCount == 0 and tool.Parent == nil)
			attributes.ToxicRainXP = 60
			assert(not runtime:ConsumeApple(player, tool) and attributes.ToxicRainXP == 60)
		end)
	end },
	{ Name = "apple consumption finds a backpack apple but rejects foreign tools and lost players", Callback = function()
		withApplePlayer(function(runtime, player, attributes, marker, backpack)
			runtime:_giveApple(player, marker)
			local tool = player.Character:FindFirstChildOfClass("Tool")
			assert(tool)
			tool.Parent = backpack
			local foreign = Instance.new("Tool")
			foreign:SetAttribute("ToxicRainApple", true)
			assert(not runtime:ConsumeApple(player, foreign))
			foreign:Destroy()
			assert(runtime:ConsumeApple(player) and attributes.ToxicRainXP == 100)
			marker:SetAttribute("Taken", false)
			runtime:_giveApple(player, marker)
			runtime._round:Eliminate(1)
			attributes.ToxicRainXP = 20
			assert(not runtime:ConsumeApple(player) and attributes.ToxicRainXP == 20)
		end)
	end },
	{ Name = "apple keyboard sends only a validated intention while holding an apple", Callback = function()
		assert(AppleProtocol.ValidateConsumeIntent({}))
		assert(not AppleProtocol.ValidateConsumeIntent({ Health = 100 }))
		assert(not AppleProtocol.ValidateConsumeIntent("apple"))
		local count, state, queued = 1, "Running", 0
		local controller = AppleController.new({
			PlayersModule = { GetLocalPlayer = function() return { GetAttribute = function() return count end } end },
			Workspace = { GetAttribute = function() return state end },
			Communication = { Queue = function(_self, messageType, payload)
				assert(messageType == AppleProtocol.ConsumeIntent and AppleProtocol.ValidateConsumeIntent(payload))
				queued += 1
				return true
			end },
		})
		assert(controller:RequestConsume() and queued == 1)
		count = 0
		assert(not controller:RequestConsume() and queued == 1)
		count, state = 1, "Completed"
		assert(not controller:RequestConsume() and queued == 1)
	end },
	{ Name = "push hand is compact white and has no long arm or green cuff", Callback = function()
		local backpack = Instance.new("Backpack")
		local player = { FindFirstChildOfClass = function() return backpack end }
		local runtime = ShelterCombatRuntime.new({ PlayersModule = {}, Workspace = {}, Communication = {} })
		local ok, err = pcall(function()
			runtime:_createPushTool(player :: any)
			local tool = backpack:FindFirstChildOfClass("Tool")
			assert(tool and not tool:FindFirstChild("LongArm") and not tool:FindFirstChild("ToxicCuff"))
			local handle = tool:FindFirstChild("Handle") :: BasePart
			for _, part in tool:GetChildren() do
				if part:IsA("BasePart") and part ~= handle then
					assert(part.Color == Color3.fromRGB(245, 245, 245))
					assert((part.Position - handle.Position).Magnitude + part.Size.Magnitude * 0.5 < 3.3)
					assert(part.Massless and not part.CanCollide)
				end
			end
		end)
		backpack:Destroy()
		assert(ok, tostring(err))
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
		assert(#first.Fountains == 0)
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
