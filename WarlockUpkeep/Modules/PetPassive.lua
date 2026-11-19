local _, ns = ...
local M = ns:NewModule("petPassive")

-- Demon on passive: it won't fight back or help, which is easy to forget after a pull with crowd control. The
-- icon shows while the pet bar's Passive is active, and a click puts the demon on Defensive.

-- true while the demon is on passive, false when it isn't (or there's no demon), nil when unreadable.
local function Passive()
    if not GetPetActionInfo then return false end
    local exists = ns.Bool(UnitExists, "pet")
    if exists == nil then return nil end
    if not exists then return false end
    if ns.Bool(UnitIsDeadOrGhost, "pet") then return false end
    for i = 1, NUM_PET_ACTION_SLOTS or 10 do
        local r = { pcall(GetPetActionInfo, i) }
        if not r[1] then return nil end
        local name = r[2]
        if ns.IsSecret(name) then return nil end
        if name == "PET_MODE_PASSIVE" then
            -- name, texture, isToken (1 or true for the bar's own buttons), isActive; clients with a subtext
            -- before the texture have the texture (a string) where isToken would be.
            local active
            if type(r[4]) == "string" then active = r[6] else active = r[5] end
            if ns.IsSecret(active) then return nil end
            return active and true or false
        end
    end
    return false
end

function M:Init()
    self.button = ns.CreateActionIcon("petPassive", "Demon on passive")
    self.button.previewState = "passive"
    self.button.hint = function(tt)
        tt:AddLine(ns.L["Your demon is on passive. Click to put it on defensive."], 1, 0.82, 0)
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
    -- The action is set also while hidden: in combat it can't change any more, only show up.
    b:SetAction({ type1 = "macro", macrotext1 = "/petdefensive" }, "Interface\\Icons\\Ability_Defend", nil, nil)
    b:SetState(passive and "passive" or nil)
end
