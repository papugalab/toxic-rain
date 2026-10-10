--!strict

local Harness = require(script.Parent.TestHarness)
local Runtime = require(script.Parent.Parent.Modules.ToxicRain.StudioNpcTestRuntime)
local Policy = require(script.Parent.Parent.Modules.ToxicRain.StudioNpcTestPolicy)
local Protocol = require(game.ReplicatedStorage.Shared.ToxicRain.StudioNpcTestProtocol)
local Controller = require(game.ReplicatedStorage.Project.Client.ToxicRain.StudioNpcTestController)
local Signal = require(game.ReplicatedStorage.Shared.Util.Signal)

local function setup(scope: any, studio: boolean, userId: number)
	local world = scope:Track(Instance.new("Folder"))
	local character = scope:Track(Instance.new("Model"))
	local root = Instance.new("Part") root.Name = "HumanoidRootPart" root.CFrame = CFrame.new(2, 4, 6) root.Parent = character
	local humanoid = Instance.new("Humanoid") humanoid.Parent = character
	local attrs = {}
	local player: any = {
		UserId = userId, Character = character,
		SetAttribute = function(_self, key, value) attrs[key] = value end,
		GetAttribute = function(_self, key) return attrs[key] end,
	}
	local removing = Signal.new()
	scope:Defer(function() removing:Destroy() end)
	local onRemoved = nil
	local players: any = {
		CharacterRemoving = removing,
		ObservePlayers = function(_self, added, removed) added(player) onRemoved = removed end,
	}
	local round: any = { state = "Waiting", ready = 0, suspended = false }
	round._round = { GetSnapshot = function() return { state = round.state, readyCount = round.ready } end }
	function round:SetStudioTestSuspended(value) self.suspended = value end
	function round:_publish() world:SetAttribute("ToxicRainRoundState", self.state) end
	local creates, starts, stops, hooks = 0, 0, 0, 0
	local clock = 0
	local runtime = Runtime.new({
		IsStudio = studio, PlaceId = 79356340322631, GameId = 10762145525,
		PlayersModule = players, Workspace = world, Round = round,
		Combat = { _createHooks = function() hooks += 1 end, _syncPhase = function() end },
		Communication = { RegisterHandler = function() end },
		Clock = function() return clock end,
		CreateFixture = function()
			creates += 1
			return { Start = function() starts += 1 end, Stop = function() stops += 1 end }
		end,
	})
	scope:Defer(function() runtime:Stop() end)
	return runtime, player, round, world, root,
		function() return creates, starts, stops, hooks end,
		function(value) clock = value end,
		function() if onRemoved then onRemoved(player) end end
end

local tests = {
	{ Name = "published owner and strangers cannot create a test or see the panel", Callback = function(scope)
		for _, entry in { {false, Policy.AdminUserId}, {true, 17} } do
			local runtime, player, round, world, _, counts = setup(scope, entry[1], entry[2])
			runtime:Initialize() runtime:Initialize()
			assert(player:GetAttribute("ToxicRainAdminTestAllowed") == false)
			player:SetAttribute("ToxicRainAdminTestAllowed", true)
			assert(not runtime:HandleIntent(player, {Action = "Start"}))
			assert(not runtime:HandleIntent(player, {Action = "Stop"}))
			assert(counts() == 0 and not round.suspended and not world:GetAttribute("ToxicRainStudioNpcTestActive"))
		end
	end },
	{ Name = "permission is pinned to Studio account and project identity", Callback = function()
		assert(Policy.IsAllowed(true, Policy.AdminUserId, 79356340322631, 10762145525))
		assert(not Policy.IsAllowed(false, Policy.AdminUserId, 79356340322631, 10762145525))
		assert(not Policy.IsAllowed(true, Policy.AdminUserId, 12, 10762145525))
		assert(not Policy.IsAllowed(true, Policy.AdminUserId, 79356340322631, 12))
	end },
	{ Name = "intent rejects extra fields and client supplied participants", Callback = function()
		assert(Protocol.ValidateIntent({Action = "Start"}))
		assert(Protocol.ValidateIntent({Action = "Stop"}))
		for _, payload in { {}, {Action = "Start", UserId = Policy.AdminUserId}, {Action = "Start", Count = 16}, {Action = "Delete"} } do
			assert(not Protocol.ValidateIntent(payload))
		end
		assert(not Protocol.ValidateIntent("Start"))
	end },
	{ Name = "start replay and stop restore observer and ordinary round", Callback = function(scope)
		local runtime, player, round, world, root, counts, setTime = setup(scope, true, Policy.AdminUserId)
		local initial = root.CFrame
		runtime:Initialize()
		assert(runtime:HandleIntent(player, {Action = "Start"}))
		assert(root.Anchored and round.suspended and world:GetAttribute("ToxicRainStudioNpcTestActive"))
		assert(not runtime:HandleIntent(player, {Action = "Start"}))
		setTime(3)
		assert(runtime:HandleIntent(player, {Action = "Start"}))
		local creates, starts, stops = counts()
		assert(creates == 2 and starts == 2 and stops == 1)
		root.CFrame = CFrame.new(100, 4, 300)
		assert(runtime:HandleIntent(player, {Action = "Stop"}))
		runtime:Stop()
		local _, _, finalStops, hooks = counts()
		assert(finalStops == 2 and hooks == 2)
		assert(not root.Anchored and root.CFrame == initial and not round.suspended)
		assert(world:GetAttribute("ToxicRainStudioNpcTestActive") == false and world:GetAttribute("ToxicRainRoundState") == "Waiting")
	end },
	{ Name = "test cannot interrupt a normal group or solo queue", Callback = function(scope)
		local runtime, player, round, _, _, counts = setup(scope, true, Policy.AdminUserId)
		round.state = "Running"
		assert(not runtime:HandleIntent(player, {Action = "Start"}))
		round.state = "Waiting" round.ready = 1
		assert(not runtime:HandleIntent(player, {Action = "Start"}))
		assert(counts() == 0 and not round.suspended)
	end },
	{ Name = "admin leave cleans up an active test", Callback = function(scope)
		local runtime, player, round, world, root, counts, _, remove = setup(scope, true, Policy.AdminUserId)
		runtime:Initialize() assert(runtime:HandleIntent(player, {Action = "Start"}))
		remove() remove()
		local _, _, stops = counts()
		assert(stops == 1 and not round.suspended and not root.Anchored)
		assert(world:GetAttribute("ToxicRainStudioNpcTestActive") == false)
	end },
	{ Name = "client creates no controls and queues no intent without permission", Callback = function()
		local queues, views = 0, 0
		local client = Controller.new({
			PlayersModule = { GetLocalPlayer = function() return { GetAttribute = function() return false end } end },
			UI = { GetHudHost = function() views += 1 return nil end },
			Communication = { Queue = function() queues += 1 return true end },
		})
		client:_createView()
		assert(not client:Request("Start") and views == 0 and queues == 0 and client._view == nil)
	end },
}

return { runAll = function() return Harness.runAll("StudioNpcTestRunner", tests) end }
