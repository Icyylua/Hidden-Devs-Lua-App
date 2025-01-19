local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer -- get the local player

local SpinnerConfig = require(ReplicatedStorage:WaitForChild("SpinnerConfig")) -- load spinner configuration
local AUTO_SPIN_GAMEPASS_ID = 1034246327 -- define the auto spin gamepass id
local INSTANT_SPIN_GAMEPASS_ID = 1033938716 -- define the instant spin gamepass id
local ITEM_SIZE = 150 -- define the size of each item
local ITEM_SPACING = 15 -- define the spacing between items

local gui = player.PlayerGui:WaitForChild("SpinnerGui") -- get the spinner GUI
local mainFrame = gui.MainFrame -- reference to the main frame of the GUI
local spinnerFrame = mainFrame.SpinnerFrame -- reference to the spinner frame

-- initialize variables for spinner state
local idleConnection = nil
local isSpinning = false
local lastUpdateTime = tick()
local currentProgress = 0
local spinsLeft = 0
local lastSpinTime = 0
local isAutoSpinning = false
local hasGamepass = false
local hasInstantGamepass = false
local oddsVisible = false
local isIdleSpinning = false
local idleSpeed = 4
local isSpinnerOpen = false
local targetProgress = 0
local currentTween = nil

-- get remote events for spinning
local SpinCountUpdate = ReplicatedStorage.Remotes:WaitForChild("SpinCountUpdate")
local SpinRemote = ReplicatedStorage.Remotes:WaitForChild("RequestSpin")
local SpinResult = ReplicatedStorage.Remotes:WaitForChild("SpinResult")
local TimerSync = ReplicatedStorage.Remotes:WaitForChild("TimerSync")

local function playClickSound()
	local clickClone = gui.ClickSound:Clone() -- clone the click sound
	clickClone.Parent = gui
	clickClone:Play() -- play the click sound
	clickClone.Ended:Connect(function()
		clickClone:Destroy() -- destroy the sound instance after it ends
	end)
end

local function playClickForItems()
	local itemWidth = ITEM_SIZE + 5 -- calculate the width of each item
	local pointerX = spinnerFrame.AbsolutePosition.X + (spinnerFrame.AbsoluteSize.X / 2) -- get the center position of the spinner
	local containerX = spinnerFrame.ItemsContainer.AbsolutePosition.X -- get the position of the items container
	local relativeX = pointerX - containerX -- calculate the relative position
	local currentItemIndex = math.floor(relativeX / itemWidth) -- determine the current item index
	local clickClone = gui.ClickSound:Clone() -- clone the click sound
	clickClone.Parent = gui
	clickClone:Play() -- play the click sound
	clickClone.Ended:Connect(function()
		clickClone:Destroy() -- destroy the sound instance after it ends
	end)
	return currentItemIndex -- return the current item index
end

local function createSpinItems()
	for _, item in ipairs(spinnerFrame.ItemsContainer:GetChildren()) do
		item:Destroy() -- clear existing items in the container
	end

	spinnerFrame.ItemsContainer.Size = UDim2.new(0.95, 0, 0.9, 0) -- set the size of the items container
	spinnerFrame.ItemsContainer.Position = UDim2.new(0.025, 0, 0.05, 0) -- set the position of the items container

	local itemCount = 100 -- define the number of items to create
	local items = {}
	local distribution = {75, 5, 2, 12, 3, 2, 1} -- define the distribution of items

	for itemIndex, count in ipairs(distribution) do
		for i = 1, count do
			table.insert(items, SpinnerConfig.items[itemIndex]) -- add items based on distribution
		end
	end

	-- shuffle the items
	for i = #items, 2, -1 do
		local j = math.random(i)
		items[i], items[j] = items[j], items[i]
	end

	-- create item frames for the spinner
	for i, item in ipairs(items) do
		local itemFrame = Instance.new("ImageLabel") -- create a new image label for the item
		itemFrame.Name = "Item_" .. i -- set the name of the item frame
		itemFrame.Size = UDim2.new(0, ITEM_SIZE, 0, ITEM_SIZE) -- set the size of the item frame
		itemFrame.Position = UDim2.new(0, (i-1) * (ITEM_SIZE + ITEM_SPACING), 0.5, -ITEM_SIZE/2) -- position the item frame
		itemFrame.Image = item.image -- set the image of the item frame
		itemFrame.BackgroundTransparency = 1 -- make the background transparent
		itemFrame.Parent = spinnerFrame.ItemsContainer -- add the item frame to the items container
	end
