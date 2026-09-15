Utkast: buggrapport till GIANTS om enhetsmatchningen under Proton.

Den har ar svagare som arende an Nintendo-rapporten: det finns ingen sjalvklar
fix, eftersom IG_-konventionen finns av ett giltigt skal. Rakna med motfragor.
Skicka den EFTER Nintendo-rapporten, och lank till forumposten for detaljerna.

---

# Under Proton, no device definition ever matches a device Wine treats as a gamepad

**Versions:** FS25 1.23.1.0, Proton Experimental. Applies to FS22 as well.

## Summary

On Linux, Wine appends `&IG_00` to the hardware id of every device it considers
a gamepad — not only Xbox-compatible ones, as Windows does. The game then skips
those devices when matching `shared/inputDevices/*.xml`, so they all fall back
to the generic gamepad profile regardless of whether a definition exists for
them.

This affects every controller class, not one vendor.

## Detail

Wine's `winebus.sys` sets `is_gamepad` either from a vendor check or from a
heuristic on axis and button counts. `is_gamepad` — not `is_xbox_gamepad` —
produces the compatible id `WINEBUS\WINE_COMP_XINPUT`, `winexinput.sys` binds,
and the id becomes:

    HID\VID_057E&PID_2009&IG_00\512&64-B5-C6-43-7C-E5&0&0&1

The device is still enumerated over RawInput. It is renamed, not hidden.

On Windows the `IG_` marker means the device is genuinely XInput-capable, and
it is the documented signal for RawInput and DirectInput applications to skip
it so input is not delivered twice. **The game is very likely doing the right
thing by skipping it.** The divergence is on Wine's side.

The practical consequence is that on Linux, a Saitek Heavy Equipment Side
Panel, a Nintendo Switch Pro Controller and anything else Wine classifies as a
gamepad can never match its own shipped definition, however complete that
definition is.

## What is measured and what is inferred

Measured: the suffix is present on the affected device and absent on devices
Wine does not classify as gamepads; `WINE_COMP_XINPUT` appeared exactly once in
the prefix registry, on the affected device; the definition matches correctly
once the device reaches the game without the suffix.

Inferred: that it is specifically the suffix that causes the game to skip the
device. That follows from what the convention is for, but the alternative —
that the game never sees the device at all — has not been ruled out from the
outside.

## Possible directions

None of these are obviously correct, which is why this is a discussion rather
than a patch request.

* Match on the vendor and product portion of the id, ignoring an `IG_` suffix,
  when the device is not also being delivered through XInput. Keeps the Windows
  behaviour intact but is more work than it sounds.
* An opt-in setting for Proton users that disables the `IG_` skip.
* Report it upstream to WineHQ instead and treat it as not the game's problem —
  a legitimate answer, and one I would understand.

## Workaround in the meantime

Mirroring the device to a virtual one that Wine does not classify as a gamepad,
and hiding the original with a udev rule. Written up here with scripts:

    <lank till forumposten>
