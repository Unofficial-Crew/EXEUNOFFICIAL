local OPPONENT_SCALE = 0.6
local OPPONENT_ALPHA = 0.5

local PLAYER_Y_OFFSET = 0.10
local WAVE_AMPLITUDE = 12
local WAVE_STAGGER = 0.12
local WAVE_DURATION = 0.45

local SWEEP_DURATION = 2.0
local TRANSITION_DURATION = 0.8

local BAR_MARGIN = 10

local opponentBaseX = {}
local opponentBaseY = {}
local opponentScaleX = {}
local opponentScaleY = {}
local opponentAlpha = {}

local playerBaseX = {}
local playerBaseY = {}
local playerWaveY = {}
local playerWaveAmplitude = {}
local playerOffsetsX = {}

local playerLaneWidth = 0

local waveActive = false
local sweepActive = false
local opponentNotesHidden = false

local sweepDirection = true
local sweepCompleted = 0

local opponentShiftOrigin = {}
local opponentShifted = false

local noteScaleMult = 1
local noteScaleFrom = 1
local noteScaleTo = 1
local noteScaleTime = 0

local comboShift = 0
local comboShiftFrom = 0
local comboShiftTo = 0
local comboShiftTime = 0
local comboShiftDuration = 0

local function usesMobileLayout()
    if buildTarget ~= 'ios' and buildTarget ~= 'android' then
        return false
    end

    if not getPropertyFromClass(
        'backend.ClientPrefs',
        'data.middleScroll'
    ) then
        return false
    end

    return getPropertyFromClass(
        'backend.ClientPrefs',
        'data.middlescrollType'
    ) == 'mobile'
    or getPropertyFromClass(
        'backend.ClientPrefs',
        'data.mobileOpponentNotes'
    ) == true
end

local function swapOpponentX(i)
    if usesMobileLayout() then
        return (screenWidth / 2) -
            (100 + (5 + getPropertyFromClass(
                'objects.Note',
                'swagWidth'
            )) * (4 - i))
    end

    return _G['defaultOpponentStrumX' .. i]
end

local function swapPlayerX(i)
    if usesMobileLayout() then
        return (screenWidth / 2) +
            (100 + (5 + getPropertyFromClass(
                'objects.Note',
                'swagWidth'
            )) * i)
    end

    return _G['defaultPlayerStrumX' .. i]
end

local function refreshBases()
    local minX = math.huge
    local maxX = -math.huge

    for i = 0, 3 do
        opponentBaseX[i + 1] = _G['defaultOpponentStrumX' .. i]
        opponentBaseY[i + 1] = _G['defaultOpponentStrumY' .. i]

        playerBaseX[i + 1] = _G['defaultPlayerStrumX' .. i]
        playerBaseY[i + 1] = _G['defaultPlayerStrumY' .. i]

        local width =
            getPropertyFromGroup('strumLineNotes', i + 4, 'width')

        minX = math.min(minX, playerBaseX[i + 1])
        maxX = math.max(maxX, playerBaseX[i + 1] + width)
    end

    playerLaneWidth = maxX - minX

    for i = 1, 4 do
        playerOffsetsX[i] = playerBaseX[i] - minX
    end
end

local function hideOpponentNotes()
    opponentNotesHidden = true

    for i = 0, getProperty('unspawnNotes.length') - 1 do
        if not getPropertyFromGroup('unspawnNotes', i, 'mustPress') then
            setPropertyFromGroup('unspawnNotes', i, 'alpha', 0)
            setPropertyFromGroup('unspawnNotes', i, 'visible', false)
        end
    end

    for i = 0, getProperty('notes.length') - 1 do
        if not getPropertyFromGroup('notes', i, 'mustPress') then
            setPropertyFromGroup('notes', i, 'alpha', 0)
            setPropertyFromGroup('notes', i, 'visible', false)
        end
    end
end

local function showOpponentNotes()
    opponentNotesHidden = false

    for i = 0, getProperty('notes.length') - 1 do
        if not getPropertyFromGroup('notes', i, 'mustPress') then
            setPropertyFromGroup('notes', i, 'alpha', 1)
            setPropertyFromGroup('notes', i, 'visible', true)
        end
    end

    for i = 0, getProperty('unspawnNotes.length') - 1 do
        if not getPropertyFromGroup('unspawnNotes', i, 'mustPress') then
            setPropertyFromGroup('unspawnNotes', i, 'alpha', 1)
            setPropertyFromGroup('unspawnNotes', i, 'visible', true)
        end
    end
end

