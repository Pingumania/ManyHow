-- *************************************************************
-- ManyHow, a simple, addon to modify loot messages to tell you
-- how many you now have of the items you just looted.  Can
-- also tell you how much money you have as you loot.
-- By DemonCroc
-- *************************************************************

ManyHow = LibStub("AceAddon-3.0"):NewAddon("ManyHow", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("ManyHow")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

--  ************************************************************
-- All of this first part is setting up the configuration
--  ************************************************************

local optFrame

local options = {
	args = { --  options are registered here into blizzard interface
		type = "group",
		icon = '',
		name = L["ManyHow"],
		args = {
			Spacer = {
				type = "header",
				order = 1,
				name = L["MHLoot"]
			},
			-- We will place module options here, titled by module name
			-- Profile member will get added here by loading it from the db
		}
	}
}

-- Which modules do we want enabled by default?  This is tied to the ManyHow database, so it is saved across loads
local defaultModuleStatus = {
	profile = {
		modules = {
			["MHLoot"] = true,
			["Parser"] = true,
		}
	}
}

ManyHow:SetDefaultModuleState(true)

--local optionFrames = {}
local ACD3 = LibStub("AceConfigDialog-3.0")

-- Key is currency ID number
-- Value is currency name
ManyHow.currencyInfo = {}

-- *******************
-- A bit of setup here, but still mostly configuration related stuff
-- *******************
function ManyHow:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("ManyHowDB", defaultModuleStatus, "Default")
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("ManyHow", options.args)
	optFrame = ACD3:AddToBlizOptions("ManyHow", "ManyHow", nil)

	for rawModName, theMod in self:IterateModules() do
		-- check if the module has options
		local t
		if theMod.GetOptions then
			local modNameToUse = (theMod.modName or rawModName)
			t = theMod:GetOptions()
			options.args.args[modNameToUse] = t
		end
	end

	self.db.profile.modules["MHLoot"] = true

	-- Fetch currency information
	for _, id in ipairs(ManyHow.currencyIDs) do
		local info = C_CurrencyInfo.GetCurrencyInfo(id)
		if info and info.name ~= "" then
			ManyHow.currencyInfo[id] = info.name
		end
	end

	self:RegisterChatCommand("ManyHow", "OpenConfig")
	self.db.RegisterCallback(self, "OnProfileChanged", "UpdateConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "UpdateConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "UpdateConfig")
end

-- called by the /ManyHow command.  Opens to the ManyHow config page in the blizzard options
function ManyHow:OpenConfig(input)
	--InterfaceOptionsFrame_OpenToCategory(ManyHow.lastConfig)
	InterfaceOptionsFrame_OpenToCategory("ManyHow")  -- optFrame
end

--[[
-- This code deals with enabling/disabling modules as the user clicks on them.
do
	local timer, t = nil, 0
	local function update(arg1)
		t = t + arg1
		if t > 0.5 then
			timer:SetScript("OnUpdate", nil)
			ManyHow:UpdateConfig()
		end
	end
	function ManyHow:SetUpdateConfig()
		t = 0
		timer = timer or CreateFrame("Frame", nil, UIParent)
		timer:SetScript("OnUpdate", update)
	end
end
]]--

function ManyHow:UpdateConfig()
	for k, v in self:IterateModules() do
		if v:IsEnabled() then
			v:Disable()
			v:Enable()
		end
	end
end

--  ************************************************************
--  ok, finally time to get down to work
--  ************************************************************
function ManyHow:OnEnable()
--	ManyHow:Print(L["Welcome to ManyHow! Type /ManyHow to configure."])
	for k, v in self:IterateModules() do
		if self.db.profile.modules[k] ~= false then
			v:Enable()
		end
	end

	if not options.args.args.Profiles then
		options.args.args.Profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	end
end

function ManyHow:OnDisable()
end

function ManyHow.DebugPrint(prntstr)
	--ManyHow:Print(prntstr)
end