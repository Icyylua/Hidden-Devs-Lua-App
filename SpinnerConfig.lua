return {
	items = {
		{
			name = "Nothing", -- name of the item
			image = "rbxassetid://70570421292094", -- put your image id for all of them
			chance = 75.2593, -- probability of getting this item
			reward = "none" -- reward type for this item
		},
		{
			name = "2x Luck (15min)", 
			image = "rbxassetid://76624189462768", 
			chance = 5.3697, 
			reward = "luck2x"
		},
		{
			name = "3x Luck (10min)", 
			image = "rbxassetid://118150443038614", 
			chance = 2.3488, 
			reward = "luck3x" 
		},
		{
			name = "+1 Spin", 
			image = "rbxassetid://125714059822649", 
			chance = 12.1967, 
			reward = "spin1"
		},
		{
			name = "+3 Spins", 
			image = "rbxassetid://83491483547250", 
			chance = 3.4267, 
			reward = "spin3" 
		},
		{
			name = "+10 Spins",
			image = "rbxassetid://76174103012241",
			chance = 1.3987,
			reward = "spin10"
		},
		{
			name = "UGC Item",
			image = "rbxassetid://81282108177840", 
			chance = 0.0001,
			reward = "ugc" 
		}
	},

	gamepassIds = {
		autoSpin = 1034246327, -- id for the auto spin gamepass
		instantSpin = 1033938716 -- id for the instant spin gamepass
	},

	ugcItems = {
		{
			name = "Current UGC", -- name of the ugc item
			image = "rbxassetid://81282108177840", -- image id for the ugc item
			itemId = 0000000 -- ugc id
		}
	}
}
