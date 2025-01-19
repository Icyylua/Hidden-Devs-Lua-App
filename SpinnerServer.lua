local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local SpinnerConfig = require(ReplicatedStorage:WaitForChild("SpinnerConfig"))
local AUTO_SPIN_GAMEPASS_ID = 1034246327
local PREMIUM_COOLDOWN = 30
local NORMAL_COOLDOWN = 60
local SAVE_COOLDOWN = 600
local FORCE_SAVE_COOLDOWN = 300
local lastSaveTimes = {}
local pendingSaves = {}
local isSaving = false

local SpinCountUpdate = ReplicatedStorage.Remotes:WaitForChild("SpinCountUpdate")
local SpinRemote = ReplicatedStorage.Remotes:WaitForChild("RequestSpin")
local SpinResult = ReplicatedStorage.Remotes:WaitForChild("SpinResult")
local TimerSync = ReplicatedStorage.Remotes:WaitForChild("TimerSync")
local LuckUpdate = ReplicatedStorage.Remotes:WaitForChild("LuckUpdate")
local GetCurrentOdds = ReplicatedStorage.Functions:WaitForChild("GetCurrentOdds")

local PlayerData = {}
_G.PlayerData = PlayerData

local SpinnerData = DataStoreService:GetDataStore("SpinnerData_v2")
local playerLuck = {}
local luckTimers = {}

local addSpins = ReplicatedStorage.Functions.AddSpins

local DefaultData = {
	spinsLeft = 0,
	lastSpin = 0,
	totalSpins = 0,
	inventory = {},
	extraSpins = 0,
	luckMultiplier = 1,
	luckEndTime = 0
}

