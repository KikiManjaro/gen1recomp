-- Haptic feedback on the on-screen pad: every fresh virtual press fires a
-- short love.system.vibrate pulse scaled by options.haptics (a 0..10 level,
-- 0 = OFF), recorded here by swapping love.system.vibrate for a recorder.
--   luajit tests/engine/touch_haptics_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local check, eq = T.check, T.eq
love = love or require("tests.love_stub")

local SaveData = require("src.core.SaveData")
local Haptics = require("src.core.Haptics")
local Input = require("src.core.Input")
local TC = require("src.core.TouchControls")

Input:init()

local pulses = {}
local realVibrate = love.system.vibrate
love.system.vibrate = function(seconds) pulses[#pulses + 1] = seconds end

local realGetOS = love.system.getOS
love.system.getOS = function() return "Android" end
love.window = love.window or {}
local oldSafe = love.window.getSafeArea
local function setRect(w, h)
  love.window.getSafeArea = function() return 0, 0, w, h end
  love.graphics.getDimensions = function() return w, h end
  TC.layoutW, TC.layoutH, TC.layoutOx, TC.layoutOy, TC.L = nil, nil, nil, nil, nil
end
local function resetPulses() pulses = {} end

-- defaults are a 0..10 level, OFF (0), and mergeOptions preserves a value
local d = SaveData.defaultOptions()
eq(d.haptics, 0, "defaultOptions carries haptics level 0 (OFF)")
local merged = SaveData.mergeOptions({ haptics = 8 })
eq(merged.haptics, 8, "mergeOptions keeps a loaded haptics level")

TC:init()
setRect(380, 720)
TC:applyOptions(SaveData.defaultOptions())
-- the default is OFF; arm a level for the pulse tests below
Haptics.applyOptions({ haptics = 5 })

local function pressAt(id, x, y)
  TC:touchpressed(id, x, y)
  TC:touchreleased(id, x, y)
end

-- a fresh press pulses with the current level's duration
resetPulses()
pressAt(1, TC:layout().a.cx, TC:layout().a.cy)
eq(#pulses, 1, "A press fires one pulse")
eq(pulses[1], 0.085, "level 5 is an 85ms tick")

-- level scales the duration across the whole 0..10 range
Haptics.applyOptions({ haptics = 1 })
resetPulses()
pressAt(1, TC:layout().a.cx, TC:layout().a.cy)
eq(pulses[1], 0.015, "level 1 is a 15ms tick")
Haptics.applyOptions({ haptics = 10 })
resetPulses()
pressAt(1, TC:layout().a.cx, TC:layout().a.cy)
eq(pulses[1], 0.400, "level 10 is a 400ms buzz")
Haptics.applyOptions(SaveData.defaultOptions())

-- level 0 stays silent
Haptics.applyOptions({ haptics = 0 })
resetPulses()
pressAt(1, TC:layout().a.cx, TC:layout().a.cy)
eq(#pulses, 0, "level 0 stays silent")
Haptics.applyOptions({ haptics = 5 })

-- a second finger joining an existing hold must not re-pulse
local ax, ay = TC:layout().a.cx, TC:layout().a.cy
resetPulses()
TC:touchpressed(1, ax, ay)
TC:touchpressed(2, ax + 1, ay + 1)
TC:touchreleased(2, ax + 1, ay + 1)
TC:touchreleased(1, ax, ay)
eq(#pulses, 1, "joining a held button does not double-pulse")

-- the d-pad pulses on press and again when the held direction changes
local dz = TC:layout().dpad
resetPulses()
TC:touchpressed(3, dz.cx + dz.w * 0.4, dz.cy) -- right
eq(#pulses, 1, "d-pad press pulses")
TC:touchmoved(3, dz.cx - dz.w * 0.4, dz.cy)    -- slide to left
eq(#pulses, 2, "d-pad direction change re-pulses")
TC:touchreleased(3, dz.cx - dz.w * 0.4, dz.cy)
eq(#pulses, 2, "releasing adds no pulse")

-- garbage levels normalize instead of erroring
Haptics.applyOptions(nil)
eq(Haptics.level(), 0, "nil options -> default level (OFF)")
Haptics.applyOptions({ haptics = 99 })
eq(Haptics.level(), Haptics.LEVEL_MAX, "level clamps high")
Haptics.applyOptions({ haptics = -3 })
eq(Haptics.level(), 0, "level clamps low (off)")
Haptics.applyOptions({ haptics = "loud" })
eq(Haptics.level(), 0, "non-numeric level -> default (OFF)")
Haptics.applyOptions(SaveData.defaultOptions())

-- the single settings row steps the 0..10 level and clamps at the ends
local OptionsMenu = require("src.ui.OptionsMenu")
local stubGame = {
  save = { options = SaveData.defaultOptions() },
  data = nil,
  modStatus = {},
}
local menu = OptionsMenu.new(stubGame)
local levelRow
for _, row in ipairs(menu.rows) do
  if row.id == "hapticLevel" then levelRow = row end
end
check(levelRow ~= nil, "HAPTIC LEVEL row survives mobile buildRows")
eq(levelRow.value(stubGame), "OFF", "HAPTIC LEVEL defaults to OFF")
check(levelRow.step(stubGame, 1) == true, "level step applies")
eq(stubGame.save.options.haptics, 1, "step up lands on 1")
eq(levelRow.value(stubGame), "1", "value reflects the new level")
check(levelRow.step(stubGame, -1) == true, "level step applies at the floor")
eq(stubGame.save.options.haptics, 0, "step down clamps at OFF")
stubGame.save.options.haptics = 10
check(levelRow.step(stubGame, 1) == true, "level step applies at the ceiling")
eq(stubGame.save.options.haptics, 10, "step up clamps at 10")

-- the row exists in the settings menu and rides the touch-pad gate
local function read(path)
  local f = assert(io.open(path, "r"))
  local src = f:read("*a")
  f:close()
  return src
end
local optSrc = read("src/ui/OptionsMenu.lua")
check(optSrc:find('id = "hapticLevel"', 1, true) ~= nil,
      "OptionsMenu has the HAPTIC LEVEL row")
check(optSrc:find('id = "haptics"', 1, true) == nil,
      "OptionsMenu no longer has a separate HAPTICS toggle row")
check(optSrc:find('row.id ~= "hapticLevel"', 1, true) ~= nil,
      "haptic row shares the touch-pad mobile gate")
local gameSrc = read("src/core/Game.lua")
check(gameSrc:find('require("src.core.Haptics").applyOptions', 1, true) ~= nil,
      "Game:applyOptions pushes haptics state")

love.system.vibrate = realVibrate
love.system.getOS = realGetOS
if oldSafe then love.window.getSafeArea = oldSafe
else love.window.getSafeArea = nil end

T.finish("touch_haptics")
