local QBCore = exports['qb-core']:GetCoreObject()
local OutsideVehicles = {}

QBCore.Commands.Add("setjobvehicles", "Assigné un véhicule à une entreprise", {{name = 'plate', help = 'Plaque d\'imatriculation'}, {name = 'type', help = 'Type de job (1 ou 2)'},{name = 'job'}}, false, function(source, args)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    local plate = args[1]  
    local job = args[3]
    local type = args[2]
    local boss
    if type == '1' then
        boss = pData.PlayerData.job.isboss
    elseif type == '2' then
        boss = pData.PlayerData.gang.isboss
    else 
        TriggerClientEvent('QBCore:Notify', source, "La valeur du type d'affaire n'est pas renseigné ! ", 'error')
    end
    if boss then
        QBCore.Functions.TriggerCallback('qb-garages:server:checkVehicleOwner', source, function(owned)     --Check owner
            if owned then
                MySQL.query("UPDATE player_vehicles SET citizenid = ?, job = ? WHERE plate = ?", {"NULL", job, plate})
                if type == "1" then
                    TriggerClientEvent('QBCore:Notify', source, 'Vous avez bien ajouter '..plate..' au garage de votre société', 'success')
                else
                    TriggerClientEvent('QBCore:Notify', source, 'Vous avez bien ajouter '..plate..' au garage de votre organisation', 'success')   
                end
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
            end
        end, plate)
    else
        if type == 1 then
            TriggerClientEvent('QBCore:Notify', source, "Vous n'êtes pas le dirigeant de cette société ("..job..')', 'error')
        else
            TriggerClientEvent('QBCore:Notify', source, "Vous n'êtes pas le dirigeant de cette organisation ("..job..')', 'error')
        end
    end
    QBCore.Commands.Refresh(src)
end)

