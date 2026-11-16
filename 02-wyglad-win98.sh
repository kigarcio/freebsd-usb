#!/bin/sh
# =====================================================================
# 02-wyglad-win98.sh – ETAP 2: wygląd wzorowany na Windows 98
# Projekt: Przenośny system FreeBSD na USB
# System:  FreeBSD 14.5-RELEASE, amd64
#
# Użycie (jako root, po etapie 1):
#     sh 02-wyglad-win98.sh <nazwa_uzytkownika>
#
# Realizowane wymagania (checklista v2):
#   ZP02  wygląd Windows 98: szare okna 3D, pasek zadań, menu Start,
#         ikony na pulpicie, przyciski okien w prawym górnym rogu
#   ZP03  jgmenu jako menu Start, LXPanel jako pasek zadań
#   WF03  pulpit z menu i paskiem zadań
#   WF04  uruchamianie aplikacji z menu
#   WF10  personalizacja (LXAppearance, ObConf, ustawienia pulpitu)
#   WF24  wylogowanie, restart, wyłączenie z menu Start
#   WNF17 wyłącznie elementy na wolnych licencjach (Papirus: GPL-3.0,
#         Adwaita: LGPL/CC-BY-SA,
#         motyw Openbox i ikona Start – własne)
#
# UWAGA: skrypt nadpisuje konfigurację panelu, menu i pulpitu użytkownika
# (stan początkowy systemu). Można go uruchamiać wielokrotnie.
# =====================================================================

set -eu

# ---------------------------------------------------------------------
# 0. Sprawdzenie warunków
# ---------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Błąd: uruchom skrypt jako root." >&2
    exit 1
fi
if [ $# -ne 1 ]; then
    echo "Użycie: sh $0 <nazwa_uzytkownika>" >&2
    exit 1
fi

USER_NAME="$1"
if ! pw usershow "$USER_NAME" >/dev/null 2>&1; then
    echo "Błąd: użytkownik '$USER_NAME' nie istnieje." >&2
    exit 1
fi
USER_HOME=$(pw usershow "$USER_NAME" | cut -d: -f9)
USER_GROUP=$(id -gn "$USER_NAME")

PREFIX=/usr/local
THEME_NAME="Klasyczny-98"           # własny motyw Openbox
FONT="DejaVu Sans 9"

# Kolory Windows 98
C_FACE="#c0c0c0"     # szary 3D
C_DARK="#808080"     # cień
C_NAVY="#000080"     # aktywny pasek tytułu
C_DESK="#008080"     # morskie tło pulpitu

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '    UWAGA: %s\n' "$*"; WARNINGS="$WARNINGS\n - $*"; }
WARNINGS=""

backup() {
    if [ -f "$1" ] && [ ! -f "$1.orig" ]; then
        cp -p "$1" "$1.orig"
    fi
}

MISSING=""
install_pkgs() {
    for p in "$@"; do
        if pkg info -e "$p"; then
            echo "    [jest]  $p"
        elif pkg install -y "$p" >/dev/null 2>&1; then
            echo "    [OK]    $p"
        else
            echo "    [BŁĄD]  $p"
            MISSING="$MISSING $p"
        fi
    done
}

# ---------------------------------------------------------------------
# 1. Pakiety
# ---------------------------------------------------------------------
log "Instalacja pakietów wyglądu"
#   papirus-icon-theme – pełny, nowoczesny zestaw ikon (GPL-3.0)
#   adwaita-icon-theme – ikony i kursory domyślne dla GTK, zapasowe ikony
#   gnome-themes-extra – motyw Adwaita także dla aplikacji GTK2
#   lxappearance – graficzna zmiana motywu, ikon, czcionek (WF10)
#   gvfs         – kosz na pulpicie, później montowanie nośników (WF22)
#   xcape        – sam klawisz Windows otwiera menu Start
#   lxtask       – Menedżer zadań (Ctrl+Alt+Delete, WF21)
#   scrot        – zrzuty ekranu klawiszem Print Screen (WF21)
install_pkgs papirus-icon-theme adwaita-icon-theme gnome-themes-extra \
             lxappearance gvfs xcape lxtask scrot

