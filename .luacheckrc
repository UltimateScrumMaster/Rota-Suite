-- .luacheckrc — Luacheck configuration for WoW 3.3.5a (Interface 30300)
std = "lua51"

-- Copias de SavedVariables y referencias generadas (datos, no codigo del addon)
exclude_files = { "backups/**", "tools/golden/**" }

-- Max line length and formatting options
max_line_length = 140
ignore = {
    "212", -- Unused argument
    "213", -- Unused loop variable
}

-- WoW 3.3.5a API Globals & Project Globals
globals = {
    -- WoW System / UI Globals
    "SlashCmdList",
    "SLASH_ROTAPROBE1",
    "SLASH_ROTAPROBE2",
    "SLASH_ROTACORE1",
    "SLASH_ROTACORE2",
    "SLASH_ROTA1",
    "SLASH_ROTA2",
    "SLASH_ROTAEDIT1",
    "SLASH_ROTAEDIT2",
    "DEFAULT_CHAT_FRAME",
    "UIParent",
    "Minimap",
    "GameTooltip",
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory",
    "GetCursorPosition",
    "IsShiftKeyDown",
    "CreateFrame",
    "GetTime",
    "hooksecurefunc",
    "wipe",
    "LoadAddOn",
    "GameFontNormal",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "GameFontNormalSmall",
    "GameFontNormalLarge",

    -- Spell & Cooldown APIs
    "GetSpellInfo",
    "GetSpellCooldown",
    "IsSpellInRange",
    "IsUsableSpell",
    "IsCurrentSpell",
    "GetSpellTabInfo",
    "GetSpellBookItemInfo",
    "GetSpellBookItemName",
    "GetNumSpellTabs",
    "GetSpellName",
    "GetSpellLink",

    -- Rune APIs (Death Knight 3.3.5a)
    "GetRuneCooldown",
    "GetRuneType",

    -- Stance APIs (Warrior 3.3.5a)
    "GetShapeshiftForm",

    -- Unit & Power APIs
    "UnitAura",
    "UnitBuff",
    "UnitDebuff",
    "UnitPower",
    "UnitPowerMax",
    "UnitMana",
    "UnitManaMax",
    "UnitHealth",
    "UnitHealthMax",
    "UnitCreatureType",
    "UnitName",
    "UnitClass",
    "UnitRace",
    "UnitLevel",
    "UnitExists",
    "UnitIsDead",
    "UnitIsDeadOrGhost",
    "UnitAffectingCombat",

    -- Inventory / Item APIs
    "GetInventoryItemID",
    "GetInventoryItemCooldown",

    -- Combat Log APIs
    "CombatLogClearEntries",

    -- Talent & Glyph APIs
    "GetNumTalentTabs",
    "GetNumTalents",
    "GetTalentInfo",
    "GetTalentTabInfo",
    "GetActiveTalentGroup",
    "GetGlyphSocketInfo",
    "IsSpellKnown",

    -- Dropdown APIs (WoW 3.3.5a)
    "UIDropDownMenu_Initialize",
    "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_SetSelectedValue",
    "UIDropDownMenu_GetSelectedValue",
    "UIDropDownMenu_SetText",
    "UIDropDownMenu_CreateInfo",
    "UIDropDownMenu_AddButton",

    -- Rebuffed Lua API Globals
    "C_NamePlate",
    "UnitIsControlled",
    "UnitIsSilenced",
    "UnitIsDisarmed",
    "CopyToClipboard",
    "GetSpellBaseCooldown",
    "QueueInteract",
    "CheckInteractDistance",
    "UnitCanAttack",
    "UnitThreatSituation",
    "UnitIsUnit",

    -- SavedVariables & Addon Globals
    "RotaProbeDB",
    "RotaProbe",
    "RotationIR",
    "RotaCore",
    "RotaCoreDB",
    "RotaClass_DK",
    "RotaClass_PAL",
    "RotaClass_WAR",
    "RotaEditor",

    -- Testing & Mocking Globals
    "wowmock",
}
