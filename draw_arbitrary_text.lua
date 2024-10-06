function widget:GetInfo()
    return {
        name      = "Draw Arbitrary Text",
        desc      = "Draws arbitrary text on the map! Mouse over somewhere and use /write_text Hello There!",
        author    = "Tom Fyuri, socdoneleft",
        date      = "2023",
        license   = "GPL",
        layer     = 1,
        enabled   = true
    }
end

-- WIP, missing symbols?
-- Code by Tom Fyuri
-- 1/2 of characters by Tom Fyuri, 1/2 by socdoneleft
-- socdoneleft fixed pic easter egg and added luaui cmd to change char size

-- if you experience trouble with lines getting cut off - enable VSync (adaptive is ok)

local lineCoords = {
    A = {
        {x = 0, y = 10},
        {x = 0, y = 0},
        {x = 10, y = 0},
        {x = 10, y = 5},
        {x = 0, y = 5},
        {x = 10, y = 5},
        {x = 10, y = 10},
    },
    B = {
        {x = 0, y = 0},
        {x = 8, y = 0},
        {x = 10, y = 2},
        {x = 10, y = 4},
        {x = 8, y = 5},
        {x = 0, y = 5},
        {x = 8, y = 5},
        {x = 10, y = 6},
        {x = 10, y = 8},
        {x = 8, y = 10},
        {x = 0, y = 10},
        {x = 0, y = 0}
    },
    C = {
        {x = 10, y = 0},
        {x = 0, y = 0},
        {x = 0, y = 10},
        {x = 10, y = 10}
    },
    D = {
        {x = 0, y = 0},
        {x = 8, y = 0},
        {x = 10, y = 2},
        {x = 10, y = 8},
        {x = 8, y = 10},
        {x = 0, y = 10},
        {x = 0, y = 0}
    },
    E = {
        {x = 10, y = 0},
        {x = 0, y = 0},
        {x = 0, y = 10},
        {x = 10, y = 10},
        {x = 0, y = 10},

        {x = 0, y = 5},
        {x = 10, y = 5}
    },
	F = {
		{x = 0, y = 10},
		{x = 0, y = 5},
		{x = 5, y = 5},
		{x = 0, y = 5},
		{x = 0, y = 0},
		{x = 10, y = 0}
	},
    G = {
        {x = 10, y = 0},
        {x = 0, y = 0},
        {x = 0, y = 10},
        {x = 10, y = 10},
        {x = 10, y = 5},
        {x = 5, y = 5}
    },
    H = {
        {x = 0, y = 0},
        {x = 0, y = 10},
        {x = 0, y = 5},
        {x = 10, y = 5},
        {x = 10, y = 0},
        {x = 10, y = 10}
    },
    I = {
        {x = 2, y = 0},
		{x = 8, y = 0},
		{x = 5, y = 0},
        {x = 5, y = 10},
        {x = 2, y = 10},
		{x = 8, y = 10},
    },
    J = {
        {x = 0, y = 10},
        {x = 8, y = 10},
        {x = 10, y = 8},
        {x = 10, y = 0},
    },
    K = {
        {x = 0, y = 10},
        {x = 0, y = 0},
		{x = 0, y = 5},
        {x = 10, y = 10},
        {x = 0, y = 5},
        {x = 10, y = 0}
    },
    L = {
        {x = 0, y = 0},
        {x = 0, y = 10},
        {x = 10, y = 10}
    },
	M = {
		{x = 0, y = 10},
		{x = 0, y = 0},
		{x = 5, y = 5},
		{x = 10, y = 0},
		{x = 10, y = 10}
	},
    N = {
        {x = 0, y = 10},
        {x = 0, y = 0},
        {x = 10, y = 10},
        {x = 10, y = 0}
    },
    O = {
        {x = 0, y = 3},
        {x = 0, y = 7},
		{x = 3, y = 10},
        {x = 7, y = 10},
        {x = 10, y = 7},
		{x = 10, y = 3},
		{x = 7, y = 0},
		{x = 3, y = 0},
        {x = 0, y = 3}
    },
    P = {
        {x = 0, y = 10},
        {x = 0, y = 0},
        {x = 10, y = 0},
        {x = 10, y = 5},
        {x = 0, y = 5}
    },
    Q = {
        {x = 0, y = 3},
        {x = 0, y = 7},
		{x = 3, y = 10},
        {x = 6, y = 10},
		{x = 8, y = 8},
		{x = 10, y = 10},
		{x = 6, y = 6},
		{x = 8, y = 8},
        {x = 10, y = 6},
		{x = 10, y = 3},
		{x = 7, y = 0},
		{x = 3, y = 0},
        {x = 0, y = 3}
    },
    R = {
        {x = 0, y = 10},
        {x = 0, y = 0},
        {x = 10, y = 0},
        {x = 10, y = 5},
        {x = 0, y = 5},
        {x = 10, y = 10}
    },
    S = {
        {x = 10, y = 0},
		{x = 3, y = 0},
		{x = 0, y = 2},
		{x = 0, y = 3},
		{x = 3, y = 5},
		{x = 7, y = 5},
		{x = 10, y = 7},
		{x = 10, y = 8},
		{x = 7, y = 10},
		{x = 0, y = 10}
    },
    T = {
        {x = 0, y = 0},
        {x = 10, y = 0},
        {x = 5, y = 0},
        {x = 5, y = 10}
    },
    U = {
        {x = 10, y = 0},
        {x = 10, y = 10},
        {x = 0, y = 10},
        {x = 0, y = 0}
    },
    V = {
        {x = 10, y = 0},
        {x = 5, y = 10},
        {x = 0, y = 0}
    },
    W = {
        {x = 0, y = 0},
		{x = 2, y = 10},
		{x = 5, y = 2},
        {x = 8, y = 10},
        {x = 10, y = 0}
    },
    X = {
        {x = 0, y = 10},
		{x = 10, y = 0},
		{x = 5, y = 5},
		{x = 0, y = 0},
        {x = 10, y = 10}
    },
    Y = {
        {x = 0, y = 0},
        {x = 5, y = 5},
        {x = 10, y = 0},
        {x = 5, y = 5},
        {x = 5, y = 10}
    },
    Z = {
        {x = 0, y = 0},
        {x = 10, y = 0},
        {x = 0, y = 10},
        {x = 10, y = 10}
    },
    ["!"] = {
        {x = 4, y = 0},
		{x = 6, y = 0},
        {x = 5, y = 8},
        {x = 6, y = 9},
        {x = 5, y = 10},
        {x = 4, y = 9},
        {x = 5, y = 8},
		{x = 4, y = 0}
    },
	["?"] = {
		{x = 5, y = 8},
		{x = 4, y = 9},
        {x = 5, y = 10},
        {x = 6, y = 9},
        {x = 5, y = 8},
		{x = 10, y = 8},
		{x = 0, y = 8},
		{x = 10, y = 5},
		{x = 10, y = 3},
		{x = 7, y = 0},
		{x = 3, y = 0},
		{x = 0, y = 3},
	},
	["."] = {
        {x = 5, y = 10},
        {x = 6, y = 9},
        {x = 4, y = 9},
		{x = 5, y = 10}
	},
	[","] = {
        {x = 5, y = 10},
        {x = 6, y = 9},
		{x = 6, y = 8},
		{x = 5, y = 7},
        {x = 4, y = 8},
		{x = 5, y = 9},
		{x = 4, y = 10},
		{x = 5, y = 10}
	},
	["'"] = {
        {x = 5, y = 3},
        {x = 6, y = 2},
		{x = 6, y = 1},
		{x = 5, y = 0},
        {x = 4, y = 1},
		{x = 5, y = 2},
		{x = 4, y = 3},
		{x = 5, y = 3}
	},
	["1"] = {
		{x = 2, y = 3},
		{x = 5, y = 0},
		{x = 5, y = 10},
		{x = 2, y = 10},
		{x = 8, y = 10}
	},
	["2"] = {
		{x = 0, y = 3},
		{x = 3, y = 0},
		{x = 7, y = 0},
		{x = 10, y = 3},
		{x = 0, y = 10},
		{x = 10, y = 10}
	},
	["3"] = {
		{x = 0, y = 2},
		{x = 2, y = 0},
		{x = 8, y = 0},
		{x = 10, y = 2},
		{x = 7, y = 5},
		{x = 3, y = 5},
		{x = 7, y = 5},
		{x = 10, y = 8},
		{x = 8, y = 10},
		{x = 2, y = 10},
		{x = 0, y = 8}
	},
	["4"] = {
		{x = 0, y = 0},
		{x = 0, y = 5},
		{x = 10, y = 5},
		{x = 10, y = 0},
		{x = 10, y = 10}
	},
	["5"] = {
        {x = 10, y = 0},
        {x = 0, y = 0},
        {x = 0, y = 5},
        {x = 10, y = 5},
        {x = 10, y = 10},
        {x = 0, y = 10}
    },
	["6"] = {
		{x = 10, y = 2},
		{x = 8, y = 0},
		{x = 2, y = 0},
		{x = 0, y = 2},
		{x = 0, y = 8},
		{x = 2, y = 10},
		{x = 8, y = 10},
		{x = 10, y = 8},
		{x = 10, y = 6},
		{x = 8, y = 4},
		{x = 2, y = 4},
		{x = 0, y = 6}
	},
	["7"] = {
		{x = 0, y = 0},
		{x = 10, y = 0},
		{x = 3, y = 10},
	},
	["8"] = {
		{x = 2, y = 5},
		{x = 2, y = 5},
		{x = 0, y = 7},
		{x = 0, y = 8},
		{x = 2, y = 10},
		{x = 8, y = 10},
		{x = 10, y = 8},
		{x = 10, y = 7},
		{x = 8, y = 5},
		{x = 2, y = 5},
		{x = 0, y = 3},
		{x = 0, y = 2},
		{x = 2, y = 0},
		{x = 8, y = 0},
		{x = 10, y = 2},
		{x = 10, y = 3},
		{x = 8, y = 5}
	},
	["9"] = {
		{x = 0, y = 10},
		{x = 10, y = 10},
		{x = 10, y = 0},
		{x = 0, y = 0},
		{x = 0, y = 5},
		{x = 10, y = 5}
	},
	["0"] = {
        {x = 0, y = 2},
        {x = 0, y = 8},
		{x = 2, y = 10},
        {x = 8, y = 10},
		{x = 9, y = 9},
		{x = 1, y = 1},
		{x = 9, y = 9},
        {x = 10, y = 8},
		{x = 10, y = 2},
		{x = 8, y = 0},
		{x = 2, y = 0},
        {x = 0, y = 2}
	},
	["~"] = {
		{x = 8, y = 2},
		{x = 6, y = 0},
		{x = 2, y = 0},
		{x = 0, y = 2},
		{x = 0, y = 5},
		{x = 4, y = 5},
		{x = 4, y = 2},
		{x = 0, y = 2},
		{x = 0, y = 5},
		{x = 1, y = 5},
		{x = 1, y = 5},
		{x = 1, y = 10},
		{x = 3, y = 10},
		{x = 3, y = 8},
		{x = 6, y = 8},
		{x = 6, y = 10},
		{x = 8, y = 10},
		{x = 8, y = 6},
		{x = 10, y = 6},
		{x = 10, y = 2},
		{x = 8, y = 2},
		{x = 8, y = 6}
	},
	["`"] = { -- this one is a picture of a lobster, requires text_scale 10 at least
		{x = 0.5, y = 0.1},
		{x = 0.2, y = 0.5},
		{x = 0, y = 0.8},
		{x = 0.1, y = 1.6},
		{x = 1.4, y = 2.7},
		{x = 2.6, y = 2.8},
		{x = 1.4, y = 2.7},
		{x = 1.9, y = 3.8},
		{x = 2.9, y = 4.4},
		{x = 2.9, y = 4.6},
		{x = 1.7, y = 5.7},
		{x = 1.7, y = 5.9},
		{x = 2, y = 5.9},
		{x = 3.1, y = 5.1},
		{x = 2.9, y = 4.6},
		{x = 3.1, y = 5.1},
		{x = 3.1, y = 5.5},
		{x = 2, y = 6.5},
		{x = 2, y = 6.8},
		{x = 2.2, y = 6.8},
		{x = 3.3, y = 6},
		{x = 3.1, y = 5.5},
		{x = 3.3, y = 6},
		{x = 3.4, y = 6.4},
		{x = 2.4, y = 7.3},
		{x = 2.5, y = 7.6},
		{x = 3.6, y = 6.9},
		{x = 3.4, y = 6.4},
		{x = 3.6, y = 6.9},
		{x = 3.7, y = 7.7},
		{x = 3.9, y = 8.2},
		{x = 2.9, y = 9.4},
		{x = 2.8, y = 9.5},
		{x = 2.8, y = 9.7},
		{x = 2.9, y = 9.8},
		{x = 3.8, y = 9.9},
		{x = 4.6, y = 9.9},
		{x = 4.7, y = 9.8},
		{x = 5.3, y = 9.8},
		{x = 5.4, y = 9.9},
		{x = 5.9, y = 9.9},
		{x = 7, y = 9.8},
		{x = 7, y = 9.4},
		{x = 6.1, y = 8.2},
		{x = 6.2, y = 7.7},
		{x = 6.4, y = 7},
		{x = 7.2, y = 7.6},
		{x = 7.4, y = 7.4},
		{x = 6.6, y = 6.5},
		{x = 6.4, y = 7},
		{x = 6.6, y = 6.5},
		{x = 6.6, y = 6},
		{x = 7.6, y = 6.7},
		{x = 7.7, y = 6.4},
		{x = 6.8, y = 5.5},
		{x = 6.6, y = 6},
		{x = 6.8, y = 5.5},
		{x = 6.8, y = 5.2},
		{x = 7.9, y = 5.9},
		{x = 8.1, y = 5.6},
		{x = 7.1, y = 4.6},
		{x = 6.8, y = 4.9},
		{x = 6.8, y = 5.2},
		{x = 6.8, y = 4.9},
		{x = 7.1, y = 4.6},
		{x = 8.3, y = 3.3},
		{x = 8.5, y = 2.8},
		{x = 9.4, y = 2.1},
		{x = 9.8, y = 1.4},
		{x = 9.9, y = 1},
		{x = 9.8, y = 0.5},
		{x = 9.4, y = 0.1},
		{x = 8.8, y = 0.5},
		{x = 8.3, y = 1.1},
		{x = 7.8, y = 0.5},
		{x = 7.7, y = 0},
		{x = 7.3, y = 0},
		{x = 6.6, y = 0.6},
		{x = 6.5, y = 1.2},
		{x = 6.6, y = 1.9},
		{x = 6.9, y = 2.3},
		{x = 7.3, y = 1.7},
		{x = 8.3, y = 1.1},
		{x = 7.3, y = 1.7},
		{x = 6.9, y = 2.3},
		{x = 7.2, y = 2.8},
		{x = 7.7, y = 2.9},
		{x = 8.5, y = 2.8},
		{x = 7.7, y = 2.9},
		{x = 7.2, y = 2.8},
		{x = 6.9, y = 3.4},
		{x = 7, y = 4},
		{x = 7.1, y = 4.6},
		{x = 7, y = 4},
		{x = 6.9, y = 3.4},
		{x = 6.6, y = 2.8},
		{x = 6.2, y = 2.4},
		{x = 6.2, y = 2.1},
		{x = 6.1, y = 2},
		{x = 5.8, y = 2},
		{x = 5.6, y = 2.2},
		{x = 5.6, y = 2.4},
		{x = 5.7, y = 2.5},
		{x = 6.1, y = 2.5},
		{x = 6.2, y = 2.4},
		{x = 6.2, y = 2.1},
		{x = 6.1, y = 2},
		{x = 5.8, y = 2},
		{x = 5, y = 2.1},
		{x = 4.2, y = 2},
		{x = 3.8, y = 2},
		{x = 3.7, y = 2.1},
		{x = 3.7, y = 2.4},
		{x = 3.8, y = 2.5},
		{x = 4.1, y = 2.5},
		{x = 4.2, y = 2.4},
		{x = 4.2, y = 2},
		{x = 3.8, y = 2},
		{x = 3.7, y = 2.1},
		{x = 3.7, y = 2.4},
		{x = 3.2, y = 3},
		{x = 2.9, y = 3.5},
		{x = 2.9, y = 4.4},
		{x = 3.1, y = 5.1},
		{x = 4, y = 5.9},
		{x = 4.9, y = 6},
		{x = 5.7, y = 6},
		{x = 6.3, y = 5.6},
		{x = 6.8, y = 5.2},
		{x = 6.8, y = 5.5},
		{x = 6.6, y = 6},
		{x = 6, y = 6.6},
		{x = 5, y = 6.8},
		{x = 4, y = 6.6},
		{x = 3.3, y = 6},
		{x = 3.4, y = 6.4},
		{x = 3.6, y = 6.9},
		{x = 4.1, y = 7.4},
		{x = 5, y = 7.6},
		{x = 5.8, y = 7.4},
		{x = 6.4, y = 7},
		{x = 6.6, y = 6.5},
		{x = 6.6, y = 6},
		{x = 6.8, y = 5.5},
		{x = 6.8, y = 5.2},
		{x = 6.3, y = 5.6},
		{x = 5.7, y = 6},
		{x = 4.9, y = 6},
		{x = 4, y = 5.9},
		{x = 3.1, y = 5.1},
		{x = 2.9, y = 4.6},
		{x = 2.9, y = 4.4},
		{x = 2.9, y = 3.5},
		{x = 2.6, y = 2.8},
		{x = 2.9, y = 2.4},
		{x = 3.2, y = 1.9},
		{x = 3.3, y = 1.2},
		{x = 3.1, y = 0.5},
		{x = 2.3, y = 0},
		{x = 1.9, y = 0.7},
		{x = 1.6, y = 1.1},
		{x = 0.5, y = 0.1},
		{x = 1.6, y = 1.1},
		{x = 2.2, y = 1.5},
		{x = 2.8, y = 2},
		{x = 2.9, y = 2.4},
		{x = 2.9, y = 2.4},
		{x = 2.9, y = 2.4}
	}
    -- TODO needs the rest of special chars like , . - = < > and so on?
}