# ---------------------------------------------------------------------
# 2. Motywy: GTK Adwaita, ikony Papirus, kursory Adwaita
#    Standardowe, ogólnodostępne motywy z repozytorium FreeBSD –
#    bez naśladowania wyglądu innego systemu.
# ---------------------------------------------------------------------
log "Motywy GTK, ikon i kursorów"
GTK_THEME="Adwaita"
ICON_THEME="Papirus"
CURSOR_THEME="Adwaita"

# Usunięcie motywu Chicago95 z wcześniejszej wersji skryptu (jeśli był)
if pkg info -e chicago95; then
    pkg delete -y chicago95 >/dev/null 2>&1 && echo "    usunięto pakiet chicago95"
fi
if [ -d "$PREFIX/share/themes/Chicago95" ]; then
    rm -rf "$PREFIX/share/themes/Chicago95" && echo "    usunięto motyw GTK Chicago95"
fi

[ -d "$PREFIX/share/icons/$ICON_THEME" ] \
    || warn "brak ikon $ICON_THEME w $PREFIX/share/icons"
[ -d "$PREFIX/share/icons/$CURSOR_THEME/cursors" ] \
    || warn "brak kursorów $CURSOR_THEME w $PREFIX/share/icons"
echo "    GTK: $GTK_THEME, ikony: $ICON_THEME, kursory: $CURSOR_THEME"

# ---------------------------------------------------------------------
# 3. Własny motyw Openbox „Klasyczny-98”
#    Motyw ramek okien opracowano samodzielnie: szare ramki 3D, granatowy pasek tytułu
#    okna aktywnego i szary nieaktywnego (jednolite kolory, bez gradientu).
# ---------------------------------------------------------------------
log "Motyw Openbox $THEME_NAME"
OB_THEME_DIR="$PREFIX/share/themes/$THEME_NAME/openbox-3"
mkdir -p "$OB_THEME_DIR"
cat > "$OB_THEME_DIR/themerc" <<EOF
# $THEME_NAME – motyw Openbox wzorowany na Windows 98
# Projekt: przenośny system FreeBSD na USB

border.width: 1
padding.width: 3
padding.height: 2
window.handle.width: 0
window.client.padding.width: 2
window.client.padding.height: 2
window.label.text.justify: left
menu.overlap.x: 0
menu.overlap.y: 0

# --- Ramki okien ---
window.active.border.color: $C_FACE
window.inactive.border.color: $C_FACE
window.active.client.color: $C_FACE
window.inactive.client.color: $C_FACE
window.active.title.separator.color: $C_FACE
window.inactive.title.separator.color: $C_FACE

# --- Pasek tytułu (jednolity kolor, bez gradientu) ---
window.active.title.bg: Flat Solid
window.active.title.bg.color: $C_NAVY
window.inactive.title.bg: Flat Solid
window.inactive.title.bg.color: $C_DARK

window.active.label.bg: Parentrelative
window.active.label.text.color: #ffffff
window.inactive.label.bg: Parentrelative
window.inactive.label.text.color: $C_FACE

# --- Przyciski (minimalizuj, maksymalizuj, zamknij) ---
window.active.button.unpressed.bg: Raised Solid
window.active.button.unpressed.bg.color: $C_FACE
window.active.button.unpressed.image.color: #000000
window.active.button.hover.bg: Raised Solid
window.active.button.hover.bg.color: $C_FACE
window.active.button.hover.image.color: #000000
window.active.button.pressed.bg: Sunken Solid
window.active.button.pressed.bg.color: $C_FACE
window.active.button.pressed.image.color: #000000
window.active.button.toggled.bg: Sunken Solid
window.active.button.toggled.bg.color: $C_FACE
window.active.button.toggled.image.color: #000000
window.active.button.disabled.bg: Raised Solid
window.active.button.disabled.bg.color: $C_FACE
window.active.button.disabled.image.color: $C_DARK

window.inactive.button.unpressed.bg: Raised Solid
window.inactive.button.unpressed.bg.color: $C_FACE
window.inactive.button.unpressed.image.color: #000000
window.inactive.button.hover.bg: Raised Solid
window.inactive.button.hover.bg.color: $C_FACE
window.inactive.button.hover.image.color: #000000
window.inactive.button.pressed.bg: Sunken Solid
window.inactive.button.pressed.bg.color: $C_FACE
window.inactive.button.pressed.image.color: #000000
window.inactive.button.toggled.bg: Sunken Solid
window.inactive.button.toggled.bg.color: $C_FACE
window.inactive.button.toggled.image.color: #000000
window.inactive.button.disabled.bg: Raised Solid
window.inactive.button.disabled.bg.color: $C_FACE
window.inactive.button.disabled.image.color: $C_DARK

