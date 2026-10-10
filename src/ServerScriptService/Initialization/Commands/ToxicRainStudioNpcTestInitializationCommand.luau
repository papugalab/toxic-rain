--!strict
local Command = {}
Command.__index = Command
function Command.new(runtime: any)
	return setmetatable({ Id = "ToxicRainStudioNpcTest", DependsOn = { "ToxicRainShelterCombat" }, _runtime = runtime }, Command)
end
function Command:Initialize(_context: any) self._runtime:Initialize() end
return Command
