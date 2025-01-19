local marketplace_service = game:GetService("MarketplaceService")

local donation_products = {
	{amount = 30, id = 2703106801, spins = 1}, 
	{amount = 60, id = 2703128746, spins = 2},
	{amount = 120, id = 2703106801, spins = 4},
	{amount = 300, id = 2703106801, spins = 10},
	{amount = 600, id = 2703106801, spins = 20}
}

-- try to set up the donation gui and handle potential errors
local success, error = pcall(function()
	local main_frame = script.Parent.DonationGui:WaitForChild("MainFrame", 5) -- wait for the main frame to load
	local buttons_frame = main_frame:WaitForChild("ButtonsFrame", 5) -- wait for the buttons frame to load
	local button_template = script:WaitForChild("ButtonTemplate", 5) -- wait for the button template to load

	-- loop through each donation product to create buttons
	for i, product in ipairs(donation_products) do
		local button = button_template:Clone() -- create a new button from the template
		button.Name = "DonateButton_" .. i -- assign a unique name to the button
		button.Text = product.amount .. " R$ = " .. product.spins .. " Spins" -- set the button text to show the donation amount and spins
		button.Position = UDim2.new(0.1, 0, 0.1 + (i-1) * 0.15, 0) -- position the button in the frame
		button.Parent = buttons_frame -- add the button to the buttons frame

		-- connect the button click event to prompt the purchase
		button.MouseButton1Click:Connect(function()
			marketplace_service:PromptProductPurchase(game.Players.LocalPlayer, product.id) -- prompt the player to purchase the product
		end)
	end
end)
