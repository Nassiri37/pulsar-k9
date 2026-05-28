local Config = require 'shared/config'

local function trimPlate(plate)
	if not plate then
		return nil
	end

	if string.strtrim then
		return string.strtrim(plate)
	end

	return string.gsub(plate, '^%s*(.-)%s*$', '%1')
end

local function isIllegalItem(itemName)
	for _, illegal in ipairs(Config.K9.illegalItems) do
		if illegal == itemName then
			return true
		end
	end
	return false
end

local function itemsToContent(items)
	local content = {}

	for _, slot in pairs(items) do
		if slot and slot.name then
			content[#content + 1] = {
				name = slot.name,
				count = slot.count or 1,
			}
		end
	end

	return content
end

local function loadStashFromDatabase(dbId)
	if not dbId or dbId == '' then
		return nil
	end

	local data = MySQL.scalar.await('SELECT data FROM ox_inventory WHERE owner = ? AND name = ?', { '', dbId })
	if not data or data == '' then
		return nil
	end

	local ok, decoded = pcall(json.decode, data)
	if ok and type(decoded) == 'table' then
		return decoded
	end

	return nil
end

local function getTrunkInventoryIds(vin, plate)
	local ids = {}
	local seen = {}

	local function add(id)
		if not id or id == '' or seen[id] then
			return
		end

		seen[id] = true
		ids[#ids + 1] = id
	end

	plate = trimPlate(plate)
	vin = vin and tostring(vin) or nil

	if plate then
		add('trunk' .. plate)
		add('trunk-' .. plate)
	end

	if vin and vin ~= '' then
		add('trunk-' .. vin)
		add('trunk' .. vin)
	end

	return ids
end

local function getTrunkDbIds(vin, plate)
	local ids = {}
	local seen = {}

	local function add(id)
		if not id or id == '' or seen[id] then
			return
		end

		seen[id] = true
		ids[#ids + 1] = id
	end

	plate = trimPlate(plate)
	vin = vin and tostring(vin) or nil

	if plate then
		add(plate)
		add('trunk-' .. plate)
		add('trunk' .. plate)
	end

	if vin and vin ~= '' then
		add(vin)
		add('trunk-' .. vin)
		add('trunk' .. vin)
	end

	return ids
end

local function loadTrunkFromEntity(plate, netId)
	if not netId or not plate then
		return nil
	end

	local invId = 'trunk' .. plate
	local inv = exports.ox_inventory:Inventory({
		id = invId,
		type = 'trunk',
		netid = netId,
	})

	if inv and inv.items and next(inv.items) then
		return inv.items
	end

	return nil
end

function GetContent(vin, plate, netId)
	plate = trimPlate(plate)

	if (not plate or plate == '') and netId then
		local entity = NetworkGetEntityFromNetworkId(netId)
		if entity and entity > 0 then
			plate = trimPlate(GetVehicleNumberPlateText(entity))
		end
	end

	if (not vin or vin == '') and netId then
		local entity = NetworkGetEntityFromNetworkId(netId)
		if entity and entity > 0 then
			local state = Entity(entity).state
			if state and state.VIN then
				vin = state.VIN
			end
		end
	end

	if netId and plate then
		local items = loadTrunkFromEntity(plate, netId)
		if items then
			return itemsToContent(items)
		end
	end

	for _, invId in ipairs(getTrunkInventoryIds(vin, plate)) do
		local items = exports.ox_inventory:GetInventoryItems(invId)
		if items and next(items) then
			return itemsToContent(items)
		end
	end

	for _, dbId in ipairs(getTrunkDbIds(vin, plate)) do
		local items = loadStashFromDatabase(dbId)
		if items and next(items) then
			return itemsToContent(items)
		end
	end

	return {}
end


function hasIllegalItems(target)
	for _, item in ipairs(Config.K9.illegalItems) do
		if exports.ox_inventory:GetItemCount(target, item) > 0 then
			return true
		end
	end
	return false
end

RegisterNetEvent("K9:server:spawnK9", function(model, colour, vest)
	local allowed = exports["pulsar-jobs"]:HasJob(source, Config.K9.job, nil, nil, nil, true)
	if allowed then
		TriggerClientEvent("K9:client:spawnK9", source, model, colour, vest)
	elseif Logger then
		Logger:Info("K9", "Player " .. source .. " tried to spawn K9 without proper job (Cheater?).")
	end
end)

RegisterNetEvent("K9:server:searchPerson")
AddEventHandler("K9:server:searchPerson", function(target)
	local playerHasIllegal = hasIllegalItems(target)
	if playerHasIllegal then
		TriggerClientEvent("k9:client:search_results", source, true, "person")
	else
		TriggerClientEvent("k9:client:search_results", source, false, "person")
	end
end)

RegisterNetEvent("K9:server:searchVehicle", function(vin, plate, players, netId)
	local src = source
	plate = trimPlate(plate)

	if (not plate or plate == '') and (not vin or vin == '') and not netId then
		TriggerClientEvent("k9:client:search_results", src, false, "vehicle")
		return
	end

	local trunkInventory = GetContent(vin, plate, netId) or {}
	local containsIllegal = false

	for _, item in ipairs(trunkInventory) do
		if isIllegalItem(item.name) then
			containsIllegal = true
			break
		end
	end

	Wait(Config.K9.searchTime * 1000)
	TriggerClientEvent("k9:client:search_results", src, containsIllegal, "vehicle", trunkInventory)
end)
