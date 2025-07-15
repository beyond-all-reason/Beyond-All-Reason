# Restricted User Widgets

## User and Unit Control widgets

A **User Widget** is any widget added to a users installation inside `<datadir>/LuaUI/Widgets/`, thus not part of the base game.

There is also a subset of user widgets considered **Unit Control**, those are the ones capable of giving orders to units. 

## Disabling user widgets

*Unit control* widgets are sometimes required to be disabled, for example at some ranked or tournament games. In other cases lobbies might want to be even stricter and disallow all user widgets.

The reason to disallow either kind of widgets, is because they may give an unfair advantage, still other widgets can be desired as they favour personalizing the game without really helping player performance.

Games can restrict user widgets by using the following modoptions:

### AllowUserWidgets

This modoption allows enabling/disabling user widgets for the game.

Use `!bSet AllowUserWidgets 0/1` to enable/disable.

Disabling this will make the user widgets folder not to be parsed at game start.

### AllowUnitControlWidgets

This modoption allows disabling *unit control* user widgets for the game.

Use `!bSet AllowUnitControlWidgets 0/1` to disable.

Disabling this means the game won't load `control` user widgets, and will disable all of `Spring.GiveOrder*` methods for user widgets.

This option won't do anything if `AllowUserWidgets` is disabled.

## Notes for Widget developers

If your Widget uses any of the functions marked as *unit control*, it's going to fail when running in restricted lobbies disallowing them.

There are two ways to go about this:

### Mark as 'control' so it won't be enabled

You need to add 'control' element to the widget's GetInfo():

```lua
function widget:GetInfo()
  return {
    (...),
    control = true,
  }
```

This marks the widget so won't be run when not allowed, thus won't generate errors.

### Check widget.canControlUnits

Alternatively, you can check `widget.canControlUnits` to see whether 'unit control' is allowed for your widget.

If `false`, you should be careful not to use any of the 'unit control' methods, like any of `Spring.GiveOrder*`.

