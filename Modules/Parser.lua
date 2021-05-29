-- *************************************************************
-- Simple modularized chat message parser.
-- Still has a way to go to make it useful across addins.
-- This may end up as a library some day.
-- By DemonCroc
-- Special thanks to Mikord for showing the way
-- *************************************************************

local mod = ManyHow:NewModule("Parser")
local L = LibStub("AceLocale-3.0"):GetLocale("ManyHow")
mod.modName = L["Parser"]
mod.canBeDisabled = false
local HMDebPrint = ManyHow.DebugPrint

-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

-- Information about global strings for CHAT_MSG_X events.
-- This contains the mapping between EVENTS and the global strings (globalstrings.lua) that are associated with those events
local eventToGlobalStringMap

-- This contains mapping between the global strings, and various things about the information that can be extracted from those strings
-- Examples are "This is a loot event", or "money information can be found in capture field 2".
local parseEventFillers

--[[
The various global strings referenced in eventToGlobalStringMap are themselves parsed to find where certain data fields are located. For instance, in
the global string LOOT_ITEM_PUSHED_SELF which has the value "You receive item: %s.", the %s marks a location where information can be extracted from
the string.  The rest of the string can be used to make sure we're attempting to capture using the correct template. A copy of LOOT_ITEM_PUSHED_SELF
is created, converting the %s into a capture element (%.+), and the result is stored in searchPatterns.

searchPatterns is a mapping between the original global string and the resulting search and capture string.
]]
local searchPatterns = {}

-- This contains information about the order various capture fields were found in the global strings (stored in searchPatterns).
-- This can be useful in other locales.  For intance, in English, a string might have capture strings ordered as A B C, but when
-- translated into French, the order is B A C.  This table holds information that can be used to make sure the right information
-- gets placed in the correct fields in the parsed output.
local captureOrders = {}

-- Captured and parsed event data.
local captureTable = {}
--local parserEvent = {}

-- ****************************************************************************
-- Compares two global strings so the most specific one comes first.  This
-- prevents incorrectly capturing information for certain events.
-- ****************************************************************************
local function GlobalStringCompareFunc(globalStringNameOne, globalStringNameTwo)
	-- Get the global string for the passed names.
	local globalStringOne = _G[globalStringNameOne]
	local globalStringTwo = _G[globalStringNameTwo]
    local gsOneStripped = gsub(globalStringOne, "%%%d?%$?[sd]", "")
    local gsTwoStripped = gsub(globalStringTwo, "%%%d?%$?[sd]", "")

    -- Check if the stripped global strings are the same length.
    if (strlen(gsOneStripped) == strlen(gsTwoStripped)) then
        -- Count the number of captures in each string.
        local numCapturesOne = 0
        for _ in gmatch(globalStringOne, "%%%d?%$?[sd]") do
            numCapturesOne = numCapturesOne + 1
        end

        local numCapturesTwo = 0
        for _ in gmatch(globalStringTwo, "%%%d?%$?[sd]") do
            numCapturesTwo = numCapturesTwo + 1
        end

        -- Return the global string with the least captures.
        return numCapturesOne < numCapturesTwo
    else
        -- Return the longer global string.
        return strlen(gsOneStripped) > strlen(gsTwoStripped)
    end
end

-- ****************************************************************************
-- Converts the passed global string into a lua search pattern with a capture
-- order table and stores the results so any requests to convert the same
-- global string will just return the cached one.
-- ****************************************************************************
local function ConvertGlobalString(globalStringName)
    -- Don't do anything if the passed global string does not exist.
    local globalString = _G[globalStringName]
    if (globalString == nil) then return end

    -- Return the cached conversion if it has already been converted.
    if (searchPatterns[globalStringName]) then
        return searchPatterns[globalStringName], captureOrders[globalStringName]
    end

    -- Hold the capture order.
    local captureOrder
    local numCaptures = 0

    -- Escape lua magic chars.
    local searchPattern = gsub(globalString, "([%^%(%)%.%[%]%*%+%-%?])", "%%%1")

    -- Loop through each capture and setup the capture order.
    for captureIndex in gmatch(searchPattern, "%%(%d)%$[sd]") do
        if (not captureOrder) then captureOrder = {} end
        numCaptures = numCaptures + 1
        captureOrder[tonumber(captureIndex)] = numCaptures
    end

    -- Convert %1$s / %s to (.+) and %1$d / %d to (%d+).
    searchPattern = gsub(searchPattern, "%%%d?%$?s", "(.+)")
    searchPattern = gsub(searchPattern, "%%%d?%$?d", "(%%d+)")

    -- Escape any remaining $ chars.
    searchPattern = gsub(searchPattern, "%$", "%%$")

    -- Cache the converted pattern and capture order.
    searchPatterns[globalStringName] = searchPattern
    captureOrders[globalStringName] = captureOrder

    -- Return the converted global string.
    return searchPattern, captureOrder