window.active.handle.bg: Raised Solid
window.active.handle.bg.color: $C_FACE
window.inactive.handle.bg: Raised Solid
window.inactive.handle.bg.color: $C_FACE
window.active.grip.bg: Raised Solid
window.active.grip.bg.color: $C_FACE
window.inactive.grip.bg: Raised Solid
window.inactive.grip.bg.color: $C_FACE

# --- Menu Openboxa (prawy przycisk na pulpicie) ---
menu.border.width: 1
menu.border.color: #000000
menu.separator.color: $C_DARK
menu.separator.width: 1
menu.separator.padding.width: 4
menu.separator.padding.height: 3
menu.title.bg: Flat Solid
menu.title.bg.color: $C_NAVY
menu.title.text.color: #ffffff
menu.title.text.justify: left
menu.items.bg: Raised Solid
menu.items.bg.color: $C_FACE
menu.items.text.color: #000000
menu.items.disabled.text.color: $C_DARK
menu.items.active.bg: Flat Solid
menu.items.active.bg.color: $C_NAVY
menu.items.active.text.color: #ffffff
menu.items.active.disabled.text.color: $C_DARK

# --- Okno przełączania zadań (Alt+Tab) ---
osd.border.width: 1
osd.border.color: #000000
osd.bg: Raised Solid
osd.bg.color: $C_FACE
osd.label.bg: Parentrelative
osd.label.text.color: #000000
osd.hilight.bg: Flat Solid
osd.hilight.bg.color: $C_NAVY
osd.unhilight.bg: Flat Solid
osd.unhilight.bg.color: $C_DARK
EOF

# ---------------------------------------------------------------------
# 4. Ikona przycisku Start (własna – bez logo Microsoft, WNF17)
# ---------------------------------------------------------------------
log "Ikona i skrót przycisku Start"
mkdir -p "$PREFIX/share/pixmaps"
cat > "$PREFIX/share/pixmaps/start-klasyczny.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
  <rect x="1" y="1" width="46" height="46" fill="#c0c0c0"/>
  <path d="M1 47V1h46" fill="none" stroke="#ffffff" stroke-width="2"/>
  <path d="M1 47h46V1" fill="none" stroke="#404040" stroke-width="2"/>
  <circle cx="24" cy="24" r="15" fill="#c8102e" stroke="#000000" stroke-width="2"/>
  <path d="M17 17l14 7-14 7z" fill="#ffffff"/>
</svg>
EOF

# Skrót uruchamiający menu Start – ukryty w samym menu (NoDisplay)
mkdir -p "$PREFIX/share/applications"
cat > "$PREFIX/share/applications/menu-start.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Start
Comment=Menu Start
Exec=jgmenu_run
Icon=$PREFIX/share/pixmaps/start-klasyczny.svg
NoDisplay=true
EOF

# ---------------------------------------------------------------------
# 5. Ekran logowania LightDM w stylu Windows 98
# ---------------------------------------------------------------------
log "Wygląd ekranu logowania"
GREETER_CONF="$PREFIX/etc/lightdm/lightdm-gtk-greeter.conf"
backup "$GREETER_CONF"
cat > "$GREETER_CONF" <<EOF
[greeter]
background=$C_DESK
user-background=false
theme-name=$GTK_THEME
icon-theme-name=$ICON_THEME
font-name=$FONT
clock-format=%H:%M
indicators=~host;~spacer;~clock;~spacer;~session;~power
EOF
[ -n "$CURSOR_THEME" ] && echo "cursor-theme-name=$CURSOR_THEME" >> "$GREETER_CONF"

# =====================================================================
# Konfiguracja użytkownika
# =====================================================================
CFG="$USER_HOME/.config"
mkdir -p "$CFG/openbox" "$CFG/jgmenu" "$CFG/gtk-3.0" \
         "$CFG/lxpanel/default/panels" "$CFG/pcmanfm/default"

