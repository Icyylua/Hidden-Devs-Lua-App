local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CheckFavorite = ReplicatedStorage.Functions:WaitForChild("CheckFavorite") -- get the checkfavorite function from replicatedstorage

CheckFavorite.OnClientInvoke = function() -- define what happens when the CheckFavorite function is invoked
	local success, isFavorited = pcall(function()
		return StarterGui:GetCore("IsGameFavorited") -- check if the game is favorited
	end)
	return success and isFavorited or false -- return the result or false if the check failed
end