local writingText = nil
local textToWrite = ""
local letterCount = 0
local iLetter = 0
local startPosX = 0
local startPosY = 0
local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local frames = 1
local letterSpacing = 20  -- spacing between letters
local sizeBoost = 5

local drawnLines = 1
local lastCoord = 1
local lastSecond = os.time()

local function WriteTextAction(_, _, args, data)
    local text = table.concat(args, " ")
    WriteText(text)
end

function widget:TextCommand(command)
    -- Command keywords and their shorthand counterparts
    local commands = {
        write_text = {full = 'write_text', short = 'wr', action = WriteText},
        text_scale = {full = 'text_scale', short = 'ts', action = function(size) sizeBoost = math.max(5, tonumber(size) or 5) end}
    }

    -- Split the command into words (by spaces)
    local words = {}
    for word in string.gmatch(command, "%S+") do
        table.insert(words, word)
    end

    -- The first word is the command keyword, the rest are arguments
    local keyword = words[1]
    local args = table.concat(words, " ", 2)  -- Combine the remaining words as arguments

    -- Helper function to match and process the command
    local function processCommand(keywordData)
        if keyword == keywordData.full or keyword == keywordData.short then
            keywordData.action(args)
            return true -- Command processed
        end
        return false
    end

    -- Process each command keyword
    for _, keywordData in pairs(commands) do
        if processCommand(keywordData) then
            break -- Exit once a command is processed
        end
    end
