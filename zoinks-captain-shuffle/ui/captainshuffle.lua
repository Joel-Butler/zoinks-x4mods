--
-- Captain Shuffle script
-- Intended for use on the map menu, allows assignment of the highest ranking unassigned captain to a selected ship.
--
--

-- ffi setup

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	typedef uint64_t AIOrderID;
	typedef int32_t BlacklistID;
	typedef uint64_t BuildTaskID;
	typedef int32_t FightRuleID;
	typedef uint64_t FleetUnitID;
	typedef uint64_t MissionID;
	typedef uint64_t NPCSeed;
	typedef uint64_t TradeID;
	typedef int32_t TradeRuleID;
	typedef uint64_t UniverseID;

	const char* ConvertInputString(const char* text, const char* defaultvalue);
	uint64_t ConvertStringTo64Bit(const char* idstring);
	const char* FormatDateTimeString(int64_t time, const char* uiformat);
	int64_t GetCurrentUTCDataTime(void);
	const char* GetUserData(const char* name);
   const char* GetFleetName(UniverseID controllableid);
   uint64_t GetFleetUnit(UniverseID controllableid);
   uint32_t GetAllFleetUnits(FleetUnitID* result, uint32_t resultlen, UniverseID controllableid);
   uint32_t GetNumFleetUnitSubordinateFleetUnits(FleetUnitID fleetunitid, int subordinategroupid);
   uint32_t GetNumFleetUnitSubordinates(FleetUnitID fleetunitid, int32_t subordinategroupid);
   uint32_t GetFleetUnitSubordinateFleetUnits(FleetUnitID* result, uint32_t resultlen, FleetUnitID fleetunitid, int subordinategroupid);
   bool IsComponentClass(UniverseID componentid, const char* classname);
   const char* GetComponentName(UniverseID componentid);
   UniverseID CreateNPCFromPerson(NPCSeed person, UniverseID controllableid);

   typedef struct {
		FleetUnitID fleetunitid;
		const char* name;
		const char* idcode;
		const char* macro;
		BuildTaskID buildtaskid;
		UniverseID replacementid;
	} FleetUnitInfo;


]]


local modules = {}
Captain_Shuffle = {
	fleetUnits = {},
	numFleetUnits = 0,  
	fleetCaptains = {},
	numFleetCaptains =0,
	shuffleableEmployees = {},
	numShuffleableEmployees = 0
}

local function init()
   RegisterEvent("ZoinksCaptainShuffle", Captain_Shuffle.captainShuffle)
end