local function shiftForBars(entering, duration, distance)

    if entering then

        if opponentShifted then
            return
        end

        opponentShifted = true

        local inset = distance + BAR_MARGIN

        for i = 0, 3 do

            local y = getPropertyFromGroup('strumLineNotes', i, 'y')
            local height = getPropertyFromGroup('strumLineNotes', i, 'height')
            local visible = getPropertyFromGroup('strumLineNotes', i, 'frameHeight') *
                opponentScaleY[i + 1] * OPPONENT_SCALE

            opponentShiftOrigin[i + 1] = y

            local targetY

            if (y + height / 2) > (screenHeight / 2) then
                targetY = screenHeight - inset - (height + visible) / 2
            else
                targetY = inset - (height - visible) / 2
            end

            noteTweenY(
                'barOppShift' .. i,
                i,
                targetY,
                duration,
                'quadOut'
            )

        end

        comboShiftTo = inset

    else

        if not opponentShifted then
            return
        end

        opponentShifted = false

        for i = 0, 3 do

            cancelTween('barOppShift' .. i)

            noteTweenY(
                'barOppRestore' .. i,
                i,
                opponentShiftOrigin[i + 1],
                duration,
                'quadIn'
            )

        end

        comboShiftTo = 0

    end

    comboShiftFrom = comboShift
    comboShiftTime = 0
    comboShiftDuration = math.max(0.001, duration)

end

local function applyOpponentNoteScale(newMult)

    local ratio = newMult / noteScaleMult

    if ratio ~= 1 then

        for i = 0, getProperty('notes.length') - 1 do

            if not getPropertyFromGroup('notes', i, 'mustPress') then

                local prefix = 'notes.members[' .. i .. '].scale.'

                setProperty(prefix .. 'x', getProperty(prefix .. 'x') * ratio)

                if not getPropertyFromGroup('notes', i, 'isSustainNote') then
                    setProperty(prefix .. 'y', getProperty(prefix .. 'y') * ratio)
                end

            end

        end

    end

    noteScaleMult = newMult

end

function onUpdate(elapsed)

    if noteScaleMult ~= noteScaleTo then

        noteScaleTime = noteScaleTime + elapsed

        local t = math.min(1, noteScaleTime / TRANSITION_DURATION)
        local eased

        if t < 0.5 then
            eased = 4 * t * t * t
        else
            eased = 1 - ((-2 * t + 2) ^ 3) / 2
        end

        if t >= 1 then
            applyOpponentNoteScale(noteScaleTo)
        else
            applyOpponentNoteScale(noteScaleFrom + (noteScaleTo - noteScaleFrom) * eased)
        end

    end

    if comboShift ~= comboShiftTo then

        comboShiftTime = comboShiftTime + elapsed

        local t = math.min(1, comboShiftTime / comboShiftDuration)

        comboShift = comboShiftFrom + (comboShiftTo - comboShiftFrom) * t * (2 - t)

        setProperty('comboBarInset', comboShift)

    end

end

function onSpawnNote(id, noteData, noteType, isSustainNote, strumTime)
    if noteScaleMult ~= 1 then
        if not getPropertyFromGroup('notes', id, 'mustPress') then
            local prefix = 'notes.members[' .. id .. '].scale.'

            setProperty(prefix .. 'x', getProperty(prefix .. 'x') * noteScaleMult)

            if not isSustainNote then
                setProperty(prefix .. 'y', getProperty(prefix .. 'y') * noteScaleMult)
            end
        end
    end

    if opponentNotesHidden then
        if not getPropertyFromGroup('notes', id, 'mustPress') then
            setPropertyFromGroup('notes', id, 'alpha', 0)
            setPropertyFromGroup('notes', id, 'visible', false)
        end
    end
end

function onUpdatePost()
    if opponentNotesHidden then
        for i = 0, getProperty('notes.length') - 1 do
            if not getPropertyFromGroup('notes', i, 'mustPress') then
                setPropertyFromGroup('notes', i, 'alpha', 0)
                setPropertyFromGroup('notes', i, 'visible', false)
            end
        end
    end
end

function onCreatePost()

    for i = 0, 3 do

        opponentScaleX[i + 1] =
            getProperty('strumLineNotes.members[' .. i .. '].scale.x')

        opponentScaleY[i + 1] =
            getProperty('strumLineNotes.members[' .. i .. '].scale.y')

        opponentAlpha[i + 1] =
            getPropertyFromGroup('strumLineNotes', i, 'alpha')

    end

end