end

local function checkGamepasses()
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, AUTO_SPIN_GAMEPASS_ID) -- check if the player owns the auto spin gamepass
	end)
	hasGamepass = success and result -- store the result of the check

	local instantSuccess, instantResult = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, INSTANT_SPIN_GAMEPASS_ID) -- check if the player owns the instant spin gamepass
	end)
	hasInstantGamepass = instantSuccess and instantResult -- store the result of the check

	return hasGamepass, hasInstantGamepass -- return the results
end

local function updateTimer()
	local cooldown = player.MembershipType == Enum.MembershipType.Premium and 30 or 60 -- set cooldown based on membership type
	local currentTime = os.time() -- get the current time

	if not lastSpinTime then return end -- exit if last spin time is not set

	if currentTween then
		currentTween:Cancel() -- cancel any existing tween
		currentTween = nil
	end

	local elapsed = currentTime - lastSpinTime -- calculate elapsed time since last spin
	local initialProgress = math.min(1, elapsed / cooldown) -- calculate initial progress based on cooldown
	mainFrame.TimerFrame.TimerFill.Size = UDim2.new(initialProgress, 0, 1, 0) -- update the timer fill size

	local remainingTime = cooldown - elapsed -- calculate remaining time
	if remainingTime > 0 then
		currentTween = TweenService:Create(mainFrame.TimerFrame.TimerFill, 
			TweenInfo.new(
				remainingTime, 
				Enum.EasingStyle.Linear, 
				Enum.EasingDirection.InOut
			), 
			{Size = UDim2.new(1, 0, 1, 0)} -- animate the timer fill to full size
		)
		currentTween:Play() -- play the tween
	end

	RunService.RenderStepped:Connect(function()
		local timeLeft = math.ceil(cooldown - (os.time() - lastSpinTime)) -- calculate time left
		if timeLeft > 0 then
			mainFrame.TimerFrame.TimerText.Text = "+1 Spin in " .. timeLeft .. "s" -- update timer text
		end
	end)
end

game:GetService("RunService").Heartbeat:Connect(updateTimer) -- connect the update timer to the heartbeat event

local function hideOdds()
	oddsVisible = false -- set odds visibility to false
	for _, item in ipairs(spinnerFrame.ItemsContainer:GetChildren()) do
		local oddsLabel = item:FindFirstChild("OddsLabel") -- find the odds label
		if oddsLabel then oddsLabel:Destroy() end -- destroy the odds label if it exists
	end
end

local function showOdds()
	if isSpinning then return end -- exit if currently spinning
	oddsVisible = true -- set odds visibility to true
	for _, item in ipairs(spinnerFrame.ItemsContainer:GetChildren()) do
		local existingLabel = item:FindFirstChild("OddsLabel") -- check for existing odds label
		if existingLabel then existingLabel:Destroy() end -- destroy existing label
	end

	local totalChance = 0 -- initialize total chance
	for _, item in ipairs(SpinnerConfig.items) do
		totalChance = totalChance + item.chance -- calculate total chance
	end

	for _, item in ipairs(spinnerFrame.ItemsContainer:GetChildren()) do
		local itemIndex = (tonumber(item.Name:match("%d+")) - 1) % #SpinnerConfig.items + 1 -- get the item index
		local itemConfig = SpinnerConfig.items[itemIndex] -- get the item configuration

		local oddsLabel = Instance.new("TextLabel") -- create a new text label for odds
		oddsLabel.Name = "OddsLabel" -- set the name of the odds label
		oddsLabel.Size = UDim2.new(1, 0, 0.3, 0) -- set the size of the odds label
		oddsLabel.Position = UDim2.new(0, 0, 0.7, 0) -- position the odds label
		oddsLabel.BackgroundColor3 = Color3.new(0, 0, 0) -- set background color
		oddsLabel.BackgroundTransparency = 0.5 -- set background transparency
		oddsLabel.TextColor3 = Color3.new(1, 1, 1) -- set text color
		oddsLabel.TextScaled = true -- scale text to fit
		oddsLabel.Text = string.format("%.4f%%", (itemConfig.chance / totalChance) * 100) -- set odds text
		oddsLabel.Parent = item -- add the odds label to the item
	end
