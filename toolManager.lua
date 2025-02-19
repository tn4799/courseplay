local abs, cos, sin, min, max, deg = math.abs, math.cos, math.sin, math.min, math.max, math.deg;
local _;
-- ##### MANAGING TOOLS ##### --
function courseplay:attachImplement(implement)
	local rootVehicle = implement:getRootVehicle()
	if rootVehicle and SpecializationUtil.hasSpecialization(courseplay, rootVehicle.specializations) and
		rootVehicle.hasCourseplaySpec then
		courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, rootVehicle, '%s attached', nameNum(implement))
		courseplay:updateOnAttachOrDetach(rootVehicle)
	end
end

-- We need to add a hook here as onPostAttachImplement is not called for the vehicle when an implement is attached
-- to another implement (and not directly to the vehicle)
AttacherJoints.attachImplement = Utils.appendedFunction(AttacherJoints.attachImplement, courseplay.attachImplement);

function courseplay:detachImplement(implementIndex)
	local spec = self.spec_attacherJoints
	local implement = spec.attachedImplements[implementIndex]
	if implement then
		local rootVehicle = implement.object:getRootVehicle()
		if rootVehicle and SpecializationUtil.hasSpecialization(courseplay, rootVehicle.specializations) and
			rootVehicle.hasCourseplaySpec then
			courseplay.debugVehicle(courseplay.DBG_IMPLEMENTS, rootVehicle, '%s detached', nameNum(implement.object))
			-- do not update yet as the implement is still attached to the vehicle.
			-- defer the update until the next updateTick(), by that time things settle down
			rootVehicle.cp.toolsDirty = true
		end
	end
end

-- Same here, we want to also know when an implement is detached from another implement. Prepend means we'll be
-- called before the implement is detached so we'll be able to find the root vehicle.
AttacherJoints.detachImplement = Utils.prependedFunction(AttacherJoints.detachImplement, courseplay.detachImplement);

function courseplay:updateOnAttachOrDetach(vehicle)
	-- TODO: refactor this (if it is even still needed), this ignore list is all over the place...
	vehicle.cpTrafficCollisionIgnoreList = {}

	courseplay:resetTools(vehicle)
	
	vehicle.cp.settings:validateCurrentValues()

	-- reset tool offset to the preconfigured value if exists
	vehicle.cp.settings.toolOffsetX:setToConfiguredValue()

	if vehicle.cp.driver then
		vehicle.cp.driver:refreshHUD()
	end

end

--- Set up tool configuration after something is attached or detached
function courseplay:resetTools(vehicle)
	vehicle.cp.workTools = {}
	-- are there any tippers?
	vehicle.cp.hasAugerWagon = false;

	vehicle.cp.workToolAttached = courseplay:updateWorkTools(vehicle, vehicle);

	courseplay.hud:setReloadPageOrder(vehicle, -1, true);

	courseplay:calculateWorkWidth(vehicle, true);
end;

function courseplay:isAttachedMixer(workTool)
	return workTool.typeName == "mixerWagon" or (not workTool.cp.hasSpecializationDrivable and  workTool.cp.hasSpecializationMixerWagon)
