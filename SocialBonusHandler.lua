local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GroupId = 35299332 -- define the group id for bonuses
local CreatorId = 3562164023 -- define the creator id for following bonuses

local LuckUpdate = ReplicatedStorage.Remotes:WaitForChild("LuckUpdate") -- get the remote for luck updates
local CheckFavorite = ReplicatedStorage.Functions:WaitForChild("CheckFavorite") -- get the function to check if the player has favorited the game
local GetGamepassLuck = ReplicatedStorage.Functions:WaitForChild("GetGamepassLuck") -- get the function to check gamepass luck

local playerLuck = {} -- table to store luck values for players
local playerBonuses = {} -- table to store bonus statuses for players

local function setupBoostIcons(player)
	local gui = player.PlayerGui:WaitForChild("PremiumGui") -- get the player's GUI

	local premiumIcon = gui.BoostIcons.PremiumIcon -- reference to the premium icon
	local premiumTooltip = premiumIcon.Tooltip -- reference to the tooltip for the premium icon

	if player.MembershipType ~= Enum.MembershipType.Premium then
		premiumIcon.ImageTransparency = 0.5 -- set transparency if not a premium member
	end

	premiumTooltip.Text = player.MembershipType == Enum.MembershipType.Premium and 
		"Spin cooldown reduced: 60s → 30s" or 
		"Must have Roblox Premium to unlock" -- set tooltip text based on membership type

	premiumIcon.MouseEnter:Connect(function()
		premiumTooltip.Visible = true -- show tooltip on mouse enter
	end)
	premiumIcon.MouseLeave:Connect(function()
		premiumTooltip.Visible = false -- hide tooltip on mouse leave
	end)

	local groupIcon = gui.BoostIcons.GroupIcon -- reference to the group icon
	local groupTooltip = groupIcon.Tooltip -- reference to the tooltip for the group icon
	local isInGroup = player:IsInGroup(GroupId) -- check if the player is in the group
	groupIcon.ImageTransparency = isInGroup and 0 or 0.5 -- set transparency based on group membership
	groupTooltip.Text = isInGroup and 
		"In Group: +1x Luck Boost Active!" or 
		"Join our group for +1x Luck Boost!" -- set tooltip text based on group status

	groupIcon.MouseEnter:Connect(function()
		groupTooltip.Visible = true -- show tooltip on mouse enter
	end)
	groupIcon.MouseLeave:Connect(function()
		groupTooltip.Visible = false -- hide tooltip on mouse leave
	end)

	local followIcon = gui.BoostIcons.FollowIcon -- reference to the follow icon
	local followTooltip = followIcon.Tooltip -- reference to the tooltip for the follow icon
	local success, isFollowing = pcall(function()
		return player:IsFollowing(CreatorId) -- check if the player is following the creator
	end)
	followIcon.ImageTransparency = (success and isFollowing) and 0 or 0.5 -- set transparency based on following status
	followTooltip.Text = (success and isFollowing) and 
		"Following: +1x Luck Boost Active!" or 
		"Follow the owner for +1x Luck Boost!" -- set tooltip text based on following status

	followIcon.MouseEnter:Connect(function()
		followTooltip.Visible = true -- show tooltip on mouse enter
	end)
	followIcon.MouseLeave:Connect(function()
		followTooltip.Visible = false -- hide tooltip on mouse leave
	end)

	local favoriteIcon = gui.BoostIcons.FavoriteIcon -- reference to the favorite icon
	local favoriteTooltip = favoriteIcon.Tooltip -- reference to the tooltip for the favorite icon
	local success2, isFavorited = pcall(function()
		return CheckFavorite:InvokeClient(player) -- check if the player has favorited the game
	end)
	favoriteIcon.ImageTransparency = (success2 and isFavorited) and 0 or 0.5 -- set transparency based on favorite status
	favoriteTooltip.Text = (success2 and isFavorited) and 
		"Favorited: +1x Luck Boost Active!" or 
		"Favorite the game for +1x Luck Boost!" -- set tooltip text based on favorite status

	favoriteIcon.MouseEnter:Connect(function()
		favoriteTooltip.Visible = true -- show tooltip on mouse enter
	end)
	favoriteIcon.MouseLeave:Connect(function()
		favoriteTooltip.Visible = false -- hide tooltip on mouse leave
	end)

	local luckX4Icon = gui.BoostIcons.Luckx4Icon -- reference to the 4x luck icon
	local luckX4Tooltip = luckX4Icon.Tooltip -- reference to the tooltip for the 4x luck icon
	local success3, gamepassLuck = pcall(function()
		return GetGamepassLuck:Invoke(player) -- get the gamepass luck for the player
	end)

	luckX4Icon.ImageTransparency = (success3 and gamepassLuck > 1) and 0 or 0.5 -- set transparency based on gamepass luck
	luckX4Tooltip.Text = (success3 and gamepassLuck > 1) and 
		"4x Luck Boost Applied!" or 
		"Purchase 4x Luck gamepass to unlock!" -- set tooltip text based on gamepass luck

	luckX4Icon.MouseEnter:Connect(function()
		luckX4Tooltip.Visible = true -- show tooltip on mouse enter
	end)
	luckX4Icon.MouseLeave:Connect(function()
		luckX4Tooltip.Visible = false -- hide tooltip on mouse leave
	end)