-- function captainShuffle is called from MD and expects its context to be the fleet owner.
-- from there it will iterate over sub fleet items and attempt to assign a better captain to each item based on
-- available employees - available meaining any better pilot currently working as a service, marine or unassigned role.
function Captain_Shuffle.captainShuffle(_, params)
   -- AddUITriggeredEvent("ZoinksShuffle", "Starting Lua")
   local controllable = C.ConvertStringTo64Bit(tostring(params))
	if(C.IsComponentClass(controllable, "ship")) then
		local subordinates = GetSubordinates(params)
		local actionText = ""
		Captain_Shuffle.fleetUnits = subordinates
		-- TODO: We currently only go one level deep - can we do this for all fleet units?
		-- could we filter for ship type as part of the request? 
		Captain_Shuffle.numFleetUnits = #subordinates
		if Captain_Shuffle.numFleetUnits > 0 then
			-- AddUITriggeredEvent("ZoinksShuffle", "It worked, got ".. tostring(Captain_Shuffle.numFleetUnits) .. " subordinates.")s
			-- TODO: Get captains and skills - create table of ships and captains - generate combined captain skill 
				Captain_Shuffle.loadCaptains()
			-- TODO: Create table of crew in Marine, Unassigned and Service roles sorted by combined captain skill (highest to lowest)
				Captain_Shuffle.loadEmployees()
				-- AddUITriggeredEvent("ZoinksShuffle", "Shufflable Employee count is: ".. tostring(Captain_Shuffle.numShuffleableEmployees) .. ".")
				Captain_Shuffle.sortEmployees()
				-- Lua ipars tables appear to start at 1
				-- AddUITriggeredEvent("ZoinksShuffle", "Empoyees sorted Top Captain candidate is: ".. Captain_Shuffle.shuffleableEmployees[1].name .. ".")
			-- TODO: For each captain in list, if the first (best) potential captain is better skilled, transfer. 
			for _, captain in ipairs(Captain_Shuffle.fleetCaptains) do
				--is the top shuffleableEmployee more skilled? 
				--yes : transfer and remove the transferred employee from the table. 
				-- no: continue to the next captain (our ordered list means we assume that if the top is no good, the rest will not be either)
				if(captain.skill < Captain_Shuffle.shuffleableEmployees[1].skill) then
					-- AddUITriggeredEvent("ZoinksShuffle", "Identified potential transfer from : " .. captain.name .. " To: " .. Captain_Shuffle.shuffleableEmployees[1].name .. ".")
					--now we need to figure out the best path to transfer... There's a UI example of this we could leverage...
					-- 1. Do we have room? If yes we use the MD command as demonstrated in menu_playerinfo.lua line 6696 (may not work, assumes person is already on ship.)
					-- Update: I think we actually want the process from menu_map.lua line 22920 for exchanging crew... This does require crew to be unassigned on a captainable ship though... 
					
					--Updated logic:
					-- 1. We know the person to transfer is on a ship and is *not* the captain. We'll temporarily make them one, and then set the real captain back. 
					local shuffleCaptain, shipname = GetComponentData(Captain_Shuffle.shuffleableEmployees[1].container, "assignedaipilot", "name")
					local inboundCaptain = C.ConvertStringTo64Bit(tostring(Captain_Shuffle.shuffleableEmployees[1].id))
					local shuffleShip64 = C.ConvertStringTo64Bit(tostring(Captain_Shuffle.shuffleableEmployees[1].container))
					local demoteCaptain = C.ConvertStringTo64Bit(tostring(captain.id))
					local shuffleCaptainName = GetComponentData(shuffleCaptain, "name")
					--local targetShip = captain.container
					local targetShip64 = C.ConvertStringTo64Bit(tostring(captain.containerId))
					-- local captainNPC = Captain_Shuffle.getCaptainNPCSeed(captain.containerId)
					-- update - entities do not appear to have seeds... not quite sure how we transfer them, maybe just with their entity id? 
					-- let's get all the default 'person' stuff
								-- get real NPC if instantiated

					-- AddUITriggeredEvent("ZoinksShuffle", "Transfer Plan for Captain: " .. shuffleCaptainName .. ", ship: ".. shipname  .. "New Pilot:" .. Captain_Shuffle.shuffleableEmployees[1].name ..  " seed: " .. tostring(Captain_Shuffle.shuffleableEmployees[1].id)  ..".")
					-- do we have a valid ship and existing captain... 
					if shuffleCaptain and IsValidComponent(shuffleCaptain) then
						if(C.IsComponentClass(shuffleShip64, "ship")) then 
							-- DebugError("Attempting to set employee : " .. tostring(inboundCaptain) .. " and ship: " ..tostring(shuffleShip64) .. " via MD." )
							-- C.SignalObjectWithNPCSeed(shuffleCaptain64, "npc__control_dismissed", inboundCaptain, shuffleShip64)
							-- we now make a list of NPC Seeds to move... we'll need the seed for the captain... 
							local leftnpcs = ffi.new("NPCSeed[?]", 1)
							local rightnpcs = ffi.new("NPCSeed[?]", 1)
							local rightnpcCount = 0

							local rightNPC = Captain_Shuffle.getLowSkillNPC(captain.containerId, "service")

							leftnpcs[0] = inboundCaptain
							
							if(rightNPC ~= nil) then 
								rightnpcs[0] = C.ConvertStringTo64Bit(tostring(rightNPC))
								rightnpcCount = 1
							end

							-- Ego example: local result = C.PerformCrewExchange2(
						    --		menu.contextMenuData.leftShip, 
							--		menu.contextMenuData.rightShip, 
							--		leftnpcs, 
							--		menu.contextMenuData.crew.left.moved, 
							--		rightnpcs, 
							--		menu.contextMenuData.crew.right.moved, 
							--		captainfromleft, 
							--		captainfromright, 
							--		exchangecaptains, 
							--		checkonly)
							local result = C.PerformCrewExchange2(shuffleShip64, targetShip64, leftnpcs, 1, rightnpcs, rightnpcCount, inboundCaptain, 0, false, false)
							local reason = ffi.string(result.reason)
							-- AddUITriggeredEvent("ZoinksShuffle", "Transfer Result: " .. reason .. ".")
							actionText = actionText .. captain.name .. " => " ..  Captain_Shuffle.shuffleableEmployees[1].name .. " => " .. shipname  .."\n"
						else
								DebugError("captainshuffle: failed setting new pilot.")
						end
						table.remove(Captain_Shuffle.shuffleableEmployees, 1)
					else
						-- AddUITriggeredEvent("ZoinksShuffle", "Invalid ship for listed shuffle.")
					end
				end
			end
			AddUITriggeredEvent("ZoinksShuffleResults", actionText)
			-- AddUITriggeredEvent("ZoinksShuffle", "Done with shuffle - moves are triggered via MD.")
		else
			DebugError("captainshuffle: No subordinates for Controllable " .. 
			tostring(params) .. " name: " .. 
			ffi.string(C.GetComponentName(controllable)) ..
			" fleet: " ..
			ffi.string(C.GetFleetName(controllable)) .. 
			" fleetunit " .. tostring(fleetunit)
			)
		end
   	else 
    	AddDebugErrorUITriggeredEvent("captainshuffle: Invalid object passed to Lua (ComponentClass is not 'ship')")
   	end
