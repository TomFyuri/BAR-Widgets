function widget:GetInfo()
    return {
        name      = "Unit Enemy Last Com Tracker",
        desc      = "Notify about Enemy Last Commander location.",
        author    = "Tom Fyuri",
        date      = "2023",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true
    }
end

-- I like to memorize where the commanders are. As well as pin a ghost on their last positions. It helps with bombing runs and to end games faster than usual.
-- it will also mark last two and last coms positions once to you or team, see below.

-- default global pinging mode is: local - only you see such pings
-- there is a command /luaui enable_global_pings to make all pings global and viewable by your allies
-- ^ you should probably only use it if you play with friends and they dont have this widget
-- (/luaui disable_global_pings flips it back to local only)

-- TODO rewrite so double com warning happens at different frames?

-- bug - commanders killed out of sight seem to leave ghosts stuck until the game end therefore:
-- IN-PROGRESS if activeComs pos in inLos for over one minute and there is no commander there - remove it.
-- it's unlikely for com to be there anyway without radar spotting them... unless they are cloaked? hmm hmm...

local EnemyComCount = 0
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local spGetAIInfo           = Spring.GetAIInfo
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetTeamInfo         = Spring.GetTeamInfo
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitHealth       = Spring.GetUnitHealth
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitTeam			= Spring.GetUnitTeam
local spIsUnitAllied        = Spring.IsUnitAllied
local spMarkerAddPoint      = Spring.MarkerAddPoint
local spMarkerErasePosition = Spring.MarkerErasePosition
local spGetTeamColor		= Spring.GetTeamColor
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
--local sputGetHumanName      = Spring.Utilities.GetHumanName
local spEcho = Spring.Echo
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitTeam = Spring.GetUnitTeam
local spGetTeamList = Spring.GetTeamList
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetTeamUnits = Spring.GetTeamUnits
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spIsGUIHidden = Spring.IsGUIHidden
local spIsPosInLos = Spring.IsPosInLos
local spGetUnitViewPosition	= Spring.GetUnitViewPosition
local spValidUnitID = Spring.ValidUnitID
local spSendCommands = Spring.SendCommands

local lastNotifyFrame = 0
local notifyCoolDown = 30*30*60 -- 1 minute

local frames_defer = 30
local prevX, prevY, prevZ = 0, 0, 0
local prevMarkX = {}
local prevMarkY = {}
local prevMarkZ = {}
local lastPos = {0,0,0}
local lastMarkerText = ""
local markerToMake = nil

local lastComID = nil

local notifiedLastTwoCommanders = false
local notifiedAboutLastCom = false
local warnedAboutLastEnemyCom = false

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local activeComs = {}
local activeComTimeout = {}

local global_pings = true -- false means yes

function widget:TextCommand(command)
    if (string.find(command, 'disable_global_pings') == 1) or (string.find(command, 'global_pings_disable') == 1) then
        global_pings = true
				spEcho("Global pings: disabled.")
    elseif (string.find(command, 'enable_global_pings') == 1) or (string.find(command, 'global_pings_enable') == 1) then
        global_pings = false
				spEcho("Global pings: enabled.")
    end
end

local function colourNames(teamID)
	local nameColourR, nameColourG, nameColourB, nameColourA = spGetTeamColor(teamID)
	local R255 = math.floor(nameColourR * 255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
	local G255 = math.floor(nameColourG * 255)
	local B255 = math.floor(nameColourB * 255)
	if R255 % 10 == 0 then
		R255 = R255 + 1
	end
	if G255 % 10 == 0 then
		G255 = G255 + 1
	end
	if B255 % 10 == 0 then
		B255 = B255 + 1
	end
	return "\255" .. string.char(R255) .. string.char(G255) .. string.char(B255) --works thanks to zwzsg
end

function widget:UnitDestroyed(unitID, _, _, _, _, _)
	activeComs[unitID] = nil

  if (Spring.GetSpectatingState()) then
    return -- widgetHandler:RemoveWidget()
  end

  if (lastComID) and (lastComID == unitID) then
    local x, y, z = spGetUnitPosition(unitID)
    if (x) then
      spMarkerAddPoint(x, y, z, "Owari da!", global_pings)
    elseif (prevX) then
      spMarkerAddPoint(prevX, prevY, prevZ, "Owari da!", global_pings)
    end
    -- else could not find last com
  end
end

function widget:UnitEnteredLos(unitID, teamID) --, allyTeam, unitDefID)
	if spIsUnitAllied(unitID) or spGetSpectatingState() then
		return
	end

	local unitDefID = spGetUnitDefID(unitID)

	if not unitDefID then
		return
	end

	if isCommander[unitDefID] then
		local x, y, z = spGetUnitPosition(unitID)
		activeComs[unitID] = {x,y,z,teamID,unitDefID}
    activeComTimeout[unitID] = 0 -- reset timeout timer because we can see unit
		--spMarkerAddPoint(x,y,z,"nano here",true)
	end
