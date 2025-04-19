storyData = {}

function loadresources()
	storyjson = loadresource("story.json", "text")
end

function startGame()
	saveState.variables = deepcopy(storyData.variableDefs)
	linkTo("main", "start")
end

function init()
	storyData = jsonparse(gettext(storyjson))
	startGame()
end

function showtext()
	drawtext(storyData.stories["main"].cards["start"].cardType, 20, 20)
end

lastInputTime = 0
inputCooldown = 0.1

function update()
	if time() - lastInputTime < inputCooldown then
		return
	end

	local inputProcessed = false

	if input(8) then
		if selectedid < #linkids then
			selectedid = selectedid + 1
			inputProcessed = true
		end
	elseif input(4) then
		if selectedid > 1 then
			selectedid = selectedid - 1
			inputProcessed = true
		end
	elseif input(16) then
		linkTo(saveState.story, linkids[selectedid])
		inputProcessed = true
	end

	if inputProcessed then
		lastInputTime = time()
	end
end

function handleMeta(metaData)
	for i, meta in ipairs(metaData) do
		if meta.customKey == "portrait" then
			portrait = loadbuiltin("portrait-" .. meta.customValue .. ".png", "image")
		end

		if meta.customKey == "bg" then
			bg = loadbuiltin(meta.customValue .. ".png", "image")
		end

		if meta.customKey == "topstyle" then
			topstyle = meta.customValue
		end
	end
end

linkids = {}
selectedid = 1
shownlinks = 0

portrait = loadbuiltin("portrait-erin.png", "image")
bg = loadbuiltin("hm-skybox1.png", "image")

toptextcolor = 8
replytextcolor = 8
replytextcolorselected = 32
topstyle = "dialogue"
toptextx = 110
toptextw = 360

