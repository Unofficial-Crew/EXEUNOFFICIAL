local sentenceIndex = 0
local sentenceWords = {}
local wordIndex = 0
local prevVal1 = nil
local useAutoSpaces = true

function onCreatePost()
	makeLuaText('mytext', '', 860)
	screenCenter('mytext', 'x')
	setTextSize('mytext', 28)
	setTextFont('mytext', 'sonichud.ttf')
	setObjectCamera('mytext', 'other')
	addLuaText('mytext')
end

function onEvent(n, val1, val2)
	if n == 'Lyrics' then
		local isNewSentence = (prevVal1 == nil) or (val1:sub(1, #prevVal1) ~= prevVal1)

		if isNewSentence then
			sentenceIndex = sentenceIndex + 1
			local key = 'lyrics.prey.' .. sentenceIndex
			local translated = getSongLyric(key, val1)
			sentenceWords = {}

			if translated:find(';') then
				useAutoSpaces = false
				for part in (translated .. ';'):gmatch('([^;]*);') do
					if part ~= '' then
						table.insert(sentenceWords, part)
					end
				end
			else
				useAutoSpaces = true
				for w in translated:gmatch('%S+') do
					table.insert(sentenceWords, w)
				end
			end

			wordIndex = 0
		end

		if wordIndex < #sentenceWords then
			wordIndex = wordIndex + 1
		end

		local display = ''
		for i = 1, wordIndex do
			if i > 1 and useAutoSpaces then 
				display = display .. ' ' 
			end
			display = display .. sentenceWords[i]
		end

		prevVal1 = val1

		setTextString('mytext', display)
		setTextColor('mytext', val2)

		cancelTween('Noo')
		cancelTimer('goodbye')
		setProperty('mytext.alpha', 1)
		runTimer('goodbye', 1)
	end
end

function onTimerCompleted(t)
	if t == 'goodbye' then
		doTweenAlpha('Noo', 'mytext', 0, 1)
	end
end