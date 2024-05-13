function widget:GetInfo() return {
	name    = "Unit Marker - alternative",
	desc    = "[v1.0.2] Marks spotted units of interest. Updates location and build progress.",
	author  = "Sprung, rollmops, Tom Fyuri",
	date    = "2024",
	license = "GNU GPL v2",
	layer   = 0,
	enabled = true,
} end

-- how does this widget work:
-- it will automatically mark first 10 t3 units (further t3 units are not marked) - each t3 unit only has a limit of 3 pings maximum, no more.
-- it will mark first air raid
-- it will mark first com drop
-- it will mark all gremlins once
-- it will mark ghosts
-- it will mark scout-riders in the first 3 minutes of the match
-- it will warn about enemy game ender arties
-- it will mark anti-nukes, nukes and tac silos

-- make sure to check out other notification/tracking widgets!

-- default global pinging mode is: local - only you see such pings
-- there is a command /luaui enable_global_pings to make all pings global and viewable by your allies
-- ^ you should probably only use it if you play with friends and they dont have this widget
-- (/luaui disable_global_pings flips it back to local only)

local SHOW_OWNER = { show_owner = true }
local MARK_EACH = { mark_each_appearance = true }
local DEFAULT = { }
--local UnitDefNames = UnitDefNames
local unitlistNames = {
	--t3
	corkorg = MARK_EACH,
	corjugg = MARK_EACH, -- not jug lol
	armthor = MARK_EACH,
	armbanth = MARK_EACH,

	-- nukes and game enders
	corsilo = { mark_each_appearance = true, show_owner = true, },
	armsilo = { mark_each_appearance = true, show_owner = true, },
	corbuzz = { mark_each_appearance = true, show_owner = true, },
	armvulc = { mark_each_appearance = true, show_owner = true, },

	-- ? sorta mini nuke?
	cortron = MARK_EACH,
	armemp = MARK_EACH,

	-- anti-nuke?
	corfmd = MARK_EACH,
	armamd = MARK_EACH,
	-- mobile
	armscab = MARK_EACH,
	cormabm = MARK_EACH,
	armcarry = MARK_EACH,
	armcarry2 = MARK_EACH,
	corcarry = MARK_EACH,
	corcarry2 = MARK_EACH,

	-- gremlin fucks
	armgremlin = MARK_EACH,

	-- spies, maybe gremlin tank later?
	armspy = MARK_EACH,
	corspy = MARK_EACH,
}
local armgremlinUnitDefID = UnitDefNames.armgremlin.id

local unitList = {}
local activeDefID = {}

-- associative arrays, where keys are 'unitID's, to save the position and the text of the last marker of a given unit.
local lastMarkerText = {}
local lastPos = {}

-- since issuing spMarkerErasePosition (to remove the old marker) and then spMarkerAddPoint (to make a new marker)
-- doesn't seem to work in cases where location is not changed (the new marker disappears after less than 1 second, I
-- think it is somehow related to both commands being processed in the same drawing frame?), I made an ugly hack,
-- namely, after spMarkerErasePosition, I defer the creation of the new marker: the text and the position of the new
-- marker are stored in markersToMake, (keys are again 'unitID's), then the script counts 'frames_defer' game frames,
-- and only then spMarkerAddPoint is issued.
local markersToMake = {}
local frames_defer = 15

local t3_unit_count = 0
local t3_unit_limit = 10
local t3_unit_pings_limit = 3 -- each unique unit will only get 3 pings, if the unit is still alive and got more than 3 pings - no more pings
local t3_unit_list = {}
local t3_unit_defs = {
	UnitDefNames.corkorg.id,
	UnitDefNames.corjugg.id,
	UnitDefNames.armthor.id,
	UnitDefNames.armbanth.id,
}
local gremlinAutoIgnore = {}

local armvulcDefID = UnitDefNames.armvulc.id
local corbuzzDefID = UnitDefNames.corbuzz.id
local function isCalamity(unitDefID)
	return ((armvulcDefID == unitDefID) or (corbuzzDefID == unitDefID))
end

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end
local comDropDetected = false

