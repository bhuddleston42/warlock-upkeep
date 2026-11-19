local _, ns = ...
local M = ns:NewModule("petPassive")

-- Demon on passive: it won't fight back or help, which is easy to forget after a pull with crowd control. The
-- icon shows while the pet bar's Passive is active, and a click presses the chosen mode's button on the pet bar.

local function Cfg() return ns.db.petPassive end

-- The modes a click can pick. The pet bar names them differently by client: newer ones (also Forever) have
-- PET_MODE_DEFENSIVEASSIST for Defensive and Assist instead of Aggressive. The bar tells which it has once a
-- demon is out.
local MODES = {
    { value = "defensive", text = "Defensive" },
    { value = "aggressive", text = "Aggressive" },
    { value = "assist", text = "Assist" },
}
local MODE_OF = {
    PET_MODE_DEFENSIVE = "defensive", PET_MODE_DEFENSIVEASSIST = "defensive",
    PET_MODE_AGGRESSIVE = "aggressive", PET_MODE_ASSIST = "assist",
}
local TOC = select(4, GetBuildInfo())
local DEFAULT_ON_BAR = { defensive = true, [TOC >= 50000 and "assist" or "aggressive"] = true }

-- Pet bar slot of each mode, remembered per character: the bar can only be read with a demon out.
local function Slots()
    ns.cdb.petModeSlots = ns.cdb.petModeSlots or {}
    return ns.cdb.petModeSlots
end

-- Modes for the settings: the ones seen on this character's pet bar, or the client's usual ones.
function M.ModeList()
    local seen, list = Slots(), {}
    local any = next(seen) ~= nil
    for _, m in ipairs(MODES) do
        if (any and seen[m.value]) or (not any and DEFAULT_ON_BAR[m.value]) then list[#list + 1] = m end
    end
    return list
end

-- Reads the pet bar: true while the demon is on passive, false when it isn't (or there's no demon), nil when
-- unreadable. Remembers the slots of the mode buttons on the way.
local function Passive()
    if not GetPetActionInfo then return false end
    local exists = ns.Bool(UnitExists, "pet")
    if exists == nil then return nil end
    if not exists then return false end
    if ns.Bool(UnitIsDeadOrGhost, "pet") then return false end
    local passive, slots = false, {}
    for i = 1, NUM_PET_ACTION_SLOTS or 10 do
        local r = { pcall(GetPetActionInfo, i) }
        if not r[1] then return nil end
        local name = r[2]
        if ns.IsSecret(name) then return nil end
        if type(name) == "string" and MODE_OF[name] then slots[MODE_OF[name]] = i end
        if name == "PET_MODE_PASSIVE" then
            -- name, texture, isToken (1 or true for the bar's own buttons), isActive; clients with a subtext
            -- before the texture have the texture (a string) where isToken would be.
            local active
            if type(r[4]) == "string" then active = r[6] else active = r[5] end
            if ns.IsSecret(active) then return nil end
            passive = active and true or false
        end
    end
    if next(slots) then ns.cdb.petModeSlots = slots end
    return passive
end

-- The mode a click sets: the chosen one if this pet bar has it, Defensive otherwise.
local function Target()
    local slots, mode = Slots(), Cfg().mode or "defensive"
    if slots[mode] then return mode, slots[mode] end
    return "defensive", slots.defensive
end

local function ModeText(mode)
    for _, m in ipairs(MODES) do
        if m.value == mode then return ns.L[m.text] end
    end
    return mode
end

function M:Init()
    self.button = ns.CreateActionIcon("petPassive", "Demon on passive")
    self.button.previewState = "passive"
    self.button.hint = function(tt)
        tt:AddLine(string.format(ns.L["Your demon is on passive. Click to set: %s."], ModeText((Target()))), 1, 0.82, 0)
    end
    for _, e in ipairs({ "PET_BAR_UPDATE", "PET_UI_UPDATE" }) do
        ns:RegisterEvent(e, function() M:Update() end)
    end
    ns:RegisterEvent("UNIT_PET", function(_, unit) if unit == "player" then M:Update() end end)
end

function M:ApplySettings() end

function M:Update()
    local b = self.button
    local passive = Passive()
    if passive == nil then passive = self.lastPassive end -- unreadable: keep last known
    self.lastPassive = passive
    -- The passive mode's own picture, as on the pet bar: the icon shows what's wrong, the click fixes it. The
    -- click presses the mode's button on the pet bar, the way the bar itself does (a demon not seen yet: the
    -- usual Defensive slot). The action is set also while hidden: in combat it can't change any more.
    local _, slot = Target()
    local texture = PET_PASSIVE_TEXTURE or "Interface\\Icons\\Ability_Seal"
    b:SetAction({ type1 = "pet", action1 = slot or 9 }, texture, nil, nil)
    b:SetState(passive and "passive" or nil)
end
