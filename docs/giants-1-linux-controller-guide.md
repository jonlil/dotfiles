Utkast: forumpost till GIANTS community, riktad till Linux/Proton-spelare.
Galler bade FS22 och FS25 - enhetsmatchningen ar densamma.

---

# Why your wheel or controller falls back to the generic gamepad profile under Proton

If you play on Linux and your Saitek panel, Logitech wheel or Nintendo Pro
Controller shows up as `XINPUT_GAMEPAD` in the controls menu — with most
buttons unbindable and the wrong button labels — this is why, and what you can
do about it.

It is not a bug in the game as such. It is an interaction between how Wine
classifies input devices and how Farming Simulator matches them.

## How the game identifies a controller

Every supported device has a definition in the game directory:

    shared/inputDevices/*.xml

    <deviceMapping backends="ps4;rawInput;directInput;macosXSdl">
        <productKey productId="2218" vendorId="0738" />
        <productName vendorId="0738">
            <keyword text="saitek" /><keyword text="side" /> ...
        <category>farmSidePanel</category>

The match is made on **vendor and product id**, over RawInput. Note what is
missing from `backends`: `xinput`. It is missing from **all 72 definitions**
that ship with FS25 — the string does not appear in a single one.

That is not an oversight. XInput cannot carry device identity: the API gives
you a slot number and a fixed button set, with no vendor or product. So a
device that arrives over XInput matches no definition at all and falls back to
the generic gamepad profile.

## Why Wine sends your device down the XInput path

Wine's `winebus.sys` decides whether a device is a gamepad, and that decision
alone routes it to XInput. Two different things can trigger it.

**It guesses from the counts.** In `dlls/winebus.sys/bus_udev.c`:

    if (is_xbox_gamepad(vid, pid)) is_gamepad = TRUE;
    else if (axis_count == 6 && button_count >= (hat_count ? 10 : 14))
        is_gamepad = TRUE;

A Saitek Heavy Equipment Side Panel has exactly 6 axes and 28 buttons, so the
guess fires even though a control deck is not a gamepad. The matching wheel
escapes by a single button: it has 9, and the threshold is 10 because it has a
hat.

**Or the device says so itself.** A Nintendo Switch Pro Controller declares
Usage Page 1, Usage 0x05 (Game Pad) in its own HID report descriptor. Wine
relays that faithfully — it is correct — and the device is a gamepad.

Either way the result is the same. `is_gamepad` produces the compatible id
`WINEBUS\WINE_COMP_XINPUT`, `winexinput.sys` binds to it, and the device's
hardware id gains an `&IG_00` suffix:

    HID\VID_057E&PID_2009&IG_00\512&64-B5-C6-43-7C-E5&0&0&1

The device is **not hidden** from RawInput. It is renamed. And `IG_` is the
documented Windows convention telling RawInput and DirectInput applications to
skip the device, so that you do not get doubled input from something XInput is
already delivering. The game skipping it is very likely correct behaviour.

On Windows the suffix would only be applied to genuinely Xbox-compatible
devices, so a Pro Controller keeps a clean `VID_057E&PID_2009` and the shipped
definition matches. Under Wine it does not.

## How to check what is happening

The game's own log always records what it accepted:

    My Games/FarmingSimulator2025/log.txt

    Input System: Mad Catz Saitek Side Panel Control Deck
                  (VID: 0738 PID: 2218 VER: 0110 Cat: FARMSIDEPANEL) added

If you see only `XINPUT_GAMEPAD` there, no definition matched.

For the layer below, add this to the game's launch options in Steam:

    WINEDEBUG=+rawinput PROTON_LOG=1 %command%

and look in `~/steam-<appid>.log`:

    add_device Adding device 0x5 / ...HID#VID_057E&PID_2009&IG_00#...

The `&IG_00` is the thing to look for. If it is there, the device will not
match a definition no matter what you bind.

## The workaround

Mirror the physical device to a virtual one that Wine will not call a gamepad,
and hide the original so the two do not collide.

The virtual device must carry the **same vendor, product and version** as the
original, and a name containing the definition's keywords, or it will not match
either. What it must not carry is anything that makes Wine call it a gamepad:

* Move the buttons out of the `BTN_GAMEPAD` range (0x130-0x13f) into
  `BTN_JOYSTICK` (0x120-0x12f). This is what stops Wine deriving a Game Pad
  usage.
* Break `axis_count == 6` if the device has exactly six axes — one extra,
  never-driven axis is enough. Extra axes do not disturb the game's matching:
  it maps axes by name, and the Saitek wheel's own definition has 7
  `axisMapping` entries for a 6-axis device.

Then a udev rule makes the physical device unreadable to Wine, so the virtual
one wins. Clearing `ID_INPUT_JOYSTICK` is not enough — `lnxev_device_create()`
has no tag filter at all and creates a HID device for every node in the input
subsystem, skipping one only when `open()` fails. You have to close the
permissions.

## Five things that will waste your evening

These all cost me hours. In rough order of how much.

**Ghost entries in the prefix registry.** Every virtual device you try leaves a
dead entry behind, and while one exists for a vendor/product the live device is
never registered. Wine logs them:

    warn:rawinput:add_device Failed to open device file
        L"\??\HID#VID_0738&PID_2218#0&..." status 0xc0000034

Delete the `Enum\HID\VID_xxxx&PID_yyyy` and `Enum\WINEBUS\...` sections from
`system.reg` with the game closed. Wine rebuilds the live ones on next start.

**udev triggers are per subsystem.** `udevadm trigger --action=add -s input`
does not touch hidraw nodes, and Wine prefers hidraw when it exists. Use
`-s input -s hidraw`, or unplug and replug.

**HID usages are assigned positionally, not by evdev code.** If you declare
`ABS_X, ABS_Y, ABS_RX, ABS_RY` — skipping `ABS_Z` — you do not get usages
X, Y, Rx, Ry. You get X, Y, Z, Rx, and every axis after the gap is read as the
wrong one. Fill the gap with an unused axis. (Inferred from the symptom and
confirmed by the fix, not read out of Wine's source.)

**Axis centring.** A uinput device starts with every axis at 0. If 0 is outside
the axis range you declared, the game reads it as full deflection until you
happen to move that axis. Emit a centred value right after `UI_DEV_CREATE`.

**Deadzones.** The kernel's `flat` value is ignored by the game. The per-device
deadzone in `inputBinding.xml` is overwritten whenever the game saves. The
global one in `game.xml` applies to every device at once, so raising it for a
drifting stick ruins a wheel. Putting the deadzone in the mirroring bridge
solves all three: it is per device, it survives the game rewriting its config,
and it applies to everything reading the device.

## What we actually did

Three pieces: a mirroring service, a udev rule, and a one-off registry clean.

### 1. The udev rule

Hides the physical device from Wine so the virtual one wins, without hiding the
virtual one — which is awkward, because both must carry the same vendor and
product. The discriminator is the device path: uinput devices live under
`/devices/virtual/input/`, while Bluetooth ones are under
`/devices/virtual/misc/uhid/` and USB ones under `/devices/pci*/usb*`.

`/etc/udev/rules.d/72-fs25-controllers.rules`:

    SUBSYSTEM=="input", KERNEL=="event*|js*", DEVPATH!="*/virtual/input/*", \
      ATTRS{id/vendor}=="0738", ATTRS{id/product}=="2218", \
      TAG-="uaccess", MODE="0600", OWNER="root"

    SUBSYSTEM=="hidraw", KERNELS=="000?:0738:2218.*", \
      TAG-="uaccess", MODE="0600", OWNER="root"

Three things that matter here:

The filename must sort **before** `73-seat-late.rules`, which runs the
`uaccess` builtin. Name it `99-` and your `TAG-="uaccess"` is applied before the
tag is re-added, and does nothing.

`KERNELS=="000?:VVVV:PPPP.*"` is bus-agnostic on purpose: `0003` is USB and
`0005` is Bluetooth. The same rule covers a controller however it is connected.

The values are case-sensitive and inconsistent between attributes.
`ATTRS{id/vendor}` gives lowercase (`057e`), `KERNELS` gives uppercase (`057E`).

Verify with `getfacl /dev/input/eventN`: the user's ACL entry may remain, but
`mask::` must be `---` so it shows as `#effective:---`.