end;
function courseplay:isAttacherModule(workTool)
	if workTool.spec_attacherJoints.attacherJoint then
		local workToolsWheels = workTool:getWheels();
		return (workTool.spec_attacherJoints.attacherJoint.jointType == AttacherJoints.JOINTTYPE_SEMITRAILER and (not workToolsWheels or (workToolsWheels and #workToolsWheels == 0))) or workTool.cp.isAttacherModule == true;
	end;
	return false;
end;
function courseplay:isBaleLoader(workTool) -- is the tool a bale loader?
	return SpecializationUtil.hasSpecialization(BaleLoader, workTool.specializations) or
			(workTool.balesToLoad ~= nil and workTool.baleGrabber ~=nil and workTool.grabberIsMoving~= nil);
end;
function courseplay:isBaler(workTool) -- is the tool a baler?
	return SpecializationUtil.hasSpecialization(Baler, workTool.specializations) or
			workTool.balerUnloadingState ~= nil or courseplay:isSpecialBaler(workTool);
end;
function courseplay:isCombine(workTool)
	return workTool.cp.hasSpecializationCombine and workTool.startThreshing ~= nil and workTool.cp.capacity ~= nil  and workTool.cp.capacity > 0;
end;

function courseplay:isChopper(workTool)
	if workTool.cp.hasSpecializationCombine then
		local fillUnitCapacity = workTool:getFillUnitCapacity(workTool.spec_combine.fillUnitIndex)
		if not fillUnitCapacity then
			courseplay.infoVehicle(workTool, 'has no fill capacity, so it is not a chopper')
			return false
		end
		return workTool.startThreshing ~= nil and fillUnitCapacity > 10000000
	else
		return false
	end
end;

function courseplay:isFoldable(workTool) --is the tool foldable?
	return SpecializationUtil.hasSpecialization(Foldable, workTool.specializations) and
			workTool.spec_foldable.foldingParts ~= nil and #workTool.spec_foldable.foldingParts > 0;
end;
function courseplay:isFrontloader(workTool)
    return Utils.getNoNil(workTool.typeName == "attachableFrontloader", false);
end;

function courseplay:isHookLift(workTool)
	if workTool.spec_attacherJoints.attacherJoint then
		return workTool.spec_attacherJoints.attacherJoint.jointType == AttacherJoints.JOINTTYPE_HOOKLIFT;
	end;
	return false;
end
function courseplay:isMixer(workTool)
	return workTool.typeName == "selfPropelledMixerWagon" or (workTool.cp.hasSpecializationDrivable and  workTool.cp.hasSpecializationMixerWagon)
end;

function courseplay:isRoundbaler(workTool) -- is the tool a roundbaler?
	return courseplay:isBaler(workTool) and workTool.spec_baler ~= nil and (workTool.spec_baler.baleCloseAnimationName ~= nil and workTool.spec_baler.baleUnloadAnimationName ~= nil or courseplay:isSpecialRoundBaler(workTool));
end;
function courseplay:isSowingMachine(workTool) -- is the tool a sowing machine?
	return SpecializationUtil.hasSpecialization(SowingMachine, workTool.specializations)
end;

function courseplay:isSprayer(workTool) -- is the tool a sprayer/spreader?
	return SpecializationUtil.hasSpecialization(Sprayer, workTool.specializations)
end;
function courseplay:isWheelloader(workTool)
	return workTool.typeName:match("wheelLoader");
end;
function courseplay:hasShovel(workTool)
	if workTool.cp.hasSpecializationShovel then
		return true
	end
end
function courseplay:hasLeveler(workTool)
	if workTool.cp.hasSpecializationLeveler then
		return true
	end
end

function courseplay:isTrailer(workTool)
	return workTool.typeName:match("trailer");
end;

-- UPDATE WORKTOOL DATA
function courseplay:updateWorkTools(vehicle, workTool, isImplement)
	local mode = vehicle.cp.settings.driverMode:get()

	if not isImplement then
		courseplay.debugLine(courseplay.DBG_IMPLEMENTS, 3);
		courseplay:debug(('%s: updateWorkTools(%s, %q, isImplement=false) (mode=%d)'):format(nameNum(vehicle),tostring(vehicle.name), nameNum(workTool), mode), courseplay.DBG_IMPLEMENTS);
	else
		courseplay.debugLine(courseplay.DBG_IMPLEMENTS);
		courseplay:debug(('%s: updateWorkTools(%s, %q, isImplement=true)'):format(nameNum(vehicle),tostring(vehicle.name), nameNum(workTool)), courseplay.DBG_IMPLEMENTS);
	end;

	-- Reset distances if in debug mode 6.
	if courseplay.debugChannels[courseplay.DBG_IMPLEMENTS] ~= nil and courseplay.debugChannels[courseplay.DBG_IMPLEMENTS] == true then
		workTool.cp.distances = nil;
	end;

	courseplay:setNameVariable(workTool);
	courseplay:setOwnFillLevelsAndCapacities(workTool)
	local hasWorkTool = false;
	local hasWaterTrailer = false

	local isAllowedOkay,isDisallowedOkay = CpManager.validModeSetupHandler:isModeValid(mode,workTool)
	if isAllowedOkay and isDisallowedOkay then
		if mode == courseplay.MODE_TRANSPORT then
			-- For reversing purpose ?? still needed ?
			if isImplement then
				hasWorkTool = true;
				vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
			end
		else
			hasWorkTool = true;
			vehicle.cp.workTools[#vehicle.cp.workTools + 1] = workTool;
		end
	end


	-- MODE 4: FERTILIZER AND SEEDING
	if mode == courseplay.MODE_SEED_FERTILIZE then
		if isAllowedOkay and isDisallowedOkay then
			vehicle.cp.hasMachinetoFill = true;
		end;
	end
	--belongs to mode3 but should be considered even if the mode is not set correctely
	if workTool.cp.isAugerWagon then
		vehicle.cp.hasAugerWagon = true;
	end;


	vehicle.cp.hasWaterTrailer = hasWaterTrailer

	if hasWorkTool then
		courseplay:debug(('%s: workTool %q added to workTools (index %d)'):format(nameNum(vehicle), nameNum(workTool), #vehicle.cp.workTools), courseplay.DBG_IMPLEMENTS);
	end;

	--------------------------------------------------

	if not isImplement or hasWorkTool or workTool.cp.isNonTippersHandledWorkTool then
		--FOLDING PARTS: isFolded/isUnfolded states
		courseplay:setFoldedStates(workTool);
	end;

	-- REVERSE PROPERTIES
	courseplay:getReverseProperties(vehicle, workTool);

	-- TRAFFIC COLLISION IGNORE LIST
	courseplay:debug(('%s: adding %q (%q) to cpTrafficCollisionIgnoreList'):format(nameNum(vehicle), nameNum(workTool), tostring(workTool.cp.xmlFileName)), courseplay.DBG_TRAFFIC);
	vehicle.cpTrafficCollisionIgnoreList[workTool.rootNode] = true;
	-- TRAFFIC COLLISION IGNORE LIST (components)
	if workTool.components ~= nil then
		courseplay:debug(('%s: adding %q (%q) components to cpTrafficCollisionIgnoreList'):format(nameNum(vehicle), nameNum(workTool), tostring(workTool.cp.xmlFileName)), courseplay.DBG_TRAFFIC);
		for i,component in pairs(workTool.components) do
			vehicle.cpTrafficCollisionIgnoreList[component.node] = true;
		end;
	end;

	-- CHECK ATTACHED IMPLEMENTS
	for k,impl in pairs(workTool:getAttachedImplements()) do
		local implIsWorkTool = courseplay:updateWorkTools(vehicle, impl.object, true);
		if implIsWorkTool then
			hasWorkTool = true;
		end;
	end;

	-- STEERABLE (vehicle)
	if not isImplement then
		vehicle.cp.numWorkTools = #vehicle.cp.workTools;

		-- list debug
		if courseplay.debugChannels[courseplay.DBG_TRAFFIC] then
			courseplay.debugLine(courseplay.DBG_IMPLEMENTS);
			courseplay:debug(('%s cpTrafficCollisionIgnoreList'):format(nameNum(vehicle)), courseplay.DBG_TRAFFIC);
			for a,b in pairs(vehicle.cpTrafficCollisionIgnoreList) do
        if g_currentMission.nodeToObject[ a ] then
          local name = g_currentMission.nodeToObject[a].name;
          courseplay:debug(('\\___ [%s] = %s (%q)'):format(tostring(a), tostring(name), tostring(getName(a))), courseplay.DBG_TRAFFIC);
        end
			end;
		end;

		-- TURN DIAMETER
		if g_server ~= nil then
			courseplay:setAutoTurnDiameter(vehicle, hasWorkTool);
		end

		-- TIP REFERENCE POINTS
		courseplay:setTipRefOffset(vehicle);


		-- FINAL WORKTOOLS TABLE DEBUG
		if courseplay.debugChannels[courseplay.DBG_IMPLEMENTS] then
			courseplay.debugLine(courseplay.DBG_IMPLEMENTS);
			if vehicle.cp.numWorkTools > 0 then
				courseplay:debug(('%s: workTools:'):format(nameNum(vehicle)), courseplay.DBG_IMPLEMENTS);
				for i=1, vehicle.cp.numWorkTools do
					courseplay:debug(('\\___ [%d] = %s'):format(i, nameNum(vehicle.cp.workTools[i])), courseplay.DBG_IMPLEMENTS);
				end;
			else
				courseplay:debug(('%s: no workTools set'):format(nameNum(vehicle)), courseplay.DBG_IMPLEMENTS);
			end;
		end;
	end;

	--------------------------------------------------

	if not isImplement then
		courseplay.debugLine(courseplay.DBG_IMPLEMENTS, 3);
	end;

	return hasWorkTool;
end;

function courseplay:setTipRefOffset(vehicle)
	vehicle.cp.tipRefOffset = 0;
	for i=1, vehicle.cp.numWorkTools do
		vehicle.cp.workTools[i].cp.rearTipRefPoint = nil;
		if vehicle.cp.hasMachinetoFill then
			vehicle.cp.tipRefOffset = 1.5;
		elseif vehicle.cp.workTools[i].rootNode ~= nil and vehicle.cp.workTools[i].tipReferencePoints ~= nil then
			if  #(vehicle.cp.workTools[i].tipReferencePoints) > 1 then
				for n=1 ,#(vehicle.cp.workTools[i].tipReferencePoints) do
					local tipperX, tipperY, tipperZ = getWorldTranslation(vehicle.cp.workTools[i].tipReferencePoints[n].node);
					local tipRefPointX, tipRefPointY, tipRefPointZ = worldToLocal(vehicle.cp.workTools[i].rootNode, tipperX, tipperY, tipperZ);
					courseplay:debug(string.format("point%s : tipRefPointX (%s), tipRefPointY (%s), tipRefPointZ(%s)",tostring(n),tostring(tipRefPointX),tostring(tipRefPointY),tostring( tipRefPointZ)),courseplay.DBG_REVERSE)
					tipRefPointX = abs(tipRefPointX);
					if tipRefPointX > vehicle.cp.tipRefOffset then
						if tipRefPointX > 0.1 then
							vehicle.cp.tipRefOffset = tipRefPointX;
						else
							vehicle.cp.tipRefOffset = 0
						end;
					end

					-- Find the rear tipRefpoint in case we are BGA tipping.
					if tipRefPointX < 0.1 and tipRefPointZ < 0 then
						if not vehicle.cp.workTools[i].cp.rearTipRefPoint or vehicle.cp.workTools[i].tipReferencePoints[n].width > vehicle.cp.workTools[i].tipReferencePoints[vehicle.cp.workTools[i].cp.rearTipRefPoint].width then
							vehicle.cp.workTools[i].cp.rearTipRefPoint = n;
							courseplay:debug(string.format("%s: Found rear TipRefPoint: %d - tipRefPointZ = %f", nameNum(vehicle), n, tipRefPointZ), courseplay.DBG_REVERSE);
						end;
					end;
				end;
			else
				vehicle.cp.workTools[i].cp.rearTipRefPoint = 1
				vehicle.cp.tipRefOffset = 0;
			end;
		end;
	end;
end;


function courseplay:isFolding(workTool) --returns isFolding, isFolded, isUnfolded
	if not courseplay:isFoldable(workTool) then
		return false, false, true;
	end;

	local isFolding, isFolded, isUnfolded = false, true, true;
	courseplay:debug(string.format('%s: isFolding(): realUnfoldDirection=%s, turnOnFoldDirection=%s, startAnimTime=%s, foldMoveDirection=%s',
		nameNum(workTool), tostring(workTool.cp.realUnfoldDirection), tostring(workTool.turnOnFoldDirection),
		tostring(workTool.startAnimTime), tostring(workTool.foldMoveDirection)), courseplay.DBG_CYCLIC);

	if workTool.spec_foldable.foldAnimTime ~= (workTool.spec_foldable.oldFoldAnimTime or 0) then
		if workTool.spec_foldable.foldMoveDirection > 0 and workTool.spec_foldable.foldAnimTime < 1 then
			isFolding = true;
		elseif workTool.spec_foldable.foldMoveDirection < 0 and workTool.spec_foldable.foldAnimTime > 0 then
			isFolding = true;
		end;
		workTool.spec_foldable.oldFoldAnimTime = workTool.spec_foldable.foldAnimTime;
	end;

	isUnfolded = workTool:getIsUnfolded();
	isFolded = not isUnfolded and not isFolding;

	courseplay:debug(string.format('\treturn isFolding=%s, isFolded=%s, isUnfolded=%s',
		tostring(isFolding), tostring(isFolded), tostring(isUnfolded)), courseplay.DBG_CYCLIC);
	return isFolding, isFolded, isUnfolded;
end;


function courseplay:setFoldedStates(object)
	if courseplay:isFoldable(object) and object.spec_foldable.turnOnFoldDirection then
		courseplay.debugLine(courseplay.DBG_IMPLEMENTS);
		courseplay:debug(nameNum(object) .. ': setFoldedStates()', courseplay.DBG_IMPLEMENTS);

		object.cp.realUnfoldDirection = object.spec_foldable.turnOnFoldDirection;
		if object.cp.foldingPartsStartMoveDirection and object.cp.foldingPartsStartMoveDirection ~= 0 and object.cp.foldingPartsStartMoveDirection ~= object.spec_foldable.turnOnFoldDirection then
			object.cp.realUnfoldDirection = object.spec_foldable.turnOnFoldDirection * object.cp.foldingPartsStartMoveDirection;
		end;

		courseplay:debug(string.format('startAnimTime=%s, turnOnFoldDirection=%s, foldingPartsStartMoveDirection=%s --> realUnfoldDirection=%s', 
			tostring(object.startAnimTime), tostring(object.turnOnFoldDirection), tostring(object.cp.foldingPartsStartMoveDirection), 
			tostring(object.cp.realUnfoldDirection)), courseplay.DBG_IMPLEMENTS);

		for i,foldingPart in pairs(object.spec_foldable.foldingParts) do
			foldingPart.isFoldedAnimTime = 0;
			foldingPart.isFoldedAnimTimeNormal = 0;
			foldingPart.isUnfoldedAnimTime = foldingPart.animDuration;
			foldingPart.isUnfoldedAnimTimeNormal = 1;

			if object.cp.realUnfoldDirection < 0 then
				foldingPart.isFoldedAnimTime = foldingPart.animDuration;
				foldingPart.isFoldedAnimTimeNormal = 1;
				foldingPart.isUnfoldedAnimTime = 0;
				foldingPart.isUnfoldedAnimTimeNormal = 0;
			end;
			courseplay:debug(string.format('\tfoldingPart %d: isFoldedAnimTime=%s (normal: %d), isUnfoldedAnimTime=%s (normal: %d)',
				i, tostring(foldingPart.isFoldedAnimTime), foldingPart.isFoldedAnimTimeNormal, tostring(foldingPart.isUnfoldedAnimTime), 
				foldingPart.isUnfoldedAnimTimeNormal), courseplay.DBG_IMPLEMENTS);
		end;
		courseplay.debugLine(courseplay.DBG_IMPLEMENTS);
	end;
end;


function courseplay:setAutoTurnDiameter(vehicle, hasWorkTool)
	courseplay.debugLine(courseplay.DBG_IMPLEMENTS, 3);
	local turnRadius, turnRadiusAuto = 10, 10;

	vehicle.cp.turnDiameterAuto = vehicle.cp.vehicleTurnRadius * 2;
	courseplay:debug(('%s: Set turnDiameterAuto to %.2fm (2 x vehicleTurnRadius)'):format(nameNum(vehicle), vehicle.cp.turnDiameterAuto), courseplay.DBG_IMPLEMENTS);
	local mode = vehicle.cp.settings.driverMode:get()
	-- Check if we have worktools and if we are in a valid mode
	if hasWorkTool and (mode == courseplay.MODE_COMBI or mode == courseplay.MODE_OVERLOADER or mode == courseplay.MODE_SEED_FERTILIZE or mode == courseplay.MODE_FIELDWORK) then
		courseplay:debug(('%s: getHighestToolTurnDiameter(%s)'):format(nameNum(vehicle), vehicle.name), courseplay.DBG_IMPLEMENTS);

		local toolTurnDiameter = AIDriverUtil.getTurningRadius(vehicle) * 2

		-- If the toolTurnDiameter is bigger than the turnDiameterAuto, then set turnDiameterAuto to toolTurnDiameter
		if toolTurnDiameter > vehicle.cp.turnDiameterAuto then
			courseplay:debug(('%s: toolTurnDiameter(%.2fm) > turnDiameterAuto(%.2fm), turnDiameterAuto set to %.2fm'):format(nameNum(vehicle), toolTurnDiameter, vehicle.cp.turnDiameterAuto, toolTurnDiameter), courseplay.DBG_IMPLEMENTS);
			vehicle.cp.turnDiameterAuto = toolTurnDiameter;
		end;
	end;


	if vehicle.cp.turnDiameterAutoMode then
		vehicle.cp.turnDiameter = vehicle.cp.turnDiameterAuto;
		courseplay:debug(('%s: turnDiameterAutoMode is active: turnDiameter set to %.2fm'):format(nameNum(vehicle), vehicle.cp.turnDiameterAuto), courseplay.DBG_IMPLEMENTS);
	end;
	courseplay.debugLine(courseplay.DBG_IMPLEMENTS, 1);
end;

function courseplay:addCpNilTempFillLevelFunction()
	local cpNilTempFillLevel = function(self, state)
		if state ~= self.state and state == BunkerSilo.STATE_CLOSED then
			self.cpTempFillLevel = nil;
		end;
	end;
	BunkerSilo.setState = Utils.prependedFunction(BunkerSilo.setState, cpNilTempFillLevel);
end;

function courseplay:resetTipTrigger(vehicle, changeToForward)
	if vehicle.cp.currentTipTrigger ~= nil then
		vehicle.cp.currentTipTrigger = nil;
		if vehicle.cp.backupUnloadSpeed then
			courseplay:changeReverseSpeed(vehicle, nil, vehicle.cp.backupUnloadSpeed, true);
			vehicle.cp.backupUnloadSpeed = nil;
		end;
		if changeToForward and vehicle.Waypoints[vehicle.cp.waypointIndex].rev then
			courseplay:setWaypointIndex(vehicle, courseplay:getNextFwdPoint(vehicle));
			vehicle.cp.ppc:initialize()
		end;
	end
end;

--- Iterator for all work areas of an object
function courseplay:workAreaIterator(object)
	local i = 0
	return function()
		i = i + 1
		local wa = object and object.getWorkAreaByIndex and object:getWorkAreaByIndex(i)
		if wa then return i, wa end
	end
end

function courseplay:hasWorkAreas(object)
	return object and object.getWorkAreaByIndex and object:getWorkAreaByIndex(1)
end

--- Get the working width of thing. Will return the maximum of the working width of thing and
-- all of its implements
-- TODO: consolidate this with the logic in FieldworkAIDriver:setMarkers()
function courseplay:getWorkWidth(thing, logPrefix)
	logPrefix = logPrefix and logPrefix .. '  ' or ''
	courseplay.debugFormat(courseplay.DBG_IMPLEMENTS,'%s%s: getting working width...', logPrefix, nameNum(thing))
	-- check if we have a manually configured working width
	local width = g_vehicleConfigurations:get(thing, 'workingWidth')
	if not width then
		-- no manual config, check AI markers
		width = courseplay:getAIMarkerWidth(thing, logPrefix)
	end
	if not width then
		-- no AI markers, check work areas
		width = courseplay:getWorkAreaWidth(thing, logPrefix)
	end
	local implements = thing:getAttachedImplements()
	if implements then
		-- get width of all implements
		for _, implement in ipairs(implements) do
			width = math.max( width, courseplay:getWorkWidth(implement.object, logPrefix))
		end
	end
	courseplay.debugFormat(courseplay.DBG_IMPLEMENTS, '%s%s: working width is %.1f', logPrefix, nameNum(thing), width)
	return width
end

function courseplay:getWorkAreaWidth(object, logPrefix)
	logPrefix = logPrefix or ''
	-- TODO: check if there's a better way to find out if the implement has a work area
	local width = 0
	for i, wa in courseplay:workAreaIterator(object) do
		-- work areas are defined by three nodes: start, width and height. These nodes
		-- define a rectangular work area which you can make visible with the
		-- gsVehicleDebugAttributes console command and then pressing F5
		local x, _, _ = localToLocal(wa.width, wa.start, 0, 0, 0)
		width = math.max(width, math.abs(x))
		local _, _, z = localToLocal(wa.height, wa.start, 0, 0, 0)
		courseplay.debugFormat(courseplay.DBG_IMPLEMENTS, '%s%s: work area %d is %s, %.1f by %.1f m',
			logPrefix, nameNum(object), i, g_workAreaTypeManager.workAreaTypes[wa.type].name, math.abs(x), math.abs(z))
	end
	if width == 0 then
		courseplay.debugFormat(courseplay.DBG_IMPLEMENTS, '%s%s: has NO work area', logPrefix, nameNum(object))
	end
	return width
end

function courseplay:getAIMarkerWidth(object, logPrefix)
	logPrefix = logPrefix or ''
	if object.getAIMarkers then
		local aiLeftMarker, aiRightMarker = object:getAIMarkers()
		if aiLeftMarker and aiRightMarker then
			local left, _, _ = localToLocal(aiLeftMarker, object.cp.directionNode or object.rootNode, 0, 0, 0);
			local right, _, _ = localToLocal(aiRightMarker, object.cp.directionNode or object.rootNode, 0, 0, 0);
			local width, _, _ = localToLocal(aiLeftMarker, aiRightMarker, 0, 0, 0)
			courseplay.debugFormat( courseplay.DBG_IMPLEMENTS, '%s%s aiMarkers: left=%.2f, right=%.2f (width %.2f)', logPrefix, nameNum(object), left, right, width)

			if left < right then
				left, right = right, left -- yes, lua can do this!
				courseplay.debugFormat(courseplay.DBG_IMPLEMENTS, '%s%s left < right -> switch -> left=%.2f, right=%.2f', logPrefix, nameNum(object), left, right)
			end
			return left - right;
		end
	end
end

--this one enable the buttons and allows the user to change the mode
function courseplay:getIsToolCombiValidForCpMode(vehicle,cpModeToCheck)
	--5 is always valid
	if cpModeToCheck == 5 then 
		return true;
	end
	local callback = {}
	callback.isDisallowedOkay = true
	courseplay:getIsToolValidForCpMode(vehicle,cpModeToCheck,callback)
	return callback.isAllowedOkay and callback.isDisallowedOkay
end

function courseplay:getIsToolValidForCpMode(object, mode, callback)
	local isAllowedOkay,isDisallowedOkay = CpManager.validModeSetupHandler:isModeValid(mode,object)
	callback.isAllowedOkay = callback.isAllowedOkay or isAllowedOkay
	callback.isDisallowedOkay = callback.isDisallowedOkay and isDisallowedOkay
	for _,impl in pairs(object:getAttachedImplements()) do
		courseplay:getIsToolValidForCpMode(impl.object, mode, callback)
	end
end

function courseplay:updateFillLevelsAndCapacities(vehicle)
	courseplay:setOwnFillLevelsAndCapacities(vehicle)
	vehicle.cp.totalFillLevel = vehicle.cp.fillLevel;
	vehicle.cp.totalCapacity = vehicle.cp.capacity;
	if vehicle.cp.fillLevel ~= nil and vehicle.cp.capacity ~= nil then
		vehicle.cp.totalFillLevelPercent = (vehicle.cp.fillLevel*100)/vehicle.cp.capacity;
	end
	--print(string.format("vehicle itself(%s): vehicle.cp.totalFillLevel:(%s)",tostring(vehicle:getName()),tostring(vehicle.cp.totalFillLevel)))
	--print(string.format("vehicle itself(%s): vehicle.cp.totalCapacity:(%s)",tostring(vehicle:getName()),tostring(vehicle.cp.totalCapacity)))
	if vehicle.cp.workTools ~= nil then
		for _,tool in pairs(vehicle.cp.workTools) do
			local hasMoreFillUnits = courseplay:setOwnFillLevelsAndCapacities(tool)
			if hasMoreFillUnits and tool ~= vehicle then
				vehicle.cp.totalFillLevel = (vehicle.cp.totalFillLevel or 0) + tool.cp.fillLevel
				vehicle.cp.totalCapacity = (vehicle.cp.totalCapacity or 0 ) + tool.cp.capacity
				vehicle.cp.totalFillLevelPercent = (vehicle.cp.totalFillLevel*100)/vehicle.cp.totalCapacity;
				--print(string.format("%s: adding %s to vehicle.cp.totalFillLevel = %s",tostring(tool:getName()),tostring(tool.cp.fillLevel), tostring(vehicle.cp.totalFillLevel)))
				--print(string.format("%s: adding %s to vehicle.cp.totalCapacity = %s",tostring(tool:getName()),tostring(tool.cp.capacity), tostring(vehicle.cp.totalCapacity)))
			end
		end
	end
	--print(string.format("End of function: vehicle.cp.totalFillLevel:(%s)",tostring(vehicle.cp.totalFillLevel)))
end

function courseplay:setOwnFillLevelsAndCapacities(workTool)
	local fillLevel, capacity = 0,0
	local fillLevelPercent = 0;
	local fillType = 0;
	if workTool.getFillUnits == nil then
		return false
	end
	local fillUnits = workTool:getFillUnits()
	for index,fillUnit in pairs(fillUnits) do
		-- TODO: why not fillUnit.fillType == FillType.DIESEL? answer: because you may have diesel in your trailer
		if workTool.getConsumerFillUnitIndex and (index == workTool:getConsumerFillUnitIndex(FillType.DIESEL)
				or index == workTool:getConsumerFillUnitIndex(FillType.DEF)
				or index == workTool:getConsumerFillUnitIndex(FillType.AIR))
				or fillUnit.capacity > 999999 then
		else

			fillLevel = fillLevel + fillUnit.fillLevel
			capacity = capacity + fillUnit.capacity
			if fillLevel ~= nil and capacity ~= nil then
				fillLevelPercent = (fillLevel*100)/capacity;
			else
				fillLevelPercent = nil
			end
			fillType = fillUnit.lastValidFillType
		end
	end

	workTool.cp.fillLevel = fillLevel
	workTool.cp.capacity = capacity
	workTool.cp.fillLevelPercent = fillLevelPercent
	workTool.cp.fillType = fillType
	--print(string.format("%s: adding %s to workTool.cp.fillLevel",tostring(workTool:getName()),tostring(workTool.cp.fillLevel)))
	--print(string.format("%s: adding %s to workTool.cp.capacity",tostring(workTool:getName()),tostring(workTool.cp.capacity)))
	return true
end
