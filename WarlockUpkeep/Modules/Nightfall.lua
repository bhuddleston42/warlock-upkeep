local _, ns = ...
local D = ns.data
local M = ns:NewModule("nightfall")

-- Nightfall: while its proc (Shadow Trance) is up the next Shadow Bolt is instant, so the icon shows and a click
-- casts Shadow Bolt. The proc mostly comes in combat, where Forever and Retail hide auras from addons; then the
-- spell alert on Shadow Bolt, the buff frame and the Cooldown Manager tell instead, and an instant Shadow Bolt
-- (one without a cast bar) means the proc was spent.

local buff = ns.NewBuffTracker(D.nightfallBuffs, D.nightfallDuration, "nightfall")
local isBolt = {}
for _, id in ipairs(D.shadowBolt) do isBolt[id] = true end

local function Plain(v)
    if v ~= nil and not ns.IsSecret(v) then return v end
end

local function IsShadowBolt(id)
    id = Plain(id)
    if not id then return false end
    if isBolt[id] then return true end
    local name = ns.SpellName(id)
    return name ~= nil and name == ns.SpellName(D.shadowBolt[1])
end

-- The game's spell alert on Shadow Bolt: true / false once it has fired, nil before.
local overlay, overlayUntil
local hardCasts = {}

local function Spent()
    buff.has, buff.instance, buff.expires, buff.castAt = false, nil, nil, nil
    if overlay ~= nil then overlay = false end
end

-- true while the proc is up, false when it isn't, nil when unknown.
local function ReadProc()
    local has = buff:Read()
    if buff.src == "aura API" then return has end
    if overlay and overlayUntil and GetTime() >= overlayUntil then overlay = false end
    if overlay ~= nil then return overlay end
    return has
end

function M:Init()
    self.button = ns.CreateActionIcon("nightfall", "Nightfall")
    self.button.previewState = "proc"
    self.button.hint = function(tt)
        tt:AddLine(ns.L["Nightfall: your next Shadow Bolt is instant. Click to cast it."], 0.7, 0.4, 1)
    end

    ns:RegisterEvent("UNIT_AURA", function(_, unit, info)
        if ns.IsSecret(unit) or unit ~= "player" then return end
        buff:OnAuraUpdate(info)
        M:Update()
    end)
    local function OnOverlay(event, spellID)
        if not IsShadowBolt(spellID) then return end
        overlay = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW"
        overlayUntil = overlay and GetTime() + D.nightfallDuration or nil
        if overlay then C_Timer.After(D.nightfallDuration + 0.1, function() M:Update() end) end
        M:Update()
    end
    ns:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", OnOverlay)
    ns:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", OnOverlay)
    -- A Shadow Bolt with a cast bar is a normal one; an instant one spent the proc.
    ns:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit, castGUID, spellID)
        if unit == "player" and IsShadowBolt(spellID) and Plain(castGUID) then hardCasts[castGUID] = true end
    end)
    ns:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, castGUID, spellID)
        if unit ~= "player" or not IsShadowBolt(spellID) then return end
        local guid = Plain(castGUID)
        if guid and hardCasts[guid] then
            hardCasts[guid] = nil
            return
        end
        Spent()
        M:Update()
    end)
    for _, e in ipairs({ "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        ns:RegisterEvent(e, function(_, unit, castGUID)
            if unit == "player" and Plain(castGUID) then hardCasts[castGUID] = nil end
        end)
    end
end

function M:ApplySettings() end

-- A passive talent may not show as known on every client: a proc seen once counts as learned too.
local function TalentKnown()
    if ns.cdb.nightfallSeen then return true end
    for _, id in ipairs(D.nightfallTalent) do
        if ns.IsKnown(id) then return true end
    end
    return false
end

function M:Update()
    local b = self.button
    local spell = ns.HighestKnown(D.shadowBolt)
    local proc = ReadProc()
    if proc == nil then proc = self.lastProc end
    self.lastProc = proc
    if proc then ns.cdb.nightfallSeen = true end
    if not spell or not TalentKnown() then
        b:SetUnlearned(ns.SpellTexture(D.shadowBolt[1]), D.shadowBolt[1])
        b:SetState(nil)
        return
    end
    -- The action is set also while hidden: in combat it can't change any more, only show up on the proc.
    b:SetSpell(spell)
    b:SetState(proc and "proc" or nil)
end