end


-- function: Captain_Shuffle.getLowSkillUnit(component) given a container object
-- returns a single NPC at the bottom of the skill rung in 'service' we can use to ensure an equivalent
-- transfer of crew to avoid overfilling ships.
-- note - there's some code duplication here i should clean up...

function Captain_Shuffle.getLowSkillNPC(component, rolename) 
	local rolemax = C.GetNumAllRoles()
	local shipPeopleTable = ffi.new("PeopleInfo[?]", rolemax)
	local shipPersonnel = 0
	local shipemployees = {}
	if Captain_Shuffle.isShip(component) and rolename == "service" or rolename == "marine" or rolename == "unassigned" then 
		-- get all ship people in our specified role - skill level is automatically by this role, so we can skip the additional calculation of skills.
		local shipPeopleCount = C.GetPeople2(shipPeopleTable, rolemax, component, true)
		for i = 0, shipPeopleCount - 1 do
			shipPersonnel = shipPersonnel + shipPeopleTable[i].amount
			local roleid = ffi.string(shipPeopleTable[i].id)
			local numtiers = shipPeopleTable[i].numtiers
			-- I'm unclear on the use of tiers here... we've got People, now we're inserting based on a new call of GetRoleTIerNPCs?
			if numtiers > 0 and roleid == rolename then
				local tiertable = ffi.new("RoleTierData[?]", numtiers)
				numtiers = C.GetRoleTiers(tiertable, numtiers, component, shipPeopleTable[i].id)
				for j = 0, numtiers - 1 do
					local numpersons = tiertable[j].amount
					if numpersons > 0 then
						local persontable = GetRoleTierNPCs(component, roleid, tiertable[j].skilllevel)
						for k, person in ipairs(persontable) do
							table.insert(shipemployees, { id = person.seed, name = person.name, combinedskill = person.combinedskill, roleid = roleid, container = component})
						end
					end
				end
			elseif roleid == "unassigned" and roleid == rolename then
				-- note: for unassigned we're just going to pick the first one. 
				local persontable = GetRoleTierNPCs(component, roleid, 0)
				--print("numpersons: " .. tostring(#persontable))
				for k, person in ipairs(persontable) do
					--print(k .. ": " .. person.name)
					table.insert(shipemployees, { id = person.seed, name = person.name, combinedskill = person.combinedskill, roleid = roleid, container = component})
				end
			end
		end
		if(#shipemployees > 0) then
			if(roleid == "unassigned" ) then 
			-- the first unassigned person will do.
				return shipemployees[1].id
			end
			-- let's sort first in ascending order of skill. 
			table.sort(shipemployees, 
				function (a, b) 
					return Captain_Shuffle.skillSorter(a, b, true)
				end
			)
			-- we should now have the least useful person in 'role' as item 1
			return shipemployees[1].id
		else
			-- we don't have any employees available of this type.
			return nil
		end		
	else
		-- invalid parameters passed (either we don't have a ship or an appropriate role), we'll just return nil.
		return nil
	end
end

function Captain_Shuffle.loadEmployees()
   -- We want people sorted by their skillset for pilot
   -- but we only want people in role Marine, Unassigned or Service
   -- unassigned: roleid == "unassigned"
   -- roleID for captain: aipilot
   -- 
   -- Ego do this by iterating over each ship and station... we'll need to do the same. 
   -- Derived from function menu.getEmployeeList() in menu_playerinfo.lua

   -- While the menu allows sorting by different skills, we just want good captains, 
   -- and want to exclude people doing an 'important' job - so effectively we want marines,
   -- service crew and unassigned. 

   -- TODO: It would be super nice to be able to also grab people from the terraforming buckets
   -- a task for later... 
   local targetPost = "aipilot"
   local roles = { "marine", "service", "unassigned"}
   local role = "post:aipilot"

	local rolemax = C.GetNumAllRoles()

	-- interesting approach - using the max of potential people to create inner arrays/tables. 
	local shipPeopleTable = ffi.new("PeopleInfo[?]", rolemax)

   -- this bit is straight from getEmployeeList()... 
   -- give the empire employee list an update to avoid referencing destroyed objects
	local numhiredpersonnel = 0
	local empireemployees = {}

	local numownedships = C.GetNumAllFactionShips("player")
	local allownedships = ffi.new("UniverseID[?]", numownedships)
	numownedships = C.GetAllFactionShips(allownedships, numownedships, "player")
	-- Note - from a C array/table object, we need to do from 0 n-1
	for i = 0, numownedships - 1 do
		local aship = ConvertStringTo64Bit(tostring(allownedships[i]))
		if(Captain_Shuffle.isShip(aship)) then
			local shipPeopleCount = C.GetPeople2(shipPeopleTable, rolemax, aship, true)
			for i = 0, shipPeopleCount - 1 do
				numhiredpersonnel = numhiredpersonnel + shipPeopleTable[i].amount
				local roleid = ffi.string(shipPeopleTable[i].id)
				local numtiers = shipPeopleTable[i].numtiers
				-- I'm unclear on the use of tiers here... we've got People, now we're inserting based on a new call of GetRoleTIerNPCs?
				if numtiers > 0 then
					local tiertable = ffi.new("RoleTierData[?]", numtiers)
					numtiers = C.GetRoleTiers(tiertable, numtiers, aship, shipPeopleTable[i].id)
					for j = 0, numtiers - 1 do
						local numpersons = tiertable[j].amount
						if numpersons > 0 then
							local persontable = GetRoleTierNPCs(aship, roleid, tiertable[j].skilllevel)
							for k, person in ipairs(persontable) do
								table.insert(empireemployees, { id = person.seed, name = person.name, combinedskill = person.combinedskill, roleid = roleid, container = aship})
							end
						end
					end
				elseif roleid == "unassigned" then
					local persontable = GetRoleTierNPCs(locship, roleid, 0)
					--print("numpersons: " .. tostring(#persontable))
					for k, person in ipairs(persontable) do
						--print(k .. ": " .. person.name)
						table.insert(empireemployees, { id = person.seed, name = person.name, combinedskill = person.combinedskill, roleid = roleid, container = aship})
					end
				end
			end
		end
	end

	-- let's ensure the skill value is set appropriately to our captain skill
	local filteredemployees = {}
	local numfilteredemployees = 0
	for _, employeedata in ipairs(empireemployees) do
		-- Everyone should be a person as that's all we've inserted... 
		employeedata.skill = C.GetPersonCombinedSkill(C.ConvertStringTo64Bit(tostring(employeedata.container)), C.ConvertStringTo64Bit(tostring(employeedata.id)), role, targetPost)
		table.insert(filteredemployees, employeedata)
		numfilteredemployees = numfilteredemployees +1
	end
	Captain_Shuffle.shuffleableEmployees = filteredemployees
	Captain_Shuffle.numShuffleableEmployees = numfilteredemployees
end

function Captain_Shuffle.isShip(component)
		--we're expecting a uint64_t that is a component.
		if(C.IsComponentClass(component, "ship")) then 
			
			local macro, isdeployable = GetComponentData(component, "macro", "isdeployable")
			local islasertower, ware = GetMacroData(macro, "islasertower", "ware")
			local isunit = C.IsUnit(component)
			-- Does this object contain stuff, while not being a deployable, laser tower or a unit...
			-- TODO: Is there a more efficient comparision here to determine ships with NPCs onboard? 
			return ware and (not isunit) and (not islasertower) and (not isdeployable) 
		else
			return false
		end
end

function Captain_Shuffle.loadCaptains()
	local captains = {}
	local numCaptains=0
	-- shipData should be a component object... 
	for _, shipData in ipairs(Captain_Shuffle.fleetUnits) do
		local idCode = ConvertIDTo64Bit(shipData)
		local shipname, pilot = GetComponentData(shipData, "name", "assignedaipilot")
		if pilot and IsValidComponent(pilot) then
			local name, combinedskill, poststring, postname = GetComponentData(pilot, "name", "combinedskill", "poststring", "postname")
			-- our Captain's combinedskill in their active role is the skill we care about, so we'll just assgin this to 'skill'
			table.insert(captains, { id = ConvertIDTo64Bit(pilot), type = "entity", name = name, skill = combinedskill, roleid = poststring, rolename = postname, container = shipData, containerId = idCode, containername = shipname})
			numCaptains = numCaptains + 1
		end
	end
	Captain_Shuffle.fleetCaptains = captains
	Captain_Shuffle.numFleetCaptains = numCaptains
end


function Captain_Shuffle.skillSorter(a, b, invert)
	if a.skill == b.skill then
		return a.name < b.name
	end
	if invert then
		return a.skill < b.skill
	else
		return a.skill > b.skill
	end
end

function Captain_Shuffle.sortEmployees()
	
	table.sort(Captain_Shuffle.shuffleableEmployees, 
		function (a, b) 
			return Captain_Shuffle.skillSorter(a, b, false)
		end
	)
end

--- init ---

init()
