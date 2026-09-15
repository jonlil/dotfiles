Utkast: buggrapport till GIANTS. Den starkaste av de tva - konkret, liten och
helt inom deras kontroll. Skicka den forst.

---

# No binding template matches the shipped Nintendo Switch Pro Controller definition

**Versions:** FS25 1.23.1.0. The same file pair exists in FS22.

## Summary

`shared/inputDevices/NintendoSwitchProController.xml` describes a device with
four axes and digital triggers. `profileTemplate/inputBindingDefault_Gamepad.xml`
binds eleven actions to axes 11 and 12, which that device does not have. Those
eleven actions end up silently unbound, including accelerate and brake.

## Detail

The device definition is correct. A Pro Controller's ZL and ZR are digital
buttons, not analog triggers, and the definition maps them accordingly:

    <buttonMapping physical="6" logical="6" label="LT" />
    <buttonMapping physical="7" logical="7" label="RT" />

    <axisMapping physical="X"  logical="0" scale="1.2" label="LS-X" />
    <axisMapping physical="Y"  logical="1" scale="1.2" label="LS-Y" />
    <axisMapping physical="RX" logical="2" scale="1.2" label="RS-X" />
    <axisMapping physical="RY" logical="3" scale="1.2" label="RS-Y" />

Four axes, so the usable binding names are `AXIS_1` to `AXIS_4`.

But the gamepad template binds to `AXIS_11` and `AXIS_12`:

    AXIS_11   AXIS_ACCELERATE_VEHICLE, AXIS_RUN, AXIS_MAP_ZOOM_IN,
              AXIS_CONSTRUCTION_CAMERA_ZOOM, MENU_LIST_PAGE_NEXT,
              MENU_LIST_PAGE_END_GAMEPAD
    AXIS_12   AXIS_BRAKE_VEHICLE, AXIS_MAP_ZOOM_OUT, MENU_LIST_PAGE_PREV,
              MENU_LIST_PAGE_START_GAMEPAD, AXIS_CONSTRUCTION_CAMERA_ZOOM

The result in game is that the vehicle cannot be driven at all: there is no
throttle and no brake. The controls menu shows the actions with no binding.

## Checked

All 15 shipped binding templates bind `AXIS_ACCELERATE_VEHICLE` to an axis —
`AXIS_5`, `AXIS_6` or `AXIS_11`. None binds it to a button. So there is no
template that fits a gamepad whose triggers are digital.

`BUTTON_7` and `BUTTON_8` — the binding names for logical 6 and 7, the LT and
RT entries above — are not used by the gamepad template for anything else. The
positions are free.

## Workaround

Rebinding those eleven actions to `BUTTON_7` and `BUTTON_8` makes the
controller fully usable. Verified in game:

    AXIS_ACCELERATE_VEHICLE   BUTTON_8   (ZR)
    AXIS_BRAKE_VEHICLE        BUTTON_7   (ZL)
    AXIS_RUN                  BUTTON_8
    AXIS_MAP_ZOOM_IN          BUTTON_8
    AXIS_MAP_ZOOM_OUT         BUTTON_7
    MENU_LIST_PAGE_NEXT       BUTTON_8
    MENU_LIST_PAGE_PREV       BUTTON_7

The only functional loss compared to an Xbox pad is that throttle is now on/off
rather than progressive, which is inherent to the hardware.

## Suggested fix

Either a binding template for gamepads with digital triggers, or a fallback
that binds an action to the mapped button when the axis a template names does
not exist on the matched device.

## Why this may have gone unnoticed

On Windows a Pro Controller is normally delivered through XInput, where it gets
the generic gamepad profile with analog trigger axes and works. The device
definition is then never used. It only comes into play when the controller is
matched by vendor and product over RawInput — which is what happens once the
XInput path is bypassed.