function startPlayerWave(index, direction)

    if not waveActive then
        return
    end

    local strum = index + 4
    local height = getPropertyFromGroup('strumLineNotes', strum, 'height')

    local minY = 0
    local maxY = math.max(0, screenHeight - height)

    local targetY
    local tag

    if direction == 'up' then
        targetY = playerWaveY[index + 1] - playerWaveAmplitude[index + 1]
        tag = 'playerWaveUp' .. index
    else
        targetY = playerWaveY[index + 1] + playerWaveAmplitude[index + 1]
        tag = 'playerWaveDown' .. index
    end

    targetY = math.max(minY, math.min(maxY, targetY))

    noteTweenY(
        tag,
        strum,
        targetY,
        WAVE_DURATION,
        'sineInOut'
    )

end

function startPlayerSweep(toRight)

    if not sweepActive then
        return
    end

    local targetLeft

    if toRight then
        targetLeft = math.max(0, screenWidth - playerLaneWidth)
    else
        targetLeft = 0
    end

    sweepCompleted = 0

    for i = 0, 3 do

        local targetX = targetLeft + playerOffsetsX[i + 1]

        noteTweenX(
            'playerSweep' .. i,
            i + 4,
            targetX,
            SWEEP_DURATION,
            'sineInOut'
        )

    end

end

