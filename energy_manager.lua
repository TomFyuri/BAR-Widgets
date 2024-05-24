function widget:GetInfo()
	return {
		name         = "Energy Manager", -- more like anti-stall-help-for-newbies
		desc         = "Gives allies in trouble some energy. Also can adjust your energy-to-metal slider automatically.",
		author       = "Tom Fyuri",
		date         = "2024",
		license      = "GNU GPL, v2 or later",
		layer        = 0,
		enabled      = true
	}
end

-- Premise:
-- 1. I want to automatically put all excess energy into metal.
-- 2. I get beyond-all-reason annoyed if my ally with 8+ llts lets in raider army because they couldn't shoot. Same if my ally brings snipers/starlights/etc and they cannot shoot either... Also I want to boost their eco if I already have fusion and they started building their own.
-- Now, you may say "But wait, isn't energy spilling already shared?", haha, yes, top-down, but not equally! If one of your allies has higher rank than you and they have a billion energy converters, you will never get energy overflow shared from your allies, ever. Until this widget.

-- TODO detect whenever ally presses DGUN key and give them energy if its less than 5 times in a minute.
-- maybe 500 E ?
-- tricky to implement and possible to kinda abuse though

local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetTeamList = Spring.GetTeamList
local spGetTeamResources = Spring.GetTeamResources
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetPlayerInfo = Spring.GetPlayerInfo
local spShareResources = Spring.ShareResources
local spSendCommands = Spring.SendCommands
local spGetPlayerList = Spring.GetPlayerList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetAIInfo = Spring.GetAIInfo
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitHealth = Spring.GetUnitHealth
local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
local spEcho = Spring.Echo
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local math_ceil = math.ceil
local math_floor = math.floor

local adjustSlider = true -- do you want metal makers slider automated?
local dontStoreMoreThanThis = 9000 -- all energy beyond 9000 will be turned into metal
-- if you have calamity ^ this will become 30k instead

local energyThresholdDefault = 1000 -- income (without loss) should be at least this for sharing to work
local storageThresholdDefault = 1000 -- minimum E in storage before consider sending some -- realistically i don't send more than 10% of this -- also if you have calamity it automatically sets to 30k
local storagePartDefault = 0.10 -- how much of your income is reserved to be sent (counted from storage capacity instead of actual income btw)
local allyEnergyThresholdDefault = 0.10 -- less than 12% in storage means you are poor
-- we rely on mmLevel instead(!), however if it's unavailable then we use this value ^
local allyEnergyIncomeMaxDefault = 1000 -- but if your income is over 1000 than you are not poor
-- ^ if you dont want your eco/tech player to stall, consider increasing this a lot, otherwise only poor frontliners will get your energy-anti-stall measures
-- otherwise we automatically scale this higher once you have multiple afus

-- never send less than 200 in one batch, aim to send 500 or more ideally
local allyEnergySendAmount = 500
local allyEnergyMinSendAmount = 200

local myCalamityCount = 0

local armvulcDefID = UnitDefNames.armvulc.id
local corbuzzDefID = UnitDefNames.corbuzz.id
local legstarfallDefID = UnitDefNames.legstarfall.id

-- update rate is - every second
local updateRatePerSecond = 1
local updateFrameRate = updateRatePerSecond*30

local origNames = {}
local totalReceived = {}

-- verbosity stuff
local silentMode = true -- flip to true to never ever talk
local msgCount = 0
local energyDonated = 0
local energyDonatedMilestone = 100000
local energyDonatedMilestoneStep = 100000
local donationNoted = false
local warningNoted = false
local lessDenseReport = false
local supressDonationReports = false

local debug = false
local debug_text = ""
local gameover = false

local form = 24 --text format depends on screen size
local font, loadedFontSize

local vsx, vsy = Spring.GetViewGeometry()
local screenHeightOrg = 540
local screenWidthOrg = 540
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg
local screenX = (vsx * 0.5) - (screenWidth / 2)
local screenY = (vsy * 0.5) + (screenHeight / 2)
local widgetScale = (vsy / 1080)

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local function FindPlayerIDFromTeamID(teamID)
    local playerList = spGetPlayerList()
    for i = 1, #playerList do
        local playerID = playerList[i]
        local team = select(4,spGetPlayerInfo(playerID))
        if team == teamID then
            return playerID
        end
    end
    return nil
