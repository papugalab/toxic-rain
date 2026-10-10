--!strict

local TestHarness = require(script.Parent.TestHarness)
local RoundStateMachine = require(script.Parent.Parent.Modules.ToxicRain.RoundStateMachine)
local RoundRuntime = require(script.Parent.Parent.Modules.ToxicRain.RoundRuntime)
local FinishScoring = require(game.ReplicatedStorage.Shared.ToxicRain.FinishScoring)
local PodiumPresentation = require(game.ReplicatedStorage.Project.Client.ToxicRain.PodiumPresentation)

local function fixture(scope: any, count: number)
	local world = scope:Track(Instance.new("Folder"))
	local map = Instance.new("Folder") map.Name = "ToxicRainMap" map.Parent = world
	local finish = Instance.new("Part") finish.Name = "FinishZone" finish.Size = Vector3.new(54, 1, 30)
	finish.Position = Vector3.new(0, 0, 700) finish.Parent = map
	local players = {}
	for id = 1, count do
		local character = scope:Track(Instance.new("Model"))
		local root = Instance.new("Part") root.Name = "HumanoidRootPart" root.Position = Vector3.new(0, 4, 700) root.Parent = character
		local head = Instance.new("Part") head.Name = "Head" head.Parent = character
		local humanoid = Instance.new("Humanoid") humanoid.Parent = character
		local attributes = { ToxicRainXP = 100, ToxicRainQueueMode = "Running" }
		players[id] = {
			UserId = id, DisplayName = `Player{id}`, Character = character,
			GetAttribute = function(_self, name) return attributes[name] end,
			SetAttribute = function(_self, name, value) attributes[name] = value end,
		}
	end
	local boundary = { GetPlayers = function() return players end }
	local now = 0
	local runtime = RoundRuntime.new(boundary :: any, world :: any, nil, function() return now end)
	scope:Defer(function() runtime._generation += 1 runtime._podium:Clear() end)
	for id = 1, count do runtime._round:SetReady(id, true) end
	assert(runtime._round:Start(if count == 1 then 1 else nil))
	world:SetAttribute("ToxicRainWeather", "ToxicRain")
	return runtime, players, world, function(time: number) now = time end
end