end

-- ****************************************************************************
-- Fills in the capture table with the captured data if a match is found.
-- ****************************************************************************
local function CaptureData(matchStart, matchEnd, c1, c2, c3, c4, c5, c6, c7, c8, c9)
    -- Check if a match was found.
    if (matchStart) then
        captureTable[1] = c1
        captureTable[2] = c2
        captureTable[3] = c3
        captureTable[4] = c4
        captureTable[5] = c5
        captureTable[6] = c6
        captureTable[7] = c7
        captureTable[8] = c8
        captureTable[9] = c9
        -- Return the last position of the match.
        return matchEnd
    end
    -- Don't return anything since no match was found.
    return nil
end

-- ****************************************************************************
-- Reorders the capture table according to the passed capture order.
-- ****************************************************************************
local function ReorderCaptures(capOrder)
    local t, o = captureTable, capOrder

    t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9] =
    t[o[1] or 1], t[o[2] or 2], t[o[3] or 3], t[o[4] or 4], t[o[5] or 5],
    t[o[6] or 6], t[o[7] or 7], t[o[8] or 8], t[o[9] or 9]
end

-- ****************************************************************************
-- Parses the CHAT_MSG_X search style events.
-- ****************************************************************************
local function ParseSearchMessage(event,msgText)
	if not eventToGlobalStringMap[event] then
		return
    end

    -- Loop through all of the global strings associated with event
	for _, globalStringName in pairs(eventToGlobalStringMap[event]) do
		-- Make sure the function to pull the parsed data from the string exists.
		local parseEventFiller = parseEventFillers[globalStringName]
		if (parseEventFiller) then
			-- Get capture data.
			local matchEnd = CaptureData(strfind(msgText, searchPatterns[globalStringName]))

			-- Check if a match was found.
			if (matchEnd) then
				-- Check if there is a capture order for the global string and reorder the data accordingly.
				if (captureOrders[globalStringName]) then
					ReorderCaptures(captureOrders[globalStringName])
				end

				-- Create the new parser event.
				local parserEvent = {}
				parserEvent.OriginalText = msgText
				-- Populate fields that exist for all events.
				parserEvent.recipientUnit = "player"
				-- Map the captured arguments into the parser event table.
				parseEventFiller(parserEvent, captureTable)
				return parserEvent
			end -- if (matchEnd)
		end
	end
	return  -- we found no match
end

-------------------------------------------------------------------------------
-- Startup utility functions.
-------------------------------------------------------------------------------

-- ****************************************************************************
-- Creates a map of events to possible global strings
-- ****************************************************************************
local function CreateEventToGlobalStringMap()
    eventToGlobalStringMap = {
        -- Looted Items.
        CHAT_MSG_LOOT = {
            "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
            "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_BONUS_ROLL_SELF", "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE"
        },

        -- Money.
        CHAT_MSG_MONEY = {"YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD"},

        -- Currency.
        CHAT_MSG_CURRENCY = {"CURRENCY_GAINED", "CURRENCY_GAINED_MULTIPLE"},

        CHAT_MSG_COMBAT_FACTION_CHANGE = {
            "FACTION_STANDING_DECREASED", "FACTION_STANDING_DECREASED_GENERIC", "FACTION_STANDING_INCREASED",
            "FACTION_STANDING_INCREASED_ACH_BONUS", "FACTION_STANDING_INCREASED_BONUS", "FACTION_STANDING_INCREASED_DOUBLE_BONUS", "FACTION_STANDING_INCREASED_GENERIC"
            },
    }

    -- Loop through each of the events.
    for event, map in pairs(eventToGlobalStringMap) do
        -- Remove invalid global strings.
        for i = #map, 1, -1 do
            if (not _G[map[i]]) then
                tremove(map, i)
                HMDebPrint("In Parser:Removed mapping" )
            end
        end

        -- Sort the global strings from most to least specific.
        sort(map, GlobalStringCompareFunc)
    end
end

