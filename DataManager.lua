local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataManager = {}
local SpinDataStore = DataStoreService:GetDataStore("SpinnerData_v1") -- get the data store for spinner data
local PlayerData = {} -- table to hold player data
local dataChanged = {} -- table to track which players have changed data

local DefaultData = {
	spinsLeft = 0, -- default spins left
	lastSpin = 0, -- default last spin time
	totalSpins = 0, -- default total spins
	inventory = {}, -- default inventory
	extraSpins = 0 -- default extra spins
}

local SAVE_COOLDOWN = 300 -- cooldown time for saving data
local BATCH_SIZE = 3 -- number of players to save in one batch
local lastBatchTime = 0 -- track the last time data was saved

function DataManager:GetData(player)
	return PlayerData[player.UserId] -- return the data for the specified player
end

function DataManager:LoadData(player)
	if not player then return end -- exit if player is not provided
	if PlayerData[player.UserId] then return PlayerData[player.UserId] end -- return existing data if available

	local success, data = pcall(function()
		return SpinDataStore:GetAsync(player.UserId) -- attempt to load player data from the data store
	end)

	if success and data then
		PlayerData[player.UserId] = data -- store loaded data
	else
		PlayerData[player.UserId] = table.clone(DefaultData) -- use default data if loading fails
	end

	return PlayerData[player.UserId] -- return the player's data
end

local function processBatchSave()
	while true do
		task.wait(SAVE_COOLDOWN) -- wait for the save cooldown

		local currentTime = os.time() -- get the current time
		if currentTime - lastBatchTime < SAVE_COOLDOWN then
			continue -- skip if cooldown has not elapsed
		end

		local savedCount = 0 -- count of saved players
		for userId, _ in pairs(dataChanged) do
			if savedCount >= BATCH_SIZE then break end -- stop if batch size is reached

			local player = Players:GetPlayerByUserId(userId) -- get the player by user id
			if player and PlayerData[userId] then
				local success = pcall(function()
					SpinDataStore:SetAsync(userId, PlayerData[userId]) -- save player data to the data store
				end)

				if success then
					dataChanged[userId] = nil -- clear the changed flag for this player
					savedCount = savedCount + 1 -- increment saved count
				end
			else
				dataChanged[userId] = nil -- clear the changed flag if player is not found
			end
		end

		if savedCount > 0 then
			lastBatchTime = currentTime -- update the last batch save time
		end
	end
end

function DataManager:SaveData(player)
	if not player or not PlayerData[player.UserId] then return end -- exit if player data is not available
	dataChanged[player.UserId] = true -- mark this player's data as changed
end

function DataManager:AddExtraSpins(player, amount)
	local data = PlayerData[player.UserId] -- get the player's data
	if not data then return end -- exit if data is not found

	data.extraSpins = data.extraSpins + amount -- add extra spins
	dataChanged[player.UserId] = true -- mark data as changed
end

function DataManager:UseExtraSpin(player)
	local data = PlayerData[player.UserId] -- get the player's data
	if not data or data.extraSpins <= 0 then return false end -- exit if no extra spins available

	data.extraSpins = data.extraSpins - 1 -- decrement extra spins
	data.totalSpins = data.totalSpins + 1 -- increment total spins
	dataChanged[player.UserId] = true -- mark data as changed
	return true -- return success
end

task.spawn(processBatchSave) -- start the batch save process

Players.PlayerAdded:Connect(function(player)
	DataManager:LoadData(player) -- load data when player joins
end)

Players.PlayerRemoving:Connect(function(player)
	if PlayerData[player.UserId] and dataChanged[player.UserId] then
		pcall(function()
			SpinDataStore:SetAsync(player.UserId, PlayerData[player.UserId]) -- save data when player leaves
		end)
	end

	PlayerData[player.UserId] = nil -- clear player data
	dataChanged[player.UserId] = nil -- clear changed flag
end)

game:BindToClose(function()
	for userId, _ in pairs(dataChanged) do
		local player = Players:GetPlayerByUserId(userId) -- get the player by user id
		if player and PlayerData[userId] then
			pcall(function()
				SpinDataStore:SetAsync(userId, PlayerData[userId]) -- save data for players on game close
			end)
		end
	end
end)

return DataManager -- return the DataManager module