# ---------------------------------------------------------------------
# 6. Openbox: motyw, jeden pulpit, skróty klawiszowe jak w Windows
#
#    Ctrl+Esc / Windows   menu Start        Win+E      Mój komputer
#    Win+D                pokaż pulpit      Win+R      Uruchom...
#    Win+L                zablokuj ekran    Win+↑/↓    maksymalizuj/przywróć
#    Ctrl+Alt+Delete,
#    Ctrl+Shift+Esc       Menedżer zadań    Print Screen  zrzut ekranu
#    Alt+Print Screen     zrzut okna        Alt+Tab, Alt+F4 – domyślne
# ---------------------------------------------------------------------
log "Konfiguracja Openbox (rc.xml, skróty klawiszowe)"

# Pomocniczy skrypt zrzutu ekranu – zapis do katalogu Obrazy
cat > "$PREFIX/bin/zrzut-ekranu" <<'EOF'
#!/bin/sh
# zrzut-ekranu [okno] – zapisuje zrzut całego ekranu lub aktywnego okna
DIR=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME")
mkdir -p "$DIR"
if [ "${1:-}" = "okno" ]; then
    exec scrot -u "$DIR/zrzut_%Y-%m-%d_%H-%M-%S.png"
fi
exec scrot "$DIR/zrzut_%Y-%m-%d_%H-%M-%S.png"
EOF
chmod 755 "$PREFIX/bin/zrzut-ekranu"

# Skróty dodawane do rc.xml (jedna linia – wstawiana przed </keyboard>)
kb() { printf '<keybind key="%s"><action name="Execute"><command>%s</command></action></keybind>' "$1" "$2"; }
KEYBINDS="$(kb C-Escape jgmenu_run)\
$(kb W-e 'pcmanfm /')\
<keybind key=\"W-d\"><action name=\"ToggleShowDesktop\"/></keybind>\
$(kb W-r 'lxpanelctl run')\
$(kb W-l 'dm-tool lock')\
<keybind key=\"W-Up\"><action name=\"Maximize\"/></keybind>\
<keybind key=\"W-Down\"><action name=\"Unmaximize\"/></keybind>\
$(kb C-A-Delete lxtask)\
$(kb C-S-Escape lxtask)\
$(kb Print zrzut-ekranu)\
$(kb A-Print 'zrzut-ekranu okno')"
# Klawisze, których domyślne przypisania usuwamy z rc.xml (np. Win+E
# uruchamia w nim program z KDE), żeby nie dublować skrótów
OWN_KEYS=" C-Escape Super_L W-e W-d W-r W-l W-Up W-Down C-A-Delete C-S-Escape Print A-Print "
OB_DEFAULT="$PREFIX/etc/xdg/openbox/rc.xml"
OB_RC="$CFG/openbox/rc.xml"
OB_TMP="$OB_RC.tmp"
if [ -s "$OB_DEFAULT" ]; then
    # Zmiany zapisujemy najpierw do pliku tymczasowego. Gotowy plik
    # podmieniamy dopiero po sprawdzeniu, że nie jest pusty i jest
    # poprawnym XML-em – błąd nie może zostawić pustego rc.xml.
    if env LC_ALL=C awk -v keys="$OWN_KEYS" '
            # pomija bloki <keybind> dla klawiszy z listy OWN_KEYS
            skip == 0 && match($0, /<keybind key="[^"]*"/) {
                k = substr($0, RSTART + 14, RLENGTH - 15)
                if (index(keys, " " k " ")) skip = 1
            }
            skip == 0 { print }
            skip == 1 && /<\/keybind>/ { skip = 0 }
         ' "$OB_DEFAULT" \
       | env LC_ALL=C sed \
         -e "s|<name>Clearlooks</name>|<name>$THEME_NAME</name>|" \
         -e "s|<number>4</number>|<number>1</number>|" \
         -e "s|</keyboard>|$KEYBINDS</keyboard>|" \
         > "$OB_TMP" \
       && [ -s "$OB_TMP" ] \
       && { ! command -v xmllint >/dev/null 2>&1 || xmllint --noout "$OB_TMP"; }; then
        mv "$OB_TMP" "$OB_RC"
    else
        warn "modyfikacja rc.xml nie powiodła się – użyto domyślnego rc.xml; motyw wybierz ręcznie w ObConf"
        rm -f "$OB_TMP"
        cp "$OB_DEFAULT" "$OB_RC"
    fi
    grep -q "<name>$THEME_NAME</name>" "$OB_RC" \
        || warn "nie ustawiono motywu w rc.xml – wybierz '$THEME_NAME' ręcznie w ObConf"
