-- this is proof of concept widget.
-- if you really want to use it with your friends, you can! just install the same version of this widget and make sure to bind a hotkey for "sell_unit" action. see below for more information.
function widget:GetInfo() return {
	name    = "Unit Market",
	desc    = "In-game market to buy/sell units within your own ally team. Fair price!",
	author  = "Tom Fyuri",
	date    = "2023",
	license = "GNU GPL v2",
	layer   = 0,
	enabled = true,
} end

-- What's the general idea, the pitch, the plan, etc:
-- Player A should be able to offer unit (any unit) for sale, for its fare metalCost market price. Player B should be able to offer to buy the unit. Player A will add debt to tab which Player B must pay off. Player B pays their debt to Player A off. Player A sees the debt is zero and sends the unit to player B. Player B now owns the unit and Player A is now metalCost richer. This loop should be able to go on and on.
-- Why? As a frontliner on ATG I'd like to buy fusion/afus/t2-cons from the backline instead of building my own early in the match.
-- I imagine it probably has a lot of other useful cases, for example you could automatically put all your own idle ressurection bots and idle cons (except nano-turrets) on sale. As well as all afus (unless its your last afus). Even your idle factory! Maybe you could also place all idle t3 units for sale for the same reason, idk? Posibilities are many.
-- You already have factories and build power to make them fast and easy, your other allies may not be able to do so, but they may have a lot of metal because they reclaimed enemies for example, this means they may side-step the process of making their own factories and rows of build-power and get the final product directly from you.
-- Finally, you may not have any of these ideas in mind, but this is probably the best we can have until squads (unit-share) is implemented. For meaningfuly transfering units to one another and supporting the team effort, while actually paying for the trouble.

-- Extra: would probably be kinda nice if whenever your ally reclaims your stuff alive, it is considered as being bought, you get the metal for it instead of them, this way, for example: I could reclaim my ally's windgen fields to get space, while they get the metal they spend on building them.

-- As for 'energy problems' when allies are overspending energy or turrets/units can't shoot. I've already made a separate widget that should automatically give just enough energy to your allies so that they don't stall. It gives less energy than they have energyConersion slider at, so the energy is not wasted (by both of you), but cons/turrets/etc are kept working - all for the team effort, no one shall e-stall!
-- I'll share this energy-ally-anti-stall (name pending) widget separately.

-- How this Unit Market works? How do I use it?

-- As a seller:
-- 1) select units and:
-- a) write in chat: /luaui sell_unit
-- b) write in chat: /sell_unit
-- c) bind a hotkey before hand: bind alt+c /sell_unit, then just press the hotkey to toggle sellable status.
-- Once you are done you (and your allies) will see that the unit is flashing green and is displaying the word "BUY" above itself. The price is exactly the same as the unit metalCost.

-- As a buyer:
-- a) if you are owner of the unit: /luaui buy_unit (debug purposes)
-- b) otherwise: double-click over an ally unit that your ally is selling. make sure you have resources first. in case you don't have enough metal - just double-click on it again once you have enough metal. your ally will wait for you, no worries.

-- special considerations: we ignore if the unit owner can receive all the metal without overflow, don't sell units if you can't store all that metal...

-- TODO:
-- UI to: 1) Highlight units that are currently being sellable 2) Double click over such units should send buy offer right away. -- DONE
-- If devs and players like this widget, it must be re-implemented on gadget level then instead of being "optional". Gadget should track payment receiving and unit transfer instead of it being client-sided and enforce compliance and honesty. -- Well?
-- There should be a UI button to display a GUI table show-casing all units that are being sold on the team with 'buy this unit' button -- I'd do it myself if widget is really really liked and re-made with gudget support, but at this moment there is no need for it.

