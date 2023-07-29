function widget:GetInfo()
    return {
        name      = "Unit Ally Buildings Tracker",
        desc      = "Notify allies of someone going T2 factory (+LRRA +P +AN).",
        author    = "Tom Fyuri",
        date      = "2023",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true
    }
end

-- and pinpointers, notify if 3 are done or if there are less than 3 - DONE
-- track your own fusion/afus completion, only pings yourself, so you dont forget to make more eco - DONE (this is local only)
-- track anti nukes that are way too close to each other before 30th minute - KINDA DONE -- sometimes it glitches :/

-- t2 ally factory notification only happens before 12th minute btw.

-- default global pinging mode is: local - only you see such pings
-- there is a command /luaui enable_global_pings to make all pings global and viewable by your allies
-- ^ you should probably only use it if you play with friends and they dont have this widget
-- (/luaui disable_global_pings flips it back to local only)

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
--local sputGetHumanName      = Spring.Utilities.GetHumanName
local spEcho = Spring.Echo
local spGetGameSeconds = Spring.GetGameSeconds

local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitStockpile = Spring.GetUnitStockpile
local spGetTeamResources = Spring.GetTeamResources

local firstFinished = false
local allyNoted = {}
local allyNotedLRRA = {}

local factoryNotificationStopAfter = 60*12 -- 12 minutes? ok no notification for factories after that.

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

local unitBuildOptions = {}
for udefID, def in ipairs(UnitDefs) do
	if #def.buildOptions > 0 then
		unitBuildOptions[udefID] = def.buildOptions
	end
end
local function isT2Factory(unitDefID)
  local unitDef = UnitDefs[unitDefID]
  if unitDef.isFactory and unitDef.customParams and unitDef.customParams.unitgroup == "buildert2" and unitBuildOptions[unitDefID] then
    return true
  end
  return false
end

local corbuzzDefID = UnitDefNames.corbuzz.id
local armvulcDefID = UnitDefNames.armvulc.id

local armtargDefID = UnitDefNames.armtarg.id
local cortargDefID = UnitDefNames.cortarg.id

local corantinukeDefID = UnitDefNames.corfmd.id
local armantinukeDefID = UnitDefNames.armamd.id

local allyPinpointerCounter = 0

local ANTI_NUKE_RANGE = 750
local GAME_FRAME_THRESHOLD = 30 * 60 * 30

local function isCalamity(unitDefID)
  return ((corbuzzDefID == unitDefID) or (armvulcDefID == unitDefID))
end
local function isPinPointer(unitDefID)
  return ((armtargDefID == unitDefID) or (cortargDefID == unitDefID))
end
local function isAntiNuke(unitDefID)
  return ((corantinukeDefID == unitDefID) or (armantinukeDefID == unitDefID))
