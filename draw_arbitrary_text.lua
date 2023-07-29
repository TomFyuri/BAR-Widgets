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

-- WIP, severely missing the 1,2,3,4,5,6,7,8,9,0 symbol linemap.

-- Thanks socdoneleft for half of the character coord map though.
-- The rest of the code by Tom Fyuri.

local function WriteTextAction(_, _, args, data)
    local text = table.concat(args, " ")
    WriteText(text)
end

function widget:TextCommand(command)
    local keyword = 'write_text'
    if (string.find(command, keyword) == 1) then
        local text = string.sub(command, string.len(keyword) + 2) -- +2 to skip the space after 'write_text'
        WriteText(text)
    end
end

function widget:Initialize()
  --[[
  if(Spring.IsReplay() or Spring.GetSpectatingState()) then
    widgetHandler:RemoveWidget()
  end]]
	widgetHandler:AddAction("write_text", WriteTextAction, nil, 'p')
end

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
        {x = 0, y = 0},
        {x = 0, y = 5},
        {x = 10, y = 5},
        {x = 10, y = 10},
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
	      {x = 5, y = 8},
        {x = 6, y = 9},
        {x = 5, y = 10},
        {x = 4, y = 9},
        {x = 5, y = 8},
	      {x = 4, y = 0}
    }
    -- TODO numbers
    -- TODO needs special chars like , . - = < > and so on
}

local writingText = nil
local textToWrite = ""
local letterCount = 0
local iLetter = 0
local startPosX = 0
local startPosY = 0
local msx = Game.mapSizeX
local msz = Game.mapSizeZ

local frames = 0
local letterSpacing = 20  -- spacing between letters
local sizeBoost = 5

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
    iLetter = 0
    frames = 0

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
            for j = 1, #coords - 1 do
                Spring.MarkerAddLine(
                    startPosX + (coords[j].x + (iLetter - 1) * letterSpacing) * sizeBoost,
                    0,
                    startPosY + coords[j].y * sizeBoost,
                    startPosX + (coords[j + 1].x + (iLetter - 1) * letterSpacing) * sizeBoost,
                    0,
                    startPosY + coords[j + 1].y * sizeBoost
                )
            end
        --else -- this needs tweaking
        --    Spring.Echo("Error. "..letter.." is undefined character.")
        end
    end
end
local function DrawIt(frames)
  if (iLetter > letterCount) then
    writingText = nil
    return -- finished drawing
  else
    if (frames > 5) and ((frames % 10) == 0) then
      local letter = textToWrite:sub(iLetter, iLetter):upper()
      DrawLetter(letter)
      iLetter = iLetter + 1
    end
  end
end
function widget:DrawScreen()
    if not writingText then return end

    DrawIt(frames)
    frames = frames + 1
end