local function calculateCurrentOdds(player)
	if not player or not playerLuck[player.UserId] then return end -- check if player exists and has luck data
	local luckMultiplier = playerLuck[player.UserId]
	local baseChances = {75.2593, 5.3697, 2.3488, 12.1967, 3.4267, 1.3987, 0.0001}
	local adjustedChances = table.create(#baseChances) -- create a table for adjusted chances
	local totalBoost = 0

	for i = 1, #baseChances do
		adjustedChances[i] = baseChances[i] -- initialize adjusted chances with base values
	end

	for i = 2, #baseChances - 1 do
		local boostedChance = baseChances[i] * luckMultiplier -- apply luck multiplier to chances
		totalBoost = totalBoost + (boostedChance - baseChances[i]) -- calculate total boost
		adjustedChances[i] = boostedChance -- update adjusted chances
	end

	adjustedChances[1] = math.max(0, baseChances[1] - totalBoost) -- ensure the first chance doesn't go negative
	return adjustedChances
end

GetCurrentOdds.OnServerInvoke = calculateCurrentOdds -- bind the odds calculation to the remote function

local function savePlayerData(player, force)
	if not player or not PlayerData[player.UserId] then return end -- exit if player or data is missing
	if isSaving then 
		pendingSaves[player.UserId] = true -- if a save is in progress, queue this save
		return 
	end

	local currentTime = os.time()
	local lastSaveTime = lastSaveTimes[player.UserId] or 0

	if not force and currentTime - lastSaveTime < SAVE_COOLDOWN then
		pendingSaves[player.UserId] = true -- queue save if cooldown is active
		return
	end

	if force and currentTime - lastSaveTime < FORCE_SAVE_COOLDOWN then
		pendingSaves[player.UserId] = true -- queue forced save if cooldown is active
		return
	end

	isSaving = true -- mark that we're starting a save operation
	local success, err = pcall(function()
		local dataToSave = {
			spinsLeft = PlayerData[player.UserId].spinsLeft,
			lastSpinTime = PlayerData[player.UserId].lastSpinTime,
			totalSpins = PlayerData[player.UserId].totalSpins,
			inventory = PlayerData[player.UserId].inventory,
			luckMultiplier = playerLuck[player.UserId] or 1,
			luckEndTime = PlayerData[player.UserId].luckEndTime or 0
		}
		SpinnerData:SetAsync(player.UserId, dataToSave) -- save player data to the datastore
	end)

	if success then
		lastSaveTimes[player.UserId] = currentTime -- update the last save time
		pendingSaves[player.UserId] = nil -- clear the pending save flag
	end
	isSaving = false -- mark that the save operation is complete
end

local function updatePlayerLuck(player, multiplier, duration)
	local userId = player.UserId
	local currentTime = os.time()

	if luckTimers[userId] then
		luckTimers[userId]:Disconnect() -- disconnect any existing luck timer
		luckTimers[userId] = nil
	end

	playerLuck[userId] = (playerLuck[userId] or 1) + multiplier -- update player's luck

	if duration and duration ~= math.huge then
		PlayerData[userId].luckEndTime = currentTime + duration -- set the end time for luck
		LuckUpdate:FireClient(player, playerLuck[userId], duration) -- notify client of luck update

		local timeLeft = duration
		luckTimers[userId] = task.spawn(function()
			while timeLeft > 0 and player.Parent do
				timeLeft = timeLeft - 1 -- decrement time left
				LuckUpdate:FireClient(player, playerLuck[userId], timeLeft) -- update client with time left
				if timeLeft <= 0 then
					playerLuck[userId] = math.max(1, playerLuck[userId] - multiplier) -- reset luck after duration
					PlayerData[userId].luckEndTime = 0
					LuckUpdate:FireClient(player, playerLuck[userId]) -- notify client of luck reset
					break
				end
				task.wait(1) -- wait for 1 second before next update
			end
			luckTimers[userId] = nil -- clear the timer reference
		end)
	else
		LuckUpdate:FireClient(player, playerLuck[userId]) -- notify client of current luck if no duration
	end
end

local function startSpinTimer(player)
	if not player or not PlayerData[player.UserId] then return end -- exit if player or data is missing

	task.spawn(function()
		while PlayerData[player.UserId] do
			local data = PlayerData[player.UserId]
			local cooldown = player.MembershipType == Enum.MembershipType.Premium and PREMIUM_COOLDOWN or NORMAL_COOLDOWN
			local timeSinceLastSpin = os.time() - data.lastSpinTime

			if timeSinceLastSpin >= cooldown then
				data.spinsLeft = data.spinsLeft + 1 -- increment spins left
				data.lastSpinTime = os.time() -- update last spin time
				SpinCountUpdate:FireClient(player, data.spinsLeft) -- notify client of spins left
				TimerSync:FireClient(player, data.lastSpinTime) -- sync timer with client
				savePlayerData(player) -- save player data after spin
			end

			task.wait(1) -- wait for 1 second before checking again
		end
	end)
end

local function loadPlayerData(player)
	if not player then return end -- exit if player is missing

	local success, data = pcall(function()
		return SpinnerData:GetAsync(player.UserId) -- attempt to load player data from datastore
	end)

	if success and data then
		PlayerData[player.UserId] = {
			spinsLeft = data.spinsLeft,
			lastSpinTime = os.time(),
			totalSpins = data.totalSpins or 0,
			inventory = data.inventory or {},
			luckEndTime = data.luckEndTime or 0
		}

		playerLuck[player.UserId] = 1 -- initialize luck for the player

		if data.luckEndTime and data.luckEndTime > os.time() then
			local timeLeft = data.luckEndTime - os.time() -- calculate remaining luck time
			updatePlayerLuck(player, data.luckMultiplier - 1, timeLeft) -- update luck with remaining time
		end

	else
		PlayerData[player.UserId] = table.clone(DefaultData) -- set default data if no data found
		PlayerData[player.UserId].lastSpinTime = os.time() -- set last spin time to now
		playerLuck[player.UserId] = 1 -- initialize luck for new players
	end

	SpinCountUpdate:FireClient(player, PlayerData[player.UserId].spinsLeft) -- notify client of spins left
	TimerSync:FireClient(player, PlayerData[player.UserId].lastSpinTime) -- sync timer with client
	startSpinTimer(player) -- start the spin timer for the player
end

local function calculateSpin(player)
	local luckMultiplier = playerLuck[player.UserId] or 1 -- get player's luck multiplier
	local random = math.random(1, 1000000) -- generate a random number for spin outcome

	if random == 1 then
		return SpinnerConfig.items[7] -- rare case for a special item
	end

	random = math.random(1, 100000) / 1000 -- scale down the random number
	local currentSum = 0
	local baseChances = {75.2593, 5.3697, 2.3488, 12.1967, 3.4267, 1.3987}
	local adjustedChances = {}
	local totalBoost = 0

	for i = 2, #baseChances do
		adjustedChances[i] = baseChances[i] * luckMultiplier -- adjust chances based on luck
		totalBoost = totalBoost + (adjustedChances[i] - baseChances[i]) -- calculate total boost
	end

	adjustedChances[1] = math.max(0, baseChances[1] - totalBoost) -- ensure first chance doesn't go negative

	for i, chance in ipairs(adjustedChances) do
		currentSum = currentSum + chance -- accumulate chances
		if random <= currentSum then
			return SpinnerConfig.items[i] -- return the item based on the random number
		end
	end

	return SpinnerConfig.items[1] -- fallback to the first item
end

local function handleSpin(player, instant)
	if not player or not PlayerData[player.UserId] then return end -- exit if player or data is missing

	local data = PlayerData[player.UserId]
	if data.spinsLeft <= 0 then
		SpinResult:FireClient(player, nil, instant) -- no spins left, notify client
		return
	end

	local result = calculateSpin(player) -- calculate the spin result
	data.spinsLeft = data.spinsLeft - 1 -- decrement spins left
	data.totalSpins = data.totalSpins + 1 -- increment total spins

	SpinCountUpdate:FireClient(player, data.spinsLeft) -- notify client of spins left
	SpinResult:FireClient(player, result, instant) -- send spin result to client
	pendingSaves[player.UserId] = true -- mark this player for saving
end

Players.PlayerAdded:Connect(function(player)
	task.wait(1) -- wait a moment before loading data
	loadPlayerData(player) -- load player data when they join
end)

_G.addSpins = function(player, amount)
	if not player then return end -- exit if player is missing

	if not PlayerData[player.UserId] then
		loadPlayerData(player) -- load data if not already loaded
		task.wait(0.1) -- wait a moment for data to load
	end

	if PlayerData[player.UserId] then
		PlayerData[player.UserId].spinsLeft = PlayerData[player.UserId].spinsLeft + amount -- add spins
		SpinCountUpdate:FireClient(player, PlayerData[player.UserId].spinsLeft) -- notify client of new spins left
		savePlayerData(player, true) -- save player data immediately
		return true
	else
		return false -- return false if player data is still missing
	end
end

Players.PlayerRemoving:Connect(function(player)
	if PlayerData[player.UserId] then
		savePlayerData(player, true) -- save data when player leaves
	end

	local userId = player.UserId
	PlayerData[userId] = nil -- clear player data
	pendingSaves[userId] = nil -- clear pending saves
	lastSaveTimes[userId] = nil -- clear last save time
	if luckTimers[userId] then
		task.cancel(luckTimers[userId]) -- cancel any active luck timers
	end
	luckTimers[userId] = nil -- clear luck timer reference
	playerLuck[userId] = nil -- clear luck data
end)

SpinRemote.OnServerEvent:Connect(function(player, instant)
	handleSpin(player, instant) -- handle spin request from client
end)

ReplicatedStorage.Remotes.RewardEvent.OnServerEvent:Connect(function(player, item)
	if not player or not item then return end -- exit if player or item is missing

	if item.reward == "spin1" then
		PlayerData[player.UserId].spinsLeft += 1 -- add 1 spin
	elseif item.reward == "spin3" then
		PlayerData[player.UserId].spinsLeft += 3 -- add 3 spins
	elseif item.reward == "spin10" then
		PlayerData[player.UserId].spinsLeft += 10 -- add 10 spins
	elseif item.reward == "luck2x" then
		updatePlayerLuck(player, 2, 900) -- apply 2x luck for 15 minutes
	elseif item.reward == "luck3x" then
		updatePlayerLuck(player, 3, 600) -- apply 3x luck for 10 minutes
	elseif item.reward == "ugc" then
		if SpinnerConfig.ugcItems[1] and SpinnerConfig.ugcItems[1].itemId then
			pcall(function()
				MarketplaceService:PromptPurchase(player, SpinnerConfig.ugcItems[1].itemId) -- prompt purchase for UGC item
			end)
		end
	end

	if PlayerData[player.UserId] then
		SpinCountUpdate:FireClient(player, PlayerData[player.UserId].spinsLeft) -- notify client of spins left
		savePlayerData(player) -- save player data after reward
	end
end)

task.spawn(function()
	while true do
		task.wait(300) -- wait 5 minutes
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player) -- save data for all players every 5 minutes
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player, true) -- save data for all players on game close
	end
end)