### 2. The mirroring service

Runs as root, because the original is now root-only. One process handles every
configured device and rescans every few seconds, so unplugged hardware simply
waits rather than failing.

`/etc/systemd/system/joystick-bridge.service`:

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/joystick-bridge
    User=root
    Restart=on-failure
    RestartSec=10

Adding a device is a table entry. The Pro Controller's, in full:

    "match": (0x057E, 0x2009),
    "version": 0x8001,                  # must match; the game bakes it into the id
    "name": b"Pro Controller",          # must contain the definition's keywords
    "axes": [0x00, 0x01, 0x03, 0x04],   # ABS_X, Y, RX, RY
    "extra_axes": [0x02],               # ABS_Z, fills the gap so RX/RY land right
    "hats": [0x10, 0x11],
    "deadzone": 0.12,
    "curve": 1.5,
    "buttons": [
        (0x130, BTN_JOYSTICK + 0),      # BTN_SOUTH   -> B
        (0x131, BTN_JOYSTICK + 1),      # BTN_EAST    -> A
        (0x134, BTN_JOYSTICK + 2),      # BTN_WEST    -> Y
        (0x133, BTN_JOYSTICK + 3),      # BTN_NORTH   -> X
        ...
    ]

The button order is not cosmetic. The definition expects Nintendo's own
numbering — `0=B, 1=A, 2=Y, 3=X` — which is **not** the evdev codes sorted:
`hid-nintendo` maps by physical position, so `BTN_SOUTH` is B and `BTN_WEST` is
Y, but by code X (0x133) comes before Y (0x134). Wine numbers HID buttons in
ascending target-code order, so the bridge decides the order by choosing which
`BTN_JOYSTICK` code each physical button gets.