end

function notifyAboutLastEnemyCom(frame, unitID, unitDefID, unitTeam)
  if (Spring.GetSpectatingState()) then
    return -- widgetHandler:RemoveWidget()
  end

  local x, y, z = spGetUnitPosition(unitID)

	if (math.sqrt(math.pow((prevX - x), 2) + (math.pow((prevZ - z), 2)))) >= 100 then

    --local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
		local health,_,_,_,_ = spGetUnitHealth(unitID)
		local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
		local owner_name
    local markerText
		if isAI then
			local _,botName,_,botType = spGetAIInfo(unitTeam)
			owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
		else
			owner_name = spGetPlayerInfo(playerID, false) or "nobody"
		end
    if (health) and (health>0) then
      markerText = "Here's The Last Commander (".. health.."HP "..owner_name  ..")! Kill them and win the match!"
    else
      markerText = "Here's The Last Commander (".. owner_name  ..")! Kill them and win the match!"
    end
		local markColour = colourNames(unitTeam)
		markerText = markColour .. markerText

    if not lastMarkerText then
      spMarkerAddPoint (x, y, z, markerText, global_pings)

    -- if there was a marker, but the text of it or the location of the unit has changed, remove the existing marker and save the details of the new marker, which will be actually made after 'frames_defer' game frames, see widget:GameFrame below).
    elseif markerText ~= lastMarkerText or x ~= lastPos[1] or y ~= lastPos[2] or z ~= lastPos[3] then
      spMarkerErasePosition(lastPos[1], lastPos[2], lastPos[3])
      markerToMake = { x, y, z, markerText, frames_defer }
    end

    -- save the text and position of the marker as last known.
    lastPos = {x, y, z}
    lastMarkerText = markerText

    prevX, prevY, prevZ = x, y, z

    lastNotifyFrame = frame+notifyCoolDown

    if not(lastComID) then lastComID = unitID end
  end
end

function notifyAboutLastEnemyComs(frame, lastComs)
  if (Spring.GetSpectatingState()) then
    return -- widgetHandler:RemoveWidget()
  end

  for i=1, #lastComs do
    local unitID = lastComs[i][1]
    local unitDefID = lastComs[i][2]
    local unitTeam = lastComs[i][3]

    local x, y, z = spGetUnitPosition(unitID)

    --local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
		local health,_,_,_,_ = spGetUnitHealth(unitID)
		local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
		local owner_name
    local markerText
		if isAI then
			local _,botName,_,botType = spGetAIInfo(unitTeam)
			owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
		else
			owner_name = spGetPlayerInfo(playerID, false) or "nobody"
		end
    if (i==1) then
      if (health) and (health>0) then
        markerText = "Here's The 1st out of 2 Commanders (".. health.."HP "..owner_name  ..")!"
      else
        markerText = "Here's The 1st out of 2 Commanders (".. owner_name  ..")!"
      end
    else
      if (health) and (health>0) then
        markerText = "Here's The 2nd out of 2 Commanders (".. health.."HP "..owner_name  ..")!"
      else
        markerText = "Here's The 2nd out of 2 Commanders (".. owner_name  ..")!"
      end
    end
		local markColour = colourNames(unitTeam)
		markerText = markColour .. markerText

    spMarkerAddPoint (x, y, z, markerText, global_pings)
  end
end

