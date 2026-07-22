---@meta

---Translate a key to a localized string. Replaced by i18n_kikito on the mig-i18n branch.
---@param key string
---@param ... any
---@return string
function I18N(key, ...) end

---The kikito i18n instance: callable for lookups, with locale-management methods.
---@class BarI18N
---@overload fun(key: string, data?: table): string
---@field setLanguage fun(lang: string)
---@field getLocale fun(): string
---@field set fun(key: string, value: any)
---@field languages string[]

---BAR module namespace (created by init.lua; detached from the Spring table by detach-bar-modules).
---@class BARNamespace
---@field I18N BarI18N
---@field Utilities Utilities
---@field Debug BARDebug
---@field Lava Lava
---@field GetModOptionsCopy fun(): table<string, string|number|boolean>
BAR = {}