end

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

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
  	if (spGetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end
    if spIsUnitAllied(unitID) and isPinPointer(unitDefID) then
        allyPinpointerCounter = allyPinpointerCounter - 1
        if (allyPinpointerCounter == 2) or (allyPinpointerCounter == 0) then
        	  local x, y, z = spGetUnitPosition(unitID)
        		spMarkerAddPoint (x, y, z, "Our team has lost a pinpointer! We have "..allyPinpointerCounter.." out of 3 required.", global_pings)
        end
    end
end
function widget:UnitCreated(unitID, unitDefID, unitTeam)
  	if (spGetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end
    if spIsUnitAllied(unitID) then
      if isAntiNuke(unitDefID) then
        local gameFrame = spGetGameFrame()
        if gameFrame < GAME_FRAME_THRESHOLD then
        -- if covering half then ask if you are sure building it
          local x, _, z = spGetUnitPosition(unitID)
          local units = spGetUnitsInCylinder(x, z, ANTI_NUKE_RANGE)
          local bestNuke = nil
          local bestBuildProgress = -1
          local bestMissiles = -1
          for _, nearbyUnitID in ipairs(units) do
            if nearbyUnitID ~= unitID and spIsUnitAllied(nearbyUnitID) and isAntiNuke(spGetUnitDefID(nearbyUnitID)) then
              local _, _, _, _, buildProgress = spGetUnitHealth(nearbyUnitID)
              if (bestBuildProgress < buildProgress) then
                bestBuildProgress = buildProgress
                bestNuke = nearbyUnitID
              elseif (buildProgress == 1) then
                local missiles,_,_ = spGetUnitStockpile(nearbyUnitID)
                bestBuildProgress = buildProgress
                if (bestMissiles < missiles) then
                  bestMissiles = missiles
                  bestNuke = nearbyUnitID
                end
              end
            end
          end
          if (bestNuke) then
            if (bestMissiles < 1) then
              bestMissiles = 0
            end
            if (bestBuildProgress < 0) then
              bestBuildProgress = 0
            end
            if (bestBuildProgress < 1) then
              spMarkerAddPoint(x, 0, z, "Note: There is already an antinuke within "..ANTI_NUKE_RANGE.." units of this one. (Construction: "..(bestBuildProgress*100).."%)", global_pings)
            else
              if (bestMissiles > 0) then
                spMarkerAddPoint(x, 0, z, "Note: There is already an antinuke within "..ANTI_NUKE_RANGE.." units of this one. (Stockpiled: "..bestMissiles..")", global_pings)
              else
                spMarkerAddPoint(x, 0, z, "Note: There is already an antinuke within "..ANTI_NUKE_RANGE.." units of this one.", global_pings)
              end
            end
          end
        end
      end
      if isPinPointer(unitDefID) then
    	  local x, y, z = spGetUnitPosition(unitID)
        allyPinpointerCounter = allyPinpointerCounter + 1
        if (allyPinpointerCounter == 1) then
          spMarkerAddPoint (x, y, z, "Our team is building a 1st pinpointer! I'll notify us when we have 3 or more.", global_pings)
        elseif (allyPinpointerCounter == 3) then
          spMarkerAddPoint (x, y, z, "Our team is building a 3rd pinpointer! We are going to have "..allyPinpointerCounter.." out of 3 required. They reduce radar's targets drifting. Thanks everyone!", global_pings)
        elseif (allyPinpointerCounter > 3) and (allyPinpointerCounter <= 12) then
            spMarkerAddPoint (x, y, z, "Our team is building a "..allyPinpointerCounter.."th pinpointer! We already have "..(allyPinpointerCounter-1).." out of 3 required.", global_pings)
        end
      elseif isT2Factory(unitDefID) and not(allyNoted[unitTeam]) and (factoryNotificationStopAfter > spGetGameSeconds()) then
    	  local x, y, z = spGetUnitPosition(unitID)

    		local markerText = UnitDefs[unitDefID].translatedHumanName
        -- sputGetHumanName(UnitDefs[unitDefID])
        local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
  			local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
  			local owner_name
  			if isAI then
  				local _,botName,_,botType = spGetAIInfo(unitTeam)
  				owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
  			else
  				owner_name = spGetPlayerInfo(playerID, false) or "nobody"
  			end
    		if buildProgress == 1 then
    			markerText = "" .. owner_name .. " has a T2 factory: "..markerText.."."
    		else
    			markerText = "" .. owner_name .. " is making a T2 factory: "..markerText .. " (" .. math.floor(100 * buildProgress) .. "% at " ..  os.date( "%M:%S", spGetGameSeconds()) .. ")."
    		end

    		local markColour = colourNames(spGetUnitTeam(unitID))
    		markerText = markColour .. markerText

    		spMarkerAddPoint (x, y, z, markerText, global_pings)

        allyNoted[unitTeam] = true
    elseif isCalamity(unitDefID) and not(allyNotedLRRA[unitTeam]) then
        local x, y, z = spGetUnitPosition(unitID)

        local markerText = UnitDefs[unitDefID].translatedHumanName
        -- sputGetHumanName(UnitDefs[unitDefID])
        local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
        local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
        local owner_name
        if isAI then
          local _,botName,_,botType = spGetAIInfo(unitTeam)
          owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
        else
          owner_name = spGetPlayerInfo(playerID, false) or "nobody"
        end
        if buildProgress == 1 then
          markerText = "" .. owner_name .. " has a Game Ender Artillery: "..markerText.."."
        else
          markerText = "" .. owner_name .. " is making a Game Ender Artillery: "..markerText .. " (" .. math.floor(100 * buildProgress) .. "% at " ..  os.date( "%M:%S", spGetGameSeconds()) .. ")."
        end

        local markColour = colourNames(spGetUnitTeam(unitID))
        markerText = markColour .. markerText

        spMarkerAddPoint (x, y, z, markerText, global_pings)

        allyNotedLRRA[unitTeam] = true
    end
  end
end

local function isReactor(unitDefID)
	local unitDef = UnitDefs[unitDefID]
  if unitDef.energyMake >= 300 then
    return true
  end
  return false
end

local myTeamID = Spring.GetMyTeamID()
function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
	--myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:TeamChanged(teamID)
	myTeamID = Spring.GetMyTeamID()
	--myAllyTeamID = Spring.GetMyAllyTeamID()
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  	if (spGetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end
    if unitTeam == myTeamID and isReactor(unitDefID) then
        local eCurrMy, eStorMy,_ , eIncoMy, eExpeMy, eShare,eSent,eReceived = spGetTeamResources(myTeamID, "energy")
        if eIncoMy>=18000 then return end -- if we have 6 afus income or more - dont care about this notification anymore

    	  local x, y, z = spGetUnitPosition(unitID)

    		local markerText = UnitDefs[unitDefID].translatedHumanName
  			markerText = "Your "..markerText.." is complete!"

    		local markColour = colourNames(unitTeam)
    		markerText = markColour .. markerText

    		spMarkerAddPoint (x, y, z, markerText, true) -- no need to spam allies about your own eco gains
    end
    if not(firstFinished) and spIsUnitAllied(unitID) and isT2Factory(unitDefID) and (factoryNotificationStopAfter > spGetGameSeconds()) then
    	  local x, y, z = spGetUnitPosition(unitID)

    		local markerText = UnitDefs[unitDefID].translatedHumanName
        -- sputGetHumanName(UnitDefs[unitDefID])
  			local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
  			local owner_name
  			if not isAI then
  				owner_name = spGetPlayerInfo(playerID, false) or "nobody"
    			markerText = "" .. owner_name .. " has finished a T2 factory: "..markerText.."! Consider buying T2 constructors! (if they sell, ping them)"

      		local markColour = colourNames(unitTeam)
      		markerText = markColour .. markerText

      		spMarkerAddPoint (x, y, z, markerText, global_pings)

          firstFinished = true
          --widgetHandler:RemoveCallIn("UnitFinished")
        end
    end
end

function widget:Initialize()
  if(Spring.IsReplay() or spGetSpectatingState()) then
    widgetHandler:RemoveWidget()
  end
end
