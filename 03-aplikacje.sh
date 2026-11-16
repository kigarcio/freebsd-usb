#!/bin/sh
# =====================================================================
# 03-aplikacje.sh – ETAP 3: aplikacje użytkowe i ustawienia w GUI
# Projekt: Przenośny system FreeBSD na USB
# System:  FreeBSD 14.5-RELEASE, amd64
#
# Użycie (jako root, po etapach 1 i 2):
#     sh 03-aplikacje.sh <nazwa_uzytkownika>
#
# Realizowane wymagania (checklista v2):
#   WF07  sieć w GUI – NetworkMgr (ikona w zasobniku)
#   WF08  dźwięk w GUI – DSBMixer (głośność, wyciszenie, wybór urządzenia)
#   WF09  rozdzielczość ekranu w GUI – LXRandR
#   WF11  instalowanie programów w GUI – OctoPkg (z hasłem, przez sudo)
#   WF12  aktualizacje – „Aktualizacje systemu” w menu Start
#   WF13  zmiana hasła z menu Start
#   WF15  przeglądarka – Firefox po polsku
#   WF16  pakiet biurowy – LibreOffice po polsku, słownik, czcionki
#         zgodne metrycznie z czcionkami dokumentów MS Office
#   WF17  PDF, WF18 multimedia (VLC), WF19 zdjęcia, WF20 archiwa,
#   WF21  edytor tekstu (terminal, Menedżer zadań, zrzuty – etap 02)
#   ZP08  domyślne programy dla typów plików – gotowe od pierwszego startu
#
# Skrypt można uruchamiać wielokrotnie.
# UWAGA: pobiera ok. 1–1,5 GB pakietów (głównie LibreOffice i Firefox).
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
CFG="$USER_HOME/.config"
PREFIX=/usr/local

log()  { printf '\n==> %s\n' "$*"; }
WARNINGS=""
warn() { printf '    UWAGA: %s\n' "$*"; WARNINGS="$WARNINGS\n - $*"; }

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

# install_first <zmienna> <pakiet1> <pakiet2> ...
# Instaluje pierwszy dostępny pakiet z listy i zapisuje jego nazwę
# w zmiennej – dzięki temu skrypt działa, nawet gdy jakiś pakiet zniknie
# z repozytorium.
install_first() {
    _var=$1; shift
    for p in "$@"; do
        if pkg info -e "$p" || pkg install -y "$p" >/dev/null 2>&1; then
            echo "    [OK]    $p"
            eval "$_var=\$p"
            return 0
        fi
    done
    echo "    [BŁĄD]  żaden z: $*"
    MISSING="$MISSING ($*)"
    eval "$_var="
}