end

local function stopIdleAnimation()
	isIdleSpinning = false -- stop idle spinning
	if idleConnection then
		idleConnection:Disconnect() -- disconnect idle connection
		idleConnection = nil
	end
end

local function createIdleItems()
	for _, item in ipairs(spinnerFrame.ItemsContainer:GetChildren()) do
		item:Destroy() -- clear existing items in the container
	end

	spinnerFrame.ItemsContainer.Size = UDim2.new(0.95, 0, 0.9, 0) -- set the size of the items container
	spinnerFrame.ItemsContainer.Position = UDim2.new(0.025, 0, 0.05, 0) -- set the position of the items container

	local itemCount = 200 -- define the number of idle items
	local items = {}
	local pattern = {}

	for i = 1, #SpinnerConfig.items do
		table.insert(pattern, SpinnerConfig.items[i]) -- create a pattern of items
	end

	for i = 1, itemCount do
		local patternIndex = ((i-1) % #pattern) + 1 -- determine the index in the pattern
		table.insert(items, pattern[patternIndex]) -- add items based on the pattern
	end

	for i, item in ipairs(items) do
		local itemFrame = Instance.new("ImageLabel") -- create a new image label for the item
		itemFrame.Name = "Item_" .. i -- set the name of the item frame
		itemFrame.Size = UDim2.new(0, ITEM_SIZE, 0, ITEM_SIZE) -- set the size of the item frame
		itemFrame.Position = UDim2.new(0, (i-1) * (ITEM_SIZE + ITEM_SPACING), 0.5, -ITEM_SIZE/2) -- position the item frame
		itemFrame.Image = item.image -- set the image of the item frame
		itemFrame.BackgroundTransparency = 1 -- make the background transparent
		itemFrame.Parent = spinnerFrame.ItemsContainer -- add the item frame to the items container
	end
end

local function startIdleAnimation()
	if isSpinning then return end -- exit if currently spinning
	createIdleItems() -- create idle items
	spinnerFrame.ItemsContainer.Position = UDim2.new(0, 0, 0, 0) -- reset position of items container
	local patternWidth = #SpinnerConfig.items * (ITEM_SIZE + ITEM_SPACING) -- calculate the width of the pattern
	local resetPosition = -patternWidth -- set the reset position
	local lastItemIndex = -1 -- initialize last item index

	if idleConnection then idleConnection:Disconnect() end -- disconnect any existing idle connection

	idleConnection = game:GetService("RunService").RenderStepped:Connect(function()
		if not isSpinning and isSpinnerOpen and mainFrame.Visible then
			local currentPosition = spinnerFrame.ItemsContainer.Position.X.Offset -- get current position
			spinnerFrame.ItemsContainer.Position = UDim2.new(0, currentPosition - 1, 0, 0) -- move items left

			local itemWidth = ITEM_SIZE + ITEM_SPACING -- calculate item width
			local currentItemIndex = math.floor(-currentPosition / itemWidth) -- determine current item index

			if currentItemIndex ~= lastItemIndex then
				local clickClone = gui.ClickSound:Clone() -- clone the click sound
				clickClone.Parent = gui
				clickClone:Play() -- play the click sound
				clickClone.Ended:Connect(function()
					clickClone:Destroy() -- destroy the sound instance after it ends
				end)
				lastItemIndex = currentItemIndex -- update last item index
			end

			if currentPosition <= resetPosition then
				spinnerFrame.ItemsContainer.Position = UDim2.new(0, 0, 0, 0) -- reset position if needed
				lastItemIndex = -1 -- reset last item index
			end
		end
	end)
end

local function toggleSpinner()
	isSpinnerOpen = not isSpinnerOpen -- toggle spinner open state
	gui.ClickSound:Play() -- play click sound
	gui.ToggleButton.Text = isSpinnerOpen and "Close Spinner" or "Open Spinner" -- update button text

	local targetPosition = isSpinnerOpen and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(1.5, 0, 0.5, 0) -- set target position

	TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, isSpinnerOpen and Enum.EasingDirection.Out or Enum.EasingDirection.In), {Position = targetPosition}):Play() -- animate the main frame

	if not isSpinnerOpen then
		stopIdleAnimation() -- stop idle animation if closing
	else
		startIdleAnimation() -- start idle animation if opening
	end
