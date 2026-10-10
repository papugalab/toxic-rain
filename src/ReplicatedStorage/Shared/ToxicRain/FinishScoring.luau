--!strict

local FinishScoring = {}
FinishScoring.SpeedBudget = 100

-- One lost speed point per complete second; health is already integer HP.
function FinishScoring.Calculate(seconds: number, health: number)
	assert(seconds == seconds and seconds >= 0 and seconds < math.huge, "invalid finish time")
	assert(health == health and health >= 0 and health <= 100, "invalid finish health")
	local healthPoints = math.round(health)
	local speedPoints = math.max(0, FinishScoring.SpeedBudget - math.floor(seconds))
	return { time = seconds, health = healthPoints, speed = speedPoints, score = healthPoints + speedPoints }
end

function FinishScoring.Before(first: any, second: any): boolean
	if first.score ~= second.score then return first.score > second.score end
	if first.time ~= second.time then return first.time < second.time end
	return first.playerId < second.playerId
end

return table.freeze(FinishScoring)
