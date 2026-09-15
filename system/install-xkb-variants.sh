#!/bin/bash
# Installerar repots xkb-varianter i systemets symbols/se.
#
# Varje fil system/xkb-se-<namn> läggs till i /usr/share/X11/xkb/symbols/se som
# varianten se(<namn>). Filen ägs av xkeyboard-config och skrivs över vid
# uppgradering, därför installeras också en pacman-hook som kör det här
# skriptet igen efteråt.
#
# Varianter i repot:
#   xkb-se-swerty   US-liknande layout, sätts på Air75-borden
#
# F13-F24-omskrivningen ligger INTE här utan i xkb/symbols/dotfiles, eftersom
# den måste slås ihop i options-positionen för att överskrida symbols/inet.
#
# Körs som root:  sudo system/install-xkb-variants.sh
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SNIPPET_DIR="$(dirname "$SELF")"
TARGET=/usr/share/X11/xkb/symbols/se
HOOK=/etc/pacman.d/hooks/95-dotfiles-xkb.hook


if [ "$(id -u)" -ne 0 ]; then
    echo "Måste köras som root: sudo $0" >&2
    exit 1
fi

[ -w "$TARGET" ] || { echo "Hittar inte $TARGET" >&2; exit 1; }

for SNIPPET in "$SNIPPET_DIR"/xkb-se-*; do
    [ -r "$SNIPPET" ] || continue
    NAME="${SNIPPET##*/xkb-se-}"
    BEGIN_MARK="// >>> $NAME (dotfiles) >>>"
    END_MARK="// <<< $NAME (dotfiles) <<<"

    # Ta bort ett tidigare installerat block så skriptet kan köras om.
    tmp="$(mktemp)"
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        index($0, b) { skip = 1 }
        !skip        { print }
        index($0, e) { skip = 0 }
    ' "$TARGET" > "$tmp"

    {
        printf '\n%s\n' "$BEGIN_MARK"
        cat "$SNIPPET"
        printf '%s\n' "$END_MARK"
    } >> "$tmp"

    cat "$tmp" > "$TARGET"   # behåll ägare och rättigheter på originalfilen
    rm -f "$tmp"
    echo "OK: se($NAME) tillagd i $TARGET"
done

# Pacman-hook som återinstallerar varianten när xkeyboard-config uppgraderas.
if [ "${1:-}" != "--no-hook" ]; then
    mkdir -p "$(dirname "$HOOK")"
    cat > "$HOOK" <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = xkeyboard-config

[Action]
Description = Återinstallerar dotfiles xkb-varianter i symbols/se...
When = PostTransaction
Exec = $SELF --no-hook
EOF
    echo "OK: pacman-hook skriven till $HOOK"
fi

echo "--- verifierar ---"
xkbcli compile-keymap --layout se --variant swerty --options lv3:ralt_switch >/dev/null
echo "OK: se(swerty) kompilerar (Air75)"
xkbcli compile-keymap --layout se >/dev/null
echo "OK: se kompilerar fortfarande (laptoptangentbordet)"