--------------------------------
-- Probably not all functions are required, copy pasted from another widget.
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
local spSendCommands = Spring.SendCommands
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnitArray = Spring.SelectUnitArray
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()
local spAreTeamsAllied = Spring.AreTeamsAllied
local spSendLuaUIMsg = Spring.SendLuaUIMsg
local spGetUnitDefID = Spring.GetUnitDefID
local spValidUnitID = Spring.ValidUnitID
local spShareResources = Spring.ShareResources
local spGetTeamList = Spring.GetTeamList
local spGetCameraState = Spring.GetCameraState
local spGetGameSeconds = Spring.GetGameSeconds
local spEcho = Spring.Echo
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetTeamResources = Spring.GetTeamResources

local unitsOriginalTeam = {} -- Array to store units original team, in case captured? {UnitID => AllyTeamID}
local unitsUnitDefID = {} 	 -- Array to store units original unitdefid, in case captured? {UnitID => UnitDefID}
local unitsForSale = {}      -- Array to store units offered for sale {UnitID => metalCost}
local reservedUnits = {}     -- Array to keep track of reserved units {UnitID => AllyTeamID}
local debtByAllyTeamID = {}  -- Array to track the debt between allies {AllyTeamID => debtAmount}

function GetTeamData()
	for _, allyTeamID in ipairs(spGetTeamList(myAllyTeamID)) do
			debtByAllyTeamID[allyTeamID] = 0
			-- debts are zero
	end
end
function widget:Initialize()
	if (Spring.IsReplay() or spGetSpectatingState()) then
			widgetHandler:RemoveWidget()
	end
	GetTeamData()
	-- TODO, in 1vs1 or if you are alone in a team, unless for debug purposes - widget should auto-shutdown
	widgetHandler:AddAction("sell_unit", OfferToSellAction, nil, 'p')
end