end
local function getTeamName(teamID)
    local _, _, _, isAITeam = spGetTeamInfo(teamID)
    if isAITeam then
        local _, _, _, aiName = spGetAIInfo(teamID)
        if aiName then
            local niceName = spGetGameRulesParam('ainame_' .. teamID)
            if niceName then
                return niceName
            else
                return aiName
            end
        else
            return "AI Team (" .. tostring(teamID)..")"
        end
    else
        local playerID = FindPlayerIDFromTeamID(teamID)
        if playerID then
            local playerName, _ = spGetPlayerInfo(playerID, false)
            return playerName
        else
            return "Unknown Team (" .. tostring(teamID)..")"
        end
    end
end
function GetTeamData()
    -- just in case get team data again
    myAllyTeamID = Spring.GetMyAllyTeamID()
    myAllyTeamList = Spring.GetTeamList(myAllyTeamID)
    -- grab names while we are up to it
    for _, teamID in ipairs(myAllyTeamList) do
        if myTeamID ~= teamID and spAreTeamsAllied(myTeamID, teamID) then
            local name = getTeamName(teamID)
            origNames[teamID] = name
        end
    end
end
function widget:Initialize()
  if(Spring.IsReplay() or Spring.GetSpectatingState()) then
    widgetHandler:RemoveWidget()
  end
	GetTeamData()
	SetupGui()
end
function widget:GameOver() -- doesnt really trigger? use it as fallback then, gameframe can track amount of enemy commanders which is default gameplay anyway
	if gameover then return end
	GameOverEvent()
	gameover = true
end
function GameOverEvent()
	if silentMode then return end
	-- final stats
	if (energyDonated >= 10000) then -- if less than 10k donated then who cares?
		spSendCommands("say a:Final E-Share stats: "..math_floor(energyDonated).." E re-distributed.")
		PrintStats()
	end
	-- joke
	local _,playerID,isDead,isAI = spGetTeamInfo(myTeamID, false)
	local name,active = spGetPlayerInfo(playerID, false)
	local jokeNumber = 99999
	if energyDonated > jokeNumber then jokeNumber = energyDonated end
  if not(isDead) and active and name then
		spSendLuaRulesMsg('msg:ui.playersList.chat.giveEnergy:amount='..math_floor(jokeNumber)..':name='..name)
		--spSendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveEnergy', { amount = math_floor(jokeNumber), name = name }))
	end