end

local function calculateTotalLuck(bonuses, player)
	local total = 1 -- start with a base luck of 1
	if bonuses.group then total = total + 1 end -- add luck for group membership
	if bonuses.following then total = total + 1 end -- add luck for following the creator
	if bonuses.favorite then total = total + 1 end -- add luck for favoriting the game

	local success, gamepassLuck = pcall(function()
		return GetGamepassLuck:Invoke(player) -- get the gamepass luck for the player
	end)

	if success and gamepassLuck > 1 then
		total = total + 4 -- add 4x luck if gamepass is active
	end

	return total -- return the total luck value
end

local function updatePlayerLuck(player)
	if not playerBonuses[player.UserId] then
		playerBonuses[player.UserId] = {
			group = false, -- initialize group bonus
			following = false, -- initialize following bonus
			favorite = false -- initialize favorite bonus
		}
	end

	local bonuses = playerBonuses[player.UserId] -- get the player's bonuses
	local changed = false -- track if any bonuses have changed

	local isInGroup = player:IsInGroup(GroupId) -- check if the player is in the group
	if bonuses.group ~= isInGroup then
		bonuses.group = isInGroup -- update group bonus
		changed = true -- mark as changed
	end

	local success, isFollowing = pcall(function()
		return player:IsFollowing(CreatorId) -- check if the player is following the creator
	end)
	if bonuses.following ~= (success and isFollowing) then
		bonuses.following = (success and isFollowing) -- update following bonus
		changed = true -- mark as changed
	end

	local success2, isFavorited = pcall(function()
		return CheckFavorite:InvokeClient(player) -- check if the player has favorited the game
	end)
	if bonuses.favorite ~= (success2 and isFavorited) then
		bonuses.favorite = (success2 and isFavorited) -- update favorite bonus
		changed = true -- mark as changed
	end

	if changed then
		local totalLuck = calculateTotalLuck(bonuses, player) -- calculate total luck
		playerLuck[player.UserId] = totalLuck -- update player's luck
		LuckUpdate:FireClient(player, totalLuck, math.huge) -- send updated luck to the client
		setupBoostIcons(player) -- update the boost icons in the GUI
	end
end

local function startChecking(player)
	task.spawn(function()
		while player and player.Parent do
			updatePlayerLuck(player) -- update player luck periodically
			task.wait(30) -- wait for 30 seconds before checking again
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	task.wait(1) -- wait for the player to fully load
	playerLuck[player.UserId] = 1 -- initialize player's luck
	playerBonuses[player.UserId] = {
		group = false, -- initialize group bonus
		following = false, -- initialize following bonus
		favorite = false -- initialize favorite bonus
	}
	setupBoostIcons(player) -- set up boost icons for the player
	updatePlayerLuck(player) -- update player luck on join
	startChecking(player) -- start checking for updates
end)

Players.PlayerRemoving:Connect(function(player)
	playerLuck[player.UserId] = nil -- clear player's luck
	playerBonuses[player.UserId] = nil -- clear player's bonuses
end)