# Nazwa pliku .desktop programu (do ustawienia domyślnych aplikacji)
desktop_of() {
    [ -n "$1" ] || return 0
    f=$(grep -lE "^Exec=(.*/)?$1( |$)" "$PREFIX"/share/applications/*.desktop 2>/dev/null | head -n 1)
    [ -n "$f" ] && basename "$f"
}

# ---------------------------------------------------------------------
# 1. Pakiety aplikacji
# ---------------------------------------------------------------------
log "Aktualizacja listy pakietów"
pkg update

log "Aplikacje użytkowe (najdłuższy krok – kilkanaście do kilkudziesięciu minut)"
#   firefox                     – przeglądarka (WF15)
#   ffmpeg                      – kodeki wideo dla Firefoksa (WF15, WF18)
#   libreoffice, pl-libreoffice – pakiet biurowy i polski interfejs (WF16)
#   pl-hunspell                 – polski słownik sprawdzania pisowni
#   liberation-fonts-ttf        – zamienniki Arial, Times New Roman, Courier New
#   crosextrafonts-*            – zamienniki Calibri i Cambria (DOCX z Office)
#   vlc                         – multimedia (WF18)
#   xarchiver, 7-zip, zip, unzip, unrar – archiwa (WF20)
#   networkmgr, dsbmixer, octopkg      – sieć, dźwięk, programy w GUI
install_pkgs firefox ffmpeg \
             libreoffice pl-libreoffice pl-hunspell \
             liberation-fonts-ttf crosextrafonts-carlito-ttf crosextrafonts-caladea-ttf \
             vlc \
             xarchiver 7-zip zip unzip unrar \
             networkmgr dsbmixer octopkg

log "Programy z alternatywami (pierwszy dostępny)"
install_first PDF_PKG    atril-lite atril qpdfview      # PDF (WF17)
install_first IMG_PKG    gpicview ristretto             # zdjęcia (WF19)
install_first EDIT_PKG   mousepad l3afpad featherpad    # edytor tekstu (WF21)
install_first SCREEN_PKG lxrandr arandr                 # rozdzielczość (WF09)
install_pkgs webp-pixbuf-loader                         # zdjęcia WebP (WF19)

# Polecenia odpowiadające pakietom
PDF_CMD=$PDF_PKG;   [ "$PDF_PKG" = "atril-lite" ] && PDF_CMD=atril
IMG_CMD=$IMG_PKG
EDIT_CMD=$EDIT_PKG

# ---------------------------------------------------------------------
# 2. Dźwięk (WF08)
#    snd_driver ładuje sterowniki wszystkich obsługiwanych kart – ważne
#    w wersji przenośnej, uruchamianej na różnych komputerach.
# ---------------------------------------------------------------------
log "Sterowniki dźwięku"
sysrc -f /boot/loader.conf snd_driver_load=YES
kldload -n snd_driver 2>/dev/null || warn "nie załadowano snd_driver (zadziała po restarcie)"
if cat /dev/sndstat >/dev/null 2>&1; then
    echo "    wykryte urządzenia dźwiękowe:"
    sed 's/^/      /' /dev/sndstat
fi

# ---------------------------------------------------------------------
# 3. Firefox po polsku (WF15)
#    Pakiet językowy musi mieć tę samą wersję co Firefox, dlatego jego
#    adres jest wyliczany z wersji, a skrypt „Aktualizacje systemu”
#    uruchamia firefox-polski ponownie po każdej aktualizacji.
# ---------------------------------------------------------------------
log "Firefox – polski interfejs"
cat > "$PREFIX/sbin/firefox-polski" <<'EOF'
#!/bin/sh
# firefox-polski – ustawia polski pakiet językowy zgodny z wersją Firefoksa
set -eu
command -v firefox >/dev/null 2>&1 || exit 0
VER=$(firefox --version 2>/dev/null | awk '{print $NF}')
if [ -z "$VER" ]; then
    echo "firefox-polski: nie można ustalić wersji Firefoksa" >&2
    exit 1
fi
DIR=/usr/local/lib/firefox/distribution
mkdir -p "$DIR"
cat > "$DIR/policies.json" <<JSON
{
  "policies": {
    "RequestedLocales": ["pl"],
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "ExtensionSettings": {
      "langpack-pl@firefox.mozilla.org": {
        "installation_mode": "normal_installed",
        "install_url": "https://releases.mozilla.org/pub/firefox/releases/$VER/linux-x86_64/xpi/pl.xpi"
      }
    }
  }
}
JSON
echo "firefox-polski: Firefox $VER – ustawiono polski pakiet językowy"
EOF
chmod 755 "$PREFIX/sbin/firefox-polski"
if command -v firefox >/dev/null 2>&1; then
    "$PREFIX/sbin/firefox-polski" || warn "nie udało się ustawić polskiego Firefoksa"
fi

# ---------------------------------------------------------------------
# 4. Skrypty pomocnicze menu Start
# ---------------------------------------------------------------------
log "Skrypty pomocnicze (aktualizacje, zmiana hasła, menu Start)"

# Zmiana hasła (WF13) – okno z poleceniem passwd. Brak gotowego narzędzia
# graficznego dla tego zestawu komponentów – ograniczenie opisane w pracy.
cat > "$PREFIX/bin/zmien-haslo" <<'EOF'
#!/bin/sh
# zmien-haslo – zmiana hasła zalogowanego użytkownika
exec lxterminal --title="Zmiana hasła" -e sh -c '
echo "Zmiana hasła użytkownika $(id -un)"
echo "Najpierw podaj obecne hasło, potem dwa razy nowe."
echo "Wpisywane znaki nie są wyświetlane."
echo
passwd
echo
echo "Naciśnij Enter, aby zamknąć okno."
read x'
EOF
chmod 755 "$PREFIX/bin/zmien-haslo"

cat > "$PREFIX/bin/aktualizuj-system" <<'EOF'
#!/bin/sh
# aktualizuj-system – aktualizacja aplikacji (pkg) w oknie terminala (WF12)
exec lxterminal --title="Aktualizacje systemu" -e sh -c '
echo "Aktualizacja zainstalowanych aplikacji. Podaj swoje hasło."
echo
sudo pkg upgrade
# Po aktualizacji Firefoksa trzeba dopasować polski pakiet językowy
if command -v firefox-polski >/dev/null 2>&1; then
    sudo firefox-polski
fi
echo
echo "Gotowe. Naciśnij Enter, aby zamknąć okno."
read x'
EOF
chmod 755 "$PREFIX/bin/aktualizuj-system"

# Ten sam generator menu co w etapie 02 – pokazuje teraz także
# Ekran, Dźwięk, Dodaj lub usuń programy i Zmień hasło.
cat > "$PREFIX/bin/menu-start" <<'EOF'
#!/bin/sh
# menu-start – generator menu Start (CSV dla jgmenu)
# Projekt: przenośny system FreeBSD na USB
# Pozycje programów, które nie są zainstalowane, są pomijane.

katalog() { xdg-user-dir "$1" 2>/dev/null || echo "$HOME"; }
jest()    { command -v "$1" >/dev/null 2>&1; }

# --- Poziom główny ---
jest libreoffice && echo "Nowy dokument,libreoffice --writer,x-office-document"
echo "Otwórz dokument,pcmanfm \"$(katalog DOCUMENTS)\",document-open"
echo "^sep()"
echo "Aktualizacje systemu,aktualizuj-system,system-software-update"
echo "^sep()"
cat <<CSV
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
CSV

# --- Ustawienia sprzętu i systemu (etap 03) – tylko zainstalowane ---
DODATKI=""
dodaj() { DODATKI="$DODATKI$1
"; }
if jest lxrandr; then dodaj "Ekran (rozdzielczość),lxrandr,preferences-desktop-display"
elif jest arandr; then dodaj "Ekran (rozdzielczość),arandr,preferences-desktop-display"; fi
jest dsbmixer    && dodaj "Dźwięk,dsbmixer,audio-volume-high"
jest octopkg     && dodaj "Dodaj lub usuń programy,octopkg,system-software-install"
jest zmien-haslo && dodaj "Zmień hasło,zmien-haslo,dialog-password"
if [ -n "$DODATKI" ]; then
    echo "^sep()"
    printf '%s' "$DODATKI"
fi

cat <<CSV
^sep()
Menedżer zadań,lxtask,utilities-system-monitor

^tag(zamknij)
Wyloguj,openbox --exit,system-log-out
Uruchom ponownie,shutdown -r now,system-reboot
Wyłącz komputer,shutdown -p now,system-shutdown
CSV
EOF
chmod 755 "$PREFIX/bin/menu-start"

# ---------------------------------------------------------------------
# 5. Autostart: ikony sieci i dźwięku w zasobniku (WF07, WF08)
# ---------------------------------------------------------------------
log "Ikony sieci i dźwięku w zasobniku"
mkdir -p "$CFG/openbox"
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
# Ikony w zasobniku (etap 03): sieć i dźwięk. Opóźnienie – panel musi
# już działać; pgrep zapobiega podwójnemu uruchomieniu.
(sleep 4
 command -v networkmgr >/dev/null && ! pgrep -qf networkmgr && networkmgr &
 command -v dsbmixer   >/dev/null && ! pgrep -qf dsbmixer   && dsbmixer -i &
) &
EOF

# ---------------------------------------------------------------------
# 6. Firefox na pasku szybkiego uruchamiania
# ---------------------------------------------------------------------
PANEL="$CFG/lxpanel/default/panels/panel"
if [ -f "$PANEL" ] && ! grep -q 'id=firefox.desktop' "$PANEL"; then
    log "Firefox na pasku zadań"
    awk '
        { print }
        /id=lxterminal.desktop/ { po = 1; next }
        po == 1 && /}/ {
            print "    Button {"
            print "      id=firefox.desktop"
            print "    }"
            po = 0
        }
    ' "$PANEL" > "$PANEL.tmp" && mv "$PANEL.tmp" "$PANEL"
fi

# ---------------------------------------------------------------------
# 7. Domyślne programy dla typów plików (ZP08)
#    Podwójne kliknięcie pliku w menedżerze plików otwiera właściwy program.
# ---------------------------------------------------------------------
log "Domyślne programy dla typów plików"
D_WEB=$(desktop_of firefox)
D_PDF=$(desktop_of "$PDF_CMD")
D_IMG=$(desktop_of "$IMG_CMD")
D_TXT=$(desktop_of "$EDIT_CMD")
D_VID=$(desktop_of vlc)
D_ARC=$(desktop_of xarchiver)
echo "    WWW: ${D_WEB:-?}  PDF: ${D_PDF:-?}  zdjęcia: ${D_IMG:-?}"
echo "    tekst: ${D_TXT:-?}  multimedia: ${D_VID:-?}  archiwa: ${D_ARC:-?}"

assoc() {   # assoc <plik.desktop> <typ MIME> ...
    _d=$1; shift
    [ -n "$_d" ] || return 0
    for t in "$@"; do echo "$t=$_d"; done
}
{
    echo "[Default Applications]"
    assoc "$D_WEB" text/html x-scheme-handler/http x-scheme-handler/https
    assoc "$D_PDF" application/pdf
    assoc "$D_IMG" image/jpeg image/png image/gif image/webp image/bmp image/tiff
    assoc "$D_TXT" text/plain
    assoc "$D_VID" video/mp4 video/x-matroska video/webm video/x-msvideo \
                   video/mpeg video/quicktime \
                   audio/mpeg audio/mp4 audio/aac audio/ogg audio/x-vorbis+ogg \
                   audio/flac audio/x-wav audio/x-ms-wma
    assoc "$D_ARC" application/zip application/x-7z-compressed \
                   application/vnd.rar application/x-rar \
                   application/gzip application/x-compressed-tar \
                   application/x-tar
} > "$CFG/mimeapps.list"

# ---------------------------------------------------------------------
# 8. Uprawnienia do plików użytkownika
# ---------------------------------------------------------------------
chown -R "$USER_NAME:$USER_GROUP" "$CFG"

# ---------------------------------------------------------------------
# 9. Podsumowanie
# ---------------------------------------------------------------------
log "Etap 3 zakończony."
echo "Wybrane programy: PDF=$PDF_PKG, zdjęcia=$IMG_PKG, edytor=$EDIT_PKG, ekran=$SCREEN_PKG"
if [ -n "$MISSING" ]; then
    echo "UWAGA – nie udało się zainstalować:$MISSING"
fi
if [ -n "$WARNINGS" ]; then
    printf "Ostrzeżenia:%b\n" "$WARNINGS"
fi
echo "Uruchom ponownie komputer (shutdown -r now) – załadują się sterowniki"
echo "dźwięku i ikony w zasobniku."
