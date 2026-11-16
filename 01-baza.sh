#!/bin/sh
# =====================================================================
# 01-baza.sh – ETAP 1: system bazowy i minimalne środowisko graficzne
# Projekt: Przenośny system FreeBSD na USB (wygląd Windows 98)
# System:  FreeBSD 14.5-RELEASE, amd64
#
# Użycie (jako root):
#     sh 01-baza.sh <nazwa_uzytkownika>
#
# Użytkownik musi już istnieć (tworzony w instalatorze lub poleceniem adduser).
#
# Realizowane wymagania (checklista v2):
#   ZP03  Openbox, LXPanel, PCManFM, jgmenu
#   WF02  graficzne logowanie (LightDM)
#   WF11  uprawnienia administratora przez sudo z hasłem
#   WF25  synchronizacja czasu (ntpd)
#   WF27  automatyczny start interfejsu graficznego
#   WF28  polski układ klawiatury dla każdej podłączonej klawiatury
#   WNF07 konto użytkownika, brak logowania roota przez sieć
#   WNF09 polska lokalizacja
#   WNF15 zapora pf, wyłączony sshd
#
# Skrypt można uruchamiać wielokrotnie – ponowne uruchomienie nie psuje
# wcześniejszej konfiguracji.
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
    echo "Błąd: użytkownik '$USER_NAME' nie istnieje (utwórz go poleceniem adduser)." >&2
    exit 1
fi
USER_HOME=$(pw usershow "$USER_NAME" | cut -d: -f9)
USER_GROUP=$(id -gn "$USER_NAME")

log() { printf '\n==> %s\n' "$*"; }

# Kopia zapasowa pliku przed nadpisaniem (tylko za pierwszym razem)
backup() {
    if [ -f "$1" ] && [ ! -f "$1.orig" ]; then
        cp -p "$1" "$1.orig"
    fi
}

log "System: $(freebsd-version), użytkownik: $USER_NAME ($USER_HOME)"

# ---------------------------------------------------------------------
# 1. Menedżer pakietów
# ---------------------------------------------------------------------
log "Przygotowanie menedżera pakietów pkg"
if ! pkg -N >/dev/null 2>&1; then
    env ASSUME_ALWAYS_YES=yes pkg bootstrap
fi
pkg update -f

# Instalacja pakietów pojedynczo: brak jednego pakietu nie przerywa
# całego skryptu, a nazwy brakujących są wypisywane na końcu.
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
# 2. Pakiety bazowego środowiska graficznego
# ---------------------------------------------------------------------
log "Instalacja środowiska graficznego (może potrwać kilkanaście minut)"
install_pkgs \
    xorg \
    dbus \
    lightdm \
    lightdm-gtk-greeter \
    openbox \
    obconf \
    lxpanel \
    pcmanfm \
    jgmenu \
    lxterminal \
    sudo \
    dejavu \
    xdg-user-dirs

# ---------------------------------------------------------------------
# 3. Dodatki dla maszyny wirtualnej (tylko w VirtualBox)
#    Na prawdziwym sprzęcie sterowniki grafiki dobiera etap 04.
# ---------------------------------------------------------------------
VM_GUEST=$(sysctl -n kern.vm_guest)
log "Typ maszyny: $VM_GUEST"
if [ "$VM_GUEST" = "vbox" ]; then
    install_pkgs virtualbox-ose-additions xf86-video-vmware
    sysrc vboxguest_enable=YES
    sysrc vboxservice_enable=YES
fi

# ---------------------------------------------------------------------
# 4. Usługi systemowe (rc.conf)
# ---------------------------------------------------------------------
log "Konfiguracja usług w /etc/rc.conf"
sysrc dbus_enable=YES            # wymagane przez LightDM i aplikacje GTK
sysrc lightdm_enable=YES         # WF27: graficzne logowanie przy starcie
sysrc ntpd_enable=YES            # WF25: synchronizacja czasu
sysrc ntpd_sync_on_start=YES     #       nawet przy dużej odchyłce zegara
sysrc keymap=pl.kbd              # WNF09: polska klawiatura w konsoli
sysrc sshd_enable=NO             # WNF15: brak zbędnych usług sieciowych
sysrc clear_tmp_enable=YES       # czyszczenie /tmp przy starcie
sysrc dumpdev=NO                 # WNF13: brak zrzutów pamięci na nośnik

