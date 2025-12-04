#!/usr/bin/env bash
 
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'
 
CHECK="${GREEN}[OK]${NC}"
ERR="${RED}[ERR]${NC}"
INFO="${BLUE}[INFO]${NC}"
 
set -e
export DEBIAN_FRONTEND=noninteractive
 
if [[ $EUID -ne 0 ]]; then
  echo -e "${ERR} Rootként futtasd!"
  exit 1
fi
 
CHOICES=""
 
# Ha kaptunk argumentumokat (pl. 1 3 4), akkor azokat használjuk
if [[ $# -gt 0 ]]; then
  CHOICES="$*"
else
  # Menü csak akkor kell, ha nincs argumentum
  echo -e "${YELLOW}Mit szeretnél telepíteni?${NC}"
  echo -e "  1 - Node-RED"
  echo -e "  2 - Apache2 + MariaDB + PHP + phpMyAdmin"
  echo -e "  3 - MQTT (Mosquitto)"
  echo -e "  4 - mc (Midnight Commander)"
  echo -e "  5 - MINDENT telepít"
  echo
 
  if [ -t 0 ]; then
    # Van TTY, sima futtatás (./zoli.sh)
    read -rp "Választás (pl. 1 vagy 1 2 3): " CHOICES
  else
    # Pipe-ból fut (curl ... | bash), ilyenkor a /dev/tty-ról kell olvasni
    if [ -r /dev/tty ]; then
      exec 3</dev/tty
      read -u 3 -rp "Választás (pl. 1 vagy 1 2 3): " CHOICES
      exec 3<&-
    else
      echo -e "${ERR} Nem tudok a terminálról olvasni. Használd így: curl ... | bash -s 1 2 3"
      exit 1
    fi
  fi
fi
 
NODE_RED=0
LAMP=0
MQTT=0
MC=0
 
if echo "$CHOICES" | grep -qw "5"; then
  NODE_RED=1
  LAMP=1
  MQTT=1
  MC=1
fi
 
for c in $CHOICES; do
  case "$c" in
    1) NODE_RED=1 ;;
    2) LAMP=1 ;;
    3) MQTT=1 ;;
    4) MC=1 ;;
    5) ;; # már kezeltük
    *) echo -e "${YELLOW}[!] Ismeretlen opció: $c${NC}" ;;
  esac
done
 
if [[ $NODE_RED -eq 0 && $LAMP -eq 0 && $MQTT -eq 0 && $MC -eq 0 ]]; then
  echo -e "${ERR} Nem választottál semmit."
  exit 0
fi
 
STEP=1
 
echo -e "${INFO} (${STEP}/5) Rendszer frissítése..."
apt-get update -y && apt-get upgrade -y
apt-get install -y curl wget unzip ca-certificates gnupg lsb-release
echo -e "${CHECK} (${STEP}/5) Kész."
STEP=$((STEP+1))
 
if [[ $NODE_RED -eq 1 ]]; then
  echo -e "${INFO} (${STEP}/5) Node-RED telepítése..."
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    npm install -g --unsafe-perm node-red
    echo -e "${CHECK} (${STEP}/5) Node-RED kész."
  else
    echo -e "${ERR} Node.js vagy npm hiányzik – Node-RED kihagyva."
  fi
  STEP=$((STEP+1))
fi
 
if [[ $LAMP -eq 1 ]]; then
  echo -e "${INFO} (${STEP}/5) LAMP telepítése..."
  apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql \
    php-mbstring php-zip php-gd php-json php-curl
  systemctl enable apache2 mariadb
  systemctl start apache2 mariadb
 
  mysql -u root <<EOF
CREATE USER IF NOT EXISTS 'user'@'localhost' IDENTIFIED BY 'user123';
GRANT ALL PRIVILEGES ON *.* TO 'user'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
 
  cd /tmp
  wget -q -O phpmyadmin.zip https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
  unzip -q phpmyadmin.zip
  rm -rf /usr/share/phpmyadmin
  mv phpMyAdmin-*-all-languages /usr/share/phpmyadmin
  mkdir -p /usr/share/phpmyadmin/tmp
  chmod 777 /usr/share/phpmyadmin/tmp
 
  cat >/etc/apache2/conf-available/phpmyadmin.conf <<'APACHECONF'
Alias /phpmyadmin /usr/share/phpmyadmin
<Directory /usr/share/phpmyadmin>
    Options FollowSymLinks
    DirectoryIndex index.php
    Require all granted
</Directory>
APACHECONF
 
  a2enconf phpmyadmin
  systemctl reload apache2
  echo -e "${CHECK} (${STEP}/5) LAMP kész."
  STEP=$((STEP+1))
fi
 
if [[ $MQTT -eq 1 ]]; then
  echo -e "${INFO} (${STEP}/5) MQTT telepítése..."
  apt-get install -y mosquitto mosquitto-clients
  mkdir -p /etc/mosquitto/conf.d
  cat >/etc/mosquitto/conf.d/local.conf <<'MQTT'
listener 1883
allow_anonymous true
MQTT
  systemctl enable mosquitto
  systemctl restart mosquitto
  echo -e "${CHECK} (${STEP}/5) MQTT kész."
  STEP=$((STEP+1))
fi
 
if [[ $MC -eq 1 ]]; then
  echo -e "${INFO} (${STEP}/5) mc telepítése..."
  apt-get install -y mc
  echo -e "${CHECK} (${STEP}/5) mc kész."
fi
 
echo
echo -e "${GREEN}Telepítés befejezve.${NC}"
echo
