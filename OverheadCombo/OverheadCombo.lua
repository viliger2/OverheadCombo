
-- TODO: 
-- 1. Add in-game setting for changing combopoint size, spacing values, etc
-- 2. I am thinking about adding green-yellow-red indication for 1,2-3,4-5 points
--	  Basically a traffic light-like option for combopoints

local COMBO_POINT_SIZE = 12 -- size of a single point
local COMBO_POINT_SPACING = 3 -- spacing between points

-- table is used for storing current combopoint value for different targets
-- since there can be more than one nameplate and we can actually have combopoint
-- on non-target unit via mouseover macros we need to store every single
-- nameplate's current combopoint value, just in case
local OverheadCombo_ComboPointsTable = {}

-- hiding everything
local function OverheadCombo_HideComboPoints()
	for i=1, OCFrame.maxComboPoints, 1 do
		OCFrame["comboPoint"..i].Highlight:SetAlpha(0)
		OCFrame["comboPoint"..i].Shine:SetAlpha(0)
	end
	OCFrame:Hide()
end

-- gets table row for unitId
-- used to get current max combopoint value for animating things
local function OverheadCombo_FindUnit(unitId)

	for i,v in ipairs(OverheadCombo_ComboPointsTable) do
		if v.unit == unitId then
			return v
		end	
	end
	
	return nil

end

-- clears table of current combopoints
local function OverheadCombo_ClearPointsTable()
	for i, tableline in ipairs(OverheadCombo_ComboPointsTable) do
		tableline.maxPoints = 0
	end
end

-- draws combopoints on top of nameplate
local function OverheadCombo_ShowComboPoints(comboPointsOwner)

	local nameplateComboPoints = comboPointsOwner.comboPoints 
	local nameplate = comboPointsOwner.nameplate
	local unit = comboPointsOwner.unit

	local comboPointsLastMaxValueElement = OverheadCombo_FindUnit(unit)

	-- we need unitComboPointMaxValue in order to animate only the very last combopoint
	local unitComboPointMaxValue, comboPoint

	OCFrame:SetPoint("CENTER", nameplate, "CENTER")

	if comboPointsLastMaxValueElement == nil then
		unitComboPointMaxValue = 0
	else
		unitComboPointMaxValue = comboPointsLastMaxValueElement.maxPoints
	end

	if (not OCFrame:IsShown()) then
		OCFrame:Show()
		UIFrameFadeIn(OCFrame, COMBOFRAME_FADE_IN)
	end
	
	for i=1, OCFrame.maxComboPoints, 1 do
		comboPoint = OCFrame["comboPoint"..i]
		if(i <= nameplateComboPoints) then	
			if ( i > unitComboPointMaxValue ) then						
				UIFrameFadeIn(comboPoint.Highlight, COMBOFRAME_HIGHLIGHT_FADE_IN, 0, 1)
			end
		else
		end
	end
	
	-- write current combopoint value to table so we can remember it for later
	if comboPointsLastMaxValueElement == nil then
		comboPointsLastMaxValueElement = {}
		comboPointsLastMaxValueElement.maxPoints = nameplateComboPoints
		comboPointsLastMaxValueElement.unit = nameplate.namePlateUnitToken
		table.insert(OverheadCombo_ComboPointsTable, comboPointsLastMaxValueElement)
	else
		comboPointsLastMaxValueElement.maxPoints = nameplateComboPoints	
	end

end

