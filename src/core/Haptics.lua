-- Short haptic pulse on each on-screen button press, so the thumb feels
-- the press without looking.  options.haptics is a single 0..10 level
-- (0 = OFF, 10 = maximum) set by the HAPTIC LEVEL menu row.  The level
-- scales the vibration duration -- the only lever love.system.vibrate
-- exposes (inert on iOS, whose system buzz ignores it).  No-op on desktop.

local Haptics = {}

-- level 0..10 -> vibration seconds.  Monotone: the low end is a barely-there
-- tick, the top a clearly felt buzz.  Level 0 is OFF (pulse returns before
-- looking this table up).
local PULSE = {
  [1] = 0.015, [2] = 0.025, [3] = 0.040, [4] = 0.060, [5] = 0.085,
  [6] = 0.120, [7] = 0.170, [8] = 0.240, [9] = 0.320, [10] = 0.400,
}
local LEVEL_MIN, LEVEL_MAX = 0, 10
local DEFAULT_LEVEL = 0

local state = { level = DEFAULT_LEVEL }

local function clampLevel(v)
  if type(v) ~= "number" or v ~= v then return DEFAULT_LEVEL end
  return math.max(LEVEL_MIN, math.min(LEVEL_MAX, math.floor(v)))
end

-- Normalize a persisted haptics value: a 0..10 level, clamped.  Nil /
-- garbage falls back to the default (OFF).
function Haptics.normalize(v)
  return clampLevel(v)
end

function Haptics.applyOptions(opts)
  state.level = Haptics.normalize(opts and opts.haptics)
end

function Haptics.level()
  return state.level
end

function Haptics.pulse()
  if state.level <= 0 then return end
  local vibrate = love and love.system and love.system.vibrate
  if type(vibrate) ~= "function" then return end
  pcall(vibrate, PULSE[state.level] or PULSE[5])
end

Haptics.LEVEL_MIN, Haptics.LEVEL_MAX = LEVEL_MIN, LEVEL_MAX

return Haptics
