local ADDON_NAME = ...

local FUR = CreateFrame("Frame")
local PLAYER_LEVEL_BASE = 70
local BASE_DEFENSE = PLAYER_LEVEL_BASE * 5
local ARMOR_CAP_73 = 35880
local CRIT_REDUCTION_PER_DEFENSE = 0.04
local DEFENSE_PER_CRIT_PERCENT = 25
local DEFENSE_RATING_PER_SKILL_FALLBACK = 2.365
local RESILIENCE_RATING_PER_CRIT_PERCENT_FALLBACK = 39.423
local HIT_RATING_PER_PERCENT_FALLBACK = 15.77
local EXPERTISE_RATING_PER_POINT_FALLBACK = 3.9423
local RESILIENCE_CR = 15
local DEFENSE_CR = CR_DEFENSE_SKILL or 2
local HIT_CR = CR_HIT_MELEE or 6
local EXPERTISE_CR = CR_EXPERTISE or 24
local SURVIVAL_OF_THE_FITTEST = {33853, 33855, 33856}

local TARGETS = {
    {level = 73, label = "Boss 73", required = 5.6, hitCap = 9, expertiseSoftCap = 26, expertiseHardCap = 56},
    {level = 72, label = "Dungeon 72", required = 5.4, hitCap = 6, expertiseSoftCap = 24, expertiseHardCap = 54},
}

local COLORS = {
    green = "|cff66ff99",
    red = "|cffff6666",
    yellow = "|cffffd966",
    gray = "|cffb8b8b8",
    white = "|cffffffff",
    reset = "|r",
}

local LABEL_COLOR = {0.82, 0.82, 0.74}

local LOCALE = GetLocale and GetLocale() or "enUS"
local L = {
    title = "FUR:",
    uncrit = "Uncrit",
    defRating = "Def rating",
    resRating = "Res rating",
    dodge = "Dodge",
    miss = "Miss",
    avoid = "Avoid",
    armor = "Armor",
    hit = "Hit",
    expSoft = "Exp soft",
    expHard = "Exp hard",
    locked = "locked.",
    unlocked = "unlocked.",
    options = "Options",
    lockWindow = "Lock window",
    startExpanded = "Start expanded",
    showWindow = "Show window",
    autoHideCombat = "Auto hide in combat",
    autoMinimizeCombat = "Auto minimize in combat",
    resetPosition = "Reset position",
}

if LOCALE == "ptBR" then
    L = {
        title = "FUR:",
        uncrit = "Uncrit",
        defRating = "Def rating",
        resRating = "Res rating",
        dodge = "Esquiva",
        miss = "Miss",
        avoid = "Avoid",
        armor = "Armadura",
        hit = "Acerto",
        expSoft = "Exp soft",
        expHard = "Exp hard",
        locked = "travado.",
        unlocked = "destravado.",
        options = "Opcoes",
        lockWindow = "Travar janela",
        startExpanded = "Iniciar expandido",
        showWindow = "Mostrar janela",
        autoHideCombat = "Auto ocultar em combate",
        autoMinimizeCombat = "Auto minimizar em combate",
        resetPosition = "Resetar posicao",
    }
end

local function ColorText(text, ok)
    return (ok and COLORS.green or COLORS.red) .. text .. COLORS.reset
end

local function Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor((value or 0) * mult + 0.5) / mult
end

local function FormatSigned(value, decimals)
    local rounded = Round(value, decimals or 1)
    if rounded > 0 then
        return "+" .. rounded
    end
    return tostring(rounded)
end

local function FormatConservativeRating(value)
    local rounded = math.ceil(value)
    if rounded > 0 then
        return "+" .. rounded
    end
    return tostring(rounded)
end

local function FormatPercent(value)
    return string.format("%.2f%%", value or 0)
end

local function FormatDelta(value)
    local rounded = math.ceil(value)

    if rounded > 0 then
        return "+" .. rounded
    end
    return tostring(rounded)