end
function widget:GameStart()
  -- dont do anything in 1v1
	GetTeamData()
  if (#myAllyTeamList <= 1) and not (adjustSlider) then
    widgetHandler:RemoveWidget()
  end
	SetupGui()
	-- joke
	if silentMode then return end
	local _,playerID,_,_ = spGetTeamInfo(myTeamID, false)
	local name,_ = spGetPlayerInfo(playerID, false)
	spSendLuaRulesMsg('msg:ui.playersList.chat.giveEnergy:amount='..math_ceil(99999)..':name='..name)
	--spSendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveEnergy', { amount = 99999, name = name }))
end
local function GetAIName(teamID)
    local _, _, _, name, _, options = spGetAIInfo(teamID)
    local niceName = spGetGameRulesParam('ainame_' .. teamID)

    if niceName then
        name = niceName

        --[[if Spring.Utilities.ShowDevUI() and options.profile then
            name = name .. " [" .. options.profile .. "]"
        end]]
    end

    return Spring.I18N('ui.playersList.aiName', { name = name })
end
local function AdjustMMLevelSlider()
		if not adjustSlider then return end
		local eCurrMy, eStorMy,_ , eIncoMy, eExpeMy, eShare,eSent,eReceived = spGetTeamResources(myTeamID, "energy")
		local energyLimit = dontStoreMoreThanThis
		if (myCalamityCount > 0) then energyLimit = 30000 end
		conversionRate = math_floor(energyLimit/eStorMy*100)
		if conversionRate < 15 then
			conversionRate = 15
		end
		if conversionRate > 75 then
			conversionRate = 75
		end

		--spEcho("debug: too much energy in storage "..eStorMy.."... setting slider to "..conversionRate)
		spSendLuaRulesMsg(string.format(string.char(137) .. '%i', conversionRate))

		-- update GUI (currently required patching of stock widget)
		if WG['topbar'] and WG['topbar'].updateTopBarEnergy then
			WG['topbar'].updateTopBarEnergy(conversionRate)
		end
		-- here's the thing, gui_top_bar.lua widget should be patched to include this code on line 2152:
		--[[
		WG['topbar'].updateTopBarEnergy = function(value)
			mmLevel = value
			updateResbar('energy')
		end]]
		-- if not, you do not get visual update of the slider, the widget works though
end
local function UpdateEnergy()
    --local currentIncome, currentStorage, currentPull = spGetTeamResources(myTeamID, "energy")
    local eCurrMy, eStorMy,_ , eIncoMy, eExpeMy, _,eSent,eReceived = spGetTeamResources(myTeamID, "energy")
    local teamList = myAllyTeamList
    local currentIncome = eIncoMy -eSent+eReceived -- - eExpeMy
    local currentIncomeWithLoss = eIncoMy -eSent+eReceived - eExpeMy
    local currentStorage = eCurrMy
    local alliesCount = 0
    local energyThreshold = energyThresholdDefault
		local storageThreshold = storageThresholdDefault
    local allyEnergyIncomeMax = allyEnergyIncomeMaxDefault
		local storagePart = storagePartDefault
    if (currentIncome >= 3000) then
      energyThreshold = 2000 -- ?
      allyEnergyIncomeMax = 2000
			-- twice the limits if I can afford it, more if I have absurd income
    end
		if (currentIncomeWithLoss < 0) then
				storageThreshold = storageThreshold + currentIncomeWithLoss -- so basically I actually have something to give?
		end
		if (myCalamityCount > 0) then
				if (storageThreshold < 30000) then
						storageThreshold = 30000
				end
		end
    --spEcho('ok?')-- '..currentIncome..' '..currentStorage..' '..eStorMy*0.9..' '..eCurrMy)
    -- Calculate the energy available for distribution
    --spEcho('lottery active')
    local energyPool = math_floor((eCurrMy-eExpeMy) * storagePart) -- * updateRatePerSecond
		if (currentIncome>=6000) then
				allyEnergyIncomeMax = math_floor(currentIncome/3)
				if (eStorMy >= 9000) and (energyPool < 1000) then
						energyPool = 1000
				-- minimum give away moment is now higher, basically a single fusion to give someone to leg up
				end
		end
		-- maybe give way at least 2k energy once I'm at 18k+ income? don't if I have calamity?
	if (energyPool < 1) then return end
    -- 10% of my total energy, so if its 1500, then I can share 150 freely per second
    -- or 750 per "update"! so in this case, one ally will get 500 energy
		if debug then
			debug_text = ""
			--debug_text = math_floor(eCurrMy).." "..math_floor(eStorMy).." "..math_floor(eIncoMy).." "..math_floor(eExpeMy).." "..math_floor(eShare).." "..math_floor(eSent).." "..math_floor(eReceived).."\n"
			debug_text = debug_text.."CurInc: "..math_floor(currentIncome).." eThres: "..math_floor(energyThreshold).."\n".."eStor: "..math_floor(currentStorage).." eStorThres: "..math_floor(storageThreshold).."\n".."CunIncWLoss: "..math_floor(currentIncomeWithLoss).." ".."ePool: "..energyPool
		end
		-- Check if energy income and storage meet the thresholds or I excess anyway
    if ((currentIncome > energyThreshold) or ((eStorMy*0.9>(eCurrMy-eExpeMy)) and (currentIncomeWithLoss>500))) and currentStorage > storageThreshold then
			-- never send energy if I have less than storageThreshold for myself
        -- Check if there are allies eligible for energy distribution
        local alliesReceivers = {}
        --for _, wplayer in ipairs(spGetPlayerList()) do
        for _, allyTeamID in ipairs(teamList) do
						if myTeamID ~= allyTeamID and spAreTeamsAllied(myTeamID, allyTeamID) then
					  --local name,_,_,allyTeamID = spGetPlayerInfo(wplayer, false)
            --if (name) and (allyTeamID) then
            --  spEcho(tostring(name)..' '..tostring(allyTeamID)..' '..tostring(myTeamID))
            --end
            local _,playerID,isDead,isAI = spGetTeamInfo(allyTeamID, false)
            local name,active = spGetPlayerInfo(playerID, false)
        		if isAI then
              name = GetAIName(allyTeamID)
            end
						if totalReceived[allyTeamID] == nil then
							totalReceived[allyTeamID] = 0
							if origNames[allyTeamID] == nil then
								origNames[allyTeamID] = name -- fallback in case widget restarted
							end
						end
						if debug then
							debug_text = debug_text.."\n".."AllyTeam: "..name.." dead:"..tostring(isDead).." active: "..tostring(active)
						end
            --spEcho(tostring(isDead)..' '..tostring(name)..' '..tostring(active)..' '..tostring(allyTeamID)..' '..tostring(myTeamID))
            if not(isDead) and active and name then
                local aCurrMy, aStorMy, _, aIncoMy, aExpeMy, aShare,aSent,aReceived = spGetTeamResources(allyTeamID, "energy")
								local allyEnergyThreshold = spGetTeamRulesParam(allyTeamID, 'mmLevel')
								if (allyEnergyThreshold == nil) then allyEnergyThreshold = allyEnergyThresholdDefault
								else
								--if (allyEnergyThreshold > 1) then
								--	allyEnergyThreshold = allyEnergyThreshold/100
									allyEnergyThreshold = allyEnergyThreshold - 0.02
									if (allyEnergyThreshold > 0.5) then
										allyEnergyThreshold = 0.5
									end
								end
								local allyIncome = aIncoMy + aShare+aSent+aReceived
                local allyIncomeWithLoss = aIncoMy + aShare+aSent+aReceived - aExpeMy
								if debug then
									debug_text = debug_text.."\n".."aIncWLoss: "..math_floor(allyIncomeWithLoss).." aIncMax: "..math_floor(allyEnergyIncomeMax).." aCurr: "..math_floor(aCurrMy-aExpeMy).." aThres: "..math_floor(allyEnergyThreshold * aStorMy).." mmLevel:"..math_floor(allyEnergyThreshold*100).."%"
								end
                if allyIncomeWithLoss < allyEnergyIncomeMax --[[and ((aCurrMy) < (allyEnergyThreshold * aStorMy))]] and ((aCurrMy-aExpeMy)<(aStorMy*allyEnergyThreshold)) and allyIncome <= currentIncome --[[and ((aCurrMy-aExpeMy)<(aStorMy*0.9))]] then
										-- if they have more income then me, they dont need donations...
                    -- if they have fusion - no donations required, lets be serious
                    alliesCount = alliesCount + 1
                    alliesReceivers[alliesCount] = {allyTeamID, name}
										if debug then
											debug_text = debug_text.." - OK!"
										end
                elseif debug then
									debug_text = debug_text.." - NOT OK!"
								end
            end
        end end
				if debug then
					debug_text = debug_text.."\nGiveCount: "..alliesCount..".\nGave so far: "..math_floor(energyDonated)

					local top3Allies,allyCount = getTop3Allies()
					if (allyCount > 0) then
						debug_text = debug_text.."\nTop "..allyCount.." Allies who had most energy donations received:"
						for _, allyTeamID in ipairs(top3Allies) do
						    debug_text = debug_text.."\nName: ".. origNames[allyTeamID] .." received: ".. math_floor(totalReceived[allyTeamID])  .." e."
						end
					end
				end

        --spEcho('valid allies '..alliesCount)
        -- Distribute energy to eligible allies
        if alliesCount > 0 then
            local energyToSend = math.max(allyEnergyMinSendAmount, math_floor(energyPool / alliesCount))
            if (energyToSend > (eCurrMy-eExpeMy)) then energyToSend = eCurrMy-eExpeMy-50 end -- shouldn't happen
						if (energyToSend < allyEnergyMinSendAmount) then return end -- cant send min amount right away

            for i=1, alliesCount do
            --for _, allyTeamID in ipairs(teamList) do
                local allyTeamID = alliesReceivers[i][1]
                local name = alliesReceivers[i][2]
                local aCurrMy, aStorMy, _, _, _, _,_,_ = spGetTeamResources(allyTeamID, "energy")
								local allyEnergyThreshold = spGetTeamRulesParam(allyTeamID, 'mmLevel')
								if (allyEnergyThreshold == nil) then allyEnergyThreshold = allyEnergyThresholdDefault
								else
								--if (allyEnergyThreshold > 1) then
								--	allyEnergyThreshold = allyEnergyThreshold/100
									allyEnergyThreshold = allyEnergyThreshold - 0.02
									if (allyEnergyThreshold > 0.5) then
										allyEnergyThreshold = 0.5 -- more than 50% in storage? you'll be fine...
									end
								end
								if (allyEnergyThreshold >= 0.05) then -- if ally somehow managed to set their mmLevel to 7% or below - well, never give them energy, they obviously don't need any.
                -- simply being, dont send MORE than storage capacity
                if ((energyToSend+aCurrMy) >= (aStorMy*allyEnergyThreshold)) then
                  energyToSend = (aStorMy*allyEnergyThreshold) - aCurrMy -- never overfill
                end
								if (energyToSend > allyEnergyMinSendAmount) then -- cant send min amount right
										energyDonated = energyDonated + energyToSend
		                spShareResources(allyTeamID, "energy", energyToSend)
										totalReceived[allyTeamID] = energyToSend + totalReceived[allyTeamID]
										if not(supressDonationReports) and not(silentMode) then
											if not(lessDenseReport) or (energyToSend>=1000) then
								spSendLuaRulesMsg('msg:ui.playersList.chat.giveEnergy:amount='..math_ceil(energyToSend)..':name='..name)
				                --spSendCommands("say a:" .. Spring.I18N('ui.playersList.chat.giveEnergy', { amount = math_ceil(energyToSend), name = name }))
												msgCount = msgCount + 1
											end
										end
		                energyPool = energyPool - energyToSend
		                if (energyPool < allyEnergyMinSendAmount) then
		                    break
		                end
								end end
            end
        end

				if not silentMode then
				if not donationNoted and (energyDonated >= 10000 or msgCount>=50) then
						donationNoted = true
						spSendCommands("say a:I have donated "..math_floor(energyDonated).." E so far, using 10% of my spare E income. Consider making your own fusion/afus.")
						spSendCommands("say a:As long as I have spare E, I'll always give you some E every second. Forget about E-stalling. ;)")
				end
				if not warningNoted and (energyDonated >= 25000 or msgCount>=100) then
						warningNoted = true
						spSendCommands("say a:I have donated "..math_floor(energyDonated).." E! <1000 E donations are now given silently, you are still getting them, no worries! ;)")
						-- TODO code so that donation msgs are instead 'in bulk' instead of every second spam...
						lessDenseReport = true
				end
				if energyDonated >= energyDonatedMilestone then
						energyDonatedMilestone = energyDonatedMilestone+energyDonatedMilestoneStep
						local top3Allies,allyCount = getTop3Allies()
						if (allyCount > 0) then -- hmm ?
							local lolText = ""
							for _, allyTeamID in ipairs(top3Allies) do
									if (totalReceived[allyTeamID] > 0) then
											lolText = lolText.. " ".. origNames[allyTeamID] .." [".. math_floor(totalReceived[allyTeamID])  .." E]"
									end
							end
							spSendCommands("say a:I have donated "..math_floor(energyDonated).." E."..lolText) -- Let's go!")
						else
							spSendCommands("say a:I have donated "..math_floor(energyDonated).." E.") -- Let's go!")
						end
				end
				if not supressDonationReports and (energyDonated >= 100000 or msgCount>=150) then
						supressDonationReports = true
						spSendCommands("say a:All E-share reports are now silent. (they still work)") -- Let's go!")
				end
				end
    end
end

local function isCalamity(unitDefID)
	return ((armvulcDefID == unitDefID) or (corbuzzDefID == unitDefID) or (legstarfallDefID == unitDefID))
end
function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam == myTeamID then
		if isCalamity(unitDefID) then
			local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
			if (buildProgress >= 1) then
				myCalamityCount = myCalamityCount + 1
			end
		end
	end
end
function widget:UnitDestroyed(unitID, unitDefID, unitTeam, _, _, _)
	if (unitTeam == myTeamID) then
		if isCalamity(unitDefID) then
			myCalamityCount = myCalamityCount - 1
			if (myCalamityCount < 0) then
				myCalamityCount = 0
			end
		end
	end
end
function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if (unitTeam == myTeamID) then
		if isCalamity(unitDefID) then
			myCalamityCount = myCalamityCount + 1
		end
	end
end
function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == myTeamID then
		widget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil)
	end
