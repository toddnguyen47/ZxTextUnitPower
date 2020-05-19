local ZxSimpleUI = LibStub("AceAddon-3.0"):GetAddon("ZxSimpleUI")
local CoreBarTemplate = ZxSimpleUI.CoreBarTemplate

local _MODULE_NAME = "PlayerPower"
local _DECORATIVE_NAME = "Player Power"
local PlayerPower = ZxSimpleUI:NewModule(_MODULE_NAME)
PlayerPower.MODULE_NAME = _MODULE_NAME
local media = LibStub("LibSharedMedia-3.0")

--- upvalues to prevent warnings
local LibStub = LibStub
local UIParent, CreateFrame = UIParent, CreateFrame
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitClass, UnitPowerType = UnitClass, UnitPowerType
local ToggleDropDownMenu, PlayerFrameDropDown = ToggleDropDownMenu, PlayerFrameDropDown
local RegisterUnitWatch = RegisterUnitWatch
local unpack = unpack

PlayerPower._UPDATE_INTERVAL_SECONDS = 0.15
PlayerPower.unit = "player"

local _defaults = {
  profile = {
    width = 200,
    height = 26,
    positionx = 400,
    positiony = 240,
    fontsize = 14,
    font = "Friz Quadrata TT",
    fontcolor = {1.0, 1.0, 1.0},
    texture = "Blizzard",
    color = {0.0, 0.0, 1.0, 1.0},
    border = "None"
  }
}

local _powerEventColorTable = {}
_powerEventColorTable["UNIT_MANA"] = {0.0, 0.0, 1.0, 1.0}
_powerEventColorTable["UNIT_RAGE"] = {1.0, 0.0, 0.0, 1.0}
_powerEventColorTable["UNIT_ENERGY"] = {1.0, 1.0, 0.0, 1.0}
_powerEventColorTable["UNIT_RUNIC_POWER"] = {0.0, 1.0, 1.0, 1.0}

local _unitPowerTypeTable = {}
_unitPowerTypeTable["MANA"] = 0
_unitPowerTypeTable["RAGE"] = 1
_unitPowerTypeTable["FOCUS"] = 2
_unitPowerTypeTable["ENERGY"] = 3
_unitPowerTypeTable["COMBOPOINTS"] = 4
_unitPowerTypeTable["RUNES"] = 5
_unitPowerTypeTable["RUNICPOWER"] = 6

function PlayerPower:OnInitialize()
  self.db = ZxSimpleUI.db:RegisterNamespace(_MODULE_NAME, _defaults)
  self._curDbProfile = self.db.profile
  self.bars = CoreBarTemplate:new(self._curDbProfile)
  self.bars.defaults = _defaults

  self:SetEnabledState(ZxSimpleUI:getModuleEnabledState(_MODULE_NAME))
  ZxSimpleUI:registerModuleOptions(_MODULE_NAME, self.bars:getOptionTable(_DECORATIVE_NAME),
                                   _DECORATIVE_NAME)

  self:__init__()
end

function PlayerPower:OnEnable()
  self:_setUnitPowerType()
  self:_setDefaultColor()
  self:createBar()
  self:refreshConfig()
end

function PlayerPower:__init__()
  self._mainFrame = nil
  self._timeSinceLastUpdate = 0
  self._prevPowerValue = UnitPowerMax(self.unit)
  self._playerClass = UnitClass(self.unit)
  self._playerPower = 0
  self._playerPowerString = ""
end

function PlayerPower:refreshConfig()
  if self:IsEnabled() then self.bars:refreshConfig() end
end

function PlayerPower:createBar()
  local curUnitPower = UnitPower(self.unit)
  local maxUnitPower = UnitPowerMax(self.unit)
  local percentage = ZxSimpleUI:calcPercentSafely(curUnitPower, maxUnitPower)

  self._mainFrame = self.bars:createBar(percentage)
  -- Set this so Blizzard's internal engine can find `unit`
  self._mainFrame.unit = self.unit
  self._mainFrame:SetAttribute("unit", self._mainFrame.unit)
  -- Handle right click
  self._mainFrame.menu = function()
    ToggleDropDownMenu(1, nil, PlayerFrameDropDown, "cursor")
  end

  self:_registerEvents()
  self._mainFrame:SetScript("OnUpdate", function(argsTable, elapsed)
    self:_onUpdateHandler(argsTable, elapsed)
  end)
  self._mainFrame:SetScript("OnEvent", function(argsTable, event, unit)
    self:_onEventHandler(argsTable, event, unit)
  end)

  -- Ref: https://wowwiki.fandom.com/wiki/SecureStateDriver
  -- Register left clicks and right clicks as well
  -- Do NOT use SetScript("OnClick", func) !
  RegisterUnitWatch(self._mainFrame, ZxSimpleUI:getUnitWatchState(self._mainFrame.unit))
  self._mainFrame:Show()
end

-- ####################################
-- # PRIVATE FUNCTIONS
-- ####################################

---@param argsTable table
---@param elapsed number
function PlayerPower:_onUpdateHandler(argsTable, elapsed)
  self._timeSinceLastUpdate = self._timeSinceLastUpdate + elapsed
  if (self._timeSinceLastUpdate > self._UPDATE_INTERVAL_SECONDS) then
    local curUnitPower = UnitPower(self.unit)
    if (curUnitPower ~= self._prevPowerValue) then
      self:_setPowerValue(curUnitPower)
      self._prevPowerValue = curUnitPower
      self._timeSinceLastUpdate = 0
    end
  end
end

---@param argsTable table
---@param event string
---@param unit string
function PlayerPower:_onEventHandler(argsTable, event, unit)
  local upperEvent = string.upper(event)
  local upperUnit = string.upper(unit)
  if (upperEvent == "UNIT_DISPLAYPOWER" and upperUnit == self.unit) then self:_handlePowerChanged() end
end

---@param curUnitPower number
function PlayerPower:_setPowerValue(curUnitPower)
  curUnitPower = curUnitPower or UnitPower(self.unit)
  local maxUnitPower = UnitPowerMax(self.unit)
  local powerPercent = ZxSimpleUI:calcPercentSafely(curUnitPower, maxUnitPower)
  self.bars:_setStatusBarValue(powerPercent)
end

function PlayerPower:_handlePowerChanged()
  self:_setUnitPowerType()
  self:_setDefaultColor()
  self:refreshConfig()
end

function PlayerPower:_registerEvents()
  for powerEvent, _ in pairs(_powerEventColorTable) do self._mainFrame:RegisterEvent(powerEvent) end
  -- Register Druid's shapeshift form
  self._mainFrame:RegisterEvent("UNIT_DISPLAYPOWER")
end

function PlayerPower:_setUnitPowerType()
  self._playerPower, self._playerPowerString = UnitPowerType(self.unit)
end

function PlayerPower:_setDefaultColor()
  local powerTypeUpper = string.upper(self._playerPowerString)
  local colorTable = _powerEventColorTable["UNIT_" .. powerTypeUpper]
  _defaults.profile.color = colorTable
  self._curDbProfile.color = colorTable
end
