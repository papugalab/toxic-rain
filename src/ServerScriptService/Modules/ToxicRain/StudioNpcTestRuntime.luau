--!strict

local Protocol = require(game.ReplicatedStorage.Shared.ToxicRain.StudioNpcTestProtocol)
local Policy = require(script.Parent.StudioNpcTestPolicy)

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(dependencies: any): any
	return setmetatable({
		_dependencies = dependencies,
		_fixture = nil,
		_observer = nil,
		_observerRootState = nil,
		_initialized = false,
		_nextStartAt = 0,
	}, Runtime)
end

function Runtime:IsAllowed(player: any): boolean
	local d = self._dependencies
	return Policy.IsAllowed(d.IsStudio, player.UserId, d.PlaceId, d.GameId)
end

function Runtime:Stop()
	if not self._fixture then return end
	local d = self._dependencies
	self._fixture.Stop()
	self._fixture = nil
	d.Round:SetStudioTestSuspended(false)
	d.Round:_publish()
	d.Combat:_createHooks()
	d.Combat:_syncPhase()
	local world = d.Workspace
	world:SetAttribute("ToxicRainWeather", "Clear")
	world:SetAttribute("ToxicRainWeatherTimer", 0)
	world:SetAttribute("ToxicRainStartLocked", false)
	world:SetAttribute("ToxicRainStartCountdown", 0)
	world:SetAttribute("ToxicRainRoundMode", "None")
	world:SetAttribute("ToxicRainRoundStartedAt", nil)
	world:SetAttribute("ToxicRainNextRainAt", nil)
	world:SetAttribute("ToxicRainRainEndsAt", nil)
	world:SetAttribute("ToxicRainWinnerUserId", nil)
	world:SetAttribute("ToxicRainWinnerName", nil)
	world:SetAttribute("ToxicRainStudioNpcTestActive", false)
	local state = self._observerRootState
	if state and state.Root.Parent then
		state.Root.CFrame = state.CFrame
		state.Root.AssemblyLinearVelocity = Vector3.zero
		state.Root.Anchored = state.Anchored
	end
	self._observerRootState = nil
	self._observer = nil
end

function Runtime:HandleIntent(player: any, payload: any): boolean
	-- The client attribute/button is presentation only. Every request is authorized here.
	if not self:IsAllowed(player) then return false end
	if payload.Action == "Stop" then self:Stop() return true end
	local d = self._dependencies
	local now = d.Clock()
	if now < self._nextStartAt then return false end
	local snapshot = d.Round._round:GetSnapshot()
	if snapshot.state ~= "Waiting" or snapshot.readyCount > 0 then
		player:SetAttribute("ToxicRainAdminTestMessage", "Запускай тест из пустого лобби")
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	self._nextStartAt = now + 2
	if self._fixture then self:Stop() end
	self._observer = player
	self._observerRootState = { Root = root, CFrame = root.CFrame, Anchored = root.Anchored }
	root.Anchored = true
	d.Round:SetStudioTestSuspended(true)
	local ok, result = xpcall(function()
		self._fixture = d.CreateFixture({
			Observer = player, Workspace = d.Workspace,
			RoundFactory = d.RoundFactory, CombatFactory = d.CombatFactory,
		})
		d.Workspace:SetAttribute("ToxicRainStudioNpcTestActive", true)
		self._fixture.Start()
	end, debug.traceback)
	if not ok then
		if self._fixture then self:Stop()
		else
			d.Round:SetStudioTestSuspended(false)
			root.Anchored = self._observerRootState.Anchored
			self._observerRootState = nil
			self._observer = nil
		end
		player:SetAttribute("ToxicRainAdminTestMessage", "Не удалось запустить тест")
		warn("[StudioNpcTest] " .. tostring(result))
		return false
	end
	player:SetAttribute("ToxicRainAdminTestMessage", "")
	return true
end

function Runtime:Initialize()
	if self._initialized then return end
	self._initialized = true
	local d = self._dependencies
	d.Communication:RegisterHandler(Protocol.Intent, Protocol.ValidateIntent, function(player, payload)
		self:HandleIntent(player, payload)
	end)
	d.PlayersModule:ObservePlayers(function(player)
		player:SetAttribute("ToxicRainAdminTestAllowed", self:IsAllowed(player))
	end, function(player)
		if player == self._observer then self:Stop() end
	end)
	d.PlayersModule.CharacterRemoving:Connect(function(player)
		if player == self._observer then self:Stop() end
	end)
end

return Runtime
