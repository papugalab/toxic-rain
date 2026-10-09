--!strict

export type Result = "Active" | "Won" | "Lost" | "Left"

local RoundStateMachine = {}
RoundStateMachine.__index = RoundStateMachine

function RoundStateMachine.new(minPlayers: number, maxPlayers: number)
	assert(minPlayers >= 1 and maxPlayers >= minPlayers, "invalid player limits")
	return setmetatable({
		_minPlayers = minPlayers,
		_maxPlayers = maxPlayers,
		_state = "Waiting",
		_ready = {} :: { [number]: boolean },
		_results = {} :: { [number]: Result },
		_startedCount = 0,
		_winnerPlayerId = nil :: number?,
	}, RoundStateMachine)
end

function RoundStateMachine:SetReady(playerId: number, isReady: boolean): boolean
	if self._state == "Running" or self._state == "Completed" then return false end
	self._ready[playerId] = if isReady then true else nil
	local count = 0
	for _ in self._ready do count += 1 end
	self._state = if count >= self._minPlayers then "Countdown" else "Waiting"
	return true
end

function RoundStateMachine:Start(minimumPlayersOverride: number?): boolean
	local minimumPlayers = minimumPlayersOverride or self._minPlayers
	if self._state ~= "Countdown" and not (self._state == "Waiting" and minimumPlayersOverride ~= nil) then return false end
	local count = 0
	for playerId in self._ready do
		if count >= self._maxPlayers then break end
		self._results[playerId] = "Active"
		count += 1
	end
	if count < minimumPlayers then self._state = "Waiting" return false end
	self._startedCount = count
	self._state = "Running"
	return true
end

function RoundStateMachine:Finish(playerId: number): boolean
	if self._state ~= "Running" or self._results[playerId] ~= "Active" or self._winnerPlayerId ~= nil then return false end
	self._winnerPlayerId = playerId
	for participantId, result in self._results do
		if result == "Active" then
			self._results[participantId] = if participantId == playerId then "Won" else "Lost"
		end
	end
	self._state = "Completed"
	return true
end

function RoundStateMachine:Eliminate(playerId: number): boolean
	if self._state ~= "Running" or self._results[playerId] ~= "Active" then return false end
	self._results[playerId] = "Lost"
	return true
end

function RoundStateMachine:GetSnapshot()
	local readyCount, activeCount = 0, 0
	for _ in self._ready do readyCount += 1 end
	local results = {}
	for playerId, result in self._results do
		results[playerId] = result
		if result == "Active" or result == "Won" then activeCount += 1 end
	end
	return {
		state = self._state,
		readyCount = readyCount,
		startedCount = self._startedCount,
		activeCount = activeCount,
		winnerPlayerId = self._winnerPlayerId,
		results = results,
	}
end

return RoundStateMachine