end

local function animateSpin(instant)
	if isSpinning then return end -- exit if already spinning
	isSpinning = true -- set spinning state to true
	if oddsVisible then hideOdds() end -- hide odds if visible

	createSpinItems() -- create spin items
	spinnerFrame.ItemsContainer.Position = UDim2.new(0, 0, 0, 0) -- reset position of items container
	local lastItemIndex = -1 -- initialize last item index

	local itemWidth = ITEM_SIZE + ITEM_SPACING -- calculate item width
	local spinnerCenterOffset = (spinnerFrame.AbsoluteSize.X / 2) - (ITEM_SIZE / 2) -- calculate center offset
	local rotations = instant and 3 or 8 -- set number of rotations based on instant spin
	local totalItems = #SpinnerConfig.items -- get total number of items
	local totalDistance = (rotations * totalItems + math.random(1, totalItems)) * itemWidth -- calculate total distance to spin
	local spinDuration = instant and 2 or 7 -- set spin duration based on instant spin

	local spinTween = TweenService:Create(spinnerFrame.ItemsContainer, 
		TweenInfo.new(spinDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
		{Position = UDim2.new(0, -totalDistance + spinnerCenterOffset, 0, 0)} -- animate the items container
	)

	spinTween:Play() -- play the spin tween

	local connection = game:GetService("RunService").RenderStepped:Connect(function()
		local currentPosition = spinnerFrame.ItemsContainer.Position.X.Offset -- get current position
		local currentItemIndex = math.floor(-currentPosition / itemWidth) -- determine current item index

		if currentItemIndex ~= lastItemIndex then
			local clickClone = gui.ClickSound:Clone() -- clone the click sound
			clickClone.Parent = gui
			clickClone:Play() -- play the click sound
			clickClone.Ended:Connect(function()
				clickClone:Destroy() -- destroy the sound instance after it ends
			end)
			lastItemIndex = currentItemIndex -- update last item index
		end
	end)

	spinTween.Completed:Connect(function()
		connection:Disconnect() -- disconnect the render stepped connection
		isSpinning = false -- set spinning state to false
		if oddsVisible then showOdds() end -- show odds if they were visible

		local centerX = spinnerFrame.AbsolutePosition.X + (spinnerFrame.AbsoluteSize.X / 2) -- calculate center position
		local winningItem -- variable to store the winning item

		for _, item in ipairs(spinnerFrame.ItemsContainer:GetChildren()) do
			if item:IsA("ImageLabel") then
				local itemLeft = item.AbsolutePosition.X -- get left position of the item
				local itemRight = itemLeft + item.AbsoluteSize.X -- get right position of the item

				if centerX >= itemLeft and centerX <= itemRight then -- check if the center is within the item bounds
					for _, configItem in ipairs(SpinnerConfig.items) do
						if configItem.image == item.Image then
							winningItem = configItem -- set the winning item
							break
						end
					end
					break
				end
			end
		end

		if winningItem then
			gui.WinSound:Play() -- play win sound
			gui.WinPopup.WinImage.Image = winningItem.image -- set winning item image
			gui.WinPopup.NameLabel.Text = winningItem.name -- set winning item name
			gui.WinPopup.Size = UDim2.new(0, 0, 0, 0) -- set initial size to zero
			gui.WinPopup.Position = UDim2.new(0.5, 0, 0.5, 0) -- center the popup
			gui.WinPopup.Visible = true -- make the popup visible

			local popupTween = TweenService:Create(gui.WinPopup, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
				Size = UDim2.new(0.186, 0, 0.372, 0), -- animate the size of the popup
				Position = UDim2.new(0.407, 0, 0.314, 0) -- animate the position of the popup
			})

			popupTween.Completed:Connect(function()
				local RewardEvent = ReplicatedStorage.Remotes:WaitForChild("RewardEvent") -- get the reward event
				RewardEvent:FireServer(winningItem) -- fire the reward event with the winning item
			end)

			popupTween:Play() -- play the popup tween

			task.wait(2) -- wait for 2 seconds

			local closeTween = TweenService:Create(gui.WinPopup, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0), -- animate the size to zero
				Position = UDim2.new(0.5, 0, 0.5, 0) -- center the popup again
			})
			closeTween:Play() -- play the close tween

			closeTween.Completed:Connect(function()
				gui.WinPopup.Visible = false -- hide the popup
				if isAutoSpinning and spinsLeft > 0 then
					SpinRemote:FireServer(false) -- request another spin if auto spinning
				else
					startIdleAnimation() -- start idle animation if not auto spinning
				end
			end)
		end
	end)