local markingActive = true

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
local spGetUnitTransporter = Spring.GetUnitTransporter
local spSendCommands = Spring.SendCommands

local prevX, prevY, prevZ = 0, 0, 0
local prevMarkX = {}
local prevMarkY = {}
local prevMarkZ = {}

local warnedAboutBombers = false
local airPlanesCount = 0
local WARN_BOMBER_COUNT = 4 -- more than 4 bombers? time to warn
local bomberUnitDefIDs = {
	UnitDefNames.armliche.id,
	UnitDefNames.armthund.id,
	UnitDefNames.armpnix.id,
	UnitDefNames.corshad.id,
	UnitDefNames.corhurc.id,
	UnitDefNames.corcrw.id,
}
-- we count gunships as well, whichever is first warned is fine
local WARN_GUNSHIP_COUNT = 6 -- more than 6 bombers? time to warn
local gunshipUnitDefIDs = {
	UnitDefNames.armkam.id,
	UnitDefNames.armblade.id,
	UnitDefNames.armbrawl.id,
	UnitDefNames.corape.id,
}
local airPlanesFound = {}
local unitPings = {}

local armfleaDefID = UnitDefNames.armflea.id
local corfavDefID = UnitDefNames.corfav.id
local armfavDefID = UnitDefNames.armfav.id
local function isScout(unitDefID)
	return ((unitDefID == armfleaDefID) or (unitDefID == corfavDefID))
end
local warnedAboutCalamity = false
local warnAboutScouts = true
local WARN_ABOUT_SCOUTS_DURATION = 60*3 -- 3 minutes

-- for additional feature: for markers of building in progress, add the game time at which the specified building progress was spotted
local spGetGameSeconds = Spring.GetGameSeconds

function widget:Initialize()
	if (Spring.IsReplay() or spGetSpectatingState()) then
		widgetHandler:RemoveWidget()
	--else
	end
end

for name, data in pairs(unitlistNames) do
	activeDefID[UnitDefNames[name].id] = true
	unitList[UnitDefNames[name].id] = data
	--spEcho("Activated: "..UnitDefNames[name].name.." - "..UnitDefNames[name].id)
end
-- add scouts temporarily
activeDefID[armfleaDefID] = true
unitList[armfleaDefID] = MARK_EACH
activeDefID[corfavDefID] = true
unitList[corfavDefID] = MARK_EACH
activeDefID[armfavDefID] = true
unitList[armfavDefID] = MARK_EACH

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
	local R255 = math.floor(nameColourR * 255)  --the first \255 is just a tag (not colour setting) no part caspGetSpectatingStaten end with a zero due to engine limitation (C)
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

local function refreshCallin()
	if not markingActive then
		widgetHandler:RemoveCallIn("UnitEnteredLos")
		widgetHandler:RemoveCallIn("UnitDecloaked")
	end
	if spGetSpectatingState() then
		widgetHandler:RemoveCallIn("UnitEnteredLos")
		widgetHandler:RemoveCallIn("UnitDecloaked")
	elseif markingActive then
		widgetHandler:UpdateCallIn('UnitEnteredLos')
		widgetHandler:UpdateCallIn("UnitDecloaked")
	end
end

widget.PlayerChanged = refreshCallin
widget.Initialize = refreshCallin
widget.TeamDied = refreshCallin

local function FindComDrop(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] and spGetUnitTransporter(unitID) then
		local x, y, z = spGetUnitPosition(unitID)
		local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
		local owner_name
		local markerText
		if isAI then
			local _,botName,_,botType = spGetAIInfo(unitTeam)
			owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
		else
			owner_name = spGetPlayerInfo(playerID, false) or "nobody"
		end
		markerText = "".. owner_name  .." is doing a com drop? A transport with loaded Commander detected!"
		local markColour = colourNames(unitTeam)
		markerText = markColour .. markerText
		spMarkerAddPoint (x, y, z, markerText, global_pings)
		comDropDetected = true
		return true
	end
	return false
end