end

function widget:Initialize()
	widgetHandler:AddAction("write_text", WriteTextAction, nil, 'p')
end

function WriteText(text)
    if writingText then return end -- finish previous text first
  	local mx, my = Spring.GetMouseState()
    if not mx or not my then return end
    local _, coords = Spring.TraceScreenRay(mx, my, true)
    if not coords or not coords[1] then return end
    startPosX = coords[1]
    startPosY = coords[3]

    textToWrite = text
    letterCount = string.len(text)
    iLetter = 1
    frames = 1

    -- this is where text starts, now we need to shift it be half height and half width
    startPosX = startPosX + math.floor((-(((#text) * letterSpacing * sizeBoost - (sizeBoost*letterSpacing*0.33)))) * 0.5)
    startPosY = startPosY + math.floor((-(((1) * letterSpacing * sizeBoost - (sizeBoost*letterSpacing*0.33)))) * 0.5)
    -- ^ I honestly have no clue how I came up with this equation, I don't remember

    if startPosX < 0 then
      -- bump it
      startPosX = 0
    end
    -- TODO if its going to spill over right side of map, move it to left a bit?

    writingText = true
end

local function DrawLetter(letter)
    if (letter ~= " " and letter) then
        local coords = lineCoords[letter]
        if (coords) then
            local index = lastCoord
            --if not index or index >= #coords then index = 1 end
            for j = index, #coords - 1 do
                lastCoord = j
                if (drawnLines % 30) == 0 then -- limit drawing to 30 lines per second
                    if lastSecond == os.time() then
                        --Spring.Echo("Paused drawing "..drawnLines.." lines at "..os.time()..".")
                        lastSecond = os.time()
                        drawnLines = 1
                        return -- pause and wait until the next frame
                    else
                        lastSecond = os.time()
                    end
                end
                Spring.MarkerAddLine(
                    startPosX + (coords[j].x + (iLetter - 1) * letterSpacing) * sizeBoost,
                    0,
                    startPosY + coords[j].y * sizeBoost,
                    startPosX + (coords[j + 1].x + (iLetter - 1) * letterSpacing) * sizeBoost,
                    0,
                    startPosY + coords[j + 1].y * sizeBoost
                )
                drawnLines = drawnLines + 1
            end
            lastCoord = 1
        end
    end
    iLetter = iLetter + 1
end
local function DrawIt(frames)
  if (iLetter > letterCount) then
    writingText = nil
    drawnLines = 1
    return -- finished drawing
  else
    if ((frames % 10) == 0) then
      local letter = textToWrite:sub(iLetter, iLetter):upper()
      DrawLetter(letter)
    end
  end
end
function widget:DrawScreen()
    if not writingText then return end

    DrawIt(frames)
    frames = frames + 1
end
