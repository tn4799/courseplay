-- triggers
local _;

--- TODO: 	courseplay:updateAllTriggers() needs to be removed
---			and the triggers should be checked from the tables of Triggers at the end of the file.
---			Cleaning up all the possible raycast would also be needed. No idea what is happening there.


-- FIND TRIGGERS
function courseplay:doTriggerRaycasts(vehicle, triggerType, direction, sides, x, y, z, nx, ny, nz, raycastDistance)
	local numIntendedRaycasts = sides and 3 or 1;
	--[[if vehicle.cp.hasRunRaycastThisLoop[triggerType] and vehicle.cp.hasRunRaycastThisLoop[triggerType] >= numIntendedRaycasts then
		return;
	end;]]
	local callBack, debugChannel, r, g, b;
	if triggerType == 'tipTrigger' then
		callBack = 'findTipTriggerCallback';
		debugChannel = 1;
		r, g, b = 1, 0, 1;
	elseif triggerType == 'specialTrigger' then
		callBack = 'findSpecialTriggerCallback';
		debugChannel = 19;
		r, g, b = 0, 1, 0.6;
	elseif triggerType == 'fuelTrigger' then
		callBack = 'findFuelTriggerCallback';
		debugChannel = 19;
		r, g, b = 0, 1, 0.6;
	else
		return;
	end;

	local distance = raycastDistance or 10;
	direction = direction or 'fwd';

	--------------------------------------------------

	courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 1);
	
	if sides and vehicle.cp.tipRefOffset ~= 0 then
		if (triggerType == 'tipTrigger' and vehicle.cp.currentTipTrigger == nil) 
		or (triggerType == 'specialTrigger') 
		or (triggerType == 'fuelTrigger' and vehicle.cp.fuelFillTrigger == nil) then
			local x, _, z = localToWorld(vehicle.cp.directionNode, vehicle.cp.tipRefOffset, 0, 0);
			--local x, _, z = localToWorld(vehicle.aiTrafficCollisionTrigger, vehicle.cp.tipRefOffset, 0, 0);
			courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 2);
		end;

		if (triggerType == 'tipTrigger' and vehicle.cp.currentTipTrigger == nil) 
		or (triggerType == 'specialTrigger') 
		or (triggerType == 'fuelTrigger' and vehicle.cp.fuelFillTrigger == nil) then
			local x, _, z = localToWorld(vehicle.cp.directionNode, -vehicle.cp.tipRefOffset, 0, 0);
			--local x, _, z = localToWorld(vehicle.aiTrafficCollisionTrigger, -vehicle.cp.tipRefOffset, 0, 0);
			courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, 3);
		end;
	end;

	vehicle.cp.hasRunRaycastThisLoop[triggerType] = numIntendedRaycasts;
end;

function courseplay:doSingleRaycast(vehicle, triggerType, direction, callBack, x, y, z, nx, ny, nz, distance, debugChannel, r, g, b, raycastNumber)
	if courseplay.debugChannels[debugChannel] and  courseplay.debugChannels[courseplay.DBG_CYCLIC] then
		courseplay:debug(('%s: call %s raycast (%s) #%d'):format(nameNum(vehicle), triggerType, direction, raycastNumber), debugChannel);
	end;
	local num = raycastAll(x,y,z, nx,ny,nz, callBack, distance, vehicle);
	if courseplay.debugChannels[debugChannel] then
		if num > 0 then
			--courseplay:debug(('%s: %s raycast (%s) #%d: object found'):format(nameNum(vehicle), triggerType, direction, raycastNumber), debugChannel);
		end;
		cpDebug:drawLine(x,y,z, r,g,b, x+(nx*distance),y+(ny*distance),z+(nz*distance));
	end;
end;

