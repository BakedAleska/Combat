local ServerScriptService = game:GetService("ServerScriptService")
local ProfileService = require(ServerScriptService.Server.Services.ProfileService)

return function(Context, Target)
	ProfileService.Wipe(Target)
end
