-- Lander
-- (c) 2015 Koen Bolhuis

local action = arg[1]
local arguments = {}

for i = 2, #arg do
	table.insert(arguments, arg[i])
end

---- Constants ----
local INDEX_FILE = "_pages/index.html"
local INDEX_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title>{% config.name %}</title>
</head>
<body>
	<h1>Hello world!</h1>
</body>
</html>]]

local POST_FILE = "_pages/post.html"
local POST_DEFAULT_CONTENT = [[<!DOCTYPE html>
<html>
<head>
	<title>{% get( post.title ) %}
</head>
<body>
	<h1>{% get( post.title ) %}</h1>
	<p>Posted on {% get( post.date ) %} by {% get( post.author ) %}</p>
	<p>{% get( post.content ) %}
</body>
</html>]]

local CONFIG_FILE = "_config.lua"
local CONFIG_DEFAULT_CONTENT = [[return {
	name = "A website",
}]]

---- Required files and directories ----
local DIRECTORIES = {"_posts", "_pages", "_output"}

local FILES = {
	[INDEX_FILE] = INDEX_DEFAULT_CONTENT,
	[CONFIG_FILE] = CONFIG_DEFAULT_CONTENT,
}

---- Actions ----
if action == "setup" then

	print("Setting up site")

	for _, dir in ipairs(DIRECTORIES) do
		print("Making " .. dir)
		os.execute("mkdir " .. dir)
	end

	for file, content in pairs(FILES) do
		print("Making " .. file)

		local handle = io.open(file, "w")

		if not handle then
			print("Error: cannot create '" .. file .. "'")
			os.exit(1)
		end

		if content and content ~= "" then
			handle:write(content)
		end

		handle:close()
	end

	print("Done")

elseif action == "make" then

	print("Generating site")

	local result, siteConfigFunc = pcall(loadfile, CONFIG_FILE)

	if not result then
		print("Error: cannot open the site config file (" .. CONFIG_FILE .. ")")
		os.exit(1)
	end

	local result, siteConfig = pcall(siteConfigFunc)

	if not result then
		print("Error: something went wrong while loading the site config file")
		os.exit(1)
	end

	print("Loaded site config")

	--TODO: things

end