function courseplay:updateAllTriggers()
	courseplay:debug('updateAllTriggers()', courseplay.DBG_TRIGGERS);

	--RESET
	if courseplay.triggers ~= nil then
		for k,triggerGroup in pairs(courseplay.triggers) do
			triggerGroup = nil;
		end;
		courseplay.triggers = nil;
	end;
	courseplay.triggers = {
		tipTriggers = {};
		fillTriggers = {};
		damageModTriggers = {};
		gasStationTriggers = {};
		liquidManureFillTriggers = {};
		sowingMachineFillTriggers = {};
		sprayerFillTriggers = {};
		waterReceivers = {};
		waterTrailerFillTriggers = {};
		weightStations = {};
		allNonUpdateables = {};
		all = {};
	};
	courseplay.triggers.tipTriggersCount = 0;
	courseplay.triggers.fillTriggersCount = 0;
	courseplay.triggers.allCount = 0;
	
	--[[
	courseplay.triggers.damageModTriggersCount = 0;
	courseplay.triggers.gasStationTriggersCount = 0;
	courseplay.triggers.liquidManureFillTriggersCount = 0;
	courseplay.triggers.sowingMachineFillTriggersCount = 0;
	courseplay.triggers.sprayerFillTriggersCount = 0;
	courseplay.triggers.waterReceiversCount = 0;
	courseplay.triggers.waterTrailerFillTriggersCount = 0;
	courseplay.triggers.weightStationsCount = 0;
	courseplay.triggers.allNonUpdateablesCount = 0;
	


	-- UPDATE
]]
	if g_currentMission.itemsToSave ~= nil then
		courseplay:debug('   check itemsToSave', courseplay.DBG_TRIGGERS);
		
		local counter = 0;
		for index,itemToSave in pairs (g_currentMission.itemsToSave) do
			counter = counter +1;
			local item = itemToSave.item
			if item.sellingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(item.sellingStation.unloadTriggers) do
					if unloadTrigger.baleTriggerNode then
						local triggerId = unloadTrigger.baleTriggerNode;
						trigger = {
									triggerId = triggerId;
									acceptedFillTypes = item.sellingStation.acceptedFillTypes;
									unloadTrigger = unloadTrigger;				
								}
						
						courseplay:debug(string.format('    add %s(%s) to tipTriggers',item.sellingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					end
				end
			end
			
			if item.bga and item.bga.bunker then
				courseplay:debug('   found a BGA', courseplay.DBG_TRIGGERS);
				local trigger = {}
				local fillTypes ={}
				for i=1, #item.bga.bunker.slots do
					for filltype,_ in pairs (item.bga.bunker.slots[i].fillTypes) do
						fillTypes[filltype] = true
						courseplay:debug(string.format('     add %d(%s) from slot%d to acceptedFilltypes',filltype, g_fillTypeManager.indexToName[filltype] , i), courseplay.DBG_TRIGGERS);
						--item.bga.bunker.slots[x].fillTypes[filltype]
					end
				end
				for _,unloadTrigger in pairs(item.bga.bunker.unloadingStation.unloadTriggers) do
					if unloadTrigger.baleTriggerNode then
						local triggerId = unloadTrigger.baleTriggerNode;
						trigger = {
									triggerId = triggerId;
									acceptedFillTypes = fillTypes;
									unloadTrigger = unloadTrigger;
									unloadingStation = item.bga.bunker.unloadingStation;
								}
						
						courseplay:debug(string.format('    add %s(%s) to tipTriggers',item.bga.bunker.unloadingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					end
					if unloadTrigger.exactFillRootNode then
						local triggerId = unloadTrigger.exactFillRootNode;
						trigger = {
									triggerId = triggerId;
									acceptedFillTypes = fillTypes;
									unloadTrigger = unloadTrigger;
									unloadingStation = item.bga.bunker.unloadingStation;									
								}
						
						courseplay:debug(string.format('    add %s(%s) to tipTriggers',item.bga.bunker.unloadingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					end
				end
				courseplay:debug('   BGA End -------------', courseplay.DBG_TRIGGERS);
			end			
		end
		courseplay:debug(('  %i in list'):format(counter), courseplay.DBG_TRIGGERS);
	end


	-- placeables objects
	if g_currentMission.placeables ~= nil then
		courseplay:debug('   check placeables', courseplay.DBG_TRIGGERS);
		local counter = 0
		for placeableIndex, placeable in pairs(g_currentMission.placeables) do
			counter = counter +1 

			if placeable.unloadingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(placeable.unloadingStation.unloadTriggers) do
					local triggerId = unloadTrigger.exactFillRootNode;
					trigger = {
								triggerId = triggerId;
								acceptedFillTypes = placeable.storages[1].fillTypes;
								unloadingStation = placeable.unloadingStation;
								unloadTrigger = unloadTrigger;
							}
					
					courseplay:debug(string.format('    add %s(%s) to tipTriggers',placeable.unloadingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
					courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
				end
			end
			
			
			if placeable.sellingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(placeable.sellingStation.unloadTriggers) do
					local triggerId = unloadTrigger.exactFillRootNode or unloadTrigger.baleTriggerNode;
					trigger = {
								triggerId = triggerId;
								acceptedFillTypes = placeable.sellingStation.acceptedFillTypes;
								unloadTrigger = unloadTrigger;				
							}
					courseplay:debug(string.format('    add %s(%s) to tipTriggers',placeable.sellingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
					courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
				end
			end
			
			if placeable.modulesById ~= nil then
				for i=1,#placeable.modulesById do
					local myModule = placeable.modulesById[i]
					--[[print(string.format("myModule[%i]:",i))
					for index,value in pairs (myModule) do
						print(string.format("__%s:%s",tostring(index),tostring(value)))
					end]]
					if myModule.unloadPlace ~= nil then
							local triggerId = myModule.unloadPlace.target.unloadPlace.exactFillRootNode;
							local trigger = {	
												triggerId = triggerId;
												acceptedFillTypes = myModule.unloadPlace.fillTypes;
												--capacity = myModule.fillCapacity;
												--fillLevels = myModule.fillLevels;
											}
							courseplay:debug(string.format('    add %s(%s) to tipTriggers',myModule.moduleName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
							courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');							
					end
										
					if myModule.feedingTrough ~= nil then
						local triggerId = myModule.feedingTrough.target.feedingTrough.exactFillRootNode;
						local trigger = {	
											triggerId = triggerId;
											acceptedFillTypes = myModule.feedingTrough.fillTypes;
											--capacity = myModule.fillCapacity;
											--fillLevels = myModule.fillLevels;
										}
						courseplay:debug(string.format('    add %s(%s) to tipTriggers',myModule.moduleName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
						courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
					end
					if myModule.loadPlace ~= nil then                                            
                        local triggerId = myModule.loadPlace.triggerNode;                        						      
						courseplay:debug(string.format('    add %s(%s) to fillTriggers',myModule.moduleName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
						courseplay:cpAddTrigger(triggerId, myModule.loadPlace, 'fillTrigger');
                    end					
				end
			end
			
			if placeable.buyingStation ~= nil then
				for _,loadTrigger in pairs (placeable.buyingStation.loadTriggers) do
					local triggerId = loadTrigger.triggerNode;
					courseplay:debug(string.format('    add %s(%s) to fillTriggers (buyingStation)', placeable.buyingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
					courseplay:cpAddTrigger(triggerId, loadTrigger, 'fillTrigger');
				end
			end
			
			if placeable.loadingStation ~= nil then
				for _,loadTrigger in pairs (placeable.loadingStation.loadTriggers) do
					local triggerId = loadTrigger.triggerNode;
					courseplay:debug(string.format('    add %s(%s) to fillTriggers (loadingStation)', placeable.loadingStation.stationName,tostring(triggerId)), courseplay.DBG_TRIGGERS);
					courseplay:cpAddTrigger(triggerId, loadTrigger, 'fillTrigger');
				end
			end


		end
		courseplay:debug(('   %i found'):format(counter), courseplay.DBG_TRIGGERS);
	end;
	
	
	if g_currentMission.vehicles ~= nil then
		courseplay:debug('   check fillTriggerVehicles', courseplay.DBG_TRIGGERS);
		local counter = 0
		for vehicleIndex, vehicle in pairs(g_currentMission.vehicles) do
				if vehicle.spec_fillTriggerVehicle then
					if vehicle.spec_fillTriggerVehicle.fillTrigger ~= nil then
						counter = counter +1
						local trigger = vehicle.spec_fillTriggerVehicle.fillTrigger
						local triggerId = trigger.triggerId

						courseplay:cpAddTrigger(triggerId, trigger, 'fillTrigger');
						courseplay:debug(string.format('    add %s(%i) to fillTriggers (fillTriggerVehicle)', vehicle:getName(),triggerId), courseplay.DBG_TRIGGERS);
					end
				end
		end
		courseplay:debug(('   %i found'):format(counter), courseplay.DBG_TRIGGERS);
	end;

	for _, trigger in pairs(Triggers.getBunkerSilos()) do
		courseplay:debug('   check bunkerSilos', courseplay.DBG_TRIGGERS);
		if courseplay:isValidTipTrigger(trigger) and trigger.bunkerSilo then
			local triggerId = trigger.triggerId;
			courseplay:debug(('    add tipTrigger: id=%d, is BunkerSiloTipTrigger '):format(triggerId), courseplay.DBG_TRIGGERS);
						
			--local area = trigger.bunkerSiloArea
			--local px,pz, pWidthX,pWidthZ, pHeightX,pHeightZ = Utils.getXZWidthAndHeight(detailId, area.sx,area.sz, area.wx, area.wz, area.hx, area.hz);
			--local _ ,_,totalArea = getDensityParallelogram(detailId, px, pz, pWidthX, pWidthZ, pHeightX, pHeightZ, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels);
			trigger.capacity = 10000000 --DensityMapHeightUtil.volumePerPixel*totalArea*800 ;
			--print(string.format("capacity= %s  fillLevel= %s ",tostring(trigger.capacity),tostring(trigger.fillLevel)))
			courseplay:cpAddTrigger(triggerId, trigger, 'tipTrigger');
			
		end
	end
	
	if g_currentMission.nodeToObject ~= nil then
		courseplay:debug('   check nodeToObject', courseplay.DBG_TRIGGERS);
		for _,object in pairs (g_currentMission.nodeToObject) do
			if object.exactFillRootNode ~= nil and not courseplay.triggers.all[object.exactFillRootNode] then
				courseplay:debug(string.format('    add %s(%s) to tipTriggers (nodeToObject->exactFillRootNode)', '',tostring(object.exactFillRootNode)), courseplay.DBG_TRIGGERS);
				courseplay:cpAddTrigger(object.exactFillRootNode, object, 'tipTrigger');
			end
			if object.triggerNode ~= nil and not courseplay.triggers.all[object.triggerNode] then
				local triggerId = object.triggerNode;
				courseplay:debug(string.format('    add %s(%s) to fillTriggers (nodeToObject->triggerNode )', '',tostring(triggerId)), courseplay.DBG_TRIGGERS);
				courseplay:cpAddTrigger(triggerId, object, 'fillTrigger');
			end
			--[[if object.baleTriggerNode ~= nil and not courseplay.triggers.all[object.baleTriggerNode] then
				courseplay:cpAddTrigger(object.baleTriggerNode, object, 'tipTrigger');
				courseplay:debug(('    add tipTrigger: id=%d, name=%q, className=%q, is BunkerSiloTipTrigger '):format(object.baleTriggerNode, '', className), courseplay.DBG_TRIGGERS);
			end]]
		end			
	end
	
	if g_company ~= nil and g_company.triggerManagerList ~= nil then
		courseplay:debug('   check globalCompany mod', courseplay.DBG_TRIGGERS);
		for i=1,#g_company.triggerManagerList do
			local triggerManager = g_company.triggerManagerList[i];			
			courseplay:debug(string.format('    triggerManager %d:',i), courseplay.DBG_TRIGGERS);
			for index, trigger in pairs (triggerManager.registeredTriggers) do
				if trigger.exactFillRootNode then
					trigger.triggerId = trigger.exactFillRootNode;
					trigger.acceptedFillTypes = trigger.fillTypes
					courseplay:debug(string.format('    add %s(%s) to tipTriggers (globalCompany mod)', '',tostring(trigger.triggerId)), courseplay.DBG_TRIGGERS);
					courseplay:cpAddTrigger(trigger.triggerId, trigger, 'tipTrigger');
				end	
				if trigger.triggerNode then
					trigger.triggerId = trigger.triggerNode;
					trigger.isGlobalCompanyFillTrigger = true
					courseplay:debug(string.format('    add %s(%s) to fillTriggers (globalCompany mod)', '',tostring(trigger.triggerId)), courseplay.DBG_TRIGGERS);
					courseplay:cpAddTrigger(trigger.triggerId, trigger, 'fillTrigger');
				end
			end
		end	
	end
end;

function courseplay:cpAddTrigger(triggerId, trigger, groupType)
	--courseplay:debug(('%s: courseplay:cpAddTrigger: TriggerId: %s,trigger: %s, triggerType: %s,groupType: %s'):format(nameNum(self), tostring(triggerId), tostring(trigger), tostring(triggerType), tostring(groupType)), courseplay.DBG_TRIGGERS);
	local t = courseplay.triggers;
	if t.all[triggerId] ~= nil then return; end;

	t.all[triggerId] = trigger;
	t.allCount = t.allCount + 1;

	-- tipTriggers
	if groupType == 'tipTrigger' then
		t.tipTriggers[triggerId] = trigger;
		t.tipTriggersCount = t.fillTriggersCount + 1;
	elseif groupType == 'fillTrigger' then	
		t.fillTriggers[triggerId] = trigger;
		t.fillTriggersCount = t.fillTriggersCount + 1;
	end;
end;

--Tommi TODO check if its still needed
function courseplay:isValidTipTrigger(trigger)
	local isValid = trigger.className and (trigger.className == 'SiloTrigger' or trigger.isAlternativeTipTrigger or StringUtil.endsWith(trigger.className, 'TipTrigger') and trigger.triggerId ~= nil);
	return isValid;
end;


function courseplay:printTipTriggersFruits(trigger)
	for k,_ in pairs(trigger.acceptedFillTypes) do
		print(('    %s: %s'):format(tostring(k), tostring(g_fillTypeManager.indexToName[k])));
	end
end;
--[[
	Global table to store all triggers types:

	They get stored by their unique trigger id.

 	- LoadTriggers are basically all placeable triggers to fill upon.

 	- FillTriggers are all vehicles with fill triggers spec.

 	- UnloadTriggers are basically all placeable triggers to unload at, except bunker silos.
 		They can be separated in normal unload trigger and bale unload triggers.

	- BunkerSilos 
]]--
Triggers = {}

Triggers.loadingTriggers = {}
Triggers.unloadingTriggers = {}
Triggers.baleUnloadingTriggers = {}
Triggers.fillTriggers = {}
Triggers.bunkerSilos = {}

function Triggers.getBunkerSilos()
	return Triggers.bunkerSilos
end

function Triggers.getLoadingTriggers()
	return Triggers.loadingTriggers
end

function Triggers.getFillTriggers()
	return Triggers.fillTriggers
end


---Add all relevant triggers on create and remove them on delete.
function Triggers.addLoadingTrigger(trigger,superFunc,...)
	local returnValue = superFunc(trigger,...)

	if trigger.triggerNode then
		Triggers.loadingTriggers[trigger.triggerNode] = trigger
	end
	return returnValue
end
LoadTrigger.load = Utils.overwrittenFunction(LoadTrigger.load,Triggers.addLoadingTrigger)

function Triggers.addUnloadingTrigger(trigger,superFunc,...)
	local returnValue = superFunc(trigger,...)

	if trigger.exactFillRootNode then
		Triggers.unloadingTriggers[trigger.exactFillRootNode] = trigger
	end

	if trigger.baleTriggerNode then 
		Triggers.baleUnloadingTriggers[trigger.baleTriggerNode] = trigger
	end

	return returnValue
end
UnloadTrigger.load = Utils.overwrittenFunction(UnloadTrigger.load,Triggers.addUnloadingTrigger)

function Triggers.addFillTrigger(_,superFunc,triggerId, ...)
	local trigger = superFunc(_,triggerId, ...)
	if trigger.triggerId then
		Triggers.fillTriggers[triggerId] = trigger
	end 
	return trigger
end
FillTrigger.new = Utils.overwrittenFunction(FillTrigger.new,Triggers.addFillTrigger)

function Triggers.removeLoadingTrigger(trigger)
	if trigger.triggerNode then
		Triggers.loadingTriggers[trigger.triggerNode] = trigger
	end
end
LoadTrigger.delete = Utils.appendedFunction(LoadTrigger.delete,Triggers.removeLoadingTrigger)

function Triggers.removeUnloadingTrigger(trigger)
	if trigger.exactFillRootNode then 
		Triggers.unloadingTriggers[trigger.exactFillRootNode] = nil
	end

	if trigger.baleTriggerNode then 
		Triggers.baleUnloadingTriggers[trigger.baleTriggerNode] = nil
	end

end
UnloadTrigger.delete = Utils.prependedFunction(UnloadTrigger.delete,Triggers.removeUnloadingTrigger)

function Triggers.removeFillTrigger(trigger)
	if trigger.triggerId then
		Triggers.fillTriggers[trigger.triggerId] = nil
	end
end
FillTrigger.delete = Utils.prependedFunction(FillTrigger.delete,Triggers.removeFillTrigger)


function Triggers.addBunkerSilo(silo,superFunc,...)
	local returnValue = superFunc(silo,...)

	--- Not sure if this is needed, some old magic maybe ?
	silo.triggerId = silo.interactionTriggerNode
	silo.bunkerSilo = true
	silo.className = "BunkerSiloTipTrigger"
	silo.rootNode = silo.nodeId
	silo.triggerStartId = silo.bunkerSiloArea.start
	silo.triggerEndId = silo.bunkerSiloArea.height
	silo.triggerWidth = courseplay:nodeToNodeDistance(silo.bunkerSiloArea.start, silo.bunkerSiloArea.width)

	Triggers.bunkerSilos[silo.triggerId] = silo
	return returnValue

end
BunkerSilo.load = Utils.overwrittenFunction(BunkerSilo.load,Triggers.addBunkerSilo)

function Triggers.removeBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	Triggers.bunkerSilos[triggerNode] = nil
end
BunkerSilo.delete = Utils.prependedFunction(BunkerSilo.delete,Triggers.removeBunkerSilo)

---Global Company

function Triggers.addLoadingTriggerGC(trigger,superFunc,...)
	local returnValue = Triggers.addLoadingTrigger(trigger,superFunc,...)

	TriggerHandler.onLoad_GC_LoadingTriggerFix(trigger,superFunc,...)

	return returnValue
end

-- do not remove this comment
-- vim: set noexpandtab: