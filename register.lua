--COURSEPLAY
--print_r(g_fruitTypeManager)
--print_r(g_vehicleTypeManager)
--DebugUtil.printTableRecursively(g_fillTypeManager, '  ', 0, 10)

local numInstallationsVehicles = 0;
local courseplaySpecName = g_currentModName .. ".courseplay"

function courseplay.registerEventListeners(vehicleType)
	print(string.format( "## Courseplay: Registering event listeners for %s", vehicleType.name))
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDelete", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", courseplay)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", courseplay)
end

function courseplay.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAILowFrequency", AIDriver.updateAILowFrequency)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit", courseplay.doCheckSpeedLimit)
end

-- Register interface functions to start/stop the Courseplay driver
function courseplay.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "startCpDriver",  courseplay.startCpDriver)
	SpecializationUtil.registerFunction(vehicleType, "stopCpDriver",   courseplay.stopCpDriver)
end

function courseplay:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	ActionEventsLoader.onRegisterVehicleActionEvents(self,isActiveForInput, isActiveForInputIgnoreSelection)
end

if courseplay.houstonWeGotAProblem then
	return;
end;

-- register courseplay specification in vehicle types and prepare compatibility with GlobalCompany
function courseplay:register(secondTime)
	if secondTime then
		print('## Courseplay: register later loaded mods:');
		-- compatibility with GlobalCompany triggers
		if g_company then
			if g_company.loadingTrigger then 
				if g_company.loadingTrigger.loadTriggerCallback then
					g_company.loadingTrigger.loadTriggerCallback = Utils.appendedFunction(g_company.loadingTrigger.loadTriggerCallback, TriggerHandler.loadTriggerCallback);
				end
				if g_company.loadingTrigger.onActivateObject then 
					g_company.loadingTrigger.onActivateObject = Utils.overwrittenFunction(g_company.loadingTrigger.onActivateObject, TriggerHandler.onActivateObjectGlobalCompany)
				end
				if g_company.loadingTrigger.load then
					g_company.loadingTrigger.load = Utils.overwrittenFunction(g_company.loadingTrigger.load, Triggers.addLoadingTriggerGC);
				end
				if g_company.loadingTrigger.delete then
					g_company.loadingTrigger.delete = Utils.prependedFunction(g_company.loadingTrigger.delete, Triggers.removeLoadingTrigger);
				end
			end
			if g_company.unloadingTrigger then 
				if g_company.unloadingTrigger.load then
					g_company.unloadingTrigger.load = Utils.overwrittenFunction(g_company.unloadingTrigger.load, Triggers.addUnloadingTrigger);
				end
				if g_company.unloadingTrigger.delete then
					g_company.unloadingTrigger.delete = Utils.prependedFunction(g_company.unloadingTrigger.delete, Triggers.removeUnloadingTrigger);
				end
			end
			print('## Global company functions overwritten.');
		end
	else
		print('## Courseplay: register into vehicle types:');
	end
	-- add courseplay specification to vehicle types
	for typeName,vehicleType in pairs(g_vehicleTypeManager.vehicleTypes) do
		if SpecializationUtil.hasSpecialization(AIVehicle, vehicleType.specializations) and not vehicleType.specializationsByName[courseplaySpecName] then
				print("  install courseplay into "..typeName)
				g_vehicleTypeManager:addSpecialization(typeName, courseplaySpecName)
				numInstallationsVehicles = numInstallationsVehicles + 1;
		end;
	end;
	if secondTime then
		print('## Courseplay: register later loaded mods: done');
	end	
end;

function courseplay:attachablePostLoad(xmlFile)
	if self.cp == nil then self.cp = {}; end;

	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	--SET SPECIALIZATION VARIABLE
	courseplay:setNameVariable(self);

	--SEARCH AND SET OBJECT'S self.name IF NOT EXISTING
	if self.name == nil then
		self.name = courseplay:getObjectName(self, xmlFile);
	end;
end;

function courseplay:articulatedAxisOnLoad()
	-- Due to a bug in Giant's ArticulatedAxis:onLoad() maxRotation has a value in degrees instead of radians,
	-- fix that here.
	if self.maxRotation and self.maxRotation > math.pi then
		print(string.format('## %s: fixing maxRotation, setting to %.0f degrees', self:getName(), self.maxRotation))
		self.maxRotation = math.rad(self.maxRotation)
	end
end

function courseplay.vehiclePostLoadFinished(self, superFunc, ...)
	local loadingState = superFunc(self, ...);
	if loadingState ~= BaseMission.VEHICLE_LOAD_OK then
		-- something failed. Probably handle this: do not do anything else
		-- return loadingState;
	end

	if self.cp == nil then self.cp = {}; end;

	-- XML FILE NAME VARIABLE
	if self.cp.xmlFileName == nil then
		self.cp.xmlFileName = courseplay.utils:getFileNameFromPath(self.configFileName);
	end;

	-- make sure every vehicle has the CP API functions
	self.getIsCourseplayDriving = courseplay.getIsCourseplayDriving;
	self.setIsCourseplayDriving = courseplay.setIsCourseplayDriving;
	self.setCpVar = courseplay.setCpVar;

	courseplay:setNameVariable(self);

	return loadingState;
end;

