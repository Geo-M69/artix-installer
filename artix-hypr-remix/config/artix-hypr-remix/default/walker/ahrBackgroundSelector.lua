--
-- AHR Background Selector — Walker/Elephant plugin
--
-- Provides an image-preview background picker for the current AHR theme.
-- Activated via: ahr theme bg-switcher
-- Or by prefixing with "/" in walker and selecting "AHR Backgrounds".
--
Name = "ahrBackgroundSelector"
NamePretty = "AHR Backgrounds  🖼"
HideFromProviderlist = false
SearchName = true
SearchContent = true
SearchContentFields = {"Text"}

local function shell_escape(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Remove leading numbering/dashes, strip extension, replace dashes/underscores
-- with spaces, and capitalise each word.
local function format_name(filename)
  local name = filename:gsub("^%d%d?[-_ ]?", "")
  name = name:gsub("^%-+", "")
  name = name:gsub("%.[^%.]+$", "")
  name = name:gsub("[%-_]", " ")
  name = name:gsub("%S+", function(word)
    return word:sub(1, 1):upper() .. word:sub(2):lower()
  end)
  return name
end

function GetEntries()
  local entries = {}
  local home = os.getenv("HOME")
  local ahr_root = os.getenv("AHR_THEME_FRAMEWORK_ROOT") or (home .. "/.config/artix-hypr-remix")

  -- Read current theme name from AHR state
  local theme_name_file = io.open(ahr_root .. "/current/theme.name", "r")
  local theme_name = theme_name_file and theme_name_file:read("*l") or nil
  if theme_name_file then
    theme_name_file:close()
  end

  if not theme_name or theme_name == "" then
    table.insert(entries, {
      Text = "No theme active",
      Actions = {},
    })
    return entries
  end

  -- Read current background
  local bg_link = ahr_root .. "/current/background"
  local current_bg = nil
  local bg_handle = io.popen("readlink -f " .. shell_escape(bg_link) .. " 2>/dev/null || true")
  if bg_handle then
    current_bg = bg_handle:read("*l")
    bg_handle:close()
  end

  -- Background search directories (exact mirror of ahr_theme_collect_backgrounds)
  local dirs = {
    ahr_root .. "/backgrounds/" .. theme_name,
    ahr_root .. "/current/theme/backgrounds",
    ahr_root .. "/default/backgrounds/" .. theme_name,
    "/usr/share/backgrounds",
    "/usr/share/wallpapers",
  }

  -- Collect unique backgrounds — use raw path strings (via find -L), same as
  -- the shell library's sort -u dedupe.  Do NOT resolve symlinks here so
  -- entries match what ahr-theme bg-next cycles through.
  local seen = {}
  local bg_list = {}

  for _, bg_dir in ipairs(dirs) do
    local handle = io.popen(
      "find -L " .. shell_escape(bg_dir)
        .. " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \\) 2>/dev/null | LC_ALL=C sort"
    )
    if handle then
      for bg_path in handle:lines() do
        -- Use raw find -L path (mirrors shell library sort -u behaviour)
        if not seen[bg_path] then
          seen[bg_path] = true
          bg_list[#bg_list + 1] = bg_path
        end
      end
      handle:close()
    end
  end

  if #bg_list == 0 then
    table.insert(entries, {
      Text = "No backgrounds for " .. theme_name,
      Actions = {},
    })
    return entries
  end

  -- Build entries with previews and current-background marker
  for _, bg_path in ipairs(bg_list) do
    local filename = bg_path:match("([^/]+)$") or bg_path
    local display_name = format_name(filename)

    -- Mark current background
    if current_bg and bg_path == current_bg then
      display_name = "✓ " .. display_name
    end

    table.insert(entries, {
      Text = display_name,
      Value = bg_path,
      Actions = {
        activate = "ahr-theme bg-set " .. shell_escape(bg_path),
      },
      Preview = bg_path,
      PreviewType = "file",
    })
  end

  return entries
end
