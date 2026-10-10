--!strict

local Policy = {}

-- The place owner, verified in the matching Studio session.
Policy.AdminUserId = 4364136284

function Policy.IsAllowed(isStudio: boolean, userId: number, placeId: number, gameId: number): boolean
	return isStudio and userId == Policy.AdminUserId
		and placeId == 79356340322631 and gameId == 10762145525
end

return table.freeze(Policy)