function widget:GameFrame(frame)
  if ((frame % 30) == 15) then

    if (markerToMake) then
  		if markerToMake[5] > 0 then
  			markerToMake[5] = markerToMake[5] - 30
  		else
  			spMarkerAddPoint ( markerToMake[1], markerToMake[2], markerToMake[3], markerToMake[4], global_pings)
  			markerToMake = nil
  		end
    end
  end
  if ((frame % 60) == 15) then
		for unitID,_ in pairs(activeComs) do
      --if spValidUnitID(unitID) then
  			local x, y, z = spGetUnitPosition(unitID)
  			if x and z then -- and spIsPosInLos(x,y,z) then
  				local unitDefID = activeComs[unitID][5]
  				activeComs[unitID] = {x,y,z, spGetUnitTeam(unitID),unitDefID}
        else
          local x,y,z,_,_ = activeComs[unitID]
          if x and z and spIsPosInLos(x,y,z) then
            activeComTimeout[unitID] = activeComTimeout[unitID]+2
            if (activeComTimeout[unitID]>=60) then
              activeComs[unitID] = nil -- 60 seconds in Los and not seen? remove it.
              activeComTimeout[unitID] = nil
            end
          end
  			end
      --end
		end

    if (frame > lastNotifyFrame) then
      EnemyComCount = spGetTeamRulesParam(myTeamID, "enemyComCount")

      if not(notifiedAboutLastCom) and (EnemyComCount == 1) then
        if not (warnedAboutLastEnemyCom) then
            warnedAboutLastEnemyCom = true
            if not(global_pings) then -- consider saying this anyway...
            spSendCommands("say a:Enemy team is down to their last commander!")
            end -- remember: false means yes in this case ^
        end

        -- Loop through all teams
        local enemyTeams = spGetTeamList()

        -- Iterate through each enemy team
        for _, teamID in ipairs(enemyTeams) do
          if not(spAreTeamsAllied(myTeamID, teamID)) then  -- Skip your own ally team

            -- Get the units of the current enemy team
            local enemyUnits = spGetTeamUnits(teamID)

            -- Iterate through each enemy unit
            for _, unitID in ipairs(enemyUnits) do
              -- Check if the unit is a commander
              local unitDefID = spGetUnitDefID(unitID)
              if (unitDefID and isCommander[unitDefID]) then
                notifyAboutLastEnemyCom(frame, unitID, unitDefID, teamID)
                notifiedAboutLastCom = true
              end
            end
          end
        end
      elseif not(notifiedLastTwoCommanders) and (EnemyComCount == 2) then
        -- Loop through all teams
        local enemyTeams = spGetTeamList()

        local enemyCommanders = {}
        local enenyComsFound = 0
        -- Iterate through each enemy team
        for _, teamID in ipairs(enemyTeams) do
          if not(spAreTeamsAllied(myTeamID, teamID)) then  -- Skip your own ally team

            -- Get the units of the current enemy team
            local enemyUnits = spGetTeamUnits(teamID)

            -- Iterate through each enemy unit
            for _, unitID in ipairs(enemyUnits) do
              -- Check if the unit is a commander
              local unitDefID = spGetUnitDefID(unitID)
              if (unitDefID and isCommander[unitDefID]) then
                enemyCommanders[#enemyCommanders+1] = {unitID, unitDefID, teamID}
                enenyComsFound = enenyComsFound+1
                --notifyAboutLastEnemyCom(frame, unitID, unitDefID, teamID)
              end
            end
            if enenyComsFound == 2 then
              notifyAboutLastEnemyComs(frame, enemyCommanders)
              notifiedLastTwoCommanders = true
              break
            end
          end
        end
      end
    end
  end
end

--[[ -- todo draw commanders where they are last known locations
function widget:DrawWorld()
  if not spIsGUIHidden() then
		for unitID,data in pairs(activeComs) do
			if data then
				--local color = yellow
				local x,y,z,teamID = data
				gl.PushMatrix()
					gl.LoadIdentity()
					gl.Translate(x, y, z)
					gl.Rotate(0, 0, 1.0, 0 ) -- degrees don't matter
					gl.UnitShape(unitID, teamID, false, false, false)
				gl.PopMatrix()
				-- ^ based on DrawBuildingGhosts
			end
		end
	end
end]]

function widget:Initialize()
  if(Spring.IsReplay()) then -- or Spring.GetSpectatingState()) then
    widgetHandler:RemoveWidget()
  end
end

function widget:DrawWorld()
  if not spIsGUIHidden() then
		for unitID,data in pairs(activeComs) do
			if data then
				--local color = yellow
				local x,y,z --= spGetUnitPosition(unitID)
				local unitDefID = data[5]
				local teamID = data[4]
				--if not x then
					x = data[1]
					y = data[2]
					z = data[3]
				--end
				gl.PushMatrix()
					gl.Translate(x, y, z)
					gl.Billboard()
					gl.Color(spGetTeamColor(teamID)) -- or just make them 'yellow' ?
					gl.BeginText()
						gl.Text("Commander", -10.0, -15.0, 12.0)
					gl.EndText()
				gl.PopMatrix()

				gl.PushMatrix()
					gl.LoadIdentity()
					gl.Translate(x, y, z)
					gl.Rotate(0, 0, 1.0, 0 ) -- degrees don't matter
					gl.UnitShape(unitDefID, teamID, false, false, false)
				gl.PopMatrix()
				-- ^ based on DrawBuildingGhosts
			end
		end
	end
end
