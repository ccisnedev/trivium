local storage = core.get_mod_storage()
local modpath = core.get_modpath(core.get_current_modname())
local bootstrap = dofile(modpath .. "/bootstrap.lua")

local managed_privs = {
  trivium_admin = true,
  fly = true,
  fast = true,
}

local gamemode_apply_delay = 0.25
local gamemode_apply_attempts = 8

local function normalize_gamemode(value)
  if value == "creative" then
    return "creative"
  end

  return "survival"
end

local function sanitize_user(user)
  local data = user or {}

  return {
    allowed = data.allowed ~= false,
    gamemode = normalize_gamemode(data.gamemode),
    admin = data.admin == true,
  }
end

local function user_key(name)
  return "user:" .. name
end

local function load_user(name)
  local raw = storage:get_string(user_key(name))
  if raw == "" then
    return nil
  end

  local data = core.deserialize(raw)
  if type(data) ~= "table" then
    return nil
  end

  return sanitize_user(data)
end

local function save_user(name, user)
  storage:set_string(user_key(name), core.serialize(sanitize_user(user)))
end

local function ensure_seed_data()
  if storage:get_string("initialized") == "1" then
    return
  end

  storage:set_string("whitelist_enabled", bootstrap.whitelist_enabled == false and "0" or "1")

  for name, user in pairs(bootstrap.users or {}) do
    save_user(name, user)
  end

  storage:set_string("initialized", "1")
end

local function whitelist_enabled()
  return storage:get_string("whitelist_enabled") ~= "0"
end

local function current_or_default_user(name)
  local user = load_user(name)
  if user ~= nil then
    return user
  end

  return sanitize_user()
end

local function profile_privs(user)
  local privs = {
    interact = true,
    shout = true,
  }

  if user.admin then
    privs.trivium_admin = true
  end

  if user.gamemode == "creative" then
    privs.fly = true
    privs.fast = true
  end

  return privs
end

local function apply_gamemode(name, gamemode, attempt)
  local current_attempt = attempt or 1

  core.after(gamemode_apply_delay, function()
    local player = core.get_player_by_name(name)
    if player == nil then
      return
    end

    local ok, err = pcall(mcl_gamemode.set_gamemode, player, gamemode)
    if ok or current_attempt >= gamemode_apply_attempts then
      if not ok then
        core.log("warning", "[trivium_access] failed to apply gamemode for " .. name .. ": " .. tostring(err))
      end
      return
    end

    apply_gamemode(name, gamemode, current_attempt + 1)
  end)
end

local function apply_user_profile(name, player)
  local user = load_user(name)
  if user == nil then
    return
  end

  local privs = core.get_player_privs(name)
  for priv_name in pairs(managed_privs) do
    privs[priv_name] = nil
  end

  for priv_name, enabled in pairs(profile_privs(user)) do
    if enabled then
      privs[priv_name] = true
    end
  end

  core.set_player_privs(name, privs)

  if player ~= nil then
    apply_gamemode(name, user.gamemode)
  end
end

local function parse_toggle(value)
  if value == "on" or value == "true" or value == "1" then
    return true
  end

  if value == "off" or value == "false" or value == "0" then
    return false
  end

  return nil
end

local function parse_allow_args(param)
  local name, gamemode = param:match("^(%S+)%s*(%S*)$")
  if name == nil then
    return nil, nil
  end

  if gamemode == "" then
    gamemode = nil
  end

  return name, gamemode
end

local function refresh_online_player(name)
  local player = core.get_player_by_name(name)
  if player ~= nil then
    apply_user_profile(name, player)
  end
end

ensure_seed_data()

core.register_privilege("trivium_admin", {
  description = "Manage Trivium whitelist and player profiles",
  give_to_singleplayer = false,
})

core.register_on_prejoinplayer(function(name)
  if not whitelist_enabled() then
    return
  end

  local user = load_user(name)
  if user ~= nil and user.allowed then
    return
  end

  return "This office server uses a whitelist. Ask an admin to allow your player name before registering."
end)

core.register_on_joinplayer(function(player)
  local name = player:get_player_name()
  apply_user_profile(name, player)
end)

core.register_chatcommand("trivium_whitelist", {
  params = "[on|off]",
  description = "Show or change Trivium whitelist state.",
  privs = { trivium_admin = true },
  func = function(_, param)
    if param == "" then
      return true, "Whitelist is " .. (whitelist_enabled() and "on" or "off") .. "."
    end

    local enabled = parse_toggle(param)
    if enabled == nil then
      return false, "Usage: /trivium_whitelist [on|off]"
    end

    storage:set_string("whitelist_enabled", enabled and "1" or "0")
    return true, "Whitelist is now " .. (enabled and "on" or "off") .. "."
  end,
})

core.register_chatcommand("trivium_allow", {
  params = "<player> [survival|creative]",
  description = "Allow a player to join and optionally set their gamemode.",
  privs = { trivium_admin = true },
  func = function(_, param)
    local name, gamemode = parse_allow_args(param)
    if name == nil then
      return false, "Usage: /trivium_allow <player> [survival|creative]"
    end

    local user = current_or_default_user(name)
    user.allowed = true

    if gamemode ~= nil then
      if gamemode ~= "survival" and gamemode ~= "creative" then
        return false, "Gamemode must be survival or creative."
      end

      user.gamemode = normalize_gamemode(gamemode)
    end

    save_user(name, user)
    refresh_online_player(name)

    return true, name .. " is allowed with gamemode " .. user.gamemode .. "."
  end,
})

core.register_chatcommand("trivium_deny", {
  params = "<player>",
  description = "Remove a player from the whitelist and kick them if online.",
  privs = { trivium_admin = true },
  func = function(_, param)
    local name = param:match("^(%S+)$")
    if name == nil then
      return false, "Usage: /trivium_deny <player>"
    end

    local user = current_or_default_user(name)
    user.allowed = false
    user.admin = false
    user.gamemode = "survival"
    save_user(name, user)

    local player = core.get_player_by_name(name)
    if player ~= nil then
      apply_user_profile(name, player)
      core.kick_player(name, "You are no longer allowed on this server.")
    end

    return true, name .. " is no longer allowed on this server."
  end,
})

core.register_chatcommand("trivium_admin", {
  params = "<player> <on|off>",
  description = "Grant or remove Trivium admin management privileges.",
  privs = { trivium_admin = true },
  func = function(_, param)
    local name, toggle = param:match("^(%S+)%s+(%S+)$")
    if name == nil or toggle == nil then
      return false, "Usage: /trivium_admin <player> <on|off>"
    end

    local enabled = parse_toggle(toggle)
    if enabled == nil then
      return false, "Usage: /trivium_admin <player> <on|off>"
    end

    local user = current_or_default_user(name)
    user.allowed = true
    user.admin = enabled
    save_user(name, user)
    refresh_online_player(name)

    return true, name .. " admin access is now " .. (enabled and "on" or "off") .. "."
  end,
})

core.register_chatcommand("trivium_user", {
  params = "<player>",
  description = "Show the stored Trivium profile for a player.",
  privs = { trivium_admin = true },
  func = function(_, param)
    local name = param:match("^(%S+)$")
    if name == nil then
      return false, "Usage: /trivium_user <player>"
    end

    local user = load_user(name)
    if user == nil then
      return true, name .. " is not stored in the Trivium whitelist."
    end

    return true, name .. ": allowed=" .. tostring(user.allowed) .. ", gamemode=" .. user.gamemode .. ", admin=" .. tostring(user.admin)
  end,
})