else
    warn "brak lub pusty $OB_DEFAULT – pominięto rc.xml"
    # Pusty rc.xml blokuje Openboxa – usuwamy go, Openbox użyje domyślnego
    [ -s "$OB_RC" ] || rm -f "$OB_RC"
fi

# Autostart: pulpit, pasek zadań, jgmenu w tle (szybsze otwieranie menu)
cat > "$CFG/openbox/autostart" <<'EOF'
# Pulpit z ikonami i tapetą
pcmanfm --desktop &
# Pasek zadań
lxpanel &
# Menu Start uruchomione w tle – pojawia się natychmiast po kliknięciu
jgmenu --hide-on-startup &
# Samo naciśnięcie klawisza Windows = Ctrl+Esc (otwiera menu Start),
# a kombinacje Win+E, Win+D itd. działają normalnie
command -v xcape >/dev/null && xcape -e 'Super_L=Control_L|Escape' &
EOF

# ---------------------------------------------------------------------
# 7. Motyw GTK, ikony, kursory, czcionka (GTK2 i GTK3)
# ---------------------------------------------------------------------
log "Motyw GTK, ikony i kursory"
cat > "$USER_HOME/.gtkrc-2.0" <<EOF
gtk-theme-name="$GTK_THEME"
gtk-icon-theme-name="$ICON_THEME"
gtk-font-name="$FONT"
gtk-cursor-theme-name="$CURSOR_THEME"
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-button-images=1
gtk-menu-images=1
EOF

cat > "$CFG/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-font-name=$FONT
gtk-cursor-theme-name=$CURSOR_THEME
gtk-button-images=1
gtk-menu-images=1
EOF

# Kursor także poza aplikacjami GTK (np. nad pulpitem)
if [ -n "$CURSOR_THEME" ]; then
    mkdir -p "$USER_HOME/.icons/default"
    cat > "$USER_HOME/.icons/default/index.theme" <<EOF
[Icon Theme]
Inherits=$CURSOR_THEME
EOF
fi

# ---------------------------------------------------------------------
# 8. Menu Start (jgmenu) – klasyczny układ jednokolumnowy
#    (wzorowany na menu Start Windows 2000, bez paska bocznego)
#
#    ┌──────────────────────────┐
#    │ Nowy dokument            │
#    │ Otwórz dokument          │
#    │ ──────────────────────── │
#    │ Aktualizacje systemu     │
#    │ ──────────────────────── │
#    │ Programy               ▸ │
#    │ Dokumenty              ▸ │
#    │ Ustawienia             ▸ │
#    │ Uruchom...               │
#    │ ──────────────────────── │
#    │ Zamknij system...      ▸ │
#    └──────────────────────────┘
#
#    Menu generuje skrypt /usr/local/bin/menu-start – przy każdym starcie
#    jgmenu wstawia właściwe katalogi zalogowanego użytkownika.
# ---------------------------------------------------------------------
log "Menu Start (jgmenu, układ klasyczny)"

# Pomocniczy skrypt aktualizacji (WF12) – okno terminala z pkg upgrade.
# Na etapie 03 zostanie uzupełniony o narzędzie graficzne.
cat > "$PREFIX/bin/aktualizuj-system" <<'EOF'
#!/bin/sh
# aktualizuj-system – aktualizacja aplikacji (pkg) w oknie terminala
exec lxterminal --title="Aktualizacje systemu" -e sh -c '
echo "Aktualizacja zainstalowanych aplikacji. Podaj swoje hasło."
echo
sudo pkg upgrade
echo
echo "Gotowe. Naciśnij Enter, aby zamknąć okno."
read x'
EOF
chmod 755 "$PREFIX/bin/aktualizuj-system"

cat > "$PREFIX/bin/menu-start" <<'EOF'
#!/bin/sh
# menu-start – generator menu Start (CSV dla jgmenu)
# Projekt: przenośny system FreeBSD na USB