end

local function ColorDelta(value, text)
    return (value >= 0 and COLORS.green or COLORS.red) .. text .. COLORS.reset
end

local function GetKnownSotFRank()
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        for rank = #SURVIVAL_OF_THE_FITTEST, 1, -1 do
            if C_SpellBook.IsSpellKnown(SURVIVAL_OF_THE_FITTEST[rank]) then
                return rank
            end
        end
    elseif IsSpellKnown then
        for rank = #SURVIVAL_OF_THE_FITTEST, 1, -1 do
            if IsSpellKnown(SURVIVAL_OF_THE_FITTEST[rank]) then
                return rank
            end
        end
    end

    return 0
end

local function GetDefense()
    local base, modifier = UnitDefense("player")
    return (base or BASE_DEFENSE) + (modifier or 0), modifier or 0
end

local function GetResilience()
    local rating = GetCombatRating and GetCombatRating(RESILIENCE_CR) or 0
    local bonus = GetCombatRatingBonus and GetCombatRatingBonus(RESILIENCE_CR) or 0
    return rating or 0, bonus or 0
end

local function GetDefenseRating()
    if GetCombatRating then
        return GetCombatRating(DEFENSE_CR) or 0
    end
    return 0
end

local function GetResiliencePerPercent(rating, bonus)
    if rating and rating > 0 and bonus and bonus > 0 then
        return rating / bonus
    end
    return RESILIENCE_RATING_PER_CRIT_PERCENT_FALLBACK
end

local function GetDefenseRatingPerSkill(defenseRating, defenseFromGear)
    if defenseRating and defenseRating > 0 and defenseFromGear and defenseFromGear > 0 then
        return defenseRating / defenseFromGear
    end
    return DEFENSE_RATING_PER_SKILL_FALLBACK
end

local function GetRatingPerPercent(rating, bonus, fallback)
    if rating and rating > 0 and bonus and bonus > 0 then
        return rating / bonus
    end
    return fallback
end

local function GetExpertiseInfo()
    local mainExpertise = 0
    if GetExpertise then
        mainExpertise = select(1, GetExpertise()) or 0
    end

    local rating = GetCombatRating and GetCombatRating(EXPERTISE_CR) or 0
    local perPoint = EXPERTISE_RATING_PER_POINT_FALLBACK
    if rating and rating > 0 and mainExpertise and mainExpertise > 0 then
        perPoint = rating / mainExpertise
    end

    return rating or 0, mainExpertise or 0, perPoint
end

local function BuildStats()
    local defense, defenseFromGear = GetDefense()
    local defenseRating = GetDefenseRating()
    local resilienceRating, resilienceReduction = GetResilience()
    local armor = select(2, UnitArmor("player"))
    local dodge = GetDodgeChance and GetDodgeChance() or 0
    local hitRating = GetCombatRating and GetCombatRating(HIT_CR) or 0
    local hitBonus = GetCombatRatingBonus and GetCombatRatingBonus(HIT_CR) or 0
    local hitRatingPerPercent = GetRatingPerPercent(hitRating, hitBonus, HIT_RATING_PER_PERCENT_FALLBACK)
    local expertiseRating, expertise, expertiseRatingPerPoint = GetExpertiseInfo()
    local talentReduction = GetKnownSotFRank()
    local defenseReduction = math.max(0, (defense - BASE_DEFENSE) * CRIT_REDUCTION_PER_DEFENSE)
    local totalReduction = defenseReduction + resilienceReduction + talentReduction
    local defenseRatingPerSkill = GetDefenseRatingPerSkill(defenseRating, defenseFromGear)
    local resiliencePerPercent = GetResiliencePerPercent(resilienceRating, resilienceReduction)
    local byTarget = {}

    for index, target in ipairs(TARGETS) do
        local enemyAttackRating = target.level * 5
        local miss = 5 + ((defense - enemyAttackRating) * CRIT_REDUCTION_PER_DEFENSE)
        local hitCapRating = target.hitCap * hitRatingPerPercent
        local expertiseSoftRating = target.expertiseSoftCap * expertiseRatingPerPoint
        local expertiseHardRating = target.expertiseHardCap * expertiseRatingPerPoint

        byTarget[index] = {
            miss = miss,
            avoidance = dodge + miss,
            hitDelta = hitRating - hitCapRating,
            expertiseSoftDelta = expertiseRating - expertiseSoftRating,
            expertiseHardDelta = expertiseRating - expertiseHardRating,
        }
    end

    return {
        defense = defense,
        defenseFromGear = defenseFromGear,
        defenseRating = defenseRating,
        defenseReduction = defenseReduction,
        defenseRatingPerSkill = defenseRatingPerSkill,
        resilienceRating = resilienceRating,
        resilienceReduction = resilienceReduction,
        resiliencePerPercent = resiliencePerPercent,
        talentReduction = talentReduction,
        totalReduction = totalReduction,
        armor = armor or 0,
        dodge = dodge,
        hitRating = hitRating or 0,
        expertiseRating = expertiseRating,
        expertise = expertise,
        byTarget = byTarget,
    }
