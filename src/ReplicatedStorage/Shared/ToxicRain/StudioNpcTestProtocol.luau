--!strict

local Protocol = { Intent = "ToxicRain.StudioNpcTest.IntentV1" }

function Protocol.ValidateIntent(payload: any): (boolean, any?, string?)
	if typeof(payload) ~= "table" or (payload.Action ~= "Start" and payload.Action ~= "Stop") then
		return false, nil, "InvalidStudioNpcTestIntent"
	end
	for key in payload do
		if key ~= "Action" then return false, nil, "InvalidStudioNpcTestIntent" end
	end
	return true, { Action = payload.Action }, nil
end

return table.freeze(Protocol)
