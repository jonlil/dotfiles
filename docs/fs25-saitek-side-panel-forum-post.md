Draft för https://steamcommunity.com/app/1248130/discussions/0/4360117044322888411/
och https://forum.giants-software.com/viewtopic.php?t=199809

Skriv om det som passar - Steam-tråden är kortare, GIANTS-tråden tål hela texten.
Teknisk bakgrund och mätningar: ../system/gaming.md

---

## Saitek Heavy Equipment Side Panel on Linux/Proton: only 11 of 28 buttons bindable — solved

Short version: this is not a Farming Simulator bug. Wine misclassifies the
panel as an XInput gamepad, and FS25 has no XInput device profile for it, so it
falls back to a generic Xbox layout. Mirroring the panel through a virtual
input device with one extra axis fixes it completely — all 28 buttons and both
stick modes bind normally.

Verified on Arch Linux, FS25 1.23.1.0, Proton Experimental 11.0, panel
0738:2218 + wheel 0738:2217.

### Why it happens

FS25 identifies controllers from `shared/inputDevices/*.xml` in the game
directory. The panel has its own profile:

    <deviceMapping backends="ps4;rawInput;directInput;macosXSdl">
        <productKey productId="2218" vendorId="0738" />
        <category>farmSidePanel</category>
        ... 28 buttonMappings, 6 axisMappings

Note that `xinput` is not one of the backends — and it is not listed in **any**
of the 72 device definitions that ship with the game. If a device arrives over
XInput, it matches no profile at all and the game falls back to a generic
gamepad with the Xbox button set. That is exactly the eleven buttons people
report being stuck with.

So why does it arrive over XInput? Wine's `lnxev_device_create()` in
`dlls/winebus.sys/bus_udev.c` guesses the device class from counts alone:

    if (is_xbox_gamepad(vid, pid)) is_gamepad = TRUE;
    else if (axis_count == 6 && button_count >= (hat_count ? 10 : 14))
        is_gamepad = TRUE;

The side panel has exactly 6 axes and 28 buttons, so the second branch fires.
`is_gamepad` produces the compatible id `WINEBUS\WINE_COMP_XINPUT`,
`winexinput.inf` binds to it, and the panel is exposed through XInput.

`is_xbox_gamepad()` only matches vendor `0x045e`, so Saitek is not on any
blocklist — it is purely the axis and button counts. The *wheel* escapes this
by a single button: it has 9, and the threshold is 10 because it has a hat.

### The fix

Mirror the physical panel to a virtual uinput device that Wine will not
classify as a gamepad, and hide the physical one from Wine.

The virtual device needs:

* **7 axes** — the six real ones plus one unused (`ABS_THROTTLE`). This alone
  breaks `axis_count == 6`. It does not disturb FS25's matching, because the
  game maps axes by *physical name*, not by count: the wheel's own profile has
  7 `axisMapping` entries for a 6-axis device and maps `physical="Y"` twice.
* **A hat** (`ABS_HAT0X/Y`, never driven) — makes dinput report
  `DI8DEVTYPEJOYSTICK_STANDARD` instead of `_LIMITED`. Hats count separately
  from axes in the heuristic above, so this is free.
* **Buttons 1–16 moved from `BTN_GAMEPAD` (0x130) to `BTN_JOYSTICK` (0x120).**
  Buttons 17–28 stay on `BTN_TRIGGER_HAPPY` (0x2c0).
* **The same VID, PID *and version* as the original** (0738:2218, 0x0110) and
  the name `Mad Catz Saitek Side Panel Control Deck`, so the game's
  `<productKey>` and all five `<keyword>` entries match.
* **Axis range 1..255, not 0..255.** The axes are 8-bit with an even number of
  values, so the true centre 127.5 is not a reportable value. The stick rests
  at 128 and is therefore always half a step off-centre, which with a zeroed
  deadzone becomes constant input — the camera drifts and the tractor pulls to
  one side.