function onEvent(name, value1, value2)

    if name == 'Cinematics (With HUD)' then

        local duration = tonumber(value1) or 1
        local distance = tonumber(value2) or 0

        shiftForBars(distance > 0, duration, distance)

        return

    end

    if name ~= 'yourselfEvents' then
        return
    end

    if value1 == 'modchart1' then

        if usesMobileLayout() then

            for i = 0, 3 do

                noteTweenY(
                    'noteoy' .. i,
                    i,
                    _G['defaultPlayerStrumY' .. i],
                    crochet / 250,
                    'cubeIn'
                )

                if i < 2 then
                    noteTweenX(
                        'noteox' .. i,
                        i,
                        swapOpponentX(i),
                        crochet / 250,
                        'cubeIn'
                    )
                end

            end

        end

        for i = 0, 3 do

            if i < 2 then

                noteTweenX(
                    'notep' .. i,
                    i + 4,
                    swapOpponentX(i + 2),
                    crochet / 250,
                    'cubeIn'
                )

            else

                noteTweenX(
                    'notep' .. i,
                    i + 4,
                    swapPlayerX(i - 2),
                    crochet / 250,
                    'cubeIn'
                )

                noteTweenX(
                    'noteo' .. i,
                    i,
                    swapPlayerX(i),
                    crochet / 250,
                    'cubeIn'
                )

            end

        end

    elseif value1 == 'modchart1dot5' then

        for i = 0, 3 do

            if i < 2 then

                noteTweenX(
                    'noteo' .. i,
                    i,
                    swapPlayerX(i + 2),
                    crochet / 250,
                    'cubeIn'
                )

                noteTweenX(
                    'notep' .. i,
                    i + 4,
                    swapPlayerX(i),
                    crochet / 250,
                    'cubeIn'
                )

            else

                noteTweenX(
                    'noteo' .. i,
                    i,
                    swapOpponentX(i),
                    crochet / 250,
                    'cubeIn'
                )

                noteTweenX(
                    'notep' .. i,
                    i + 4,
                    swapOpponentX(i - 2),
                    crochet / 250,
                    'cubeIn'
                )

            end

        end

    elseif value1 == 'modchart2' then

        refreshBases()

        for i = 0, 7 do

            local targetX
            local targetY

            if i < 4 then
                targetX = opponentBaseX[i + 1]
                targetY = opponentBaseY[i + 1]
            else
                targetX = playerBaseX[i - 3]
                targetY = playerBaseY[i - 3]
            end

            noteTweenX(
                'modchart2ReturnX' .. i,
                i,
                targetX,
                TRANSITION_DURATION,
                'cubeInOut'
            )

            noteTweenY(
                'modchart2ReturnY' .. i,
                i,
                targetY,
                TRANSITION_DURATION,
                'cubeInOut'
            )

        end

    elseif value1 == 'modchartstart' then

        refreshBases()

        waveActive = true
        sweepActive = true

        sweepDirection = true
        sweepCompleted = 0

        setProperty('pressMissDamage', 0.025)

        noteScaleFrom = noteScaleMult
        noteScaleTo = OPPONENT_SCALE
        noteScaleTime = 0

        for i = 0, 3 do

            doTweenX(
                'opScaleX' .. i,
                'strumLineNotes.members[' .. i .. '].scale',
                opponentScaleX[i + 1] * OPPONENT_SCALE,
                TRANSITION_DURATION,
                'cubeInOut'
            )

            doTweenY(
                'opScaleY' .. i,
                'strumLineNotes.members[' .. i .. '].scale',
                opponentScaleY[i + 1] * OPPONENT_SCALE,
                TRANSITION_DURATION,
                'cubeInOut'
            )

            noteTweenAlpha(
                'opAlpha' .. i,
                i,
                OPPONENT_ALPHA,
                TRANSITION_DURATION,
                'cubeInOut'
            )

        end

        for i = 0, 3 do

            local index = i + 1
            local strum = i + 4

            local height =
                getPropertyFromGroup('strumLineNotes', strum, 'height')

            local minY = 0
            local maxY = math.max(0, screenHeight - height)

            local baseY = math.max(
                minY,
                math.min(maxY, playerBaseY[index])
            )

            local direction = downscroll and 1 or -1
            local availableSpace

            if direction == 1 then
                availableSpace = maxY - baseY
            else
                availableSpace = baseY - minY
            end

            local offset = math.min(
                screenHeight * PLAYER_Y_OFFSET,
                math.max(0, availableSpace)
            )

            playerWaveY[index] = baseY + (offset * direction)

            local spaceUp = playerWaveY[index] - minY
            local spaceDown = maxY - playerWaveY[index]

            playerWaveAmplitude[index] = math.max(
                0,
                math.min(WAVE_AMPLITUDE, spaceUp, spaceDown)
            )

            noteTweenY(
                'playerLower' .. i,
                strum,
                playerWaveY[index]+(getPropertyFromGroup('strumLineNotes', strum, 'height') * direction),
                TRANSITION_DURATION,
                'cubeInOut'
            )

        end

        startPlayerSweep(true)

    elseif value1 == 'endmodchart' then

        refreshBases()

        waveActive = false
        sweepActive = false

        setProperty('pressMissDamage', 0.05)

        applyOpponentNoteScale(1)
        noteScaleFrom = 1
        noteScaleTo = 1

        if not usesMobileLayout() then
            showOpponentNotes()
        end

        for i = 0, 3 do
            cancelTimer('playerWaveStart' .. i)
        end

        for i = 0, 3 do

            cancelTween('playerLower' .. i)

            cancelTween('playerWaveUp' .. i)
            cancelTween('playerWaveDown' .. i)

            cancelTween('playerSweep' .. i)

            cancelTween('playerRestoreX' .. i)
            cancelTween('playerRestoreY' .. i)

        end

        for i = 0, 3 do

            cancelTween('opScaleX' .. i)
            cancelTween('opScaleY' .. i)
            cancelTween('opAlpha' .. i)

            setProperty('strumLineNotes.members[' .. i .. '].scale.x', opponentScaleX[i + 1])
            setProperty('strumLineNotes.members[' .. i .. '].scale.y', opponentScaleY[i + 1])

            noteTweenAlpha(
                'opRestoreAlpha' .. i,
                i,
                opponentAlpha[i + 1],
                TRANSITION_DURATION,
                'cubeInOut'
            )

        end

        for i = 0, 3 do

            noteTweenX(
                'playerRestoreX' .. i,
                i + 4,
                playerBaseX[i + 1],
                TRANSITION_DURATION,
                'cubeInOut'
            )

            noteTweenY(
                'playerRestoreY' .. i,
                i + 4,
                playerBaseY[i + 1],
                TRANSITION_DURATION,
                'cubeInOut'
            )

        end

    end

end

function onTimerCompleted(tag, loops, loopsLeft)

    if not waveActive then
        return
    end

    if string.find(tag, 'playerWaveStart') == 1 then

        local index = tonumber(
            string.sub(
                tag,
                string.len('playerWaveStart') + 1
            )
        )

        if index ~= nil then
            startPlayerWave(index, 'up')
        end

    end

end

function onTweenCompleted(tag)

    for i = 0, 3 do

        if tag == 'playerLower' .. i then

            runTimer(
                'playerWaveStart' .. i,
                WAVE_STAGGER * i
            )

        end

    end

    for i = 0, 3 do

        if tag == 'playerWaveUp' .. i then

            if waveActive then
                startPlayerWave(i, 'down')
            end

        elseif tag == 'playerWaveDown' .. i then

            if waveActive then
                startPlayerWave(i, 'up')
            end

        end

    end

    for i = 0, 3 do

        if tag == 'playerSweep' .. i then

            if sweepActive then

                sweepCompleted = sweepCompleted + 1

                if sweepCompleted >= 4 then

                    sweepDirection = not sweepDirection

                    startPlayerSweep(sweepDirection)

                end

            end

        end

    end

end
