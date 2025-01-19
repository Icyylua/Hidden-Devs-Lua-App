local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DonationStore = DataStoreService:GetDataStore("DonationData") -- get the donation data store
local SpinCountUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SpinCountUpdate") -- get the spin count update remote
local UpdateLeaderboardEvent = ReplicatedStorage.Remotes:WaitForChild("UpdateLeaderboard") -- get the leaderboard update event

local PlayerData
while not _G.PlayerData do
	task.wait() -- wait until player data is available
end
PlayerData = _G.PlayerData

local donationProducts = {
	{amount = 30, id = 2703106801}, -- replace with your own dev product ids
	{amount = 60, id = 2703128746},
	{amount = 120, id = 2703106801},
	{amount = 300, id = 2703106801},
	{amount = 600, id = 2703106801}
}

local donations = {}

local function loadDonations()
	local success, data = pcall(function()
		return DonationStore:GetAsync("Donations") or {} -- attempt to load donations from the datastore
	end)
	if success then
		donations = data -- store loaded donations
		UpdateLeaderboardEvent:FireAllClients(donations) -- update all clients with the latest donations
	end
end

local function saveDonations()
	pcall(function()
		DonationStore:SetAsync("Donations", donations) -- save donations to the datastore
	end)
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId) -- get the player who made the purchase
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end -- exit if player not found

	for _, product in ipairs(donationProducts) do
		if receiptInfo.ProductId == product.id then -- check if the purchased product matches a donation product
			donations[tostring(player.UserId)] = (donations[tostring(player.UserId)] or 0) + product.amount -- update donations for the player
			local spinsToAdd = math.floor(product.amount / 30) -- calculate spins to add based on donation amount

			if _G.addSpins then
				local success = _G.addSpins(player, spinsToAdd) -- add spins to the player
				if success then
					UpdateLeaderboardEvent:FireAllClients(donations) -- update all clients with the latest donations
					saveDonations() -- save donations to the datastore
					return Enum.ProductPurchaseDecision.PurchaseGranted -- grant the purchase
				else
					return Enum.ProductPurchaseDecision.NotProcessedYet -- return if adding spins failed
				end
			else
				return Enum.ProductPurchaseDecision.NotProcessedYet -- return if addSpins function is not available
			end
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet -- return if no matching product found
end

loadDonations() -- load existing donations when the script runs

task.spawn(function()
	while true do
		task.wait(30) -- wait for 30 seconds
		UpdateLeaderboardEvent:FireAllClients(donations) -- periodically update all clients with the latest donations
	end
end)