function render()
	cls()

	drawimg(bg, 0, 0)

	if topstyle == "dialogue" then
		drawimg(portrait, 10, 10)
	end

	displaytext = ""

	for i, item in ipairs(showPageData.data.paragraphs) do
		if conditionCheck(item.conditions) then
			displaytext = displaytext .. storyData.loc[item.text][storyData.currentLanguage] .. "\n"
		end
	end

	if topstyle == "dialogue" then
		toptextx = 110
		toptextw = 360
	end

	if topstyle == "narration" then
		toptextx = 20
		toptextw = 460
	end

	drawtext(displaytext, toptextx, 20, toptextcolor, nil, toptextw, 140)

	linknumber = 1
	linkids = {}

	yoffset = 240

	lineheight = 21

	for i, item in ipairs(showPageData.data.links) do
		if conditionCheck(item.conditions) and item.linkText ~= "na" then
			yoffset = yoffset - lineheight
		end
	end

	for i, item in ipairs(showPageData.data.links) do
		if conditionCheck(item.conditions) and item.linkText ~= "na" then
			local linkText = storyData.loc[item.linkText][storyData.currentLanguage]

			selected = "   "
			linkcolor = replytextcolor

			if selectedid == linknumber then
				selected = "-> "
				linkcolor = replytextcolorselected
			end

			drawtext(selected .. linkText, 10, yoffset + (linknumber * lineheight), linkcolor, nil, 460, 40)

			linkids[#linkids + 1] = item.target
			linknumber = linknumber + 1
		end
	end
end

saveState = {
	storyTrail = {},
	variables = {},
	story = "",
	card = "",
}

thisPage = {
	paragraphs = {},
	elinks = {},
}

page = "home"

showPageData = { data = {} }
imageShown = { img = "" }

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end

function getCardNode(story, card)
	return storyData.stories[story].cards[card]
end

function showPage(story, card)
	local thisCardData = storyData.stories[story].cards[card]
	for i, paragraph in ipairs(thisCardData.paragraphs) do
		paragraph.class = "narration"
		local locText = storyData.loc[paragraph.text][storyData.currentLanguage]
	end
	handleMeta(thisCardData.custom)
	showPageData.data = deepcopy(thisCardData)
end

function linkTo(story, card)
	selectedid = 1
	local thisCard = getCardNode(story, card)

	saveState.story = story
	saveState.card = card

	if thisCard.nodeType == "start" then
		local goCard = storyData.stories[story].cards["start"].links[1].target
		linkTo(story, goCard)
	elseif thisCard.nodeType == "end" then
		if #saveState.storyTrail == 0 then
			return
		end

		local lastCrumb = saveState.storyTrail[#saveState.storyTrail]
		saveState.storyTrail[#saveState.storyTrail] = nil

		local linkCardId = storyData.stories[lastCrumb.story].cards[lastCrumb.card].links[1].target
		linkTo(lastCrumb.story, linkCardId)
	elseif thisCard.nodeType == "card" then
		showPage(story, card)
	elseif thisCard.nodeType == "detour" then
		saveState.storyTrail[#saveState.storyTrail + 1] = {
			story = story,
			card = card,
		}
		local linkedStorylet = thisCard.detours[1].target
		linkTo(linkedStorylet, "start")
	elseif thisCard.nodeType == "logic" then
		print("logic")
		storyData.currentSaveState.story = story
		local thisCard = storyData.stories[story].cards[card]
		local gotoLink = ""

		if #thisCard.links > 0 then
			gotoLink = thisCard.links[#thisCard.links].target
		end

		if #thisCard.links > 1 then
			for i = 1, #thisCard.links - 1 do
				if conditionCheck(thisCard.links[i].conditions) then
					gotoLink = thisCard.links[i].target
					break
				end
			end
		end
		linkTo(story, gotoLink)
	elseif thisCard.nodeType == "operator" then
		local thisOps = thisCard.links[1].operations
		local linkedCard = thisCard.links[1].target
		for i, op in ipairs(thisOps) do
			if op.operator == "eq" then
				saveState.variables[op.variable].value = op.value
			elseif op.operator == "inc" then
				saveState.variables[op.variable].value = tonumber(saveState.variables[op.variable].value)
					+ tonumber(op.value)
			elseif op.operator == "dec" then
				saveState.variables[op.variable].value = tonumber(saveState.variables[op.variable].value)
					- tonumber(op.value)
			elseif op.operator == "rnd" then
				local rndVal = randint(tonumber(op.value))
				saveState.variables[op.variable].value = rndVal
			elseif op.operator == "eval" then
				print("not supported")
			end
		end
		linkTo(story, linkedCard)
	elseif thisCard.nodeType == "meta" then
		local thisMeta = thisCard.custom
		local linkedCard = thisCard.links[1].target
		handleMeta(thisMeta)
		linkTo(story, linkedCard)
	end
end

function conditionCheck(conditions)
	if not conditions or #conditions == 0 then
		return true
	end

	local truthyCount = 0
	for i, cond in ipairs(conditions) do
		if cond.operator == "eq" then
			if tostr(saveState.variables[cond.variable].value) == tostr(cond.value) then
				truthyCount = truthyCount + 1
			end
		elseif cond.operator == "neq" then
			if saveState.variables[cond.variable].value ~= cond.value then
				truthyCount = truthyCount + 1
			end
		elseif cond.operator == "gt" then
			if tonumber(saveState.variables[cond.variable].value) > tonumber(cond.value) then
				truthyCount = truthyCount + 1
			end
		elseif cond.operator == "gte" then
			if tonumber(saveState.variables[cond.variable].value) >= tonumber(cond.value) then
				truthyCount = truthyCount + 1
			end
		elseif cond.operator == "lt" then
			if tonumber(saveState.variables[cond.variable].value) < tonumber(cond.value) then
				truthyCount = truthyCount + 1
			end
		elseif cond.operator == "lte" then
			if tonumber(saveState.variables[cond.variable].value) <= tonumber(cond.value) then
				truthyCount = truthyCount + 1
			end
		elseif cond.operator == "eval" then
			local evalStr = replaceVarsForEval(cond.value)
			local evalFn = loadstring("return " .. evalStr)
			if evalFn and evalFn() then
				truthyCount = truthyCount + 1
			end
		end
	end
	return truthyCount == #conditions
end

function clickGo(target)
	linkTo(saveState.story, target)
end
