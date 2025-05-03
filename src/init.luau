--!optimize 2
--!native
--!strict

local TS = game:GetService("TextService")
local EvaluateRichtext = require(script.EvaluateRichtext)
local GetCharacterSize = require(script.GetCharacterSize)

local escapechars = {
	["&amp;"] = "&";
	["&lt;"] = "<";
	["&gt;"] = ">";
	["&quot;"] = '"';
	["&apos;"] = "'";
}

export type LineInfo = {
	Content: string;
	Height: number;
	Width: number;
}

export type WrapTextResult = {
	Width: number;
	Height: number;
	
	Lines: {LineInfo};
	CharacterOffsets: {vector}?;
}

type textsource = TextLabel | {
	Text: string;
	TextSize: number;
	Width: number;
	
	FontFace: Font;
	RichText: boolean;
}

local textparams = Instance.new("GetTextBoundsParams")
textparams.RichText = true

local empty = {}

-- Wrap text into lines and finds offset of each character within 'CharactersToFind' if array is provided.
@native
local function WrapText(TextSource: textsource, CharactersToFind: {number}?): (WrapTextResult)
	local findcharacterresult
	local sortedcharacterarray: {number}?
	
	if CharactersToFind then
		findcharacterresult = {}
		
		sortedcharacterarray = table.clone(CharactersToFind)
		table.sort(sortedcharacterarray :: {number})		
	end
	
	local textmaxwidth, richtextsuccess
	local text = TextSource.Text
	local textsize = TextSource.TextSize

	if type(TextSource) == 'table' then
		textmaxwidth = TextSource.Width
		if TextSource.RichText then
			textparams.Size = textsize
			textparams.Text = text 
			
			richtextsuccess = pcall(TS.GetTextBoundsAsync, TS, textparams)
		end
	else 
		textmaxwidth = TextSource.AbsoluteSize.X
		richtextsuccess = if TextSource.RichText then TextSource.ContentText ~= text else false
	end
	
	local richtextdetails, escapepositions
	if richtextsuccess then richtextdetails, escapepositions = EvaluateRichtext(text, textsize, TextSource.FontFace) end

	local currentfont: Font = TextSource.FontFace
	local fonthash: string?
	
	local richtextstart, richtextend = "", ""
	local currentlinecontent = ""
	local currentcharadd = ""

	local richtext_forceupper = false
	local richtext_smallcaps = false
	local linesizechanged = true
	local haswhitespace = false
	local currentwhitespacecount = 0
	
	local currenttextsize = textsize

	local position = 0
	local splitposition = 0
	
	local splitpointwidth = 0
	local lastcurrentwidth = 0
	local currentwidth = 0
	local currentheight = 0
	
	local splitpointrichtextstart = ""
	local splitpointrichtextend = ""
	
	local lines = {}
	local linesizes: {{number}} = {}
	
	local thislinefoundcharacters: {true} = if sortedcharacterarray then {} else empty
	local foundcharactersinpotentialnewline: {true} = if sortedcharacterarray then {} else empty
	
	local function newline(mergecharadd: boolean?)
		local content, height, width = "", 0, 0

		if mergecharadd then
			content = `{currentlinecontent}{currentcharadd}{richtextend}`
			width = currentwidth

			for _, info in linesizes do 
				height = math.max(height, info[2])
			end
			
			table.clear(linesizes)
			linesizes[1] = {position, currenttextsize}

			currentcharadd = ""
			lastcurrentwidth = 0
			currentwidth = 0
			
			currentlinecontent = richtextstart
			
			for pos in thislinefoundcharacters do 
				local vec = findcharacterresult[pos]
				findcharacterresult[pos] = vector.create(vec.x, vec.y, height)
			end
			
			table.clear(thislinefoundcharacters)
		else 
			content = `{currentlinecontent}{splitpointrichtextend}`
			width = math.min(splitpointwidth, textmaxwidth)
			
			do 
				local toremove = nil
				for i, info in linesizes do 
					if info[1] <= splitposition then 
						toremove = i 
						height = math.max(height, info[2])
					else break end
				end

				if toremove and toremove ~= 1 then
					-- keep only the last number in linesizes! it's used in next line,
					table.move(linesizes, toremove, #linesizes + (toremove - 1), 1)
				end
			
			end
			
			lastcurrentwidth -= splitpointwidth
			currentwidth -= splitpointwidth
			
			for pos in foundcharactersinpotentialnewline do 
				findcharacterresult[pos] += vector.create(-splitpointwidth, height)
			end
			
			for pos in thislinefoundcharacters do 
				if foundcharactersinpotentialnewline[pos] then continue end 
				thislinefoundcharacters[pos] = nil
				
				local vec = findcharacterresult[pos]
				findcharacterresult[pos] = vector.create(vec.x, vec.y, height)
			end
			
			currentlinecontent = splitpointrichtextstart
		end

		currentheight += height
		
		table.clear(foundcharactersinpotentialnewline)
		table.insert(lines, {
			Content = content;
			Height = height;
			Width = width;
		})

		haswhitespace = false
		splitpointwidth = 0
	end
	
	local function checkfindcharacter(iswhitespace)
		if sortedcharacterarray then
			local toremove
			for i, findpos in sortedcharacterarray do 
				if findpos < position then
					toremove = i 

					local location = table.find(CharactersToFind :: {number}, findpos) :: number

					findcharacterresult[location] = vector.create(math.max(0, lastcurrentwidth), currentheight)
					thislinefoundcharacters[location] = true 
					
					if haswhitespace and (not iswhitespace) then
						foundcharactersinpotentialnewline[location] = true
					end
				else break end
			end

			if toremove then
				local len = #sortedcharacterarray
				if toremove == len then
					table.clear(sortedcharacterarray)
					sortedcharacterarray = nil
				else table.move(sortedcharacterarray, toremove + 1, len + toremove, 1) end
			end
		end
	end

	local previouschar
	local previousissmallcaps = false
	
	while true do 
		position += 1
		
		checkfindcharacter(previouschar == " ")
		local s, e = string.find(text, utf8.charpattern, position)
		
		if not s then 
			if (currentcharadd ~= "") or (haswhitespace) then newline(true) end
			break 
		end
		
		position = e :: number
		
		local whitespacecount = 0
		local isescape = false
		
		local newchar = string.sub(text, s, e)
		if newchar == "<" then
			local richtexttag: EvaluateRichtext.richtexttag? = if richtextsuccess then richtextdetails[position] else nil

			if richtexttag then
				local t = richtexttag.t

				if t == 'add' then
					local content = richtexttag[1]
					
					currentcharadd = `{currentcharadd}{content}`
					
					richtextstart = `{richtextstart}{content}`
					richtextend = `{richtexttag[2]}{richtextend}`
					
					-- i wish i could change how the bottom part looks
					if richtexttag.size then 
						currenttextsize = richtexttag.size 
						linesizechanged = true
					end

					if richtexttag.family then currentfont.Family = richtexttag.family end
					if richtexttag.weight then currentfont.Weight = richtexttag.weight end
					if richtexttag.style then currentfont.Style = richtexttag.style end
					
					if richtexttag.smallcaps then richtext_smallcaps = true end
					if richtexttag.forceupper then richtext_forceupper = true end
					
					fonthash = nil -- force update
					
				elseif t == 'remove' then
					local richtexttag = richtexttag[1]
					local finisher = richtexttag[2]

					if #currentcharadd > 0 then
						currentcharadd = `{currentcharadd}{finisher}`
					else
						if haswhitespace then
							-- didnt do new line, but whitespace exists
							-- so remove it from splitpointrichtextstart to ensure it doesnt get added again
							splitpointrichtextstart = string.sub(splitpointrichtextstart, 1, -(richtexttag[3])) 
						else
							-- did new line, either by whitespace or idk
							currentlinecontent = string.sub(currentlinecontent, 1, -(richtexttag[3])) 
						end
					end
					
					richtextstart = string.sub(richtextstart, 1, -(richtexttag[3])) 
					richtextend = string.sub(richtextend, (richtexttag[4]))
					
					-- i wish i could change how the bottom part looks
					if richtexttag.lastsize then 
						currenttextsize = richtexttag.lastsize 
						linesizechanged = true 
					end
					
					if richtexttag.lastfamily then currentfont.Family = richtexttag.lastfamily end
					if richtexttag.lastweight then currentfont.Weight = richtexttag.lastweight end
					if richtexttag.laststyle then currentfont.Style = richtexttag.laststyle end

					if richtexttag.smallcaps then richtext_smallcaps = false end
					if richtexttag.forceupper then richtext_forceupper = false end
					
					fonthash = nil -- force update
					
				elseif t == 'newline' then
					newchar = "\n" -- mock our beloved '\n' and continue off as impostor
				elseif t == 'comment' then
					currentcharadd = `{currentcharadd}{richtexttag[1]}`
				end
				
				position = richtexttag.e
				
				if t ~= 'newline' then
					continue
				end
			end
		elseif newchar == "&" then
			local match = richtextsuccess and escapepositions[position]
			if match then
				newchar = match
				position += #match - 1
				isescape = true
			end
		elseif newchar == " " then
			if sortedcharacterarray then
				whitespacecount += 1 -- position may be in whitespace
			else
				-- skip alllllll that whitespace, ignore errors here, the values are guaranteed to not be nil.
				local s, e, match = string.find(text, "^( +)", position, false)
				newchar = match
				whitespacecount = (e - s) + 1

				position = e
			end
			
			if currentwhitespacecount > 0 and (not haswhitespace) then continue end -- skip
		elseif newchar == "\r" then -- kill it and \r\n
			if string.sub(text, position + 1, position + 1) == "\n" then
				position += 1
			end
			
			newchar = "\n"
		end
		
		if linesizechanged then
			linesizechanged = false
			table.insert(linesizes, {s, currenttextsize})
		end

		local do_newline = false
		local isbreakline = false

		local length, truelength = 0, 0

		if newchar == "\n" then
			isbreakline = true
			do_newline = true
		else
			if whitespacecount > 0 then
				currentlinecontent = `{currentlinecontent}{currentcharadd}{newchar}`
				newchar = " "; currentcharadd = ""

				haswhitespace = true
				linesizechanged = true
				
				currentwhitespacecount += whitespacecount
			else 
				currentwhitespacecount = 0
			end

			if fonthash == nil then fonthash = tostring(currentfont) end
			
			local newcharcheck = if isescape then escapechars[newchar] else newchar
			length, truelength, previouschar = GetCharacterSize.get(previouschar, newcharcheck, fonthash :: string, currentfont, currenttextsize, richtext_smallcaps, richtext_forceupper, previousissmallcaps)
			previousissmallcaps = richtext_smallcaps and previouschar ~= newcharcheck
			
			if whitespacecount > 0 then 
				if sortedcharacterarray then
					table.clear(foundcharactersinpotentialnewline)
				else 
					length += truelength * (whitespacecount - 1)
				end
				
				splitpointwidth = currentwidth + length
				splitposition = position

				splitpointrichtextstart = richtextstart
				splitpointrichtextend = richtextend
			end
			
			do_newline = (currentwidth + length) > textmaxwidth
		end 
		
		if do_newline then
			previouschar = nil
			newline((not haswhitespace) or isbreakline)
		end

		if (not isbreakline) then
			lastcurrentwidth = currentwidth
			currentwidth += length
			if whitespacecount == 0 then currentcharadd ..= newchar end
		end
	end
	
	local highestwidth = 0
	for _, line in lines do 
		highestwidth = math.max(highestwidth, line.Width)
	end
	
	return {
		Width = highestwidth;
		Height = currentheight;
		
		Lines = lines;
		CharacterOffsets = findcharacterresult;
	}
end

return {
	WrapText = WrapText;
	ResetCache = GetCharacterSize.reset;
}