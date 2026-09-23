Config = {}

Config.OpenControl = 0x760A9C6F -- G
Config.PromptDistance = 3.0
Config.ExerciseDistance = 18.0

Config.StartCost = 500
Config.SkipCost = 75 -- 0 disables paid skips
Config.MaxSessionsPerCharacter = 3
Config.CooldownSeconds = 1800

Config.TimerScale = 1.0
Config.Timers = {
    familiarising = 60 * 60,
    exercise = 0, -- completed by visiting the exercise ring
    rest = 45 * 60,
    pregnancy = 2 * 60 * 60,
}

Config.Blips = {
    enabled = true,
    sprite = -641397381,
    label = 'Horse Breeding',
}

Config.Yards = {
    {
        key = 'valentine',
        label = 'Valentine Breeding',
        menu = vector3(-378.21, 783.30, 116.13),
        heading = 270.0,
        exercise = vector3(-392.51, 779.52, 115.71),
        stable = 'valentine',
        model = 'a_m_m_valfarmer_01',
        npcDistance = 80.0,
    },
    {
        key = 'strawberry',
        label = 'Strawberry Breeding',
        menu = vector3(-1829.60, -564.78, 155.99),
        heading = 160.0,
        exercise = vector3(-1792.82, -569.69, 155.98),
        stable = 'strawberry',
        model = 'a_m_m_valfarmer_01',
        npcDistance = 80.0,
    },
    {
        key = 'blackwater',
        label = 'Blackwater Breeding',
        menu = vector3(-863.40, -1366.40, 43.40),
        heading = 90.0,
        exercise = vector3(-880.20, -1366.80, 43.40),
        stable = 'blackwater',
        model = 'a_m_m_valfarmer_01',
        npcDistance = 80.0,
    },
}
