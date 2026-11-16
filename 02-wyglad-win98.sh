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
#   WNF17 wyłącznie elementy na wolnych licencjach (Chicago95: GPL/MIT,
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
C_NAVY="#000080"     # aktywny pasek tytułu (początek gradientu)
C_BLUE="#1084d0"     # aktywny pasek tytułu (koniec gradientu)
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
#   chicago95    – motyw GTK, ikony i kursory w stylu Windows 9x
#   lxappearance – graficzna zmiana motywu, ikon, czcionek (WF10)
#   gvfs         – kosz na pulpicie, później montowanie nośników (WF22)
install_pkgs chicago95 lxappearance gvfs

# ---------------------------------------------------------------------
# 2. Wykrycie zainstalowanych motywów Chicago95
#    (nazwy katalogów mogą różnić się między wersjami pakietu)
# ---------------------------------------------------------------------
log "Wykrywanie motywów Chicago95"
GTK_THEME="Chicago95"
ICON_THEME="Chicago95"
CURSOR_THEME=""

# Pakiet chicago95 we FreeBSD zawiera tylko ikony, kursory i tapety –
# bez motywu GTK. Motyw GTK pobieramy więc z repozytorium autorów
# (GitHub, licencja GPL-3.0/MIT) i instalujemy w katalogu systemowym.
CHICAGO95_REPO="https://github.com/grassmunk/Chicago95.git"
if [ ! -d "$PREFIX/share/themes/$GTK_THEME" ]; then
    echo "    brak motywu GTK w pakiecie – pobieranie z $CHICAGO95_REPO"
    command -v git >/dev/null 2>&1 || install_pkgs git
    TMP_C95=$(mktemp -d /tmp/chicago95.XXXXXX)
    if git clone --depth 1 "$CHICAGO95_REPO" "$TMP_C95" >/dev/null 2>&1 \
       && [ -d "$TMP_C95/Theme/Chicago95" ]; then
        mkdir -p "$PREFIX/share/themes"
        cp -R "$TMP_C95/Theme/Chicago95" "$PREFIX/share/themes/"
        # Wersja (commit) – do opisu w pracy, dla odtwarzalności
        echo "    zainstalowano motyw GTK Chicago95, commit: $(git -C "$TMP_C95" rev-parse --short HEAD)"
    else
        warn "nie udało się pobrać motywu GTK Chicago95 (sprawdź połączenie z siecią)"
    fi
    rm -rf "$TMP_C95"
fi
[ -d "$PREFIX/share/icons/$ICON_THEME" ] || warn "brak ikon $PREFIX/share/icons/$ICON_THEME"

for d in "$PREFIX"/share/icons/*Chicago95*; do
    if [ -d "$d/cursors" ]; then
        CURSOR_THEME=$(basename "$d")
        case "$CURSOR_THEME" in *Black*|*Standard*) break ;; esac
    fi
done
if [ -n "$CURSOR_THEME" ]; then
    echo "    kursory: $CURSOR_THEME"
else
    warn "nie znaleziono motywu kursorów Chicago95 – zostaje domyślny"
fi
echo "    GTK: $GTK_THEME, ikony: $ICON_THEME"

# ---------------------------------------------------------------------
# 3. Własny motyw Openbox „Klasyczny-98”
#    Chicago95 nie zawiera motywu dla Openboxa, dlatego motyw ramek okien
#    opracowano samodzielnie: szare ramki 3D, granatowo-niebieski
#    gradient aktywnego paska tytułu, szary gradient nieaktywnego.
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

# --- Pasek tytułu (gradient jak w Windows 98) ---
window.active.title.bg: Flat Gradient Horizontal
window.active.title.bg.color: $C_NAVY
window.active.title.bg.colorTo: $C_BLUE
window.inactive.title.bg: Flat Gradient Horizontal
window.inactive.title.bg.color: $C_DARK
window.inactive.title.bg.colorTo: #b5b5b5

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
menu.title.bg: Flat Gradient Horizontal
menu.title.bg.color: $C_NAVY
menu.title.bg.colorTo: $C_BLUE
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
# 6. Openbox: motyw, jeden pulpit, klawisz Windows otwiera menu Start
# ---------------------------------------------------------------------
log "Konfiguracja Openbox (rc.xml)"
OB_DEFAULT="$PREFIX/etc/xdg/openbox/rc.xml"
if [ -f "$OB_DEFAULT" ]; then
    sed \
      -e "s|<name>Clearlooks</name>|<name>$THEME_NAME</name>|" \
      -e "s|<number>4</number>|<number>1</number>|" \
      -e 's|</keyboard>|<keybind key="Super_L"><action name="Execute"><command>jgmenu_run</command></action></keybind><keybind key="C-Escape"><action name="Execute"><command>jgmenu_run</command></action></keybind></keyboard>|' \
      "$OB_DEFAULT" > "$CFG/openbox/rc.xml"
    grep -q "<name>$THEME_NAME</name>" "$CFG/openbox/rc.xml" \
        || warn "nie ustawiono motywu w rc.xml – wybierz '$THEME_NAME' ręcznie w ObConf"
else
    warn "brak $OB_DEFAULT – pominięto rc.xml"
fi

# Autostart: pulpit, pasek zadań, jgmenu w tle (szybsze otwieranie menu)
cat > "$CFG/openbox/autostart" <<'EOF'
# Pulpit z ikonami i tapetą
pcmanfm --desktop &
# Pasek zadań
lxpanel &
# Menu Start uruchomione w tle – pojawia się natychmiast po kliknięciu
jgmenu --hide-on-startup &
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
# 8. Menu Start (jgmenu) – układ jak w Windows 98
# ---------------------------------------------------------------------
log "Menu Start (jgmenu)"
cat > "$CFG/jgmenu/jgmenurc" <<EOF
# Menu Start w stylu Windows 98
csv_cmd = cat $CFG/jgmenu/menu-start.csv
tint2_look = 0
position_mode = fixed
menu_halign = left
menu_valign = bottom
menu_margin_x = 0
menu_margin_y = 28
menu_width = 200
menu_radius = 0
menu_border = 1
item_radius = 0
item_height = 26
icon_size = 22
icon_theme = $ICON_THEME
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

# Struktura menu: Programy ▸, Dokumenty, Ustawienia ▸, Uruchom..., Zamknij ▸
# Podmenu „Programy” generowane automatycznie z zainstalowanych aplikacji.
cat > "$CFG/jgmenu/menu-start.csv" <<'EOF'
Programy,^checkout(programy),applications-other
Dokumenty,pcmanfm "$(xdg-user-dir DOCUMENTS)",folder-documents
Ustawienia,^checkout(ustawienia),preferences-system
^sep()
Uruchom...,lxpanelctl run,system-run
^sep()
Zamknij system,^checkout(zamknij),system-shutdown

^tag(programy)
^pipe(jgmenu_run apps)

^tag(ustawienia)
Wygląd (motyw ikony czcionka),lxappearance,preferences-desktop-theme
Okna (Openbox),obconf,preferences-system-windows
Pulpit i tapeta,pcmanfm --desktop-pref,preferences-desktop-wallpaper
Pasek zadań,lxpanelctl config,preferences-desktop

^tag(zamknij)
Wyloguj,openbox --exit,system-log-out
Uruchom ponownie,shutdown -r now,system-reboot
Wyłącz komputer,shutdown -p now,system-shutdown
EOF

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
      id=$PREFIX/share/applications/menu-start.desktop
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
