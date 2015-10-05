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

local function checkExtension(path, extension)
	local pathExt = pathInfo(path)[4]
	return (pathExt == extension and lfs.attributes(path, "mode") == "file")
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

local function validatePost(postInfo)
	return postInfo["title"] and postInfo["timestamp"] and postInfo["author"]
end

local function linkTitle(title)
	title = string.lower(title)
	title = string.gsub(title, "%s", "-")
	title = string.gsub(title, "[^%w%-_]", "")

	return title
end

local function recursiveDelete(path)
	if string.sub(string.match(path, "([^/]+/?)$"), 1, 1) == "." then return end

	if lfs.attributes(path, "mode") == "directory" then
		for file in lfs.dir(path) do
			recursiveDelete(path .. "/" .. file)
		end

		lfs.rmdir(path)
	end

	os.remove(path)
end

---- Constants ----
local POSTS_DIR = "_posts"
local PAGES_DIR = "_pages"
local INCLUDES_DIR = "_includes"
local OUTPUT_DIR = "_output"

local INDEX_FILE = "_pages/index.html"
local INDEX_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title><% echo( config.siteName ) %></title>
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
local CONFIG_DEFAULT_CONTENT = [[config = {
	siteName = "A website",
	pagesAsDirectories = false,
}]]

---- Required files and directories ----
local DIRECTORIES = {POSTS_DIR, PAGES_DIR, INCLUDES_DIR, OUTPUT_DIR}

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

	--[[
	-- Remove previous output
	for file in lfs.dir(target .. OUTPUT_DIR) do
		recursiveDelete(target .. OUTPUT_DIR .. "/" .. file)
	end

	print("* Removed previous output")
	]]

	-- Show message if there's previous output
	for file in lfs.dir(target .. OUTPUT_DIR) do
		print("There's previous output in " .. target .. OUTPUT_DIR .. "."
			.. "It is recommended that you remove previous output before generating your site.")
		break
	end

	-- Load configuration file
	local result, configFunc = pcall(loadfile, target .. CONFIG_FILE)

	if not result or not configFunc then
		print("Error: cannot open the site config file (" .. target .. CONFIG_FILE .. ")")
		os.exit(1)
	end

	local configEnv = {}
	setfenv(configFunc, configEnv)

	local result = pcall(configFunc)

	if not result or not configEnv["config"] then
		print("Error: something went wrong while loading the site config file")
		os.exit(1)
	end

	local config = configEnv["config"]

	print("* Loaded site config")

	-- Load Markdown renderer
	local markdown = require("markdown")

	if not markdown then
		print("Error: something went wrong while loading the Markdown renderer")
		os.exit(1)
	end

	print("* Loaded Markdown renderer")

	print("* Converting posts")

	-- Handle posts
	local postFileContent = readFile(target .. POST_FILE)

	local posts = {}

	for file in lfs.dir(target .. POSTS_DIR) do
		local filePath = target .. POSTS_DIR .. "/" .. file

		if checkExtension(filePath, "md") or checkExtension(filePath, "markdown") then
			local fileContent = readFile(filePath)

			local postInfo = {}

			fileContent = string.gsub(fileContent, "%<%%(.-)%%%>", function(code)
				local output = ""

				local env = {
					["echo"] = function(...)
						local out = table.concat({...}, "\n")
						if type(out) == "string" then
							output = output .. out
						end
					end,
					["include"] = function(file)
						local content = readFile(target .. INCLUDES_DIR .. "/" .. file)
						if content then
							output = output .. content
						end
					end,
					["config"] = config,
				}
				setmetatable(env, {__index = _G})

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

					if env["post"] then
						postInfo = env["post"]
					end
				end

				return output
			end)

			if validatePost(postInfo) then
				postInfo["date"] = os.date("%t", postInfo["timestamp"])

				postInfo["linkTitle"] = linkTitle(postInfo["title"])

				fileContent = markdown(fileContent)
				postInfo["content"] = fileContent

				local postFileOutput = string.gsub(postFileContent, "%<%%(.-)%%%>", function(code)
					local output = ""

					local env = {
						["echo"] = function(...)
							local out = table.concat({...}, "\n")
							if type(out) == "string" then
								output = output .. out
							end
						end,
						["include"] = function(file)
							local content = readFile(target .. INCLUDES_DIR .. "/" .. file)
							if content then
								output = output .. content
							end
						end,
						["config"] = config,
						["post"] = postInfo,
					}
					setmetatable(env, {__index = _G})

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

						if env["post"] then
							postInfo = env["post"]
						end
					end

					return output
				end)

				local outputPath = target .. OUTPUT_DIR .. "/"

				local link = ""

				local create = {
					postInfo["date"]["year"],
					postInfo["date"]["month"],
					postInfo["date"]["day"]
				}

				for _, dir in ipairs(create) do
					link = link .. dir .. "/"
					lfs.mkdir(outputPath .. link)
				end

				if config.pagesAsDirectories then
					link = link .. postInfo["linkTitle"] .. "/"
					lfs.mkdir(outputPath .. link)
					link = link .. "index.html"
				else
					link = link .. postInfo["linkTitle"] .. ".html"
				end

				postInfo["link"] = link

				outputPath = outputPath .. link

				writeFile(outputPath, postFileOutput)

				table.insert(posts, postInfo)

				print(" * " .. filePath .. " -> " .. outputPath)
			end
		end
	end

	table.sort(posts, function(a, b)
		if a["timestamp"] and b["timestamp"] then
			return a["timestamp"] >= b["timestamp"]
		end
	end)

	print("* Converting pages")

	-- Handle pages
	for file in lfs.dir(target .. PAGES_DIR) do
		local filePath = target .. PAGES_DIR .. "/" .. file

		if checkExtension(filePath, "html") and not string.ends(filePath, POST_FILE) then
			local outputPath = target .. OUTPUT_DIR .. "/" .. file

			if config.pagesAsDirectories and not string.ends(filePath, INDEX_FILE) then
				local fileName = pathInfo(file)[3]
				outputPath = target .. OUTPUT_DIR .. "/" .. fileName
				lfs.mkdir(outputPath)
				outputPath = outputPath .. "/index.html"
			end

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
					["include"] = function(file)
						local content = readFile(target .. INCLUDES_DIR .. "/" .. file)
						if content then
							output = output .. content
						end
					end,
					["config"] = config,
					["posts"] = posts,
				}
				setmetatable(env, {__index = _G})

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

else
	print("Unknown action '" .. action .. "'")
end
