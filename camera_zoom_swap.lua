function widget:GetInfo()
	return {
		name         = "Camera Tools",
		desc         = "Hotkey to change zoom (like TAB does) and hotkey for fancy camera swap between two locations.",
		author       = "Tom Fyuri",
		date         = "2023",
		license      = "GNU GPL, v2 or later",
		layer        = 0,
		enabled      = true
	}
end

local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState
local spGetConfigInt   = Spring.GetConfigInt
local spSendCommands    = Spring.SendCommands
local zoomToggle = false
local cameraAnchors = {}
local cameraNum = 1
local savedCamera = 2
local function ToggleZoom()
	local cameraState = spGetCameraState()
	--[[for var,data in pairs(cameraState) do
		spEcho(var.." "..data)
	end]]
	if not cameraState then return end
	-- zooms in faster than it zooms out ?
	-- if true = zoom-in, if false = zoom-out
	local mx, my = spGetMouseState()
	local _, coords = spTraceScreenRay(mx, my, true)
	if not coords or not coords[1] then return end
	if (cameraState.dist > 12000) then -- already zoomed-out
		zoomToggle = true
	end
	if (zoomToggle) then
	-- move camera closer to where its supposed to be?
		cameraState.px,cameraState.py,cameraState.pz=coords[1],coords[2],coords[3]
		cameraState.dist = cameraState.dist - 8000 -- - (cameraState.dist * 0.25)
		--[[if (cameraState.dist < 2000) then
			cameraState.dist = 2000
		elseif (cameraState.dist > 2500) then
			cameraState.dist = 2500
    end]]
    cameraState.dist = 1550
	else
		cameraState.dist = cameraState.dist + 8000 -- + (cameraState.dist * 0.5)
	end
	spSetCameraState(cameraState)
	zoomToggle = not zoomToggle
end
local function SwapCamera()
  local cameraState = cameraAnchors[cameraNum]
  if not cameraState then -- no camera? save location
    cameraAnchors[cameraNum] = spGetCameraState()
  else
    cameraAnchors[savedCamera] = spGetCameraState()
  	-- make sure if last camera state minimized minimap to unminimize it
  	-- overview camera hides minimap
  	if spGetConfigInt("MinimapMinimize", 0) == 0 then
  		spSendCommands("minimap minimize 0")
  	end
    spSetCameraState(cameraState, 0)
    -- swap to it
  end
  if (cameraNum == 1) then
    cameraNum = 2
    savedCamera = 1
  else
    cameraNum = 1
    savedCamera = 2
  end
end
function widget:Initialize()
  widgetHandler:AddAction("toggle_zoom", ToggleZoom, nil, 'p')

  widgetHandler:AddAction("swap_camera", SwapCamera, nil, 'p')
end
