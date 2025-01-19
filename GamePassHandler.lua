local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LUCK_GAMEPASS_ID = 1034468035 -- define the gamepass id for luck
local LuckUpdate = ReplicatedStorage.Remotes:WaitForChild("LuckUpdate") -- get the remote for luck updates

local GetGamepassLuck = ReplicatedStorage.Functions:WaitForChild("GetGamepassLuck") -- get the function to check gamepass luck

local playerGamepassLuck = {} -- table to store luck values for players with the gamepass

local function checkGamepass(player)
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, LUCK_GAMEPASS_ID) -- check if the player owns the luck gamepass
	end)

	if success and hasPass then
		playerGamepassLuck[player.UserId] = 4 -- set luck to 4 if the player owns the gamepass
		return true -- return true if the player has the gamepass
	else
		playerGamepassLuck[player.UserId] = 1 -- set luck to 1 if the player does not own the gamepass
		return false -- return false if the player does not have the gamepass
	end
end

GetGamepassLuck.OnInvoke = function(player)
	return playerGamepassLuck[player.UserId] or 1 -- return the player's luck or default to 1
end

Players.PlayerAdded:Connect(function(player)
	task.wait(1) -- wait for the player to fully load
	checkGamepass(player) -- check if the player has the gamepass on join
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
	if gamepassId == LUCK_GAMEPASS_ID and wasPurchased then
		checkGamepass(player) -- check the gamepass status if the purchase was successful
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerGamepassLuck[player.UserId] = nil -- clear the player's luck data on leave
end)