end
function widget:GameFrame(frame)
		if spGetSpectatingState() then return end
    if (frame % updateFrameRate) == 1 then
        UpdateEnergy()
				AdjustMMLevelSlider()

				if not gameover then -- fallback for gameover not triggering
						local EnemyComCount = spGetTeamRulesParam(myTeamID, "enemyComCount")
						--[[local allyComs = 0
					  local teamList = myAllyTeamList
						for _, teamID in ipairs(teamList) do
							if spAreTeamsAllied(myTeamID, teamID) then
								for unitDefID,_ in pairs(isCommander) do
									allyComs = allyComs + spGetTeamUnitDefCount(teamID, unitDefID)
								end
							end
						end]]
						if EnemyComCount <= 0 --[[or allyComs <= 0]] then
								GameOverEvent()
								gameover = true
						end
				end
    end
end
function widget:TextCommand(command)
    if (string.find(command, 'disable_energy_debug') == 1) or (string.find(command, 'energy_debug_disable') == 1) then
        debug = false
    elseif (string.find(command, 'enable_energy_debug') == 1) or (string.find(command, 'energy_debug_enable') == 1) then
        debug = true
		elseif (string.find(command, 'print_energy_stats') == 1) then
				spSendCommands("say a:E-Share stats: "..math_floor(energyDonated).." E re-distributed so far.")
        PrintStats()
    end