end

local function CreateCell(parent, x, y, template, justify)
    local cell = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    cell:SetPoint("TOPLEFT", x, y)
    cell:SetSize(30, 12)
    cell:SetJustifyH(justify or "RIGHT")
    return cell
end

local function CreateLabel(parent, x, y, text)
    local label = CreateCell(parent, x, y, "GameFontHighlightSmall", "LEFT")
    label:SetSize(58, 12)
    label:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
    label:SetText(text)
    return label
end

local function MoveCell(cell, x, y, width)
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", x, y)
    cell:SetWidth(width)
end

local function EnsureDb()
    FURDB = FURDB or {}
    if FURDB.expanded == nil then
        FURDB.expanded = FURDB.startExpanded or false
    end
end

local function SetExpanded(expanded)
    EnsureDb()
    FURDB.expanded = expanded and true or false
    if FUR.frame then
        FUR:Update()
    end
end

local function MarkUserInteraction()
    if FUR.inCombat then
        FUR.combatUserChanged = true
    end
end

local function SetExpandedByUser(expanded)
    MarkUserInteraction()
    SetExpanded(expanded)
end

local function EnsureUI()
    if FUR.frame then
        return
    end

    EnsureDb()

    local frame = CreateFrame("Frame", "FURFrame", UIParent, "BackdropTemplate")
    frame:SetSize(124, 56)
    frame:SetPoint(FURDB.point or "CENTER", UIParent, FURDB.relativePoint or "CENTER", FURDB.x or 0, FURDB.y or 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 16,
        edgeSize = 0,
        insets = {left = 0, right = 0, top = 0, bottom = 0},
    })
    frame:SetBackdropColor(0.03, 0.03, 0.04, 0.72)
    frame:SetScript("OnDragStart", function(self)
        if not FURDB.locked then
            MarkUserInteraction()
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        FURDB.point = point
        FURDB.relativePoint = relativePoint
        FURDB.x = x
        FURDB.y = y
    end)

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(16)
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(0.10, 0.10, 0.08, 0.62)
    header.line = header:CreateTexture(nil, "BORDER")
    header.line:SetPoint("BOTTOMLEFT", 0, 0)
    header.line:SetPoint("BOTTOMRIGHT", 0, 0)
    header.line:SetHeight(1)
    header.line:SetColorTexture(0.72, 0.62, 0.32, 0.45)
    header:SetScript("OnClick", function()
        SetExpandedByUser(not FURDB.expanded)
    end)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", 6, -1)
    title:SetText(L.title)

    local toggleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleText:SetPoint("RIGHT", -5, -1)
    header.toggleText = toggleText
    frame.toggle = header

    local uncritLabel = CreateLabel(frame, 6, -17, L.uncrit)

    local header73 = CreateCell(frame, 63, -17, "GameFontNormalSmall", "RIGHT")
    header73:SetText("73")

    local header72 = CreateCell(frame, 91, -17, "GameFontNormalSmall", "RIGHT")
    header72:SetText("72")

    local defenseLabel = CreateLabel(frame, 6, -29, L.defRating)
    local resilienceLabel = CreateLabel(frame, 6, -41, L.resRating)

    FUR.frame = frame
    FUR.labels = {
        uncrit = uncritLabel,
        defense = defenseLabel,
        resilience = resilienceLabel,
    }
    FUR.headers = {
        target73 = header73,
        target72 = header72,
    }
    FUR.cells = {
        defense73 = CreateCell(frame, 63, -29),
        defense72 = CreateCell(frame, 91, -29),
        resilience73 = CreateCell(frame, 63, -41),
        resilience72 = CreateCell(frame, 91, -41),
    }

    FUR.expandedRows = {}
    local expandedInfo = {
        {"miss", L.miss},
        {"avoidance", L.avoid},
        {"hit", L.hit},
        {"expSoft", L.expSoft},
        {"expHard", L.expHard},
        {"dodge", L.dodge},
        {"armor", L.armor},
    }

    for index, info in ipairs(expandedInfo) do
        local y = -58 - ((index - 1) * 12)
        local row = {
            key = info[1],
            label = CreateLabel(frame, 6, y, info[2]),
            value = CreateCell(frame, 65, y, "GameFontHighlightSmall", "RIGHT"),
            delta = CreateCell(frame, 96, y, "GameFontHighlightSmall", "RIGHT"),
        }
        FUR.expandedRows[#FUR.expandedRows + 1] = row
    end

    FUR.generalSeparator = frame:CreateTexture(nil, "BORDER")
    FUR.generalSeparator:SetHeight(1)
    FUR.generalSeparator:SetColorTexture(0.72, 0.62, 0.32, 0.32)
    FUR.generalSeparator:Hide()

    if FURDB.hidden then
        frame:Hide()
    end
end

local function LayoutFrame(expanded)
    if not FUR.frame then
        return
    end

    if expanded then
        FUR.frame:SetSize(195, 174)
        MoveCell(FUR.labels.uncrit, 6, -18, 70)
        MoveCell(FUR.labels.defense, 6, -32, 70)
        MoveCell(FUR.labels.resilience, 6, -46, 70)
        MoveCell(FUR.headers.target73, 76, -18, 38)
        MoveCell(FUR.headers.target72, 122, -18, 38)
        MoveCell(FUR.cells.defense73, 76, -32, 38)
        MoveCell(FUR.cells.defense72, 122, -32, 38)
        MoveCell(FUR.cells.resilience73, 76, -46, 38)
        MoveCell(FUR.cells.resilience72, 122, -46, 38)

        for index, row in ipairs(FUR.expandedRows or {}) do
            local y = -66 - ((index - 1) * 13)
            if index >= 6 then
                y = y - 8
            end
            MoveCell(row.label, 6, y, 72)
            MoveCell(row.value, 82, y, 50)
            MoveCell(row.delta, 136, y, 52)
        end

        if FUR.generalSeparator then
            FUR.generalSeparator:ClearAllPoints()
            FUR.generalSeparator:SetPoint("TOPLEFT", FUR.frame, "TOPLEFT", 6, -130)
            FUR.generalSeparator:SetPoint("TOPRIGHT", FUR.frame, "TOPRIGHT", -6, -130)
            FUR.generalSeparator:Show()
        end
    else
        FUR.frame:SetSize(124, 56)
        MoveCell(FUR.labels.uncrit, 6, -17, 58)
        MoveCell(FUR.labels.defense, 6, -29, 58)
        MoveCell(FUR.labels.resilience, 6, -41, 58)
        MoveCell(FUR.headers.target73, 63, -17, 30)
        MoveCell(FUR.headers.target72, 91, -17, 30)
        MoveCell(FUR.cells.defense73, 63, -29, 30)
        MoveCell(FUR.cells.defense72, 91, -29, 30)
        MoveCell(FUR.cells.resilience73, 63, -41, 30)
        MoveCell(FUR.cells.resilience72, 91, -41, 30)
        if FUR.generalSeparator then
            FUR.generalSeparator:Hide()
        end
    end
end

function FUR:Update()
    EnsureUI()

    EnsureDb()
    local stats = BuildStats()
    local values = {}

    for index, target in ipairs(TARGETS) do
        local delta = stats.totalReduction - target.required
        local ok = delta >= -0.0001
        values[index] = {
            ok = ok,
            defense = ColorText(FormatConservativeRating(delta * DEFENSE_PER_CRIT_PERCENT * stats.defenseRatingPerSkill), ok),
            resilience = ColorText(FormatConservativeRating(delta * stats.resiliencePerPercent), ok),
        }
    end

    self.cells.defense73:SetText(values[1].defense)
    self.cells.resilience73:SetText(values[1].resilience)
    self.cells.defense72:SetText(values[2].defense)
    self.cells.resilience72:SetText(values[2].resilience)

    if self.frame.toggle and self.frame.toggle.toggleText then
        self.frame.toggle.toggleText:SetText(FURDB.expanded and "-" or "+")
    end

    LayoutFrame(FURDB.expanded)

    local expandedValues = {
        miss = {
            value = FormatPercent(stats.byTarget[1].miss),
            delta = FormatPercent(stats.byTarget[2].miss),
        },
        avoidance = {
            value = FormatPercent(stats.byTarget[1].avoidance),
            delta = FormatPercent(stats.byTarget[2].avoidance),
        },
        hit = {
            value = ColorDelta(stats.byTarget[1].hitDelta, FormatDelta(stats.byTarget[1].hitDelta)),
            delta = ColorDelta(stats.byTarget[2].hitDelta, FormatDelta(stats.byTarget[2].hitDelta)),
        },
        expSoft = {
            value = ColorDelta(stats.byTarget[1].expertiseSoftDelta, FormatDelta(stats.byTarget[1].expertiseSoftDelta)),
            delta = ColorDelta(stats.byTarget[2].expertiseSoftDelta, FormatDelta(stats.byTarget[2].expertiseSoftDelta)),
        },
        expHard = {
            value = ColorDelta(stats.byTarget[1].expertiseHardDelta, FormatDelta(stats.byTarget[1].expertiseHardDelta)),
            delta = ColorDelta(stats.byTarget[2].expertiseHardDelta, FormatDelta(stats.byTarget[2].expertiseHardDelta)),
        },
        dodge = {value = FormatPercent(stats.dodge), delta = ""},
        armor = {
            value = tostring(math.floor(stats.armor + 0.5)),
            deltaValue = stats.armor - ARMOR_CAP_73,
            delta = FormatDelta(stats.armor - ARMOR_CAP_73),
        },
    }

    for _, row in ipairs(self.expandedRows or {}) do
        local data = expandedValues[row.key]
        if FURDB.expanded and data then
            row.label:Show()
            row.value:Show()
            row.delta:Show()
            row.value:SetText(data.value or "")
            if data.deltaValue then
                row.delta:SetText(ColorDelta(data.deltaValue or 0, data.delta))
            elseif data.delta then
                row.delta:SetText(data.delta)
            else
                row.delta:SetText("")
            end
        else
            row.label:Hide()
            row.value:Hide()
            row.delta:Hide()
        end
    end
end

function FUR:PrintStatus()
    local stats = BuildStats()
    print(COLORS.yellow .. "FUR" .. COLORS.reset .. ": anti-crit total " .. Round(stats.totalReduction, 2) .. "%")
    for _, target in ipairs(TARGETS) do
        local delta = stats.totalReduction - target.required
        local absDelta = math.abs(delta)
        local defenseEquivalent = absDelta * DEFENSE_PER_CRIT_PERCENT * stats.defenseRatingPerSkill
        local resilienceEquivalent = absDelta * stats.resiliencePerPercent
        if delta >= -0.0001 then
            print(string.format("%s%s%s: imune, sobra %.2f%% (%s defense rating / %s resilience rating)",
                COLORS.green, target.label, COLORS.reset, absDelta, FormatConservativeRating(defenseEquivalent), FormatConservativeRating(resilienceEquivalent)))
        else
            print(string.format("%s%s%s: falta %.2f%% (%s defense rating ou %s resilience rating)",
                COLORS.red, target.label, COLORS.reset, absDelta, FormatConservativeRating(-defenseEquivalent), FormatConservativeRating(-resilienceEquivalent)))
        end
    end
end

function FUR:PrintDebug()
    local stats = BuildStats()
    print(COLORS.yellow .. "FUR debug" .. COLORS.reset)
    print(string.format("Defense total: %d | acima de %d: %s | reducao: %.2f%%",
        stats.defense,
        BASE_DEFENSE,
        FormatSigned(stats.defense - BASE_DEFENSE, 0),
        stats.defenseReduction
    ))
    print(string.format("Defense rating: %.0f | Resilience rating: %.0f | reducao resilience: %.2f%% | rating por 1%%: %.2f",
        stats.defenseRating,
        stats.resilienceRating,
        stats.resilienceReduction,
        stats.resiliencePerPercent
    ))
    print(string.format("Defense rating por 1 defense skill: %.2f", stats.defenseRatingPerSkill))
    print(string.format("Survival of the Fittest: %d/3 | reducao talento: %.0f%%",
        stats.talentReduction,
        stats.talentReduction
    ))
    print(string.format("Total anti-crit: %.2f%%", stats.totalReduction))

    for _, target in ipairs(TARGETS) do
        local delta = stats.totalReduction - target.required
        print(string.format("Nivel %d requer %.2f%% | delta %.2f%% | equiv. defense %s | equiv. resilience %s",
            target.level,
            target.required,
            delta,
            FormatConservativeRating(delta * DEFENSE_PER_CRIT_PERCENT * stats.defenseRatingPerSkill),
            FormatConservativeRating(delta * stats.resiliencePerPercent)
        ))
    end
end

function FUR:EnterCombat()
    EnsureDb()
    self.inCombat = true
    self.combatUserChanged = false
    self.preCombatState = {
        hidden = FURDB.hidden and true or false,
        expanded = FURDB.expanded and true or false,
        shown = self.frame and self.frame:IsShown() or false,
    }

    if FURDB.autoHideCombat then
        FURDB.hidden = true
        if self.frame then
            self.frame:Hide()
        end
    elseif FURDB.autoMinimizeCombat and FURDB.expanded then
        SetExpanded(false)
    end
end

function FUR:LeaveCombat()
    EnsureDb()
    self.inCombat = false
    local state = self.preCombatState
    self.preCombatState = nil

    if not state or self.combatUserChanged then
        self.combatUserChanged = false
        return
    end

    if FURDB.autoHideCombat then
        FURDB.hidden = state.hidden
        if self.frame then
            if state.shown and not state.hidden then
                self.frame:Show()
            else
                self.frame:Hide()
            end
        end
    end

    if FURDB.autoMinimizeCombat then
        SetExpanded(state.expanded)
    end

    self.combatUserChanged = false
end

local function CreateCheckButton(parent, label, x, y, getter, setter)
    local button = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    if button.Text then
        button.Text:SetText(label)
    else
        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", button, "RIGHT", 2, 0)
        text:SetText(label)
        button.Text = text
    end
    button:SetScript("OnShow", function(self)
        self:SetChecked(getter())
    end)
    button:SetScript("OnClick", function(self)
        setter(self:GetChecked())
        FUR:Update()
    end)
    return button
end

local function RefreshConfigControls(controls)
    if not controls then
        return
    end

    EnsureDb()
    controls.lockCheck:SetChecked(FURDB.locked)
    controls.expandedCheck:SetChecked(FURDB.startExpanded)
    controls.showCheck:SetChecked(not FURDB.hidden)
    controls.autoHideCheck:SetChecked(FURDB.autoHideCombat)
    controls.autoMinimizeCheck:SetChecked(FURDB.autoMinimizeCombat)
end

local function CreateConfigControls(parent, startY)
    local y = startY or -52
    local controls = {}

    controls.lockCheck = CreateCheckButton(parent, L.lockWindow, 16, y,
        function()
            EnsureDb()
            return FURDB.locked
        end,
        function(checked)
            EnsureDb()
            MarkUserInteraction()
            FURDB.locked = checked and true or false
        end
    )

    controls.expandedCheck = CreateCheckButton(parent, L.startExpanded, 16, y - 30,
        function()
            EnsureDb()
            return FURDB.startExpanded
        end,
        function(checked)
            EnsureDb()
            MarkUserInteraction()
            FURDB.startExpanded = checked and true or false
            SetExpandedByUser(checked)
        end
    )

    controls.showCheck = CreateCheckButton(parent, L.showWindow, 16, y - 60,
        function()
            EnsureDb()
            return not FURDB.hidden
        end,
        function(checked)
            EnsureDb()
            MarkUserInteraction()
            FURDB.hidden = not checked
            if FUR.frame then
                if checked then
                    FUR.frame:Show()
                else
                    FUR.frame:Hide()
                end
            end
        end
    )

    controls.autoHideCheck = CreateCheckButton(parent, L.autoHideCombat, 16, y - 90,
        function()
            EnsureDb()
            return FURDB.autoHideCombat
        end,
        function(checked)
            EnsureDb()
            FURDB.autoHideCombat = checked and true or false
        end
    )

    controls.autoMinimizeCheck = CreateCheckButton(parent, L.autoMinimizeCombat, 16, y - 120,
        function()
            EnsureDb()
            return FURDB.autoMinimizeCombat
        end,
        function(checked)
            EnsureDb()
            FURDB.autoMinimizeCombat = checked and true or false
        end
    )

    controls.reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    controls.reset:SetPoint("TOPLEFT", 20, y - 158)
    controls.reset:SetSize(130, 24)
    controls.reset:SetText(L.resetPosition)
    controls.reset:SetScript("OnClick", function()
        EnsureDb()
        MarkUserInteraction()
        FURDB.point = nil
        FURDB.relativePoint = nil
        FURDB.x = nil
        FURDB.y = nil
        EnsureUI()
        FUR.frame:ClearAllPoints()
        FUR.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end)

    RefreshConfigControls(controls)
    return controls
end

local function CreateOptionsPanel()
    if FUR.optionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "FUROptionsPanel")
    panel.name = "FUR"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("FUR - Feral Uncrit Readout")

    panel.configControls = CreateConfigControls(panel, -52)

    panel:SetScript("OnShow", function()
        RefreshConfigControls(panel.configControls)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        FUR.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    FUR.optionsPanel = panel
end

local function SaveConfigFramePosition(frame)
    EnsureDb()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    FURDB.configPoint = point
    FURDB.configRelativePoint = relativePoint
    FURDB.configX = x
    FURDB.configY = y
end

local function CreateStandaloneConfig()
    if FUR.configFrame then
        return
    end

    EnsureDb()

    local ok, frame = pcall(CreateFrame, "Frame", "FURConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    if not ok then
        frame = CreateFrame("Frame", "FURConfigFrame", UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3},
        })
        frame:SetBackdropColor(0.03, 0.03, 0.04, 0.92)
        frame:SetBackdropBorderColor(0.35, 0.33, 0.24, 0.9)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 1, 1)
    end

    frame:SetSize(360, 280)
    frame:SetPoint(FURDB.configPoint or "CENTER", UIParent, FURDB.configRelativePoint or "CENTER", FURDB.configX or 0, FURDB.configY or 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveConfigFramePosition(self)
    end)
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("FUR")

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    frame.content = content

    local contentTitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    contentTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4)
    contentTitle:SetText("FUR - Feral Uncrit Readout")

    frame.configControls = CreateConfigControls(content, -38)
    frame:SetScript("OnShow", function(self)
        RefreshConfigControls(self.configControls)
    end)

    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "FURConfigFrame"
    end
    FUR.configFrame = frame
