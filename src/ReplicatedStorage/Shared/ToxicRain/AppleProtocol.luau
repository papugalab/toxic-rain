--!strict

local Protocol = {
	ConsumeIntent = "ToxicRain.Apple.ConsumeV1",
}

function Protocol.ValidateConsumeIntent(payload: any): (boolean, any?, string?)
	if typeof(payload) ~= "table" or next(payload) ~= nil then
		return false, nil, "InvalidAppleIntent"
	end
	return true, {}, nil
end

return table.freeze(Protocol)