local function FindAboutBombers(unitID, unitDefID, unitTeam)
	local airType = 0
	for i = 1, #gunshipUnitDefIDs do
		if unitDefID == gunshipUnitDefIDs[i] then
			airType = 1
			if airPlanesCount > WARN_GUNSHIP_COUNT then
				break
			end

			local duplicate = false
			for j = 1, #airPlanesFound do
				if airPlanesFound[j] == unitID then
					duplicate = true
					break
				end
			end

			if not duplicate then
				airPlanesFound[#airPlanesFound+1] = unitID
				airPlanesCount = airPlanesCount+1
			end
			break
		end
	end
	for i = 1, #bomberUnitDefIDs do
		if unitDefID == bomberUnitDefIDs[i] then
			airType = 2
			if airPlanesCount > WARN_BOMBER_COUNT then
				break
			end

			local duplicate = false
			for j = 1, #airPlanesFound do
				if airPlanesFound[j] == unitID then
					duplicate = true
					break
				end
			end

			if not duplicate then
				airPlanesFound[#airPlanesFound+1] = unitID
				airPlanesCount = airPlanesCount+1
			end
			break
		end
	end

	if (airPlanesCount >= WARN_BOMBER_COUNT) or (airPlanesCount >= WARN_GUNSHIP_COUNT) then
		local x, y, z = spGetUnitPosition(unitID)
		local _,playerID,_,isAI = spGetTeamInfo(unitTeam, false)
		local owner_name
		local markerText
		if isAI then
			local _,botName,_,botType = spGetAIInfo(unitTeam)
			owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
		else
			owner_name = spGetPlayerInfo(playerID, false) or "nobody"
		end
		if (airType == 1) then -- say its gunships
			markerText = "".. owner_name  .." is doing an air raid? At least 6 airplanes detected, gunships included."
		else -- say its bombers
			markerText = "".. owner_name  .." is doing an air raid? At least 4 bombers detected."
		end
		local markColour = colourNames(unitTeam)
		markerText = markColour .. markerText
		spMarkerAddPoint (x, y, z, markerText, global_pings)
		warnedAboutBombers = true
		return true
	end
	return false
end

local function MarkUnit(unitID, unitDefID, teamID)
	local data = unitList[unitDefID]

	-- Check if unitDefID is within t3_unit_defs
	for i = 1, #t3_unit_defs do
		if unitDefID == t3_unit_defs[i] then
			-- Check if t3_unit_list has reached t3_unit_limit
			if t3_unit_count > t3_unit_limit then
				-- Stop further execution of the function
				return -- dont ping t3 units anymore, 20 units is enough
			end
			-- Check if unitID is already in t3_unit_list
			local duplicate = false
			for j = 1, #t3_unit_list do
				if t3_unit_list[j] == unitID then
					duplicate = true
					break
				end
			end

			-- Add unitID to t3_unit_list if it's not a duplicate
			if not duplicate then
				t3_unit_list[#t3_unit_list+1] = unitID
				t3_unit_count = t3_unit_count+1
				
				if unitPings[unitID] and unitPings[unitID] < t3_unit_pings_limit then
					return -- no more than "t3_unit_pings_limit" per each t3 unit
				end
			end
			-- Exit the loop since the unitDefID has been found
			break
		end
	end

	if unitDefID == armgremlinUnitDefID then
		if gremlinAutoIgnore[unitID] then return end -- no notify gremlins more than once each
		gremlinAutoIgnore[unitID] = true
	end
	if (spGetGameSeconds() > WARN_ABOUT_SCOUTS_DURATION) then
		warnAboutScouts = false
		activeDefID[armfleaDefID] = nil
		unitList[armfleaDefID] = nil
		activeDefID[corfavDefID] = nil
		unitList[corfavDefID] = nil
		activeDefID[armfavDefID] = nil
		unitList[armfavDefID] = nil
		if (isScout(unitDefID)) then return end
	end

	local x, y, z = spGetUnitPosition(unitID)
	--spEcho("DEBUG 2: "..unitDefID)
	prevX, prevY, prevZ = prevMarkX[unitID], prevMarkY[unitID], prevMarkZ[unitID]
	if prevX == nil then
		prevX, prevY, prevZ = 0, 0, 0
	end

	if (math.sqrt(math.pow((prevX - x), 2) + (math.pow((prevZ - z), 2)))) >= 400 then
		-- marker only really uses x and z

		local markerText = data.markerText or UnitDefs[unitDefID].translatedHumanName.. " (" .. UnitDefs[unitDefID].translatedTooltip .. ")"
		-- sputGetHumanName(UnitDefs[unitDefID])
		if data.show_owner then
			local _,playerID,_,isAI = spGetTeamInfo(teamID, false)
			local owner_name
			if isAI then
				local _,botName,_,botType = spGetAIInfo(teamID)
				owner_name = (botType or "AI") .." - " .. (botName or "unnamed")
			else
				owner_name = spGetPlayerInfo(playerID, false) or "nobody"
			end
			markerText = markerText .. " (" .. owner_name .. ")"
		end

		local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
		if buildProgress < 1 then
			markerText = markerText .. " (" .. math.floor(100 * buildProgress) .. "% at " ..  os.date( "%M:%S", spGetGameSeconds()) .. ")"
		end

		local markColour = colourNames(spGetUnitTeam(unitID))
		markerText = markColour .. markerText
		-- if there were no markers issued for the given unitID, make a marker immediately
		if not lastMarkerText[unitID] then
			spMarkerAddPoint (x, y, z, markerText, global_pings)

		-- if there was a marker, but the text of it or the location of the unit has changed, remove the existing marker and save the details of the new marker, which will be actually made after 'frames_defer' game frames, see widget:GameFrame below).
		elseif markerText ~= lastMarkerText[unitID] or x ~= lastPos[unitID][1] or y ~= lastPos[unitID][2] or z ~= lastPos[unitID][3] then
			spMarkerErasePosition(lastPos[unitID][1], lastPos[unitID][2], lastPos[unitID][3])
			markersToMake[unitID] = { x, y, z, markerText, frames_defer }
		end
		if unitPings[unitID] == nil then unitPings[unitID] = 0 end
		unitPings[unitID] = unitPings[unitID] + 1

		-- save the text and position of the marker as last known.
		lastPos[unitID] = {x, y, z}
		lastMarkerText[unitID] = markerText

		prevX, prevY, prevZ = x, y, z
		prevMarkX[unitID] = prevX
		prevMarkY[unitID] = prevY
		prevMarkZ[unitID] = prevZ

		if isCalamity(unitDefID) and not warnedAboutCalamity and not(spGetSpectatingState()) and not global_pings then
			warnedAboutCalamity = true
			if buildProgress < 1 then
				spSendCommands("say a: The enemy team is making a Game Ender Artillery!")
			else
				spSendCommands("say a: Operational enemy Game Ender Artillery spotted!")
			end
		end
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
	if not warnedAboutBombers then
		if FindAboutBombers(unitID, unitDefID, teamID) then
			return
		end
	end
	if not comDropDetected then
		if FindComDrop(unitID, unitDefID, teamID) then
			return
		end
	end
	--spEcho("DEBUG 1: "..unitDefID.." - "..activeDefID[unitDefID])
	if not activeDefID[unitDefID] then
		return
	end

	local data = unitList[unitDefID]
	if not data then
		return
	end

	MarkUnit(unitID, unitDefID, teamID)
end

-- each game frame, loop over all the deferred markers and decrease their deferment counters. For a maker that its counter reached zero, issue marker command and remove its details from markersToMake
function widget:GameFrame()
	for u, m in pairs(markersToMake) do
		if m[5] > 0 then
			markersToMake[u][5] = markersToMake[u][5] - 1
		else
			spMarkerAddPoint ( m[1], m[2], m[3], m[4], global_pings)
			markersToMake[u] = nil
		end
	end
end

-- if a unit destroyed, remove both actual and deferred markers and all the related info.
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	markersToMake[unitID] = nil
	lastMarkerText[unitID] = nil
	if lastPos[unitID] then
		spMarkerErasePosition(lastPos[unitID][1], lastPos[unitID][2], lastPos[unitID][3])
	end
	lastPos[unitID] = nil
	if unitPings[unitID] then
		unitPings[unitID] = nil
	end
end
