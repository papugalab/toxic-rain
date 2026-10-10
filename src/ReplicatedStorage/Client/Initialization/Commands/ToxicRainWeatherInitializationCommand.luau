--!strict
local Command={} Command.__index=Command
function Command.new(controller:any) return setmetatable({Id="ToxicRainWeather",DependsOn={"UI","OrdinarySound","Players"},_controller=controller},Command) end
function Command:Initialize(_context:any) self._controller:Initialize() end
return Command