katalog() { xdg-user-dir "$1" 2>/dev/null || echo "$HOME"; }

cat <<CSV
Nowy dokument,libreoffice --writer,x-office-document
Otwórz dokument,pcmanfm "$(katalog DOCUMENTS)",document-open
^sep()
Aktualizacje systemu,aktualizuj-system,system-software-update
^sep()
Programy,^checkout(programy),applications-other
Dokumenty,^checkout(dokumenty),folder-documents
Ustawienia,^checkout(ustawienia),preferences-system
Uruchom...,lxpanelctl run,system-run
^sep()
Zamknij system...,^checkout(zamknij),system-shutdown

^tag(programy)
^pipe(jgmenu_run apps)

^tag(dokumenty)
Dokumenty,pcmanfm "$(katalog DOCUMENTS)",folder-documents
Obrazy,pcmanfm "$(katalog PICTURES)",folder-pictures
Muzyka,pcmanfm "$(katalog MUSIC)",folder-music
Wideo,pcmanfm "$(katalog VIDEOS)",folder-videos
Pobrane,pcmanfm "$(katalog DOWNLOAD)",folder-download
^sep()
Mój komputer,pcmanfm /,computer

^tag(ustawienia)
Wygląd (motyw ikony czcionka),lxappearance,preferences-desktop-theme
Pulpit i tapeta,pcmanfm --desktop-pref,preferences-desktop-wallpaper
Pasek zadań,lxpanelctl config,preferences-desktop
Okna,obconf,preferences-system-windows
^sep()
Menedżer zadań,lxtask,utilities-system-monitor

^tag(zamknij)
Wyloguj,openbox --exit,system-log-out
Uruchom ponownie,shutdown -r now,system-reboot
Wyłącz komputer,shutdown -p now,system-shutdown
CSV
EOF
chmod 755 "$PREFIX/bin/menu-start"

# Wygląd menu: szare tło, granatowe zaznaczenie, duże ikony – jak w Windows 2000
cat > "$CFG/jgmenu/jgmenurc" <<EOF
# Menu Start – układ klasyczny
csv_cmd = menu-start
tint2_look = 0
position_mode = fixed
menu_halign = left
menu_valign = bottom
menu_margin_x = 0
menu_margin_y = 28
menu_width = 220
menu_padding_top = 3
menu_padding_bottom = 3
menu_padding_left = 3
menu_padding_right = 3
menu_radius = 0
menu_border = 1
item_radius = 0
item_height = 32
item_padding_x = 6
icon_size = 24
icon_text_spacing = 10
sep_height = 7
icon_theme = $ICON_THEME
icon_theme_fallback = Adwaita
font = $FONT
arrow_string = ▸
sub_hover_action = 1
color_menu_bg = $C_FACE 100
color_menu_border = #000000 100
color_norm_bg = $C_FACE 0
color_norm_fg = #000000 100
color_sel_bg = $C_NAVY 100
color_sel_fg = #ffffff 100
color_sel_border = $C_NAVY 100
color_sep_fg = $C_DARK 100
EOF
rm -f "$CFG/jgmenu/menu-start.csv"

# ---------------------------------------------------------------------
# 9. Pasek zadań (LXPanel)
#    Start | Pokaż pulpit | Szybkie uruchamianie | Zadania | Zasobnik | Zegar
# ---------------------------------------------------------------------
log "Pasek zadań (LXPanel)"
cat > "$CFG/lxpanel/default/panels/panel" <<EOF
Global {
  edge=bottom
  align=left
  margin=0
  widthtype=percent
  width=100
  height=28
  transparent=0
  tintcolor=$C_FACE
  alpha=255
  autohide=0
  heightwhenhidden=2
  setdocktype=1
  setpartialstrut=1
  usefontcolor=0
  usefontsize=0
  background=0
  iconsize=22
}
Plugin {
  type=launchbar
  Config {
    Button {
      id=menu-start.desktop
    }
  }
}
Plugin {
  type=separator
  Config {
  }
}
Plugin {
  type=wincmd
  Config {
    Button1=iconify
    Button2=shade
  }
}
Plugin {
  type=launchbar
  Config {
    Button {
      id=pcmanfm.desktop
    }
    Button {
      id=lxterminal.desktop
    }
  }
}
Plugin {
  type=separator
  Config {
  }
}
Plugin {
  type=taskbar
  expand=1
  Config {
    tooltips=1
    IconsOnly=0
    AcceptSkipPager=1
    ShowIconified=1
    ShowMapped=1
    ShowAllDesks=0
    UseMouseWheel=1
    UseUrgencyHint=1
    FlatButton=0
    MaxTaskWidth=160
    spacing=2
    GroupedTasks=0
  }
}
Plugin {
  type=tray
  Config {
  }
}
Plugin {
  type=dclock
  Config {
    ClockFmt=%R
    TooltipFmt=%A, %e %B %Y
    BoldFont=0
    IconOnly=0
    CenterText=1
  }
}
EOF

