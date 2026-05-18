local mod_version = "0.0.2"

local chat_radius_whisper = tonumber(core.settings:get("trivium.chat_radius_whisper")) or 8
local chat_radius_talk = tonumber(core.settings:get("trivium.chat_radius_talk")) or 32
local chat_radius_shout = tonumber(core.settings:get("trivium.chat_radius_shout")) or 128

local function status_message()
  return string.format(
    "Trivium mod scaffold active (v%s). Proximity chat is not enabled yet. Radii configured: whisper=%d talk=%d shout=%d.",
    mod_version,
    chat_radius_whisper,
    chat_radius_talk,
    chat_radius_shout
  )
end

core.log("action", "[trivium] " .. status_message())

core.register_chatcommand("trivium_status", {
  params = "",
  description = "Show Trivium mod scaffold status.",
  func = function()
    return true, status_message()
  end,
})
