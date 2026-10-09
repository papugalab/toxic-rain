--!strict

local Protocol = {
	MessageTypes = {
		GripIntent = "ToxicRain.ShelterCombat.GripV1",
		PushIntent = "ToxicRain.ShelterCombat.PushV1",
	},
}

function Protocol.ValidateGripIntent(payload: any): (boolean, any?, string?)
	if typeof(payload) ~= "table" or typeof(payload.SlotId) ~= "string" then
		return false, nil, "InvalidGripIntent"
	end
	if #payload.SlotId < 1 or #payload.SlotId > 48 then
		return false, nil, "InvalidGripSlot"
	end
	return true, { SlotId = payload.SlotId }, nil
end

function Protocol.ValidatePushIntent(payload: any): (boolean, any?, string?)
	if typeof(payload) ~= "table" then return false, nil, "InvalidPushIntent" end
	local direction = payload.Direction
	if typeof(direction) ~= "Vector3" then return false, nil, "InvalidPushDirection" end
	if direction.X ~= direction.X or direction.Y ~= direction.Y or direction.Z ~= direction.Z then
		return false, nil, "InvalidPushDirection"
	end
	if math.abs(direction.X) == math.huge or math.abs(direction.Y) == math.huge or math.abs(direction.Z) == math.huge then
		return false, nil, "InvalidPushDirection"
	end
	if direction.Magnitude < 0.1 then return false, nil, "InvalidPushDirection" end
	return true, { Direction = direction.Unit }, nil
end

return table.freeze(Protocol)