end
function PrintStats()
	local top3Allies,allyCount = getTop3Allies()
	if (allyCount > 0) then
		spSendCommands("say a:Top "..allyCount.." Allies who had most energy donations received:")
		for _, allyTeamID in ipairs(top3Allies) do
				spSendCommands("say a:Name: ".. origNames[allyTeamID] .." received: ".. math_floor(totalReceived[allyTeamID])  .." e.")
		end
	end
end
function getTop3Allies()
    local sortedAllies = {}
		local allyCount = 0
    for allyTeamID, energySpent in pairs(totalReceived) do
        table.insert(sortedAllies, {allyTeamID = allyTeamID, energySpent = energySpent})
				allyCount = allyCount+1
    end

    -- Sort the allies based on energy spent in descending order
    table.sort(sortedAllies, function(a, b)
        return a.energySpent > b.energySpent
    end)

    -- Get the top 3 allies
    local top3Allies = {}
		local topLimit = 3
		if allyCount < topLimit then
			topLimit = allyCount
		end
    for i = 1, topLimit do
        if sortedAllies[i] then
            table.insert(top3Allies, sortedAllies[i].allyTeamID)
        end
    end

    return top3Allies, topLimit
end

function SetupGui()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = math_floor(screenHeightOrg * widgetScale)
	screenWidth = math_floor(screenWidthOrg * widgetScale)

	screenX = math_floor((vsx * 0.4) - (screenWidth / 2))
	screenY = math_floor((vsy * 0.4) + (screenHeight / 2))

	font, loadedFontSize = WG['fonts'].getFont()

	--bGameStarted = true
	--widget:DrawScreen()
end
local spIsGUIHidden = Spring.IsGUIHidden
function widget:DrawScreen()
	if not debug then return end
	if not font then return end
  if spIsGUIHidden() then return end
	gl.Texture(false)
	local x = screenX --rightwards
	local y = screenY --upwards
	font:Begin()
	font:SetOutlineColor(0,0,0, 0.6)
	font:SetTextColor(1, 1, 1, 1)
	font:Print(debug_text, x, y, form)
	font:End()
end