# ---------------------------------------------------------------------
# 10. Pulpit (PCManFM): morskie tło, ikony Dokumenty, Kosz, Mój komputer
# ---------------------------------------------------------------------
log "Pulpit (PCManFM)"
cat > "$CFG/pcmanfm/default/desktop-items-0.conf" <<EOF
[*]
wallpaper_mode=color
wallpaper_common=1
desktop_bg=$C_DESK
desktop_fg=#ffffff
desktop_shadow=#000000
desktop_font=$FONT
show_wm_menu=0
sort=name;ascending;
show_documents=1
show_trash=1
show_mounts=1
EOF

# Ikona „Mój komputer” w katalogu pulpitu użytkownika.
# Ścieżkę odczytujemy z pliku user-dirs.dirs (a nie przez „su -l”, bo
# powłoka logowania wypisuje komunikat dnia – fortune – który psuł wynik).
DESKTOP_DIR=""
if [ -f "$CFG/user-dirs.dirs" ]; then
    DESKTOP_DIR=$(sed -n 's/^XDG_DESKTOP_DIR="\(.*\)"$/\1/p' "$CFG/user-dirs.dirs" \
                  | sed "s|\$HOME|$USER_HOME|")
fi
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$USER_HOME/Pulpit"
echo "    katalog pulpitu: $DESKTOP_DIR"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/moj-komputer.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Mój komputer
Comment=Przeglądaj dyski i foldery
Exec=pcmanfm /
Icon=computer
EOF
chmod +x "$DESKTOP_DIR/moj-komputer.desktop"

# Pozostałe skróty na pulpicie – nazwy ogólne (nie nazwy programów),
# tak jak w Windows: użytkownik szuka „przeglądarki”, a nie „Firefoksa”.
# Firefox i LibreOffice zostaną zainstalowane na etapie 03.
skrot() {   # skrot <plik> <nazwa> <polecenie> <ikona> <opis>
    cat > "$DESKTOP_DIR/$1.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$2
Comment=$5
Exec=$3
Icon=$4
EOF
    chmod +x "$DESKTOP_DIR/$1.desktop"
}
skrot przegladarka    "Przeglądarka internetowa" firefox      firefox                 "Przeglądaj Internet"
skrot pakiet-biurowy  "Pakiet biurowy"           libreoffice  libreoffice-startcenter "Dokumenty, arkusze i prezentacje"
skrot wiersz-polecen  "Wiersz poleceń"           lxterminal   utilities-terminal      "Terminal"
skrot menedzer-zadan  "Menedżer zadań"           lxtask       utilities-system-monitor "Uruchomione programy i zużycie pamięci"

# ---------------------------------------------------------------------
# 11. Uprawnienia do plików użytkownika
# ---------------------------------------------------------------------
chown -R "$USER_NAME:$USER_GROUP" "$CFG" "$USER_HOME/.gtkrc-2.0" "$DESKTOP_DIR"
[ -d "$USER_HOME/.icons" ] && chown -R "$USER_NAME:$USER_GROUP" "$USER_HOME/.icons"

# ---------------------------------------------------------------------
# 12. Podsumowanie
# ---------------------------------------------------------------------
log "Etap 2 zakończony."
if [ -n "$MISSING" ]; then
    echo "UWAGA – nie udało się zainstalować pakietów:$MISSING"
fi
if [ -n "$WARNINGS" ]; then
    printf "Ostrzeżenia:%b\n" "$WARNINGS"
fi
echo "Wyloguj się i zaloguj ponownie (albo: service lightdm restart),"
echo "aby zobaczyć nowy wygląd."