QBCore.Functions.CreateCallback("qb-garages:server:GetGarageVehicles", function(source, cb, garage, type, category)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages give player cars in the garage only
        local sharedPublic = ''
        if (not Config.SharedPublicGarages) then sharedPublic = sharedPublic..' AND garage = @garage' end
        MySQL.query(
            'SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND state = @state'..sharedPublic,
            {
                ["@citizenid"]= pData.PlayerData.citizenid,
                ["@garage"]= garage,
                ["@state"]= 1
            },
            function(result)
                if result[1] then
                    cb(result)
                else
                    cb(nil)
                end
            end
        )
    elseif type == "depot" then    --Depot give player cars that are not in garage only
        local job = pData.PlayerData.job.name
        local gang = pData.PlayerData.gang.name
        local jobboss = pData.PlayerData.job.isboss
        local gangboss = pData.PlayerData.gang.isboss
        local querry = 'SELECT * FROM player_vehicles WHERE citizenid = @cid AND (state = @state)'
        if jobboss or gangboss then
            if jobboss then
                querry = 'SELECT * FROM player_vehicles WHERE (job = @job OR citizenid = @cid) AND (state = @state)'
            elseif gangboss then
                querry = 'SELECT * FROM player_vehicles WHERE (job = @gang OR citizenid = @cid) AND (state = @state)'
            end
        end
        MySQL.query(querry, 
        {
            ['@cid'] = pData.PlayerData.citizenid,
            ['@state'] = 0,
            ['@job'] = job,
            ['@gang'] = gang,
        
        }, function(result)
            local tosend = {}
            if result[1] then
                --Check vehicle type against depot type
                for _, vehicle in pairs(result) do
                    if not OutsideVehicles[vehicle.plate] or not DoesEntityExist(OutsideVehicles[vehicle.plate].entity) then
                        if category == "air" and ( QBCore.Shared.Vehicles[vehicle.vehicle].category == "helicopters" or QBCore.Shared.Vehicles[vehicle.vehicle].category == "planes" ) then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "sea" and QBCore.Shared.Vehicles[vehicle.vehicle].category == "boats" then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "car" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "helicopters" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "planes" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "boats" then
                            tosend[#tosend + 1] = vehicle
                        end
                    end
                end
                cb(tosend)
            else
                cb(nil)
            end
        end)
    elseif type == "house" then
        
        local shared = ''
        if not Config["SharedGarages"] and type ~= "house" then
            shared = " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        end
        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?'..shared, {garage, 1}, function(result)
            if result[1] then
                cb(result)
            else
                cb(nil)
            end
        end)

    elseif type == "job" then                    --House give all cars in the garage, Job and Gang depend of config
        local job = pData.PlayerData.job.name
        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND (job = ? OR citizenid = ?)', {garage, 1, job, pData.PlayerData.citizenid}, function(result)
            if result[1] then 
                cb(result)
            else
                cb(nil)
            end
        end)
    elseif type == "gang" then
        local gang = pData.PlayerData.gang.name
        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND (job = ? OR citizenid = ?)', {garage, 1, gang, pData.PlayerData.citizenid}, function(result)
            if result[1] then 
                cb(result)
            else
                cb(nil)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garages:server:validateGarageVehicle", function(source, cb, garage, type, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages give player cars in the garage only
        local sharedPublic = ''
        if (not Config.SharedPublicGarages) then sharedPublic = sharedPublic..' AND garage = @garage' end
        MySQL.query(
            'SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND state = @state AND plate = @plate'..sharedPublic,
            {
                ["@citizenid"]= pData.PlayerData.citizenid,
                ["@garage"]= garage,
                ["@state"]= 1,
                ["@plate"]= plate
            },
            function(result)
                if result[1] then
                    cb(true)
                else
                    cb(false)
                end
            end
        )
    elseif type == "depot" then    --Depot give player cars that are not in garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND plate = ?', {pData.PlayerData.citizenid, 0, 2, plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    else
        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND plate = ?', {garage, 1, plate}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garages:server:checkOwnership", function(source, cb, plate, type, house, gang)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if type == "public" then        --Public garages only for player cars
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    elseif type == "house" then     --House garages only for player cars that have keys of the house
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                local hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, house)
                if hasHouseKey then
                    cb(true)
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    elseif type == "gang" then        --Gang garages only for gang members cars (for sharing)
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {plate}, function(result)
            if result[1] then
                --Check if found owner is part of the gang
                local resultplayer = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { result[1].citizenid })
                if resultplayer then
                    local playergang = json.decode(resultplayer.gang)
                    if playergang.name == gang then
                        cb(true)
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    else                            --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local job = pData.PlayerData.job.name
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND (job = ? OR citizenid = ?)', {plate,job, pData.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback('qb-garages:server:spawnvehicle', function (source, cb, vehInfo, coords, warp)
    local plate = vehInfo.plate
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)
    SetEntityHeading(veh, coords.w)
    SetVehicleNumberPlateText(veh, plate)
    local vehProps = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}
    cb(netId, vehProps)
end)

QBCore.Functions.CreateCallback("qb-garages:server:GetVehicleProperties", function(_, cb, plate)
    local properties = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then
        properties = json.decode(result[1].mods)
    end
    cb(properties)
end)

QBCore.Functions.CreateCallback("qb-garages:server:IsSpawnOk", function(_, cb, plate, type)
    if type == "depot" then         --If depot, check if vehicle is not already spawned on the map
        if OutsideVehicles[plate] and DoesEntityExist(OutsideVehicles[plate].entity) then
            cb(false)
        else
            cb(true)
        end
    else
        cb(true)
    end
end)

RegisterNetEvent('qb-garages:server:updateVehicle', function(state, fuel, engine, body, plate, garage, type, gang)
    QBCore.Functions.TriggerCallback('qb-garages:server:checkOwnership', source, function(owned)     --Check ownership
        if owned then
            if state == 0 or state == 1 or state == 2 then                                          --Check state value
                if type ~= "house" then
                    if Config.Garages[garage] then                                                             --Check if garage is existing
                        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
                    end
                else
                    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
                end
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        end
    end, plate, type, garage, gang)
end)