local tests = {
	{ Name = "visual language distinguishes podium, outside top three and death", Callback = function()
		assert(PodiumPresentation.OutcomeLabel("Finished", 1) == "🥇 Место 1")
		assert(PodiumPresentation.OutcomeLabel("Finished", 2) == "🥈 Место 2")
		assert(PodiumPresentation.OutcomeLabel("Finished", 3) == "🥉 Место 3")
		assert(PodiumPresentation.OutcomeLabel("Finished", 4) == "👎 Вне пьедестала")
		assert(PodiumPresentation.OutcomeLabel("Finished", 4, true) == "👎 Смещён с пьедестала")
		assert(PodiumPresentation.OutcomeLabel("Lost", nil) == "💀 Погиб в раунде")
	end },
	{ Name = "eliminated participant waits beside podium after respawn without score or rejoining", Callback = function(scope)
		local runtime, players, world = fixture(scope, 2)
		assert(runtime:EliminatePlayer(players[1], true) and not runtime:EliminatePlayer(players[1], true))
		assert(players[1].Character.Humanoid.Health == 0)
		assert(runtime._round:GetSnapshot().state == "Running" and runtime._round:GetSnapshot().activeCount == 1)
		assert(world:GetAttribute("ToxicRainWeather") == "ToxicRain" and runtime._generation == 0)
		local podium = world.ToxicRainMap.FinishPodiumRuntime
		assert(podium.Stage.Color == Color3.fromRGB(95, 100, 105))
		assert(podium.Results["1"]:GetAttribute("ToxicRainResult") == "Lost")
		assert(podium.Results["1"]:GetAttribute("ToxicRainScore") == nil and #runtime._round:GetStandings() == 0)
		local character = scope:Track(Instance.new("Model"))
		local root = Instance.new("Part") root.Name = "HumanoidRootPart" root.Parent = character
		local head = Instance.new("Part") head.Name = "Head" head.Parent = character
		local humanoid = Instance.new("Humanoid") humanoid.Parent = character
		players[1].Character = character
		runtime._podium:PlaceEliminated(players[1])
		local center = podium:GetAttribute("Center")
		assert(root.Anchored and root.Position.Z == center.Z - 9)
		assert(players[1]:GetAttribute("ToxicRainWaitingAtFinish") == true)
		assert(players[1]:GetAttribute("ToxicRainXP") == 0 and players[1]:GetAttribute("ToxicRainRank") == nil)
		assert(not runtime:TryFinish(players[1]) and not runtime:ConsumeApple(players[1]))
		assert(players[2]:GetAttribute("ToxicRainXP") == 100 and not players[2].Character.HumanoidRootPart.Anchored)
		runtime._podium:PlaceEliminated(players[1])
		assert(#podium.Results:GetChildren() == 1 and root.Position.Z == center.Z - 9)
		runtime._podium:Clear()
		assert(not root.Anchored and players[1]:GetAttribute("ToxicRainWaitingAtFinish") == nil)
	end },
	{ Name = "all ten eliminated avatars have distinct waiting spots off the podium steps", Callback = function(scope)
		local runtime, players, world = fixture(scope, 10)
		local positions = {}
		for _, player in players do
			assert(runtime:EliminatePlayer(player))
			local center = world.ToxicRainMap.FinishPodiumRuntime:GetAttribute("Center")
			local root = player.Character.HumanoidRootPart
			assert(math.abs(root.Position.X - center.X) < 22 and root.Position.Z == center.Z - 9)
			assert(not positions[root.Position.X]) positions[root.Position.X] = true
		end
	end },
	{ Name = "head banners show demotion and death for every participant with no fake death points", Callback = function(scope)
		local runtime, players, world, setTime = fixture(scope, 4)
		local host = scope:Track(Instance.new("Frame"))
		local viewWorkspace = {
			GetAttribute = function(_self, name) return world:GetAttribute(name) end,
			FindFirstChild = function(_self, name) return world:FindFirstChild(name) end,
		}
		local view = PodiumPresentation.new({GetHudHost = function() return host end}, viewWorkspace :: any,
			{GetLocalPlayer = function() return players[1] end, GetPlayers = function() return players end})
		view:Initialize()
		players[1]:SetAttribute("ToxicRainXP", 80) setTime(40) assert(runtime:TryFinish(players[1]))
		view:Update(0.016)
		setTime(41) assert(runtime:TryFinish(players[2]))
		players[3]:SetAttribute("ToxicRainXP", 90) setTime(42) assert(runtime:TryFinish(players[3]))
		view:Update(0.016)
		assert(players[1]:GetAttribute("ToxicRainRank") == 3)
		assert(host.ToxicRainFinishScore_1.TextLabel.Text:find("🥉 Место 3", 1, true))
		setTime(43) assert(runtime:TryFinish(players[4]))
		view:Update(0.016)
		assert(host.ToxicRainFinishScore_1.TextLabel.Text:find("👎 Смещён с пьедестала", 1, true))
		assert(host.ToxicRainFinishScore_1.TextLabel.Text:find("140 очков", 1, true))
		assert(host.ToxicRainFinishScore_2.TextLabel.Text:find("🥇 Место 1", 1, true))
		local center = world.ToxicRainMap.FinishPodiumRuntime:GetAttribute("Center")
		assert(players[1].Character.HumanoidRootPart.Position.Z == center.Z + 9)
		players[4]:SetAttribute("ToxicRainResult", "Lost")
		players[4]:SetAttribute("ToxicRainRank", nil) players[4]:SetAttribute("ToxicRainScore", nil)
		view:Update(0.016)
		assert(host.ToxicRainFinishScore_4.TextLabel.Text == "💀")
		assert(not host.ToxicRainFinishScore_4.TextLabel.Text:find("🏆", 1, true))
	end },
	{ Name = "simple scoring has integer complete seconds and never negative speed", Callback = function()
		local score = FinishScoring.Calculate(40, 80)
		assert(score.health == 80 and score.speed == 60 and score.score == 140)
		assert(FinishScoring.Calculate(40.99, 80).score == 140)
		assert(FinishScoring.Calculate(41, 80).score == 139)
		assert(FinishScoring.Calculate(100, 80).speed == 0)
		assert(FinishScoring.Calculate(300, 80).score == 80)
	end },
	{ Name = "invalid numeric results cannot enter the ranking", Callback = function()
		for _, time in {-1, math.huge, 0/0} do assert(not pcall(FinishScoring.Calculate, time, 100)) end
		for _, health in {-1, 101, math.huge, 0/0} do assert(not pcall(FinishScoring.Calculate, 40, health)) end
	end },
	{ Name = "later healthier player can take first place without stopping the group", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		for id = 1, 4 do round:SetReady(id, true) end
		assert(round:Start() and round:Finish(1, 40, 80) and round:Finish(2, 41, 100))
		local snapshot = round:GetSnapshot()
		assert(snapshot.state == "Running" and snapshot.activeCount == 2 and snapshot.winnerPlayerId == nil)
		assert(snapshot.standings[1].playerId == 2 and snapshot.standings[2].playerId == 1)
		assert(round:Finish(3, 42, 90) and round:Finish(4, 43, 100))
		snapshot = round:GetSnapshot()
		assert(snapshot.state == "Completed" and snapshot.winnerPlayerId == 2 and snapshot.activeCount == 0)
		assert(snapshot.standings[4].playerId == 1 and snapshot.standings[4].score == 140)
	end },
	{ Name = "ties use precise time then stable player ID, never player name", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		for id = 1, 3 do round:SetReady(id, true) end
		assert(round:Start())
		round:Finish(3, 101, 100) round:Finish(2, 100.5, 100) round:Finish(1, 100.5, 100)
		local standings = round:GetStandings()
		assert(standings[1].playerId == 1 and standings[2].playerId == 2 and standings[3].playerId == 3)
	end },
	{ Name = "duplicate and foreign finishes do not change frozen results", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		round:SetReady(1, true) round:SetReady(2, true) assert(round:Start())
		assert(not round:Finish(3, 10, 100) and round:Finish(1, 40, 80))
		assert(not round:Finish(1, 0, 100))
		local copy = round:GetStandings() copy[1].score = 999
		assert(round:GetStandings()[1].score == 140)
	end },
	{ Name = "last elimination or departure completes the round without a made up winner", Callback = function()
		for _, method in {"Eliminate", "Leave"} do
			local round = RoundStateMachine.new(2, 10)
			round:SetReady(1, true) round:SetReady(2, true) assert(round:Start())
			assert(round[method](round, 1) and round:GetSnapshot().state == "Running")
			assert(round[method](round, 2))
			assert(round:GetSnapshot().state == "Completed" and round:GetSnapshot().winnerPlayerId == nil)
		end
	end },
	{ Name = "finished results survive departure and the last active departure resolves the group", Callback = function()
		local round = RoundStateMachine.new(2, 10)
		round:SetReady(1, true) round:SetReady(2, true) assert(round:Start())
		assert(round:Finish(1, 40, 80) and not round:Leave(1) and round:Leave(2))
		assert(round:GetSnapshot().winnerPlayerId == 1 and #round:GetStandings() == 1)
	end },
	{ Name = "runtime group finish preserves weather, generation, other health and moves dynamic top three", Callback = function(scope)
		local runtime, players, world, setTime = fixture(scope, 4)
		players[1]:SetAttribute("ToxicRainXP", 80) setTime(40)
		assert(runtime:TryFinish(players[1]))
		assert(runtime._generation == 0 and world:GetAttribute("ToxicRainWeather") == "ToxicRain")
		assert(not runtime._restartScheduled and players[2]:GetAttribute("ToxicRainXP") == 100)
		assert(players[2]:GetAttribute("ToxicRainResult") == nil and not players[2].Character.HumanoidRootPart.Anchored)
		assert(players[1]:GetAttribute("ToxicRainRank") == 1 and players[1].Character.HumanoidRootPart.Anchored)
		setTime(41) assert(runtime:TryFinish(players[2]))
		assert(players[2]:GetAttribute("ToxicRainRank") == 1 and players[1]:GetAttribute("ToxicRainRank") == 2)
		players[3]:SetAttribute("ToxicRainXP", 90) setTime(42) assert(runtime:TryFinish(players[3]))
		setTime(43) assert(runtime:TryFinish(players[4]))
		assert(players[1]:GetAttribute("ToxicRainRank") == 4 and players[1]:GetAttribute("ToxicRainScore") == 140)
		local podium = world.ToxicRainMap.FinishPodiumRuntime
		assert(#podium.Results:GetChildren() == 4 and podium.Results["1"]:GetAttribute("ToxicRainScore") == 140)
		assert(runtime._round:GetSnapshot().winnerPlayerId == 2 and runtime._restartScheduled)
	end },
	{ Name = "Solo uses the same score and podium, completes, then clears owned anchors and scenery", Callback = function(scope)
		local runtime, players, world, setTime = fixture(scope, 1)
		players[1]:SetAttribute("ToxicRainXP", 80) setTime(40)
		assert(runtime:TryFinish(players[1]) and not runtime:TryFinish(players[1]))
		assert(runtime._round:GetSnapshot().state == "Completed" and players[1]:GetAttribute("ToxicRainScore") == 140)
		assert(players[1]:GetAttribute("ToxicRainResult") == "Won" and world:GetAttribute("ToxicRainWinnerName") == "Player1")
		runtime._podium:Clear() runtime._podium:Clear()
		assert(not players[1].Character.HumanoidRootPart.Anchored and not world.ToxicRainMap:FindFirstChild("FinishPodiumRuntime"))
	end },
	{ Name = "runtime refuses dead, zero health, outside zone and start locked finish", Callback = function(scope)
		local runtime, players, world, setTime = fixture(scope, 2)
		setTime(40)
		runtime._startLocked = true assert(not runtime:TryFinish(players[1])) runtime._startLocked = false
		players[1]:SetAttribute("ToxicRainXP", 0) assert(not runtime:TryFinish(players[1]))
		players[1]:SetAttribute("ToxicRainXP", 80)
		players[1].Character.HumanoidRootPart.Position = Vector3.new(0, 4, 0) assert(not runtime:TryFinish(players[1]))
		players[1].Character.HumanoidRootPart.Position = Vector3.new(0, 4, 700)
		players[1].Character.Humanoid.Health = 0 assert(not runtime:TryFinish(players[1]))
		assert(#runtime._round:GetStandings() == 0)
	end },
	{ Name = "finished players are not damaged by subsequent environmental ticks", Callback = function(scope)
		local runtime, players, world, setTime = fixture(scope, 2)
		players[1]:SetAttribute("ToxicRainXP", 80) setTime(40) assert(runtime:TryFinish(players[1]))
		players[2].Character.HumanoidRootPart.Position = Vector3.new(0, 4, 10)
		world:SetAttribute("ToxicRainFrontZ", 100) runtime:_applyEnvironmentalTick(false)
		assert(players[1]:GetAttribute("ToxicRainXP") == 80 and players[1]:GetAttribute("ToxicRainScore") == 140)
		assert(players[2]:GetAttribute("ToxicRainXP") == 82)
	end },
	{ Name = "children see calculation in three understandable stages", Callback = function()
		assert(PodiumPresentation.CalculationText(80, 60, 140, 1) == "❤️ Здоровье: 80")
		assert(PodiumPresentation.CalculationText(80, 60, 140, 2) == "❤️ 80 + ⚡ Скорость: 60")
		assert(PodiumPresentation.CalculationText(80, 60, 140, 3) == "❤️ 80 + ⚡ 60 = 🏆 140")
		assert(PodiumPresentation.CalculationText(80, 60, 140, 2, 40) == "❤️ 80 + ⚡ 60\nСкорость: 100 − 40 с = 60")
		assert(PodiumPresentation.CalculationText(80, 0, 80, 2, 120) == "❤️ 80 + ⚡ 0\nПосле 100 с: скорость 0")
	end },
	{ Name = "departed finisher keeps frozen record and does not reclaim a podium character", Callback = function(scope)
		local runtime, players, world, setTime = fixture(scope, 2)
		setTime(40) assert(runtime:TryFinish(players[1]))
		runtime._podium:RemovePlayer(1)
		players[1].Character.HumanoidRootPart.Anchored = false
		runtime._podium:Update(runtime._round:GetStandings())
		assert(world.ToxicRainMap.FinishPodiumRuntime.Results["1"]:GetAttribute("Connected") == false)
		assert(not players[1].Character.HumanoidRootPart.Anchored)
		assert(runtime._round:GetStandings()[1].score == 160)
	end },
}

local Runner = {}
function Runner.runAll() return TestHarness.runAll("FinishPodiumTestRunner", tests) end
return Runner
