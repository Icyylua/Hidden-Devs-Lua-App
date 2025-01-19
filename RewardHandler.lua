local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local SpinnerConfig = require(ReplicatedStorage:WaitForChild("SpinnerConfig")) -- load spinner configuration
local SpinResult = ReplicatedStorage:WaitForChild("SpinResult") -- get the SpinResult remote event

local RewardHandler = {} -- create a table to hold reward handling functions

local UGC_ITEMS = {
	ugc = 12345 -- define ugc item id for purchases
}

function RewardHandler:GiveReward(player, result)
	if result.reward == "none" then
		return -- exit if no reward is specified
	end

	if result.reward == "ugc" then
		pcall(function()
			MarketplaceService:PromptPurchase(player, UGC_ITEMS.ugc) -- prompt the player to purchase the UGC item
		end)
	end
end

SpinResult.OnServerEvent:Connect(function(player, result)
	RewardHandler:GiveReward(player, result) -- handle the reward when the SpinResult event is fired
end)

return RewardHandler -- return the RewardHandler table for use in other scripts
