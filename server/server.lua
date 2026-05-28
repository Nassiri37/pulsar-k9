local Config = require 'shared/config'

local function isIllegalItem(itemName)
	for _, illegal in ipairs(Config.K9.illegalItems) do
		if illegal == itemName then
			return true
		end
	end
	return false
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

RegisterNetEvent("K9:server:searchVehicle", function(vin, plate, players)
	local src = source

	if not vin or vin == "" then
		TriggerClientEvent("k9:client:search_results", src, false, "vehicle")
		return
	end

	local trunkInventory = GetContent(vin) or {}
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

local function getTrunkInventoryId(vin)
	if vin:sub(1, 6) == "trunk-" then
		return vin
	end

	return "trunk-" .. vin
end

function GetContent(vin)
	if not vin or vin == "" then
		return {}
	end

	local items = exports.ox_inventory:GetInventoryItems(getTrunkInventoryId(vin))
	if not items then
		return {}
	end

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