function widget:RecvLuaMsg(msg, playerID)
		local msgFromTeamID = select(4,spGetPlayerInfo(playerID))
    local _,playerID,_,_ = spGetTeamInfo(msgFromTeamID, false)
    local name,_ = spGetPlayerInfo(playerID, false)
		--spEcho("test: "..tostring(msg))
    local words = {}
    for word in msg:gmatch("%S+") do
        table.insert(words, word)
    end
		if not spAreTeamsAllied(myTeamID, msgFromTeamID) then return end -- huh?

    if words[1] == "offer_to_sell" then
				local unitID = tonumber(words[2])
				if (spGetUnitTeam(unitID) == msgFromTeamID and spGetUnitTeam(unitID) == msgFromTeamID) then
						local unitDefID = spGetUnitDefID(unitID)
						if not unitDefID then return end -- whats wrong?
						local unitDef = UnitDefs[unitDefID]
						if not unitDef then return end -- whats wrong?
		        unitsForSale[unitID] = unitDef.metalCost
						unitsOriginalTeam[unitID] = spGetUnitTeam(unitID)
						unitsUnitDefID[unitID] = unitDefID
						spEcho(name.." is selling "..unitDef.translatedHumanName.." for "..unitDef.metalCost.." metal.")
				end

    elseif words[1] == "offer_to_buy" then
				local unitID = tonumber(words[2])
				if (spGetUnitTeam(unitID) == msgFromTeamID and spGetUnitTeam(unitID) == msgFromTeamID) then
		        local allyTeamID = msgFromTeamID
		        if unitsForSale[unitID] and (not reservedUnits[unitID] or reservedUnits[unitID] == allyTeamID) then -- same buyer can try to buy unit multiple times, in case of a failure (not enough metal on a first attempt)
								local unitDefID = spGetUnitDefID(unitID)
								if not unitDefID then return end -- whats wrong?
								local unitDef = UnitDefs[unitDefID]
								if not unitDef then return end -- whats wrong?
								debtByAllyTeamID[allyTeamID] = debtByAllyTeamID[allyTeamID] + unitDef.metalCost
		            reservedUnits[unitID] = allyTeamID
								-- debt tallied, please pay and get the unit
            		spSendLuaUIMsg("offer_to_sell_ack " .. unitID .. " " .. allyTeamID)
						    local _,owner_playerID,_,_ = spGetTeamInfo(unitsOriginalTeam[unitID], false)
						    local owner_name,_ = spGetPlayerInfo(owner_playerID, false)
								spEcho(name.." is offering to buy "..unitDef.translatedHumanName.." for "..unitDef.metalCost.." metal from "..owner_name..".")
		        end
				end

    elseif words[1] == "offer_to_sell_ack" then
				local unitID = tonumber(words[2])
				if (spGetUnitTeam(unitID) == msgFromTeamID) then
		        local ReceiverTeamID = tonumber(words[3])
						local unitDefID = spGetUnitDefID(unitID)
						if not unitDefID then return end -- whats wrong?
						local unitDef = UnitDefs[unitDefID]
						if not unitDef then return end -- whats wrong?
						if (ReceiverTeamID == myTeamID) then
								ShareResourcesWithPlayer(spGetUnitTeam(unitID), unitDef.metalCost)
						end
				end

    elseif words[1] == "offer_to_sell_abort" then
				local unitID = tonumber(words[2])
				if (spGetUnitTeam(unitID) == msgFromTeamID) then
						local unitDefID = spGetUnitDefID(unitID)
						if not unitDefID then return end -- whats wrong?
						local unitDef = UnitDefs[unitDefID]
						if not unitDef then return end -- whats wrong?
						spEcho(name.." is no longer selling "..unitDef.translatedHumanName.." for "..unitDef.metalCost.." metal.")
		        --local allyTeamID = msgFromTeamID
						ClearUnitData(unitID)
				end

    elseif words[1] == "resources_shared" then
        local ReceiverTeamID = tonumber(words[2])
        local metalAmount = tonumber(words[3])
				if (spAreTeamsAllied(myTeamID, msgFromTeamID)) then
						if ReceiverTeamID == myTeamID then
								debtByAllyTeamID[msgFromTeamID] = debtByAllyTeamID[msgFromTeamID] - metalAmount
						end
						local _,owner_playerID,_,_ = spGetTeamInfo(ReceiverTeamID, false)
						local owner_name,_ = spGetPlayerInfo(owner_playerID, false)
						spEcho(name.." paid "..metalAmount.." metal for the unit to "..owner_name..".")
						--[[if ReceiverTeamID == myTeamID then
								spEcho(name.." debt left: "..debtByAllyTeamID[msgFromTeamID])
						end]]
				end

    elseif words[1] == "unit_sold" then
				local unitID = tonumber(words[2])
				if (spAreTeamsAllied(myTeamID, msgFromTeamID)) then
		        local oldTeamID = tonumber(words[3])
						local unitDefID = spGetUnitDefID(unitID)
						if unitDefID then
						local unitDef = UnitDefs[unitDefID]
						if unitDef then
						local _,owner_playerID,_,_ = spGetTeamInfo(oldTeamID, false)
						local owner_name,_ = spGetPlayerInfo(owner_playerID, false)
						spEcho(name.." got the "..unitDef.translatedHumanName.." unit from "..owner_name..".")
						end end
					 	if spGetUnitTeam(unitID) == msgFromTeamID then
								reservedUnits[unitID] = nil -- sell successful
								ClearUnitData(unitID)
						end
				end
    end
end