RegisterNetEvent('qb-garages:server:updateVehicleState', function(state, plate, garage)
    local type
    if Config.Garages[garage] then
        type = Config.Garages[garage].type
    else
        type = "house"
    end

    QBCore.Functions.TriggerCallback('qb-garages:server:validateGarageVehicle', source, function(owned)     --Check ownership
        if owned then
            if state == 0 then                                          --Check state value
                MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE plate = ?', {state, 0, plate})
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        end
    end, garage, type, plate)
end)

RegisterNetEvent('qb-garages:server:UpdateOutsideVehicle', function(plate, vehicle)
    local entity = NetworkGetEntityFromNetworkId(vehicle)
    OutsideVehicles[plate] = {netID = vehicle, entity = entity}
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        if Config["AutoRespawn"] then
            MySQL.update('UPDATE player_vehicles SET state = 1 WHERE state = 0', {})
        end
    end
end)

RegisterNetEvent('qb-garages:server:PayDepotPrice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money["cash"]
    local bankBalance = Player.PlayerData.money["bank"]

    local vehicle = data.vehicle

    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {vehicle.plate}, function(result)
        if result[1] then
            if cashBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney("cash", result[1].depotprice, "paid-depot")
                TriggerClientEvent("qb-garages:client:takeOutGarage", src, data)
            elseif bankBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney("bank", result[1].depotprice, "paid-depot")
                TriggerClientEvent("qb-garages:client:takeOutGarage", src, data)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_enough"), 'error')
            end
        end
    end)
end)



--External Calls
--Call from qb-vehiclesales
QBCore.Functions.CreateCallback("qb-garages:server:checkVehicleOwner", function(source, cb, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid}, function(result)
        if result[1] then
            cb(true, result[1].balance)
        else
            cb(false)
        end
    end)
end)

--Call from qb-phone
QBCore.Functions.CreateCallback('qb-garages:server:GetPlayerVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Vehicles = {}

    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result[1] then
            for _, v in pairs(result) do
                local VehicleData = QBCore.Shared.Vehicles[v.vehicle]

                local VehicleGarage = Lang:t("error.no_garage")
                if v.garage ~= nil then
                    if Config.Garages[v.garage] ~= nil then
                        VehicleGarage = Config.Garages[v.garage].label
                    else
                        VehicleGarage = Lang:t("info.house_garage")         -- HouseGarages[v.garage].label
                    end
                end

                if v.state == 0 then
                    v.state = Lang:t("status.out")
                elseif v.state == 1 then
                    v.state = Lang:t("status.garaged")
                elseif v.state == 2 then
                    v.state = Lang:t("status.impound")
                end

                local fullname
                if VehicleData["brand"] ~= nil then
                    fullname = VehicleData["brand"] .. " " .. VehicleData["name"]
                else
                    fullname = VehicleData["name"]
                end
                Vehicles[#Vehicles+1] = {
                    fullname = fullname,
                    brand = VehicleData["brand"],
                    model = VehicleData["name"],
                    plate = v.plate,
                    garage = VehicleGarage,
                    state = v.state,
                    fuel = v.fuel,
                    engine = v.engine,
                    body = v.body
                }
            end
            cb(Vehicles)
        else
            cb(nil)
        end
    end)
end)

local function getAllGarages()
    local garages = {}
    for k, v in pairs(Config.Garages) do
        garages[#garages+1] = {
            name = k,
            label = v.label,
            type = v.type,
            takeVehicle = v.takeVehicle,
            putVehicle = v.putVehicle,
            spawnPoint = v.spawnPoint,
            showBlip = v.showBlip,
            blipName = v.blipName,
            blipNumber = v.blipNumber,
            blipColor = v.blipColor,
            vehicle = v.vehicle
        }
    end
    return garages
end

exports('getAllGarages', getAllGarages)
