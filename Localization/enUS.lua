-- Localizers may copy this file to edit as necessary.
local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale("ManyHow", "enUS", true)
if not L then return end

-- ./ManyHow.lua
L["ManyHow"] = true
--L["Configure"] = true
--L["Modules"] = true
--L["Settings"] = true
L["Enable "] = true
--L["Module"] = true
--L["Enabled"] = true
--L["Disabled"] = true
L["ManyHow Settings"] = true
L["Welcome to ManyHow! Type /ManyHow to configure."] = true
L["Profiles"] = true

-- ./Modules/MHLoot
L["MHLoot"] = true
L["MHLoot Options"] = true
L["When looting money or items, show how much/many you now have."] = true
L["Money Loot Options"] = true
L["Item Loot Options"] = true
L["Show Total Money"] = true
L["Show total money on loot messages"] = true
L["Show Bags Total"] = true
L["Show total in bags on loot messages"] = true
L["Show with words"] = true
L["Show denomination with words.  321 Gold 45 Silver 67 Copper"] = true
L["Colorize money loots"] = true
L["Show total money using colors. |cffffd700321|r |cff80808045|r |cffeda55f67|r"] = true
L["Currency Loot Options"] = true
L["Show New Total"] = true
L["Show new currency total on loot messages"] = true
L["Combine Messages"] = true
L["Combine Similar Loot Messages"] = true
L["Combine multiple loots for the same item in a short timeframe together into a single message."] = true
L["Faction Options"] = true
L["Show new faction standing on faction messages"] = true
L["Delay item loot messages"] = true
L["Sometimes your inventory hasn't updated when the loot message is sent.  Setting this option will delay loot messages to allow inventory to update."] = true
L["Delay time (seconds)"] = true
L["How long to delay item loot messages"] = true
L["You now have"] = true
L["You are now"] = true
L["into"] = true
L["module"] = true

-- ./Modules/Parser
L["Parser"] = true
L["Provide chat log parsing functionality."] = true