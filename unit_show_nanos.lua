function widget:GetInfo() return {
	name    = "Unit Nano Ghost",
	desc    = "Show nano ghosts despite being mobile units...",
	author  = "Tom Fyuri",
	date    = "2023",
	license = "GNU GPL v2",
	layer   = 0,
	enabled = true,
} end

-- I got tired from not seeing nano ghosts when I do my bombing runs... how about you?
-- TODO: investigate and improve the algo of 'when to remove ghost?', unitDestroyed is unreliable if nano died beyond your LoS, so right now I keep ghost for some time and if nano is gone for over a minute and you dont see it - ghost is finally removed. However this only happens within your LoS area, if its beyond your fog of war - ghost stays.

local isNano = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not(unitDef.isFactory) and not(unitDef.canResurrect) and unitDef.isBuilder and unitDef.speed == 0  then
		isNano[unitDefID] = true
	end
end

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
local spIsGUIHidden = Spring.IsGUIHidden
local spGetGameSeconds = Spring.GetGameSeconds
local spIsPosInLos = Spring.IsPosInLos
local spGetUnitViewPosition	= Spring.GetUnitViewPosition

local activeNanos = {} -- basically just hold coordinates of enemy nanos
local activeNanosTimeout = {}

local yellow	= {1.0, 1.0, 0.3, 1.0}

local markingActive = true

function widget:Initialize()
	if (Spring.IsReplay() or spGetSpectatingState()) then
		widgetHandler:RemoveWidget()
	--else
	end
	--spEcho("OK?")
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

function widget:UnitEnteredLos(unitID, teamID) --, allyTeam, unitDefID)
	if spIsUnitAllied(unitID) or spGetSpectatingState() then
		return
	end

	local unitDefID = spGetUnitDefID(unitID)

	if not unitDefID then
		return
	end

	if isNano[unitDefID] then
		local x, y, z = spGetUnitPosition(unitID)
		activeNanos[unitID] = {x,y,z,teamID,unitDefID}
		activeNanosTimeout[unitID] = 0
		--spMarkerAddPoint(x,y,z,"nano here",true)
	end
end

function widget:GameFrame(frame)
	if frame % 90 == 15 then
		for unitID,_ in pairs(activeNanos) do
			local x, y, z = spGetUnitPosition(unitID)
			if x and z then -- and spIsPosInLos(x,y,z) then
				local unitDefID = activeNanos[unitID][5]
				activeNanos[unitID] = {x,y,z, spGetUnitTeam(unitID),unitDefID}
			else
				local x,y,z,_,_ = activeNanos[unitID]
				if x and z and spIsPosInLos(x,y,z) then
					activeNanosTimeout[unitID] = activeNanosTimeout[unitID]+2
					if (activeNanosTimeout[unitID]>=60) then
						activeNanos[unitID] = nil -- 60 seconds in Los and not seen? remove it.
						activeNanosTimeout[unitID] = nil
					end
				end
			end
		end
	end
end

-- if a unit destroyed, remove both actual and deferred markers and all the related info.
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	activeNanos[unitID] = nil
end

-- TODO add spIsPosInLos and monitor myTeamID, so dont draw nanos if you dont see them? or its fine either way?
function widget:DrawWorld()
  if not spIsGUIHidden() then
		for unitID,data in pairs(activeNanos) do
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
						gl.Text("Nano", -10.0, -15.0, 12.0)
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