end

local function OpenOptionsPanel()
    CreateOptionsPanel()
    if Settings and Settings.OpenToCategory and FUR.settingsCategory then
        Settings.OpenToCategory(FUR.settingsCategory.ID or FUR.settingsCategory)
    elseif InterfaceOptionsFrame_OpenToCategory and FUR.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(FUR.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(FUR.optionsPanel)
    end
end

local function OpenStandaloneConfig()
    CreateStandaloneConfig()
    FUR.configFrame:Show()
    RefreshConfigControls(FUR.configFrame.configControls)
end

local function SlashHandler(message)
    message = string.lower(message or "")
    EnsureUI()

    if message == "hide" then
        MarkUserInteraction()
        FURDB.hidden = true
        FUR.frame:Hide()
    elseif message == "show" then
        MarkUserInteraction()
        FURDB.hidden = false
        FUR.frame:Show()
        FUR:Update()
    elseif message == "lock" then
        MarkUserInteraction()
        FURDB.locked = not FURDB.locked
        print("FUR: " .. (FURDB.locked and L.locked or L.unlocked))
    elseif message == "debug" then
        FUR:PrintDebug()
    elseif message == "expand" then
        SetExpandedByUser(true)
    elseif message == "compact" then
        SetExpandedByUser(false)
    elseif message == "toggle" then
        SetExpandedByUser(not FURDB.expanded)
    elseif message == "options" then
        OpenOptionsPanel()
    elseif message == "config" then
        OpenStandaloneConfig()
    elseif message == "reset" then
        MarkUserInteraction()
        FURDB.point = nil
        FURDB.relativePoint = nil
        FURDB.x = nil
        FURDB.y = nil
        FUR.frame:ClearAllPoints()
        FUR.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    else
        FURDB.hidden = false
        if FUR.frame:IsShown() then
            FUR:PrintStatus()
        else
            FUR.frame:Show()
        end
        FUR:Update()
    end
end

FUR:SetScript("OnEvent", function(self, event)
    if event == "ADDON_LOADED" and ADDON_NAME ~= "FUR" then
        return
    end

    if event == "ADDON_LOADED" then
        EnsureDb()
        EnsureUI()
        CreateOptionsPanel()
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:EnterCombat()
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:LeaveCombat()
    end

    C_Timer.After(0.1, function()
        self:Update()
    end)
end)

FUR:RegisterEvent("ADDON_LOADED")
FUR:RegisterEvent("PLAYER_LOGIN")
FUR:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
FUR:RegisterEvent("COMBAT_RATING_UPDATE")
FUR:RegisterEvent("CHARACTER_POINTS_CHANGED")
FUR:RegisterEvent("UNIT_AURA")
FUR:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
FUR:RegisterEvent("PLAYER_REGEN_DISABLED")
FUR:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_FERALUNCRITREADOUT1 = "/fur"
SLASH_FERALUNCRITREADOUT2 = "/uncrit"
SlashCmdList.FERALUNCRITREADOUT = SlashHandler