function widget:GameFrame(frame)
		if (frame % 30 == 15) then -- once a second
				--spEcho("OK")
				-- loop through all reservedUnits, get their receiver team, if debt is zero - send unit
				for unitID, allyTeamID in pairs(reservedUnits) do
						if not spAreTeamsAllied(allyTeamID, myTeamID) then
								-- bug? unit belongs to enemy? or captured?
								--spEcho("debug: unit belongs to enemy?") -- ideally should transfer all units in one go...
								ClearUnitData(unitID)
						end
						--spEcho("reserved unit "..unitID.." and debt: "..debtByAllyTeamID[allyTeamID])
						if debtByAllyTeamID[allyTeamID] == 0 then
								--spEcho("debug: transfering unit") -- ideally should transfer all units in one go...

								local selectedUnits = spGetSelectedUnits()

								-- meh this too needs a gadget...
								if (#selectedUnits > 0) then
										spSelectUnitArray({unitID}, false)
										spShareResources(allyTeamID, "units") -- unit_sold should be sent by receiver

										spSelectUnitArray(selectedUnits, false)
								else
										spSelectUnitArray({unitID}, false)
										spShareResources(allyTeamID, "units") -- unit_sold should be sent by receiver
								end
						end
				end
		end
end

-- this should be what is tracked by a gadget (or provided by a gadget), because othewise if you are a dev, you can see the issue...
function ShareResourcesWithPlayer(allyTeamID, metalAmount)
		local myMetal = select(1, spGetTeamResources(myTeamID, "metal"))
		if (myMetal >= metalAmount) then
	    spShareResources(allyTeamID, "metal", metalAmount)
			spSendLuaUIMsg("resources_shared " .. allyTeamID .. " " .. metalAmount)
			local _,playerID,_,_ = spGetTeamInfo(allyTeamID, false)
			local name,_ = spGetPlayerInfo(playerID, false)
			spSendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveMetal', { amount = metalAmount, name = name }))
		end
end

function OfferToBuy(unitID)
		local unitDefID = spGetUnitDefID(unitID)
		if not UnitDefs[unitDefID] then return end
		local myMetal = select(1, spGetTeamResources(myTeamID, "metal"))
		local metalCost = UnitDefs[unitDefID].metalCost
		if (myMetal >= metalCost) then
	    spSendLuaUIMsg("offer_to_buy " .. unitID, "allies")
		end
end

-- can probably make metalCost an argument so players can set different prices -- TODO
function OfferToSell(unitID)
		if not unitsForSale[unitID] then
    	spSendLuaUIMsg("offer_to_sell " .. unitID, "allies")
		else
    	spSendLuaUIMsg("offer_to_sell_abort " .. unitID, "allies")
		end
end

function OfferToSellAction(unitID)
		local selectedUnits = spGetSelectedUnits()

		if (#selectedUnits > 0) then
				-- Iterate over the selected units and toggle the variable
				for _, unitID in ipairs(selectedUnits) do
						OfferToSell(unitID)
				end
		end
end

function widget:TextCommand(command)
    if (string.find(command, 'sell_unit') == 1) then
			local selectedUnits = spGetSelectedUnits()
		  for _, unitID in ipairs(selectedUnits) do
					OfferToSell(unitID)
			end
    elseif (string.find(command, 'buy_unit') == 1) then
			local selectedUnits = spGetSelectedUnits()
		  for _, unitID in ipairs(selectedUnits) do
					OfferToBuy(unitID)
			end
		end
end

function ClearUnitData(unitID)
		-- if unit is no longer sold then remove it from being sold
		unitsForSale[unitID] = nil
		-- if it was reserved, clear debt
		local reservedAllyTeamID = reservedUnits[unitID]
		local originalUnitDefID = unitsUnitDefID[unitID]
		local unitDef = UnitDefs[originalUnitDefID]
		if reservedAllyTeamID and unitsOriginalTeam[unitID] == myTeamID then
				debtByAllyTeamID[reservedAllyTeamID] = debtByAllyTeamID[reservedAllyTeamID] - unitDef.metalCost
		end
		reservedUnits[unitID] = nil
		unitsOriginalTeam[unitID] = nil
		unitsUnitDefID[unitID] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	ClearUnitData(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	ClearUnitData(unitID)
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if (newTeam == myTeamID and reservedUnits[unitID] == myTeamID) then
			spSendLuaUIMsg("unit_sold " .. unitID .. " " .. oldTeam, "allies")
	end
	--ClearUnitData(unitID)
end

--function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	--ClearUnitData(unitID)
--end

-------------------------------------------------------- UI code ---
local doubleClickTime = 1 -- Maximum time in seconds between two clicks for them to be considered a double-click
local maxDistanceForDoubleClick = 10 -- Maximum distance between two clicks for them to be considered a double-click
local rangeBuy = 50 -- Maximum range for units to buy over a double-click.

local lastClickCoords = nil
local lastClickTime = nil

function widget:MousePress(mx, my, button)
    if button == 1 then
        local _, coords = spTraceScreenRay(mx, my, true)

        if coords ~= nil then
            local currentTime = spGetGameSeconds()

            -- Check for a double-click
            if lastClickCoords ~= nil and lastClickTime ~= nil then
								local distance = math.floor(math.sqrt((lastClickCoords[1] - coords[1])^2 + (lastClickCoords[2] - coords[2])^2 + (lastClickCoords[3] - coords[3])^2))

                if currentTime - lastClickTime <= doubleClickTime and distance <= maxDistanceForDoubleClick then
                    -- Double-click detected
                    --Spring.Echo("Double-click detected!")

										local selectedUnits = spGetUnitsInCylinder(coords[1],coords[3],rangeBuy)
										for _, unitID in ipairs(selectedUnits) do
												if (unitID and unitsForSale[unitID]) then
														-- ignore your own units?
														local unitTeamID = spGetUnitTeam(unitID)
														if unitTeamID ~= myTeamID then -- comment this if if you are debugging
															OfferToBuy(unitID)
														end
												end
										end
										--
                end
            end

            -- Store the current click as the last click
            lastClickCoords = coords
            lastClickTime = currentTime
        end
    end
end

local spIsGUIHidden = Spring.IsGUIHidden
local animationDuration = 7
local animationFrequency = 3
function widget:DrawWorld()
	if spIsGUIHidden() or next(unitsForSale) == nil then
		return
	end

	local cameraState = spGetCameraState()
	local camHeight = cameraState and cameraState.dist or nil

	if camHeight > 9000 then
		return
	end

	for unitID, _ in pairs(unitsForSale) do
		local x, y, z = spGetUnitPosition(unitID)

		if not spIsUnitInView(unitID) or x == nil or y == nil or z == nil then
			return
		end

		local currentTime = spGetGameSeconds() % animationDuration
		local animationProgress = math.sin((currentTime / animationDuration) * (2 * math.pi * animationFrequency))

		local greenColorA	= {0.3, 1.0, 0.3, 1.0}
		local redColor = 1
		local greenColor = (0.8 + animationProgress * 0.2)

		local radiusSize = 25 + animationProgress * 25

		local ux, uy, uz = spGetUnitViewPosition(unitID)
		-- at this point ux,uy,uz should never be nil
		local yellow	= {1.0, 1.0, 0.3, 1.0}
		gl.PushMatrix()
			gl.Translate(ux, uy, uz)
			gl.Billboard()
			gl.Color(yellow)
			gl.BeginText()
				gl.Text("BUY", 12.0, 15.0, 24.0)
			gl.EndText()
		gl.PopMatrix()

		gl.Color(greenColorA)
		gl.DrawGroundCircle(x, y, z, radiusSize, 32)  -- Increase the radius based on animation progress

		local numSegments = 32
		local angleStep = (2 * math.pi) / numSegments
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			--gl.Color(1, greenColor, 0, (0.5 + animationProgress * 0.5))
			gl.Color(0.1, 1.0, 0.3, (0.5 + animationProgress * 0.5))
			gl.Vertex(x, y+25, z)
			for i = 0, numSegments do
				local angle = i * angleStep
				gl.Vertex(x + math.sin(angle) * radiusSize, y + 0, z + math.cos(angle) * radiusSize)
			end
		end) -- animmation part of the code was inspired by ally t2 lab flashing widget
	end
end
