--!strict

local FinishScoring = require(game.ReplicatedStorage.Shared.ToxicRain.FinishScoring)

export type Result = "Active" | "Finished" | "Won" | "Lost" | "Left"

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
		_finishes = {} :: { [number]: any },
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

function RoundStateMachine:GetStandings()
	local standings = {}
	for _, record in self._finishes do table.insert(standings, table.clone(record)) end
	table.sort(standings, FinishScoring.Before)
	for rank, record in standings do record.rank = rank end
	return standings
end

function RoundStateMachine:_completeIfResolved()
	for _, result in self._results do if result == "Active" then return end end
	self._state = "Completed"
	local first = self:GetStandings()[1]
	if first then
		self._winnerPlayerId = first.playerId
		self._results[first.playerId] = "Won"
	end
end

function RoundStateMachine:Finish(playerId: number, seconds: number?, health: number?): boolean
	if self._state ~= "Running" or self._results[playerId] ~= "Active" then return false end
	local record = FinishScoring.Calculate(seconds or 0, health or 100)
	record.playerId = playerId
	self._finishes[playerId] = record
	self._results[playerId] = "Finished"
	self:_completeIfResolved()
	return true
end

function RoundStateMachine:Eliminate(playerId: number): boolean
	if self._state ~= "Running" or self._results[playerId] ~= "Active" then return false end
	self._results[playerId] = "Lost"
	self:_completeIfResolved()
	return true
end

function RoundStateMachine:Leave(playerId: number): boolean
	if self._state ~= "Running" or self._results[playerId] ~= "Active" then return false end
	self._results[playerId] = "Left"
	self:_completeIfResolved()
	return true
end

function RoundStateMachine:GetSnapshot()
	local readyCount, activeCount = 0, 0
	for _ in self._ready do readyCount += 1 end
	local results = {}
	for playerId, result in self._results do
		results[playerId] = result
		if result == "Active" then activeCount += 1 end
	end
	return {
		state = self._state,
		readyCount = readyCount,
		startedCount = self._startedCount,
		activeCount = activeCount,
		winnerPlayerId = self._winnerPlayerId,
		results = results,
		standings = self:GetStandings(),
	}
end

return RoundStateMachine
