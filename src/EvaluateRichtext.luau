--!optimize 2

local escapechars = {
	["&amp;"] = true;
	["&lt;"] = true;
	["&gt;"] = true;
	["&quot;"] = true;
	["&apos;"] = true;
}

export type richtexttag = {
	t: 'add' | 'remove' | 'newline' | 'comment';
	s: number;
	e: number;
	
	lasttag: richtexttag?;
	
	size: number?; lastsize: number?;
	family: string?; lastfamily: string?;
	
	weight: Enum.FontWeight?; lastweight: Enum.FontWeight?;
	style: Enum.FontStyle?; laststyle: Enum.FontStyle?;
	
	smallcaps: boolean?;
	forceupper: boolean?;
	
	[number]: any;
}
type richtextresult = {[number]: richtexttag}
type characterescaperesult = {[number]: any}

-- Returns richtext details alongside an array containing position of escaped characters.
return @native function(text: string, textsize: number, font: Font): (richtextresult, {[number]: any})
	-- no need to check for correctness since if gettextboundsasync or contenttext ~= text work, then its correct
	
	local details: richtextresult = {}
	local escapetags: characterescaperesult = {}
	
	local forceupper = false
	local issmallcaps = false
	
	local currentfamily, currentweight, currentstyle = font.Family, font.Weight, font.Style
	
	local currenttag: richtexttag?
	local currentsize: number = textsize
	
	local position: number = 1

	while true do 
		local char_s = string.find(text, "[<&]", position, false)

		if char_s then
			local char = string.sub(text, char_s, char_s)
			if char == "<" then
				local s, e, content = string.find(text, "(%b<>)", position, false)

				if content == "<br />" then
					details[s] = {t = 'newline', s = s, e = e}
				elseif string.sub(content, 1, 4) == "<!--" then
					details[s] = {t = 'comment', s = s, e = e, content}
					
				elseif string.sub(content, 1, 2) == "</" then
					local info = currenttag
					currenttag = info.lasttag
					info.lasttag = nil
					
					
					if info.lastsize then currentsize = info.lastsize end 
					if info.lastfamily then currentfamily = info.lastfamily end
					if info.lastweight then currentweight = info.lastweight end
					if info.laststyle then currentstyle = info.laststyle end
					
					if info.smallcaps then issmallcaps = false end
					if info.forceupper then forceupper = false end
					
					details[s] = {t = 'remove', s = s, e = e, info}		
				else
					local ts, te, tm = string.find(content, "^(%w+)", 2, false)

					local finisher = `</{tm}>`
					local info = {t = "add", s = s, e = e, content, finisher, (e - s) + 2, (te - ts) + 5}

					if tm == "font" then
						local donetags = {}
						local pos = te + 1
						
						while true do 
							local s, e, name, value = string.find(content, '(%w+) *= *(%b"")', pos)
							if e then
								pos = e + 1
								if not donetags[name] then
									value = string.sub(value, 2, -2)
									
									donetags[name] = true
									if name == 'size' then
										local size = tonumber(value)
										info.lastsize, info.size, currentsize = currentsize, size, size
										
									elseif name == 'family' then
										info.lastfamily, info.family, currentfamily = currentfamily, value, value
										
									elseif name == 'face' then
										value = `rbxasset://fonts/families/{value}.json`
										info.lastfamily, info.family, currentfamily = currentfamily, value, value
										
									elseif name == 'weight' then
										if tonumber(value) then value = Enum.FontWeight:FromValue(tonumber(value) :: number)
										else value = Enum.FontWeight:FromName(value) end
										
										info.lastweight, info.weight, currentweight = currentweight, value, value
									end
								end
							else break end
						end
					elseif (tm == "i") then
						local value = Enum.FontStyle.Italic
						if currentstyle ~= value then
							info.laststyle, info.style, currentstyle = currentstyle, value, value
						end
					elseif (tm == 'b') then
						local value = Enum.FontWeight.Bold
						if currentweight ~= value then
							info.lastweight, info.weight, currentweight = currentweight, value, value
						end
					elseif (tm == "uc" or tm == "uppercase") then
						if not forceupper then
							info.forceupper = true
							forceupper = true
						end
					elseif (tm == 'sc' or tm == 'smallcaps') then
						if not issmallcaps then
							info.smallcaps = true
							issmallcaps = true
						end
					end

					info.lasttag = currenttag
					currenttag = info 

					details[char_s] = info
				end

				details[e] = details[s]
				position = e + 1
			else 
				local s, e, match = string.find(text, "^(&%w+;)", char_s, false)
				if match then
					if escapechars[match] then
						escapetags[char_s] = match
						escapetags[e] = s
					end 

					position = e + 1 -- its guaranteed we got no richtext in here so no need to check whats between & and ;
				else position = char_s + 1 end
			end

		else break end
	end

	return details, escapetags
end