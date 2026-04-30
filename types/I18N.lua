---@meta

---@class I18NModule
---@field translate fun(key: string, data: table?): string?
---@field load fun(data: table)
---@field set fun(key: string, value: string)
---@field setLocale fun(locale: string)
---@field getLocale fun(): string
---@field loadFile fun(path: string)
---@field unitName fun(unitDefName: string, data: table?): string
---@field setLanguage fun(language: string)
---@field languages table<string, string>
---@overload fun(key: string, data: table?): string
---@type I18NModule
I18N = {}