-- updates combo points
local function OverheadCombo_updateComboPoints()
	
	-- if nameplates are turned off then we hide the frame and do nothing
	if GetCVar("nameplateShowEnemies") == '0' then
		OverheadCombo_HideComboPoints()
		return
	end

	local nameplatesArray = C_NamePlate.GetNamePlates()
	local comboPointsOwner = nil

	-- we first look through entire nameplate array to check 
	-- if anyone of the units with nameplates have combopoints
	for i, nameplate in ipairs(nameplatesArray) do
		local nameplateComboPoints = GetComboPoints("player", nameplate.namePlateUnitToken)
		if nameplateComboPoints > 0 then
			comboPointsOwner = {}
			comboPointsOwner.nameplate = nameplate
			comboPointsOwner.unit = nameplate.namePlateUnitToken
			comboPointsOwner.comboPoints = nameplateComboPoints
			break
		end
	end

	-- if we found someone with combopoints - we draw frame on top of unit's nameplate
	if comboPointsOwner ~= nil then
		OverheadCombo_ShowComboPoints(comboPointsOwner)
	else
		OverheadCombo_ClearPointsTable()
		OverheadCombo_HideComboPoints()
	end

	-- done so combopoints disappear together with nameplate. we can try 
	-- setting nameplate as parent of our frame, that way once nameplate
	-- disappears combopoints will disappear with it, however I haven't 
	-- found a way to draw combopoints on top of the nameplate when 
	-- using that method, setting framelevel does nothing
	if(#nameplatesArray == 0) then
		OverheadCombo_ClearPointsTable()
		OverheadCombo_HideComboPoints()
	end

end

-- updates maximum combo points of unit and generally initilazes everything we need at the login
local function OverheadCombo_UpdateMax()

	OCFrame.maxComboPoints = UnitPowerMax("player", Enum.PowerType.ComboPoints)

	OverheadCombo_HideComboPoints()
	OverheadCombo_updateComboPoints()

end

-- creating each combo point as a frame, usning ComboPointTemplate template
-- template gives us exactly the same style of combopoints as ones used on Blizzard target frame
local function OverheadCombo_CreateTextures()

	for i = 1, 5, 1 do
		OCFrame["comboPoint"..i] = CreateFrame("Frame", "OverheadCombo_comboPoint"..i, OCFrame, "ComboPointTemplate")
		OCFrame["comboPoint"..i]:SetPoint("CENTER", OCFrame, "CENTER", 0 + (COMBO_POINT_SIZE + COMBO_POINT_SPACING) * (i - 1), 0)
		OCFrame["comboPoint"..i]:SetWidth(COMBO_POINT_SIZE)
		OCFrame["comboPoint"..i]:SetHeight(COMBO_POINT_SIZE)
		OCFrame["comboPoint"..i]:Show()
	end

end

local function EventHandler(self, event, sender, ...)

	if sender == "OverheadCombo" and event == "ADDON_LOADED" then
		OverheadCombo_CreateTextures()
		OverheadCombo_UpdateMax()
		OCFrame:UnregisterEvent("ADDON_LOADED")
	elseif event == "UNIT_POWER_FREQUENT" then
		-- TODO: wait for blizzard to fix this shit
		-- Lets imagine a scenario where you, as a rogue, have two targets on you at the same time
		-- So you Gouge one via mouseover macro and after that somehow (via Sinister or something) gain combopoint on your main one
		-- event UNIT_POWER_FREQUENT with unit COMBO_POINTS is not fired until you gain more combopoints than your mouseover target
		-- so instead of tracking events with unit COMBO_POINTS we just expect you to gain combo points on energy consumption
		-- it uses more CPU cycles and makes combo frames flicker but there is nothing I can do (I think)
		-- local unit = ...;
		-- if unit == "COMBO_POINTS" then
			OverheadCombo_updateComboPoints()
		-- end
	elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
		OverheadCombo_updateComboPoints()
	end
end

OCFrame = CreateFrame("Frame", "OverheadComboFrame", UIParent)
OCFrame:SetWidth(60)
OCFrame:SetHeight(12)
OCFrame:SetPoint("CENTER", UIParent, "CENTER")

OCFrame:RegisterEvent("ADDON_LOADED")
OCFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
OCFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
OCFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player");
OCFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player");

OCFrame:SetScript("OnEvent", EventHandler)
OCFrame:Hide()