### 3. Clearing the registry

Do this with the game closed, every time you change the virtual device's
identity:

    # in <prefix>/system.reg, delete the sections
    [System\ControlSet001\Enum\HID\VID_xxxx&PID_yyyy...]
    [System\ControlSet001\Enum\WINEBUS\VID_xxxx&PID_yyyy...]

Wine rebuilds the live entries on the next start. Skipping this is why my first
two attempts "failed" when the setup was already correct.

### 4. Fixing the bindings

Changing how the device arrives changes its device id, so the old bindings are
orphaned. The id is deterministic — `0_<vid>-<pid>-<version>-<base64 of the HID
symlink>` — and the instance path is version-based, which is what makes the
result the same on USB and Bluetooth.

We generate `inputBinding.xml` from the game's own templates rather than binding
by hand, so it is reproducible. Note that the per-device deadzone block has to
be written too: the game only creates one for devices it has already seen, and
a device with no block gets no deadzone at all.

### Scripts

    <lank till repot>

About 400 lines of Python, no dependencies beyond `/dev/uinput`, plus the udev
rule and the unit above.

Result:

    Input System: Mad Catz Saitek Side Panel Control Deck
                  (VID: 0738 PID: 2218 VER: 0110 Cat: FARMSIDEPANEL) added
    Input System: Pro Controller
                  (VID: 057E PID: 2009 VER: 8001 Cat: GAMEPAD) added

All 28 panel buttons bindable, the crane usable, and Nintendo's button labels
instead of Xbox's.

## Is it worth it

For the side panel, yes — without it only 11 of 28 buttons can be bound at all,
and the crane is unusable.

For a Pro Controller, be honest with yourself: over XInput you get a complete
236-binding profile with analog triggers and everything works. The only thing
wrong is that the game draws Xbox labels, so A and B are swapped relative to
what is printed on the controller. Getting the correct profile costs you the
bridge, a udev rule that hides the controller from **the whole system** — Steam
and other games included — and hand-fixing eleven bindings the shipped template
puts on trigger axes a Pro Controller does not have.