-- ****************************************************************************
-- Creates a map of capture functions for supported global strings.
-- ****************************************************************************
local function CreateParseEventFillers()
    parseEventFillers = {
        -- Loot events.
        LOOT_ITEM_SELF = function (p, c) p.eventType, p.isMoney, p.itemLink, p.amount = "loot", false, c[1], c[2] end,
        LOOT_ITEM_CREATED_SELF = function (p, c) p.eventType, p.isMoney, p.isCreate, p.itemLink, p.amount = "loot", false, true, c[1], c[2] end,
        LOOT_MONEY_SPLIT = function (p, c) p.eventType, p.isMoney, p.moneyString = "loot", true, c[1] end,
        CURRENCY_GAINED = function (p, c) p.eventType, p.isMoney, p.moneyString = "currency", false, c[1] end,
        CURRENCY_GAINED_MULTIPLE = function (p, c) p.eventType, p.isMoney, p.moneyString, p.amount = "currency", false, c[1], c[2] end,
        FACTION_STANDING_INCREASED = function (p, c) p.eventType, p.isMoney, p.factionString, p.amount = "faction", false, c[1], c[2] end,
        FACTION_STANDING_INCREASED_GENERIC = function (p, c) p.eventType, p.isMoney, p.factionString, p.amount = "faction", false, c[1], 0 end,
    }

    parseEventFillers["LOOT_ITEM_SELF_MULTIPLE"] = parseEventFillers["LOOT_ITEM_SELF"]
    parseEventFillers["LOOT_ITEM_CREATED_SELF_MULTIPLE"] = parseEventFillers["LOOT_ITEM_CREATED_SELF"]
    parseEventFillers["LOOT_ITEM_PUSHED_SELF"] = parseEventFillers["LOOT_ITEM_CREATED_SELF"]
    parseEventFillers["LOOT_ITEM_PUSHED_SELF_MULTIPLE"] = parseEventFillers["LOOT_ITEM_CREATED_SELF"]
    parseEventFillers["LOOT_ITEM_BONUS_ROLL_SELF"] = parseEventFillers["LOOT_ITEM_SELF"]
    parseEventFillers["LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE"] = parseEventFillers["LOOT_ITEM_SELF"]
    parseEventFillers["LOOT_MONEY_SPLIT_GUILD"] = parseEventFillers["LOOT_MONEY_SPLIT"]
    parseEventFillers["YOU_LOOT_MONEY"] = parseEventFillers["LOOT_MONEY_SPLIT"]
    parseEventFillers["YOU_LOOT_MONEY_GUILD"] = parseEventFillers["LOOT_MONEY_SPLIT"]
    parseEventFillers["FACTION_STANDING_INCREASED_ACH_BONUS"] = parseEventFillers["FACTION_STANDING_INCREASED"]
    parseEventFillers["FACTION_STANDING_INCREASED_BONUS"] = parseEventFillers["FACTION_STANDING_INCREASED"]
    parseEventFillers["FACTION_STANDING_INCREASED_DOUBLE_BONUS"] = parseEventFillers["FACTION_STANDING_INCREASED"]
    parseEventFillers["FACTION_STANDING_DECREASED"] = parseEventFillers["FACTION_STANDING_INCREASED"]
    parseEventFillers["FACTION_STANDING_DECREASED_GENERIC"] = parseEventFillers["FACTION_STANDING_INCREASED_GENERIC"]

    -- Print an error message for each global string that isn't found and remove it from the map.
    for globalStringName in pairs(parseEventFillers) do
        if (not _G[globalStringName]) then
            HMDebPrint("Unable to find global string: " .. globalStringName, 1, 0, 0)
            parseEventFillers[globalStringName] = nil
        end
    end
end

-- ****************************************************************************
-- Converts all of the supported global strings.
-- ****************************************************************************
local function ConvertGlobalStrings()
    -- Loop through all of the supported global strings.
    for globalStringName in pairs(parseEventFillers) do
        -- Get the global string converted to a lua search pattern and prepend an anchor to
        -- speed up searching.
        searchPatterns[globalStringName] = "^" .. ConvertGlobalString(globalStringName)
        --HMDebPrint(searchPatterns[globalStringName] )
    end
end

-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------

function mod:OnInitialize()
	-- Create various maps.
    -- HMDebPrint("In Parser:OnInitialize" )
	CreateEventToGlobalStringMap()
	CreateParseEventFillers()

	-- Convert the supported global strings into lua search patterns.
	ConvertGlobalStrings()
end

-- ****************************************************************************
-- ****************************************************************************
function mod:OnEnable()
    HMDebPrint("In Parser:OnEnable" )
end

-- ****************************************************************************
-- ****************************************************************************
function mod:OnDisable()
end

-------------------------------------------------------------------------------
-- External Interface
-------------------------------------------------------------------------------

-- ****************************************************************************
-- This will parse the given message, and pass back the parseEvent data
-- ****************************************************************************
function mod.ParseRawChatEvent(event,text)
	return ParseSearchMessage(event,text)
end

-- ****************************************************************************
-- ****************************************************************************
function mod:Info()
	return L["Provide chat log parsing functionality."]
end
