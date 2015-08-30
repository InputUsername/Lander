-- Lander
-- (c) 2015 Koen Bolhuis

require("lfs")

local action = arg[1]
local arguments = {}

for i = 2, #arg do
	table.insert(arguments, arg[i])
end

---- Utility functions ----
local function pathInfo(path)
	-- Returns {location, name + extension, name, extension}
	return {string.match(path, "(.-)(([^/]-)%.([^%.]+))$")}
end

local function isHtmlFile(path)
	local ext = pathInfo(path)[4]
	return (ext == "html" and lfs.attributes(path, "mode") == "file")
end

function string.ends(str, trailing)
	return (trailing == "" or string.sub(str, -string.len(trailing)) == trailing)
end

local function readFile(path)
	local handle = io.open(path)
	if not handle then return end
	local content = handle:read("*a")
	handle:close()
	return content
end

local function writeFile(path, text)
	local handle = io.open(path, "w")
	if not handle then return false end
	handle:write(text)
	handle:close()
	return true
end

---- Constants ----
local POSTS_DIR = "_posts"
local PAGES_DIR = "_pages"
local OUTPUT_DIR = "_output"

local INDEX_FILE = "_pages/index.html"
local INDEX_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title><% echo( config.site.name ) %></title>
</head>
<body>
	<h1>Hello world!</h1>
</body>
</html>]]

local POST_FILE = "_pages/post.html"
local POST_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title><% echo( post.title ) %></title>
</head>
<body>
	<h1><% echo( post.title ) %></h1>
	<p>Posted on <% echo( post.date ) %> by <% echo( post.author ) %></p>
	<p><% echo( post.content ) %></p>
</body>
</html>]]

local CONFIG_FILE = "_config.lua"
local CONFIG_DEFAULT_CONTENT = [[return {
	site = {
		name = "A website",
	},
	pagesAsDirectories = false,
}]]

---- Required files and directories ----
local DIRECTORIES = {POSTS_DIR, PAGES_DIR, OUTPUT_DIR}

local FILES = {
	[INDEX_FILE] = INDEX_DEFAULT_CONTENT,
	[POST_FILE] = POST_DEFAULT_CONTENT,
	[CONFIG_FILE] = CONFIG_DEFAULT_CONTENT,
}

---- Actions ----
if action == "setup" then

	local output = ""
	if arguments[1] then
		output = arguments[1] .. "/"
	end

	print("Setting up site")

	print("* Making directories")
	for _, dir in ipairs(DIRECTORIES) do
		print(" * " .. output .. dir .. "/")
		lfs.mkdir(output .. dir)
	end

	print("* Making files")
	for file, content in pairs(FILES) do
		print(" * " .. output .. file)

		local handle = io.open(output .. file, "w")

		if not handle then
			print("Error: cannot create '" .. output .. file .. "'")
			os.exit(1)
		end

		if content and content ~= "" then
			handle:write(content)
		end

		handle:close()
	end

	print("Done")

elseif action == "make" then

	local target = ""
	if arguments[1] then
		target = arguments[1] .. "/"
	end

	print("Generating site")

	-- Load configuration file
	local result, configFunc = pcall(loadfile, target .. CONFIG_FILE)

	if not result then
		print("Error: cannot open the site config file (" .. target .. CONFIG_FILE .. ")")
		os.exit(1)
	end

	local result, config = pcall(configFunc)

	if not result or not config then
		print("Error: something went wrong while loading the site config file")
		os.exit(1)
	end

	print("* Loaded site config")

	-- Load Markdown renderer
	local markdown = require("markdown")

	if not markdown then
		print("Error: something went wrong while loading the Markdown renderer")
		os.exit(1)
	end

	print("* Loaded Markdown renderer")

	print("* Converting pages")

	-- Handle pages
	for file in lfs.dir(target .. PAGES_DIR) do
		local filePath = target .. PAGES_DIR .. "/" .. file

		if isHtmlFile(filePath) and not string.ends(filePath, POST_FILE) then
			local outputPath = target .. OUTPUT_DIR .. "/" .. file

			print(" * " .. filePath .. " -> " .. outputPath)

			local fileContent = readFile(filePath)

			fileContent = string.gsub(fileContent, "%<%%(.-)%%%>", function(code)
				local output = ""

				local env = {
					["echo"] = function(...)
						local out = table.concat({...}, "\n")
						if type(out) == "string" then
							output = output .. out
						end
					end,
					["config"] = config,
				}

				local codeFunc, err = loadstring(code)
				if not codeFunc then
					print("Error: something went wrong while loading template code")
					print(err)
					env.echo(err .. "\n")
				else
					setfenv(codeFunc, env)
					local result, err = pcall(codeFunc)
					if not result then
						print("Error: something went wrong while running template code")
						print(err)
						env.echo(err .. "\n")
					end
				end

				return output
			end)

			writeFile(outputPath, fileContent)
		end
	end

	print("Done")

end
