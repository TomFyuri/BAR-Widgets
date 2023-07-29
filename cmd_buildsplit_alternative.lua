function widget:GetInfo()
	return {
		name      = "Build Split - alternative",
		desc      = "Splits builds over cons, and vice versa (use shift+space to activate)",
		author    = "Niobium, Tom Fyuri",
		version   = "2023",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled = true  --  loaded by default?
	}
end

-- select builders, queue a bunch of stuff using shift, press space - orders are now split between builders.
-- this is very raw widget, don't use different t1/t2 builders for this.
-- also works on mine builders! so you can create minefields faster using this.

-- TODO it will likely crash if you select both factory and con and try to split orders between both
-- so I need to filter out such situations... somehow

local floor = math.floor
local spGetSpecState = Spring.GetSpectatingState
local spTestBuildOrder = Spring.TestBuildOrder
local spGetSelUnitCount = Spring.GetSelectedUnitsCount
local spGetSelUnitsSorted = Spring.GetSelectedUnitsSorted
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetUnitCommands = Spring.GetUnitCommands

local spEcho = Spring.Echo
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnits = Spring.GetSelectedUnits

local unitBuildOptions = {}
for udefID, def in ipairs(UnitDefs) do
	if #def.buildOptions > 0 then
		unitBuildOptions[udefID] = def.buildOptions
	end
end

--local buildID = 0
local buildLocs = {}
local buildCount = 0

local heldDown = false
local selectedUnits = {}

local gameStarted

local function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
		selectedUnits = spGetSelectedUnits()
end

function widget:SelectionChanged(sel)
	selectedUnits = sel
	heldDown = false
  buildCount = 0
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts) -- 3 of 3 parameters
	local areSpec = spGetSpecState()
	if areSpec then
		widgetHandler:RemoveWidget()
		return false
	end
	if spGetSelUnitCount() < 2 then return false end

	if (cmdID >= 0) then
		heldDown = false
		return false -- do nothing
	end
	--if not (cmdID < 0 and cmdOpts.shift and cmdOpts.meta) then return false end -- Note: All multibuilds require shift
	--if spGetSelUnitCount() < 2 then return false end

	--if #cmdParams < 4 then return false end -- Probably not possible, commented for now
	--if not cmdParams then cmdParams = {0,0,0,0} end
	if not cmdParams or not cmdParams[4] then return false end
	if spTestBuildOrder(-cmdID, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]) == 0 then return false end

	--buildID = -cmdID
	buildCount = buildCount + 1
	buildLocs[buildCount] = {-cmdID, cmdParams}

	--return true --intercept
end

function widget:KeyPress(key, mods, isRepeat)
  if key == 304 then
    heldDown = true
  end

	if key == 32 then
		Distribute()
	end
end

function widget:KeyRelease(key, mods)
  if heldDown and key == 304 then
    heldDown = false
  end
end

function Distribute()
--[[end

function widget:Update()]]
	if buildCount <= 1 or not(heldDown) then return end
	-- if its a single building, also do nothing

	--local selUnits = selectedUnits --spGetSelUnitsSorted()

	local builders = {}
	local builderCount = 0

	--[[
	for uDefID, uIDs in pairs(selUnits) do
		local uBuilds = unitBuildOptions[uDefID]
		if uBuilds then
			for bi=1, #uBuilds do
				if uBuilds[bi] == buildID then
					for ui=1, #uIDs do
						builderCount = builderCount + 1
						builders[builderCount] = uIDs[ui]
					end
					break
				end
			end
		end
	end]]

	--spEcho(#selectedUnits)
	for i = 1, #selectedUnits do
    local unitID = selectedUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
    local unitDef = UnitDefs[unitDefID]
		--spEcho(unitDefID)
    if unitDef and unitDef.isBuilder then
			local uBuilds = unitBuildOptions[unitDefID]
			if uBuilds then
				for bi=1, #uBuilds do
					for j=1, #buildLocs do
						--spEcho(uBuilds[bi].." "..buildLocs[j][1])
						if uBuilds[bi] == buildLocs[j][1] then
							--for ui=1, #uIDs do
							builderCount = builderCount + 1
							builders[builderCount] = unitID
							--end
							break
						end
					end
				end
			end
		end
	end
	--spEcho(builderCount.." distributing with "..buildCount)

	spGiveOrderToUnitArray(builders, CMD.STOP, {}, {})
	-- too expensive, lets remove ALL orders
	--[[
	for bi=1, builderCount do
		local unitID = builders[bi]
		local orders = spGetUnitCommands(unitID, -1)
		local removedCount = 0

		for i = #orders, 1, -1 do
		    local order = orders[i]
		    if order.id < 0 then
		        spGiveOrderToUnit(unitID, CMD.REMOVE, { order.tag }, {})
		        removedCount = removedCount + 1
		        if removedCount >= buildCount then
		            break
		        end
		    else
					break
				end
		end
	end]]
	-- so before we start, we simply remove buildCount last orders from the unit

	if buildCount > builderCount then -- more buildings than builders
		--spEcho('1 way?')
		local ratio = floor(buildCount / builderCount)
		local excess = buildCount - builderCount * ratio -- == buildCount % builderCount
		local buildingInd = 0
		for bi=1, builderCount do
			for r=1, ratio do
				buildingInd = buildingInd + 1
				local cmdID = buildLocs[buildingInd][1]
				local location = buildLocs[buildingInd][2]
				spGiveOrderToUnit(builders[bi], -cmdID, location, {"shift"})
			end
			if bi <= excess then
				buildingInd = buildingInd + 1
				local cmdID = buildLocs[buildingInd][1]
				local location = buildLocs[buildingInd][2]
				spGiveOrderToUnit(builders[bi], -cmdID, location, {"shift"})
			end
		end
	else -- less buildings than builders
		--spEcho('2 way?')
		local ratio = floor(builderCount / buildCount)
		local excess = builderCount - buildCount * ratio -- == builderCount % buildCount
		local builderInd = 0

		for bi=1, buildCount do
			local setUnits = {}
			local setCount = 0
			for r=1, ratio do
				builderInd = builderInd + 1
				setCount = setCount + 1
				setUnits[setCount] = builders[builderInd]
			end
			if bi <= excess then
				builderInd = builderInd + 1
				setCount = setCount + 1
				setUnits[setCount] = builders[builderInd]
			end

			local cmdID = buildLocs[bi][1]
			local location = buildLocs[bi][2]
			spGiveOrderToUnitArray(setUnits, -cmdID, location, {"shift"})
		end
	end

	buildCount = 0
end
