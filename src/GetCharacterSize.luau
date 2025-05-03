--!strict
local TS = game:GetService("TextService")

type fonthash = string;
type fontsizedetails = {
	kerning: {[string]: number;};
	characterwidth: {[string]: number;}
}
type fontdetails = {fontsizedetails}

local fontdetails: { [fonthash]: fontdetails } = {}
local exposed = {}

local params = Instance.new("GetTextBoundsParams")

local escapechars = {
	["&amp;"] = "&";
	["&lt;"] = "<";
	["&gt;"] = ">";
	["&quot;"] = '"';
	["&apos;"] = "'";
}

local function getfontsizedetails(hash: fonthash, textsize): fontsizedetails
	local details = fontdetails[hash]

	if not details then
		details = {}
		fontdetails[hash] = details
	end

	if not details[textsize] then
		details[textsize] = {
			kerning = {};
			characterwidth = {};
		}
	end

	return details[textsize]
end

local function getcharkey(char: string)
	return escapechars[char] or char
end

local function configureparams(textsize: number, forcerichtext: boolean?)
	local charstart, charend = "", ""
	params.RichText = forcerichtext :: boolean
	
	if textsize > 100 then charstart, charend = `<font size={textsize}>`, "</font>"
	else params.Size = textsize end
	
	return charstart, charend
end

local function getcharactersize(char: string, hash: fonthash, font: Font, textsize: number, forcerichtext: boolean?): number
	local details = getfontsizedetails(hash, textsize)
	local key = getcharkey(char)
	
	local width = details.characterwidth[key]
	
	if (not width) then
		local charstart, charend = configureparams(textsize, forcerichtext)
		
		params.Font = font 
		params.Text = `{charstart}{char}{charend}` 
		
		local bounds = TS:GetTextBoundsAsync(params)
		width = bounds.X
		
--		warn(`width of "{key}" is {width}`)
		details.characterwidth[key] = width
	end

	return width
end

local function getkerning(previouschar: string, currentchar: string, hash: fonthash, font: Font, textsize: number, forcerichtext: boolean?)
	local details = getfontsizedetails(hash, textsize)
	local currentcharkey = getcharkey(currentchar)
	local key = `{getcharkey(previouschar)}{currentcharkey}`

	local kerning = details.kerning[key]

	if not kerning then
		local charstart, charend = configureparams(textsize, forcerichtext)

		local previouswidth = getcharactersize(previouschar, hash, font, textsize, forcerichtext) 
		-- ^^ it doesnt necessarily exist in fontsizedetails, since font could've changed
		
		local currentwidth = details.characterwidth[currentcharkey] -- always exists
		
		params.Font = font 
		params.Text = `{charstart}{previouschar}{currentchar}{charend}` 
		
		local bounds = TS:GetTextBoundsAsync(params)
		kerning = bounds.X - (previouswidth + currentwidth)
		
		details.kerning[key] = kerning
	end
	
	return kerning
end

return {
	get = function(previouschar: string?, char: string, hash: string, font: Font, textsize: number, issmallcaps: boolean?, isupper: boolean?, previousissmallcaps: boolean?): (number, number, string)
		local forcerichtext: boolean = textsize > 100
		
		if #char == 1 then
			if isupper then char = string.upper(char) end
			if char == "<" and forcerichtext then char = "&lt;"; end
			
			if issmallcaps then
				local byte = string.byte(string.lower(char))
				if byte >= 97 --[[a]] and byte <= 122 --[[z]] then
					char = `<sc>{char}</sc>`; forcerichtext = true 
				end
			end
		end
		
		local width = getcharactersize(char, hash, font, textsize, forcerichtext)
		local truewidth = width
		
		if previouschar then
			width += getkerning(previouschar, char, hash, font, textsize, forcerichtext or previousissmallcaps)
		end

		return width, truewidth, char
	end;

	reset = function()
		table.clear(fontdetails)
	end,
}