Because the virtual device must share the original's VID/PID, the two collide
in Wine — it merges them into one WINEBUS entry and the physical one wins,
XInput classification included. So the physical panel has to be made
unreadable to Wine, via a udev rule setting `MODE="0600" OWNER="root"` and
`TAG-="uaccess"` on its `event*`, `js*` and `hidraw` nodes. Clearing
`ID_INPUT_JOYSTICK` is **not** enough: `lnxev_device_create()` has no tag
filter at all and creates a HID device for every node in the input subsystem,
skipping one only when `open()` fails. The mirroring service therefore runs as
root, so it can still read the original.

The rule file must sort **before** `73-seat-late.rules`, which runs the
`uaccess` builtin — name it `70-…`, not `99-…`, or `TAG-="uaccess"` arrives too
late to have any effect.

### The trap that cost me the most time

If you experiment with virtual devices, **every discarded one leaves a dead
entry in the Wine prefix registry**, and those dead entries block the live
device. Wine logs them at startup:

    warn:rawinput:add_device Failed to open device file
        L"\??\HID#VID_0738&PID_2218#0&..." status 0xc0000034

As long as such ghosts exist for a VID/PID, FS25 calls `RIDI_DEVICEINFO` for
the live device and then stops, never proceeding to `RIDI_DEVICENAME` the way
it does for a working device. I had a correct virtual device for hours while
the game silently ignored it.

I proved it by giving an otherwise identical bridge a VID/PID with no ghosts in
my prefix (a Hori panel id): it appeared immediately and button 17 bound on the
first try. After deleting the dead sections from `system.reg`, the real
0738:2218 id worked too.

Instance paths are deterministic — mine is
`HID#VID_0738&PID_2218#272&0000FFFFFFFF22180738&0&0&0`, where `272` is `0x110`,
the version number. So as long as the virtual device reports a stable VID, PID
and version, no new ghosts accumulate. Change any of the three and you get one
ghost per variant.

### Result

    Input System: Mad Catz Saitek Heavy Eqpt. Wheel & Pedal
                  (VID: 0738 PID: 2217 VER: 0110 Cat: FARMWHEEL) added
    Input System: Mad Catz Saitek Side Panel Control Deck
                  (VID: 0738 PID: 2218 VER: 0110 Cat: FARMSIDEPANEL) added

All 28 buttons bindable, including the four toggle switches and the stick
button, and both stick modes (the red/blue mode switch selects which axis set
the stick reports on — red gives RX/RY/RZ, blue gives X/Y/Z, which is why the
game profile calls them `S1-*` and `S2-*`).

### Useful diagnostics

Steam launch options:

    WINEDEBUG=+rawinput PROTON_LOG=1 %command%

In `~/steam-<appid>.log`, look for:

    add_device Adding device 0x5 / ...VID_0738&PID_2218...   reached Wine
    GetRawInputDeviceInfo handle 0x5, command 0x2000000b     game asked (DEVICEINFO)
    GetRawInputDeviceInfo handle 0x5, command 0x20000007     game accepted (DEVICENAME)

If the last line never appears for your device, it was rejected. The game's own
log at `My Games/FarmingSimulator2025/log.txt` shows the `Input System: … added`
lines.

Also worth knowing: FS25 has **three** deadzone layers and the in-game menu only
exposes one. `inputBinding.xml` has a per-axis `deadzone` attribute,
`game.xml` has a global `<joystick … deadzone="0.14"/>` that is invisible in the
UI, and the kernel's own `flat` value is ignored by the game entirely. Axis
numbers are 0-indexed in the attributes but 1-indexed in the binding names
(`AXIS_5` is `axis="4"`).

### Scripts

Happy to share the bridge script and udev rules if anyone wants them — it is
about 150 lines of Python with no dependencies beyond `/dev/uinput`.

None of this needs registry edits in the prefix. `DisableHidraw`,
`DisableInput`, `Enable SDL` and per-device `Devices\<vid>/<pid>` keys were all
tried; none are needed and several actively make things worse.

### Upstream

The real fix belongs in Wine: the gamepad heuristic should not promote a
28-button device to XInput. Worth reporting to winehq if someone wants to.