function courseplay:vehicleDelete()
	if self.cp ~= nil then
		--if vehicle is a courseplayer, delete the vehicle from activeCourseplayers
		if CpManager.activeCoursePlayers[self.rootNode] then
			CpManager:removeFromActiveCoursePlayers(self);
		end

		-- Remove created nodes
		if self.cp.notesToDelete and #self.cp.notesToDelete > 0 then
			for _, nodeId in ipairs(self.cp.notesToDelete) do
				if nodeId and nodeId ~= 0 then
					delete(nodeId);
				end;
			end;
			self.cp.notesToDelete = nil;
		end;

		if courseplay:isCombine(self) or courseplay:isChopper(self) then
			g_combineUnloadManager:removeCombineFromList(self)
		end

	end;
end;

function courseplay:foldableLoad(savegame)
	if self.cp == nil then self.cp = {}; end;

	--FOLDING PARTS STARTMOVEDIRECTION
	local startMoveDir = getXMLInt(self.xmlFile, 'vehicle.foldingParts#startMoveDirection');
	if startMoveDir == nil then
 		local singleDir;
		local i = 0;
		while true do -- go through single foldingPart entries
			local key = string.format('vehicle.foldingParts.foldingPart(%d)', i);
			if not hasXMLProperty(self.xmlFile, key) then break; end;
			local dir = getXMLInt(self.xmlFile, key .. '#startMoveDirection');
			if dir then
				if singleDir == nil then --first foldingPart -> set singleDir
					singleDir = dir;
				elseif dir ~= singleDir then -- two or more foldingParts have non-matching startMoveDirections --> not valid
					singleDir = nil;
					break;
				elseif dir == singleDir then -- --> valid
				end;
			end;
			i = i + 1;
		end;
		if singleDir then -- startMoveDirection found in single foldingPart
			startMoveDir = singleDir;
		end;
	end;

	self.cp.foldingPartsStartMoveDirection = Utils.getNoNil(startMoveDir, 0);
end;
-- overwrite/append functions of basegame
Foldable.load = Utils.appendedFunction(Foldable.load, courseplay.foldableLoad);
-- NOTE: using loadFinished() instead of load() so any other mod that overwrites Vehicle.load() doesn't interfere
Vehicle.loadFinished = Utils.overwrittenFunction(Vehicle.loadFinished, courseplay.vehiclePostLoadFinished);
ArticulatedAxis.onLoad = Utils.appendedFunction(ArticulatedAxis.onLoad, courseplay.articulatedAxisOnLoad)
Attachable.onPostLoad = Utils.appendedFunction(Attachable.onPostLoad, courseplay.attachablePostLoad);
Vehicle.delete = Utils.prependedFunction(Vehicle.delete, courseplay.vehicleDelete);

-- no static copy is needed, just go with the pointer
-- courseplay.locales = courseplay.utils.table.copy(g_i18n.texts, true);
courseplay.locales = g_i18n.texts

-- make l10n global so they can be used in GUI XML files directly (Thanks `Mogli!)
for n,t in pairs( g_i18n.texts ) do
	if string.sub( n, 1, 10 ) == "COURSEPLAY" then
		getfenv(0).g_i18n.texts[n] = t
	end
end

g_specializationManager:addSpecialization("courseplay", "courseplay", Utils.getFilename("courseplay.lua",  g_currentModDirectory), nil)

FieldworkAIDriver.register()
courseplay:register();
print(string.format('### Courseplay: installed into %d vehicle types', numInstallationsVehicles));

-- TODO: Remove the AIVehicleUtil.driveToPoint overwrite when the new patch goes out to fix it. (Temp fix from Giants: Emil) 
--Done? if so, delete these comments
--[[ This fixes the problems with driveInDirection motor and cruise control. There is a bug some where that is setting self.rotatedTime to 0
local originaldriveInDirection = AIVehicleUtil.driveInDirection;
AIVehicleUtil.driveInDirection = function (self, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)

	local angle = 0;
    if lx ~= nil and lz ~= nil then
        local dot = lz;
		angle = math.deg(math.acos(dot));
        if angle < 0 then
            angle = angle+180;
        end
        local turnLeft = lx > 0.00001;
        if not moveForwards then
            turnLeft = not turnLeft;
        end
        local targetRotTime = 0;
        if turnLeft then
            --rotate to the left
			targetRotTime = self.maxRotTime*math.min(angle/steeringAngleLimit, 1);
        else
            --rotate to the right
			targetRotTime = self.minRotTime*math.min(angle/steeringAngleLimit, 1);
        end
		if targetRotTime > self.rotatedTime then
			self.rotatedTime = math.min(self.rotatedTime + dt*self:getAISteeringSpeed(), targetRotTime);
		else
			self.rotatedTime = math.max(self.rotatedTime - dt*self:getAISteeringSpeed(), targetRotTime);
        end
    end
    if self.firstTimeRun then
        local acc = acceleration;
        if maxSpeed ~= nil and maxSpeed ~= 0 then
            if math.abs(angle) >= slowAngleLimit then
                maxSpeed = maxSpeed * slowDownFactor;
            end
            self.spec_motorized.motor:setSpeedLimit(maxSpeed);
            if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
                self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE);
            end
        else
            if math.abs(angle) >= slowAngleLimit then
                acc = slowAcceleration;
            end
        end
        if not allowedToDrive then
            acc = 0;
        end
        if not moveForwards then
            acc = -acc;
        end
		--FS 17 Version WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acc, not allowedToDrive, self.requiredDriveMode);
		WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal*self.movingDirection, acc, not allowedToDrive, true)
    end
end
]]
