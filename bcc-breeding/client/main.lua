local Core = exports.vorp_core:GetCore()
local FeatherMenu = exports['feather-menu'].initiate()

local OpenPrompt
local PromptGroup = GetRandomIntInRange(0, 0xffffff)

local function askName()
    AddTextEntry('FMMC_MPM_NA', 'Foal name')
    DisplayOnscreenKeyboard(1, 'FMMC_MPM_NA', '', 'Foal', '', '', '', 18)
    while UpdateOnscreenKeyboard() == 0 do Wait(0) end
    if UpdateOnscreenKeyboard() ~= 1 then return nil end
    return GetOnscreenKeyboardResult()
end

local function openMenu(yard)
    local data = Core.Callback.TriggerAwait('bcc-breeding:Open', yard.key)
    if not data then return end

    local menu = FeatherMenu:RegisterMenu('bcc-breeding:yard', {
        top = '8%', left = '3%', ['1080width'] = '480px',
        contentslot = { style = { ['min-height'] = '340px' } },
        canclose = true, draggable = true,
    })
    local page = menu:RegisterPage('breed:home')
    page:RegisterElement('header', { value = data.label, slot = 'header' })

    if not data.isBreeder then
        page:RegisterElement('textdisplay', {
            value = 'Horse breeding is locked to the Horse Breeder job.'
        })
        menu:Open({ startupPage = page })
        return
    end

    page:RegisterElement('textdisplay', {
        value = ('Start a pairing for $%s. Skip a wait for $%s.'):format(data.startCost, data.skipCost)
    })

    page:RegisterElement('button', { label = 'Start pairing' }, function()
        local stallions, mares = {}, {}
        for i = 1, #(data.horses or {}) do
            local h = data.horses[i]
            if h.breedable and tostring(h.gender or ''):lower() == 'male' then
                stallions[#stallions + 1] = h
            elseif h.breedable and tostring(h.gender or ''):lower() == 'female' then
                mares[#mares + 1] = h
            end
        end
        if #stallions == 0 or #mares == 0 then
            Core.NotifyRightTip('You need a breedable stallion and mare.', 4000)
            return
        end
        local pickPage = menu:RegisterPage('breed:pick')
        pickPage:RegisterElement('header', { value = 'Choose stallion', slot = 'header' })
        for i = 1, #stallions do
            local male = stallions[i]
            pickPage:RegisterElement('button', {
                label = ('%s  %s'):format(male.name, male.genotype or ''),
            }, function()
                local marePage = menu:RegisterPage('breed:mare')
                marePage:RegisterElement('header', { value = 'Choose mare', slot = 'header' })
                for m = 1, #mares do
                    local female = mares[m]
                    marePage:RegisterElement('button', {
                        label = ('%s  %s'):format(female.name, female.genotype or ''),
                    }, function()
                        Core.Callback.TriggerAwait('bcc-breeding:Create', yard.key, male.id, female.id)
                        menu:Close()
                    end)
                end
                menu:Open({ startupPage = marePage })
            end)
        end
        menu:Open({ startupPage = pickPage })
    end)

    for i = 1, #(data.sessions or {}) do
        local row = data.sessions[i]
        local waitMin = math.ceil((row.wait or 0) / 60)
        local label = ('#%s %s — %s x %s'):format(row.id, row.phaseName, row.male, row.female)
        if row.wait > 0 then
            label = label .. (' (%sm)'):format(waitMin)
        end
        page:RegisterElement('button', { label = label }, function()
            local manage = menu:RegisterPage('breed:manage')
            manage:RegisterElement('header', { value = 'Pairing #' .. row.id, slot = 'header' })
            manage:RegisterElement('textdisplay', {
                value = ('%s\nStallion: %s\nMare: %s\nWait: %s min'):format(
                    row.phaseName, row.male, row.female, waitMin
                )
            })
            if row.canCollect then
                manage:RegisterElement('button', { label = 'Register foal' }, function()
                    local name = askName() or 'Foal'
                    Core.Callback.TriggerAwait('bcc-breeding:Collect', row.id, name)
                    menu:Close()
                end)
            else
                manage:RegisterElement('button', { label = 'Advance stage' }, function()
                    Core.Callback.TriggerAwait('bcc-breeding:Advance', row.id)
                    menu:Close()
                end)
                if (data.skipCost or 0) > 0 then
                    manage:RegisterElement('button', { label = 'Skip wait $' .. data.skipCost }, function()
                        Core.Callback.TriggerAwait('bcc-breeding:Skip', row.id)
                        menu:Close()
                    end)
                end
            end
            menu:Open({ startupPage = manage })
        end)
    end

    if #(data.sessions or {}) == 0 then
        page:RegisterElement('textdisplay', { value = 'No pairings at this yard.' })
    end

    menu:Open({ startupPage = page })
end

CreateThread(function()
    OpenPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(OpenPrompt, Config.OpenControl)
    UiPromptSetText(OpenPrompt, CreateVarString(10, 'LITERAL_STRING', 'Breeding'))
    UiPromptSetVisible(OpenPrompt, true)
    UiPromptSetStandardMode(OpenPrompt, true)
    UiPromptSetGroup(OpenPrompt, PromptGroup, 0)
    UiPromptRegisterEnd(OpenPrompt)

    if Config.Blips.enabled then
        for i = 1, #Config.Yards do
            local yard = Config.Yards[i]
            local blip = Citizen.InvokeNative(0x554d9d53f696d002, 1664425300, yard.menu)
            SetBlipSprite(blip, Config.Blips.sprite, true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, yard.label)
        end
    end

    local function loadModel(name)
        local hash = joaat(name)
        if not IsModelValid(hash) then return nil end
        if not HasModelLoaded(hash) then
            RequestModel(hash)
            local timeout = GetGameTimer() + 8000
            while not HasModelLoaded(hash) do
                if GetGameTimer() > timeout then return nil end
                Wait(10)
            end
        end
        return hash
    end

    local function spawnBreeder(yard)
        if yard.ped and DoesEntityExist(yard.ped) then return end
        local hash = loadModel(yard.model or 'a_m_m_valfarmer_01')
        if not hash then return end
        local c = yard.menu
        local ped = CreatePed(hash, c.x, c.y, c.z - 1.0, yard.heading or 0.0, false, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if not ped or ped == 0 then return end
        Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
        SetEntityCanBeDamaged(ped, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        pcall(function()
            TaskStartScenarioInPlace(ped, `WORLD_HUMAN_WRITE_NOTEBOOK`, -1, true)
        end)
        Wait(200)
        FreezeEntityPosition(ped, true)
        yard.ped = ped
    end

    local function despawnBreeder(yard)
        if yard.ped and DoesEntityExist(yard.ped) then
            DeleteEntity(yard.ped)
        end
        yard.ped = nil
    end

    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for i = 1, #Config.Yards do
            local yard = Config.Yards[i]
            local dist = #(coords - yard.menu)
            if dist <= (yard.npcDistance or 80.0) then
                spawnBreeder(yard)
            else
                despawnBreeder(yard)
            end
            if dist <= (Config.PromptDistance or 3.0) then
                sleep = 0
                UiPromptSetActiveGroupThisFrame(PromptGroup, CreateVarString(10, 'LITERAL_STRING', yard.label), 1, 0, 0, 0)
                if UiPromptHasStandardModeCompleted(OpenPrompt, 0) then
                    openMenu(yard)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #(Config.Yards or {}) do
        local yard = Config.Yards[i]
        if yard.ped and DoesEntityExist(yard.ped) then
            DeleteEntity(yard.ped)
            yard.ped = nil
        end
    end
end)
