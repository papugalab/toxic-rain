--!strict
local Command={} Command.__index=Command
function Command.new(controller:any) return setmetatable({Id="ToxicRainHud",DependsOn={"UI"},_controller=controller},Command) end
function Command:Initialize(_context:any) self._controller:Initialize() end
return Command
