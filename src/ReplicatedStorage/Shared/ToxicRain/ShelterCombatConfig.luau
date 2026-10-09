--!strict

local Config = {
	GripCapacities = { 3, 2, 1, 1, 0 },
	GripDurationSeconds = 10,
	GripReclaimLockSeconds = 2,
	GripActivationDistanceStuds = 7,
	PushRangeStuds = 10,
	PushFacingMinimumDot = 0.25,
	PushCooldownSeconds = 1.25,
	PushHorizontalSpeed = 38,
	PushVerticalSpeed = 10,
	PushVictimImmunitySeconds = 0.8,
	SoloDummyResetSeconds = 2,
}

function Config.IsCombatWeather(weather: any): boolean
	return weather == "Warning" or weather == "ToxicRain"
end

-- A grip spans the current warning/rain cycle and releases only when that rain ends.
function Config.ShouldReleaseAllGrips(roundState: any, weather: any): boolean
	return roundState ~= "Running" or weather == "Clear"
end

function Config.IsDirectionValid(direction: any): boolean
	if typeof(direction) ~= "Vector3" then return false end
	return direction.X == direction.X
		and direction.Y == direction.Y
		and direction.Z == direction.Z
		and math.abs(direction.X) < math.huge
		and math.abs(direction.Y) < math.huge
		and math.abs(direction.Z) < math.huge
		and direction.Magnitude > 0.1
end

function Config.IsWithinPushRange(origin: Vector3, target: Vector3): boolean
	local offset = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	return offset.Magnitude >= 0.01 and offset.Magnitude <= Config.PushRangeStuds
end

function Config.IsWithinPushArc(origin: Vector3, target: Vector3, direction: Vector3): boolean
	local offset = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	local facing = Vector3.new(direction.X, 0, direction.Z)
	if offset.Magnitude < 0.01 or offset.Magnitude > Config.PushRangeStuds or facing.Magnitude < 0.01 then
		return false
	end
	return offset.Unit:Dot(facing.Unit) >= Config.PushFacingMinimumDot
end

return table.freeze(Config)
