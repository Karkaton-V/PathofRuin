-- Debug console commands that toggle the completion marks for both Nehemiahs, since the marks are save data no run can reach

local COMMANDS = {}
POR.CompletionCommands = COMMANDS

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local CONDEMNED_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)

local UNTAINTED_PREFIX = "nehemiah_"
local TAINTED_PREFIX = "nehemiaht_"
local ALL_TOKEN = "all"
local REPORT_TOKEN = "marks"
local HARD_VALUE = 2 -- what a toggle sets a mark to, matching the hard mode value the full marks challenge gates in challenges.lua require

-- Console token for each mark, paired with the field name both completion mark functions use
local MARKS = {
    { Token = "heart",      Field = "MomsHeart" },
    { Token = "isaac",      Field = "Isaac" },
    { Token = "satan",      Field = "Satan" },
    { Token = "bossrush",   Field = "BossRush" },
    { Token = "bluebaby",   Field = "BlueBaby" },
    { Token = "lamb",       Field = "Lamb" },
    { Token = "megasatan",  Field = "MegaSatan" },
    { Token = "ultragreed", Field = "UltraGreed" },
    { Token = "hush",       Field = "Hush" },
    { Token = "delirium",   Field = "Delirium" },
    { Token = "mother",     Field = "Mother" },
    { Token = "beast",      Field = "Beast" },
}

local MARK_BY_TOKEN = {}
for _, mark in ipairs(MARKS) do
    MARK_BY_TOKEN[mark.Token] = mark
end

-- Current marks for a character, or nil when the REPENTOGON lookup is unavailable so a caller reports that rather than writing a blank set
local function readMarks(playerType)
    if type(Isaac.GetCompletionMarks) ~= "function" then return nil end

    local ok, marks = pcall(Isaac.GetCompletionMarks, playerType)
    if not ok or type(marks) ~= "table" then return nil end
    return marks
end

-- Writes a whole mark set back, as SetCompletionMarks takes one table per character rather than a single mark
local function writeMarks(playerType, marks)
    if type(Isaac.SetCompletionMarks) ~= "function" then return false end

    local payload = { PlayerType = playerType }
    for _, mark in ipairs(MARKS) do
        payload[mark.Field] = marks[mark.Field] or 0
    end
    return (pcall(Isaac.SetCompletionMarks, payload))
end

-- Splits "nehemiaht_all" into the character it targets and the token after the prefix, returning nil for any other command
local function parseCommand(command)
    if command:sub(1, #TAINTED_PREFIX) == TAINTED_PREFIX then
        return CONDEMNED_TYPE, command:sub(#TAINTED_PREFIX + 1)
    end
    if command:sub(1, #UNTAINTED_PREFIX) == UNTAINTED_PREFIX then
        return NEHEMIAH_TYPE, command:sub(#UNTAINTED_PREFIX + 1)
    end
    return nil, nil
end

-- Lists every mark and the value it holds, so the state is checkable without opening the menu
local function reportMarks(marks)
    local parts = {}
    for _, mark in ipairs(MARKS) do
        parts[#parts + 1] = mark.Token .. "=" .. tostring(marks[mark.Field] or 0)
    end
    return table.concat(parts, " ")
end

-- Flips one mark between cleared and earned, or to an explicit value when the command was given one
local function applyOne(marks, mark, requested)
    local current = marks[mark.Field] or 0
    local value = requested or ((current > 0) and 0 or HARD_VALUE)
    marks[mark.Field] = value
    return value
end

-- Flips every mark together, clearing them only once all of them are already earned so a partial set fills in first
local function applyAll(marks, requested)
    local complete = true
    for _, mark in ipairs(MARKS) do
        if (marks[mark.Field] or 0) <= 0 then complete = false end
    end

    local value = requested or (complete and 0 or HARD_VALUE)
    for _, mark in ipairs(MARKS) do
        marks[mark.Field] = value
    end
    return value
end

-- Handles every nehemiah_ and nehemiaht_ command, reporting what changed back to the console
function COMMANDS.OnCommand(_, command, args)
    local playerType, token = parseCommand(string.lower(command or ""))
    if not token then return end

    if not playerType or playerType <= 0 then
        return "POR: that character is not registered, so its marks cannot be reached"
    end

    local marks = readMarks(playerType)
    if not marks then
        return "POR: Isaac.GetCompletionMarks is unavailable, so the marks cannot be read"
    end

    if token == REPORT_TOKEN then
        return "POR marks: " .. reportMarks(marks)
    end

    local requested = tonumber(args)
    if requested then
        requested = math.max(0, math.min(HARD_VALUE, math.floor(requested)))
    end

    local label
    if token == ALL_TOKEN then
        label = "all marks -> " .. tostring(applyAll(marks, requested))
    else
        local mark = MARK_BY_TOKEN[token]
        if not mark then
            return "POR: unknown mark \"" .. token .. "\", try " .. ALL_TOKEN .. ", " .. REPORT_TOKEN .. ", or a boss name"
        end
        label = mark.Token .. " -> " .. tostring(applyOne(marks, mark, requested))
    end

    if not writeMarks(playerType, marks) then
        return "POR: Isaac.SetCompletionMarks refused the write"
    end
    return "POR: " .. label
end

POR:AddCallback(ModCallbacks.MC_EXECUTE_CMD, COMMANDS.OnCommand)

return COMMANDS
