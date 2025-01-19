local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpdateLeaderboardEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpdateLeaderboard") -- get the leaderboard update event
local player = Players.LocalPlayer -- get the local player
local leaderboardGui = script.Parent -- reference to the leaderboard GUI
local mainFrame = leaderboardGui:WaitForChild("MainFrame") -- wait for the main frame to load
local entriesFrame = mainFrame:WaitForChild("EntriesFrame") -- wait for the entries frame to load
local entryTemplate = script:WaitForChild("EntryTemplate") -- wait for the entry template to load

local function updateLeaderboard(donationData)
	-- clear existing entries in the entries frame
	for _, child in ipairs(entriesFrame:GetChildren()) do
		if child.Name:match("^Entry_") then
			child:Destroy() -- destroy any existing entry
		end
	end

	local sortedDonors = {}
	-- collect donors with positive donation amounts
	for userId, amount in pairs(donationData) do
		if amount > 0 then
			table.insert(sortedDonors, {userId = tonumber(userId), amount = amount}) -- insert donor data
		end
	end
	-- sort donors by donation amount in descending order
	table.sort(sortedDonors, function(a, b) return a.amount > b.amount end)

	local topColors = {
		[1] = Color3.fromRGB(255, 215, 0), -- gold for 1st place
		[2] = Color3.fromRGB(192, 192, 192), -- silver for 2nd place
		[3] = Color3.fromRGB(205, 127, 50) -- bronze for 3rd place
	}

	local placeText = {
		[1] = "1st Place", -- text for 1st place
		[2] = "2nd Place", -- text for 2nd place
		[3] = "3rd Place" -- text for 3rd place
	}

	-- create entries for the top donors
	for i, donor in ipairs(sortedDonors) do
		if i > 10 then break end -- limit to top 10 donors
		local entry = entryTemplate:Clone() -- clone the entry template

		entry.Name = "Entry_" .. i -- assign a unique name to the entry
		entry.Position = UDim2.new(0.025, 0, (i-1) * 0.19, 0) -- position the entry in the frame
		entry.Visible = true -- make the entry visible

		entry.PlayerPlace.Text = "#" .. i -- set the place text

		-- set background color based on place
		if topColors[i] then
			entry.BackgroundColor3 = topColors[i]
		else
			entry.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- default color for other places
		end

		-- attempt to get player name and thumbnail
		local success, result = pcall(function()
			local name = Players:GetNameFromUserIdAsync(donor.userId) -- get player name from user id
			local thumbType = Enum.ThumbnailType.HeadShot -- set thumbnail type
			local thumbSize = Enum.ThumbnailSize.Size420x420 -- set thumbnail size
			local content = Players:GetUserThumbnailAsync(donor.userId, thumbType, thumbSize) -- get user thumbnail

			entry.PlayerImage.Image = content -- set player image
			entry.PlayerName.Text = name -- set player name
			entry.DonationAmount.Text = donor.amount .. " R$" -- set donation amount
		end)

		if not success then
			entry.PlayerName.Text = "Unknown" -- fallback if name retrieval fails
			entry.DonationAmount.Text = donor.amount .. " R$" -- set donation amount
		end

		entry.Parent = entriesFrame -- add the entry to the entries frame
	end
end

UpdateLeaderboardEvent.OnClientEvent:Connect(updateLeaderboard) -- connect the update function to the event