# ---------------------------------------------------------------------
# 5. Strefa czasowa i lokalizacja
# ---------------------------------------------------------------------
log "Strefa czasowa Europe/Warsaw"
tzsetup Europe/Warsaw

log "Klasa logowania 'polish' (język pl_PL.UTF-8)"
if ! grep -q '^polish|' /etc/login.conf; then
    backup /etc/login.conf
    cat >> /etc/login.conf <<'EOF'

polish|Polish Users Accounts:\
	:charset=UTF-8:\
	:lang=pl_PL.UTF-8:\
	:tc=default:
EOF
    cap_mkdb /etc/login.conf
fi
pw usermod "$USER_NAME" -L polish

# ---------------------------------------------------------------------
# 6. Polski układ klawiatury w Xorg – globalnie (WF28)
#    Dzięki temu każda nowo podłączona klawiatura od razu ma układ PL.
# ---------------------------------------------------------------------
log "Polski układ klawiatury w Xorg"
mkdir -p /usr/local/etc/X11/xorg.conf.d
cat > /usr/local/etc/X11/xorg.conf.d/20-keyboard.conf <<'EOF'
Section "InputClass"
    Identifier  "Klawiatura - uklad polski"
    MatchIsKeyboard "on"
    Option      "XkbLayout" "pl"
EndSection
EOF

# ---------------------------------------------------------------------
# 7. Grupy i uprawnienia użytkownika
# ---------------------------------------------------------------------
log "Dodawanie użytkownika do grup"
#   wheel    – sudo; wymagana też przez NetworkMgr (etap 03)
#   video    – dostęp do akceleracji grafiki
#   operator – montowanie nośników (etap 04)
for g in wheel video operator; do
    pw groupmod "$g" -m "$USER_NAME"
done

log "sudo dla grupy wheel – z hasłem (WF11, WNF07)"
mkdir -p /usr/local/etc/sudoers.d
cat > /usr/local/etc/sudoers.d/wheel <<'EOF'
%wheel ALL=(ALL:ALL) ALL
EOF
chmod 440 /usr/local/etc/sudoers.d/wheel

# ---------------------------------------------------------------------
# 8. Zapora sieciowa pf (WNF15)
#    Blokuje połączenia przychodzące, przepuszcza wychodzące.
# ---------------------------------------------------------------------
log "Zapora pf"
backup /etc/pf.conf
cat > /etc/pf.conf <<'EOF'
# Zapora – projekt FreeBSD USB
set skip on lo0
block in all
pass out all keep state
# IPv6 wymaga ICMPv6 (wykrywanie sąsiadów)
pass in inet6 proto icmp6 all
EOF
sysrc pf_enable=YES

# ---------------------------------------------------------------------
# 9. Konfiguracja sesji Openbox dla użytkownika
# ---------------------------------------------------------------------
log "Sesja Openbox użytkownika $USER_NAME"
OB_DIR="$USER_HOME/.config/openbox"
mkdir -p "$OB_DIR"

# Zmienne środowiskowe sesji (wczytywane przez openbox-session)
cat > "$OB_DIR/environment" <<'EOF'
export LANG=pl_PL.UTF-8
export LC_ALL=pl_PL.UTF-8
EOF

# Programy uruchamiane po zalogowaniu
cat > "$OB_DIR/autostart" <<'EOF'
# Pulpit z ikonami i tapetą
pcmanfm --desktop &
# Pasek zadań
lxpanel &
EOF

# Polskie nazwy katalogów domowych (Pulpit, Dokumenty, Pobrane...)
su -l "$USER_NAME" -c 'env LANG=pl_PL.UTF-8 xdg-user-dirs-update' || true

chown -R "$USER_NAME:$USER_GROUP" "$USER_HOME/.config"

# ---------------------------------------------------------------------
# 10. Podsumowanie
# ---------------------------------------------------------------------
log "Etap 1 zakończony."
if [ -n "$MISSING" ]; then
    echo "UWAGA – nie udało się zainstalować pakietów:$MISSING"
    echo "Sprawdź nazwy poleceniem: pkg search <nazwa>"
fi
echo "Uruchom ponownie komputer poleceniem: shutdown -r now"
