local mod_version = "0.0.3"

local chat_radius_whisper = tonumber(core.settings:get("trivium.chat_radius_whisper")) or 8
local chat_radius_talk = tonumber(core.settings:get("trivium.chat_radius_talk")) or 32
local chat_radius_shout = tonumber(core.settings:get("trivium.chat_radius_shout")) or 128

local talk_scope = {
  name = "talk",
  radius = chat_radius_talk,
  verb = "says",
}

local whisper_scope = {
  name = "whisper",
  radius = chat_radius_whisper,
  verb = "whispers",
}

local shout_scope = {
  name = "shout",
  radius = chat_radius_shout,
  verb = "shouts",
}

local function status_message()
  return string.format(
    "Trivium proximity chat active (v%s). Radii configured: whisper=%d (/w, /whisper) talk=%d (default chat) shout=%d (/s, /shout).",
    mod_version,
    chat_radius_whisper,
    chat_radius_talk,
    chat_radius_shout
  )
end

local function trim_message(message)
  return message:match("^%s*(.-)%s*$")
end

local function player_position(player)
  return player:get_pos()
end

local function in_range(origin, target, radius)
  return vector.distance(origin, target) <= radius
end

local function audience_for(sender, radius)
  local recipients = {}
  local origin = player_position(sender)
  if origin == nil then
    return recipients
  end

  for _, player in ipairs(core.get_connected_players()) do
    local target = player_position(player)
    if target ~= nil and in_range(origin, target, radius) then
      recipients[#recipients + 1] = player
    end
  end

  return recipients
end

local function format_chat_line(sender_name, scope, message)
  return string.format("[%s] %s %s: %s", scope.name, sender_name, scope.verb, message)
end

local function deliver_message(name, scope, raw_message)
  local sender = core.get_player_by_name(name)
  if sender == nil then
    return false, "Player is no longer connected."
  end

  local message = trim_message(raw_message)
  if message == "" then
    return false, "Message cannot be empty."
  end

  local recipients = audience_for(sender, scope.radius)
  local line = format_chat_line(name, scope, message)
  for _, recipient in ipairs(recipients) do
    core.chat_send_player(recipient:get_player_name(), line)
  end

  core.log("action", string.format("[trivium] %s -> %d players within %d nodes", line, #recipients, scope.radius))
  return true
end

local function register_proximity_command(command_name, scope, usage)
  core.register_chatcommand(command_name, {
    params = "<message>",
    description = string.format("Send a %s message through Trivium proximity chat.", scope.name),
    func = function(name, param)
      local ok, response = deliver_message(name, scope, param)
      if ok then
        return true
      end

      if response == "Message cannot be empty." then
        return false, usage
      end

      return false, response
    end,
  })
end

core.log("action", "[trivium] " .. status_message())

core.register_on_chat_message(function(name, raw_message)
  if raw_message:sub(1, 1) == "/" then
    return false
  end

  local ok, response = deliver_message(name, talk_scope, raw_message)
  if ok then
    return true
  end

  core.chat_send_player(name, response)
  return true
end)

register_proximity_command("w", whisper_scope, "Usage: /w <message>")
register_proximity_command("whisper", whisper_scope, "Usage: /whisper <message>")
register_proximity_command("s", shout_scope, "Usage: /s <message>")
register_proximity_command("shout", shout_scope, "Usage: /shout <message>")

core.register_chatcommand("trivium_status", {
  params = "",
  description = "Show Trivium proximity chat status.",
  func = function()
    return true, status_message()
  end,
})