end

local function startAutoSpin()
	if not hasGamepass then
		MarketplaceService:PromptGamePassPurchase(player, AUTO_SPIN_GAMEPASS_ID) -- prompt purchase if no gamepass
		return
	end
	isAutoSpinning = true -- set auto spinning state to true
	mainFrame.AutoButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0) -- change button color to indicate active state
	if spinsLeft > 0 and not isSpinning then
		SpinRemote:FireServer(false) -- request a spin if spins are available
	end
end

local function stopAutoSpin()
	isAutoSpinning = false -- set auto spinning state to false
	mainFrame.AutoButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- reset button color
end

gui.ToggleButton.MouseButton1Click:Connect(toggleSpinner) -- connect toggle button to toggle spinner

mainFrame.SpinButton.MouseButton1Click:Connect(function()
	if isSpinning or spinsLeft <= 0 then return end -- exit if already spinning or no spins left
	stopIdleAnimation() -- stop idle animation
	SpinRemote:FireServer(false) -- request a spin
end)

mainFrame.InstantButton.MouseButton1Click:Connect(function()
	if isSpinning or spinsLeft <= 0 then return end -- exit if already spinning or no spins left

	if not hasInstantGamepass then
		MarketplaceService:PromptGamePassPurchase(player, INSTANT_SPIN_GAMEPASS_ID) -- prompt purchase if no instant gamepass
		return
	end

	SpinRemote:FireServer(true) -- request an instant spin
end)

mainFrame.AutoButton.MouseButton1Click:Connect(function()
	if isAutoSpinning then stopAutoSpin() else startAutoSpin() end -- toggle auto spin
end)

mainFrame.OddsButton.MouseButton1Click:Connect(function()
	if isSpinning then return end -- exit if currently spinning
	if oddsVisible then hideOdds() else showOdds() end -- toggle odds visibility
end)

SpinResult.OnClientEvent:Connect(function(result, instant)
	if not result then
		if isAutoSpinning then stopAutoSpin() end -- stop auto spin if no result
		return
	end
	if not isSpinning then animateSpin(instant) end -- animate spin if not already spinning
end)

SpinCountUpdate.OnClientEvent:Connect(function(spins)
	spinsLeft = spins -- update spins left
	gui.SpinText.Text = "Spins: " .. spins -- update spin text
end)

TimerSync.OnClientEvent:Connect(function(serverTime)
	lastSpinTime = serverTime -- update last spin time
	updateTimer() -- update the timer
end)

local function cleanup()
	if currentTween then
		currentTween:Cancel() -- cancel any existing tween
		currentTween = nil
	end
end

ReplicatedStorage.Remotes.LuckUpdate.OnClientEvent:Connect(function(luckMultiplier, timeLeft)
	if timeLeft and timeLeft ~= math.huge then
		local minutes = math.floor(timeLeft / 60) -- calculate minutes left
		local seconds = timeLeft % 60 -- calculate seconds left
		gui.LuckText.Text = string.format("Luck: %dx (%dm %ds)", luckMultiplier, minutes, seconds) -- update luck text
	else
		gui.LuckText.Text = string.format("Luck: %dx", luckMultiplier) -- update luck text without timer
	end
end)

spinnerFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	spinnerFrame.ItemsContainer:ClearAllChildren() -- clear items when size changes
	createSpinItems() -- recreate spin items
end)

checkGamepasses() -- check for gamepasses on startup
startIdleAnimation() -- start idle animation
