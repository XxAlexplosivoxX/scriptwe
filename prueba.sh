#!/usr/bin/env bash
#    _____    _______    _________.___               .__
#   /  _  \   \      \  /   _____/|   |   ____  ____ |  |   ___________  ______
#  /  /_\  \  /   |   \ \_____  \ |   | _/ ___\/  _ \|  |  /  _ \_  __ \/  ___/
# /    |    \/    |    \/        \|   | \  \__(  <_> )  |_(  <_> )  | \/\___ \
# \____|__  /\____|__  /_______  /|___|  \___  >____/|____/\____/|__|  /____  >
#      \/         \/        \/            \/                             \/

negro='\e[0;30m'
rojo='\e[0;31m'
verde='\e[0;32m'
amarillo='\e[0;33m'
azul='\e[0;34m'
morado='\e[0;35m'
cyan='\e[0;36m'
blanco='\e[0;37m'
negroUnd='\e[4;30m'
rojoUnd='\e[4;31m'
verdeUnd='\e[4;32m'
amarilloUnd='\e[4;33m'
azulUnd='\e[4;34m'
moradoUnd='\e[4;35m'
cyanUnd='\e[4;36m'
blancoUnd='\e[4;37m'
negroI='\e[0;90m'
rojoI='\e[0;91m'
verdeI='\e[0;92m'
amarilloI='\e[0;93m'
azulI='\e[0;94m'
moradoI='\e[0;95m'
cyanI='\e[0;96m'
blancoI='\e[0;97m'
reset='\e[0m'

clear

detectarDistro() {
    if [[ -r /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        return 1
    fi
}

detectarNombreDistro() {
    if [[ -r /etc/os-release ]]; then
        source /etc/os-release
        echo "$NAME"
    else
        return 1
    fi
}

instalarDependencias() {
    local distro="$1"
    local arrDependencias=()
    local comandoInstalar=""

    case "$distro" in
    debian|ubuntu)
        arrDependencias=("hping3" "lolcat" "aircrack-ng" "nmap" "apache2" "php" "php-common" "php-fpm" "php-mysql" "php-gd" "php-curl" "php-xml" "php-mbstring" "libapache2-mod-php" "mysql-server" "unzip")
        echo -e "${verde}[!] - Instalando paquetes para ${distro}${reset}"
        apt update &>/dev/null
        comandoInstalar="apt install -y"
        comandoComprobar="dpkg -l"
        ;;
    arch)
        arrDependencias=("hping" "lolcat" "aircrack-ng" "nmap" "apache" "php" "php-apache" "mariadb" "unzip" "php-fpm" "php-gd")
        echo -e "${verde}[!] - Instalando paquetes para Arch linux${reset}"
        echo -e "${cyan}Actualizando repositorios${reset}"
        pacman -Sy --noconfirm
        comandoInstalar="pacman -S --noconfirm"
        comandoComprobar="pacman -Qi"
        ;;
    *)
        return 1
        ;;
    esac

    for paquete in "${arrDependencias[@]}"; do
        if ! $comandoComprobar "$paquete" &>/dev/null; then
            echo -e "${verde}[!] - Instalando paquete $paquete${reset}"
            if $comandoInstalar "$paquete" &>/dev/null; then
                echo -e "${verdeI}[✓] - $paquete instalado correctamente${reset}"
            else
                echo -e "${rojoI}[!] - Ha fallado la instalación de $paquete${reset}"
            fi
        else
            echo -e "${verde}[!] - ${verdeUnd}$paquete${verde} ya está instalado${reset}"
        fi
    done

    # iniciar, habilitar o configurar demonios instalados según la distribución
    case "$distro" in
        debian|ubuntu)
            systemctl enable apache2
            systemctl start apache2
            systemctl enable mysql
            systemctl start mysql
            ;;
        arch)
            systemctl enable httpd
            systemctl enable mariadb
            
            echo -e "${cyan}[!] - Inicializando base de datos de MariaDB${reset}"
            mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql &>/dev/null

            systemctl start mariadb

            # Habilita mod_php y prefork correctamente en Arch Linux (Apache)
            sed -i 's|^#LoadModule php_module modules/libphp.*|LoadModule php_module modules/libphp.so|' /etc/httpd/conf/httpd.conf
            sed -i 's|^#Include conf/extra/php_module.conf|Include conf/extra/php_module.conf|' /etc/httpd/conf/httpd.conf

            # Cambia de MPM event a MPM prefork
            sed -i 's|^LoadModule mpm_event_module|#LoadModule mpm_event_module|' /etc/httpd/conf/httpd.conf
            sed -i '/LoadModule mpm_prefork_module/d' /etc/httpd/conf/httpd.conf
            echo "LoadModule mpm_prefork_module modules/mod_mpm_prefork.so" >> /etc/httpd/conf/httpd.conf

            # Asegura que php_module esté presente solo una vez
            sed -i '/LoadModule php_module modules\/libphp.so/d' /etc/httpd/conf/httpd.conf
            echo "LoadModule php_module modules/libphp.so" >> /etc/httpd/conf/httpd.conf

            # Asegura que se incluya la configuración extra
            sed -i '/Include conf\/extra\/php_module.conf/d' /etc/httpd/conf/httpd.conf
            echo "Include conf/extra/php_module.conf" >> /etc/httpd/conf/httpd.conf

            # Asegura que index.php sea prioridad en DirectoryIndex
            sed -i 's|DirectoryIndex index.html|DirectoryIndex index.php index.html|' /etc/httpd/conf/httpd.conf


            # activar extenciones necesarioas para frontaccounting en php.ini 
            sed -i 's/^;extension=curl/extension=curl/' /etc/php/php.ini
            sed -i 's/^;extension=xml/extension=xml/' /etc/php/php.ini
            sed -i 's/^;extension=mbstring/extension=mbstring/' /etc/php/php.ini
            sed -i 's/^;extension=gd/extension=gd/' /etc/php/php.ini
            sed -i 's/^;extension=mysqli/extension=mysqli/' /etc/php/php.ini
            sed -i 's/^;extension=pdo_mysql/extension=pdo_mysql/' /etc/php/php.ini

            # Inicia Apache
            systemctl start httpd
            systemctl reload httpd
            ;;
        *)
            return 1
            ;;
    esac
    sleep 1
}


fix_frontaccounting_permissions() {
    local fa_path="$1"  # Ajusta si es diferente
    local web_user

    echo -e "${cyan}[!] -  Corrigiendo permisos de FrontAccounting...${reset}"

    # Detectar el usuario bajo el que corre Apache/Nginx
    if id http &>/dev/null; then
        web_user="http"
    elif id www-data &>/dev/null; then
        web_user="www-data"
    elif id apache &>/dev/null; then
        web_user="apache"
    else
        echo -e "${rojo}[!] -  No se pudo detectar el usuario web (www-data/http/apache).${reset}"
        return 1
    fi

    # 1. Permitir escritura en config.php si existe
    if [ -f "$fa_path/config.php" ]; then
        chmod 666 "$fa_path/config.php"
        echo -e "${verde}[✓] - Permisos corregidos: config.php${reset}"
    else
        echo -e "${amarillo}[!] -  Archivo config.php no encontrado en $fa_path${reset}"
    fi

    # 2. Asegurar que /tmp sea escribible
    chmod 1777 /tmp && echo -e "${verde}[✓] - Permisos corregidos: /tmp${reset}"

    # 3. Permisos para company/0/
    if [ -d "$fa_path/company/0" ]; then
        chown -R "$web_user":"$web_user" "$fa_path/company/0"
        chmod -R 755 "$fa_path/company/0"
        echo -e "${verde}[✓] - Permisos corregidos: company/0/${reset}"
    else
        echo -e "${amarillo}[!] - Directorio company/0 no encontrado en $fa_path${reset}"
    fi

    echo -e "${verde}[✓] - Permisos de FrontAccounting corregidos.${reset}"
}

instalarFrontAccounting() {
    local distro="$1"

    case "$distro" in
        debian|ubuntu)
            echo -e "${verde}[+] - Descargando FrontAccounting...${reset}"
            if [ ! -d "/var/www/html/frontaccounting" ]; then
                git clone -q https://git.code.sf.net/p/frontaccounting/git /var/www/html/frontaccounting
            else
                echo -e "${amarillo}[!] - Ya existe /var/www/html/frontaccounting, omitiendo clonación${reset}"
            fi
            echo -e "${verde}[+] - Asignando permisos...${reset}"
            chown -R www-data:www-data /var/www/html/frontaccounting
            chmod -R 777 /var/www/html/frontaccounting
            echo -e "${verde}[+] - Asegurando que Apache esté corriendo...${reset}"
            if systemctl status apache2 &>/dev/null; then
                systemctl start apache2
                systemctl reload apache2
            fi
            fix_frontaccounting_permissions "/var/www/html/frontaccounting"
            ;;
        arch)
            echo -e "${verde}[+] - Descargando FrontAccounting...${reset}"
            if [ ! -d "/srv/http/frontaccounting" ]; then
                git clone -q https://git.code.sf.net/p/frontaccounting/git /srv/http/frontaccounting
            else
                echo -e "${amarillo}[!] - Ya existe /srv/http/frontaccounting, omitiendo clonación${reset}"
            fi
            echo -e "${verde}[+] - Asignando permisos...${reset}"
            chown -R http:http /srv/http/frontaccounting
            chmod -R 777 /srv/http/frontaccounting
            echo -e "${verde}[+] - Asegurando que Apache esté corriendo...${reset}"
            if systemctl status httpd &>/dev/null; then
                systemctl start httpd
                systemctl reload httpd
            fi
            fix_frontaccounting_permissions "/srv/http/frontaccounting"
            ;;
        *)
            echo -e "${rojo}[!] - pa esa distro \"$distro\" no hay!"
            ;;
    esac
}

configurarMariaDB() {
    echo -e "${verde}[+] - Protegiendo MariaDB con mysql_secure_installation...${reset}"
    mysql_secure_installation

    echo -e "${verde}[+] - Creando base de datos y usuario para FrontAccounting...${reset}"
    mysql --protocol=socket <<EOF
CREATE DATABASE frontdb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'javi'@'localhost' IDENTIFIED BY '1751';
GRANT ALL PRIVILEGES ON frontdb.* TO 'javi'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF
}

ipADecimal() {
    local IFS=. ip=$1
    read -r o1 o2 o3 o4 <<< "$ip"
    echo $(( (o1 << 24) + (o2 << 16) + (o3 << 8) + o4 ))
}

convertirEnteroAIP() {
    local IPinteger="$1"
    # se colca un formato para colocar 4 valores en decimal CON SIGNO (el %d), "d" de decimal
    # $((  )) es para hacer una operacion aritmetica en bash, sin esto no funciona
    # ya que esto lo comparte del lenguaje C. Y como comparte esto del lenguaje C
    # no funcionaria el bitshifting (dezplazamiento de bits)
    #
    # ejemplo de codigo C:
    #
    #  int main() {
    #
    #      // a = 21 (00010101 en binario)
    #      unsigned char a = 21;
    #
    #      // si se desplaza a la izquierda 1 bit sera 00101010
    #      printf("a << 1 = %d\n", (a << 1)); // a << 1 = 42
    #
    #    	// si se desplaza a la derecha 2 bits sera 00000101
    #    	printf("a >> 2 = %d", (a >> 2)); // a >> 2 = 5
    #
    #      return 0;
    #  } (incluso los dos tienen el printf xdd)
    printf "%d.%d.%d.%d" \
        $(((IPinteger >> 24) & 255)) \
        $(((IPinteger >> 16) & 255)) \
        $(((IPinteger >> 8) & 255)) \
        $((IPinteger & 255))
    # al desplazar los bits a la derecha "24 espacios" sucede los siguiente:
    # posicion inicial:
    # 11000000 10101000 00000010 0101000 (en decimal: 1616118056 y queremos 192.168.2.40)
    # dezplazamiento 24 bits a la derecha:
    # 00000000 00000000 00000000 1100000 (solo necesitamos 8 bits)
    # por ende se hace una operacion logica AND con 255
    # 255 (00000000 00000000 00000000 11111111 en binario)
    # compara bit a bit y devuelve 1 en donde hay un 1
    # 00000000 00000000 00000000 1100000
    # 00000000 00000000 00000000 1111111
    # entonces solo nos quedara: 1100000
}

escanearIPs() {
    local IPaEscanear="$1"
    if hping3 -1 -c 1 -n -q "$IPaEscanear" &>/dev/null; then
        echo "UP $IPaEscanear"
    else
        echo "DOWN $IPaEscanear"
    fi
}
export -f escanearIPs

verificarIP() {
    local IP="$1"
    if nmap -sn "$IP" 2>/dev/null | grep -q "Host is up"; then
        return 0
    else
        return 1
    fi
}

cambiarIP() {
    local interfaz="$1"
    local IP="$2"
    local gateway="$3"
    local prefijo="$4"
    local netmask="$5"
    local distro="$6"
    local red="$7"
    local broadcast="$8"
    local gestor=$(detectarGestorRed)
    local perfil="static-$interfaz"

    case "$distro" in
    debian)
        case "$gestor" in
        NetworkManager)
            echo "[!] - Configurando IP estática con NetworkManager"
            nmcli connection modify "$interfaz" \
                ipv4.addresses "$IP/$prefijo" \
                ipv4.gateway "$gateway" \
                ipv4.dns "8.8.8.8,1.1.1.1" \
                ipv4.method manual
            nmcli connection up "$interfaz"
            ;;
        systemd-networkd)
            echo "[!] - Configurando IP con systemd-networkd"
            echo -e "[!] - Cambiando IP fija a ${IP}/${prefijo} en Arch Linux"

            mkdir -p /etc/systemd/network

            cat <<EOF >/etc/systemd/network/20-$interfaz.network
[Match]
Name=$interfaz

[Network]
Address=$IP/$prefijo
Gateway=$gateway
DNS=8.8.8.8 1.1.1.1
EOF

            systemctl restart systemd-networkd
            ;;
        manual)
            echo "[!] - Aplicando con ip link/addr/manual"
            ip addr flush dev "$interfaz"
            ip addr add "$IP/$prefijo" dev "$interfaz"
            ip link set dev "$interfaz" up
            ip route add default via "$gateway"
            ;;
        *)
            echo "[!] - No se detectó gestor de red compatible"
            return 1
            ;;
        esac
        ;;

    ubuntu)
        echo -e "[!] - Cambiando IP fija a ${IP}/${prefijo} en Ubuntu (netplan)"

        cat <<EOF >/etc/netplan/01-static-ip.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $interfaz:
      dhcp4: no
      addresses:
        - $IP/$prefijo
      gateway4: $gateway
      nameservers:
        addresses:
          - 8.8.8.8
          - 1.1.1.1
EOF
        if netplan try; then
            netplan apply
        else
            echo "${rojo}[!] - Falló netplan...${reset}"
        fi
        ;;

    arch)
        case "$gestor" in
        NetworkManager)
            echo "[!] - Configurando IP estática con NetworkManager"
            nmcli connection modify "$interfaz" \
                ipv4.addresses "$IP/$prefijo" \
                ipv4.gateway "$gateway" \
                ipv4.dns "8.8.8.8,1.1.1.1" \
                ipv4.method manual
            nmcli connection up "$interfaz"
            ;;
        systemd-networkd)
            echo "[!] - Configurando IP con systemd-networkd"
            echo -e "[!] - Cambiando IP fija a ${IP}/${prefijo} en Arch Linux"

            mkdir -p /etc/systemd/network

            cat <<EOF >/etc/systemd/network/20-$interfaz.network
[Match]
Name=$interfaz

[Network]
Address=$IP/$prefijo
Gateway=$gateway
DNS=8.8.8.8 1.1.1.1
EOF

            systemctl restart systemd-networkd
            ;;
        iwd)
            echo "[!] - Conectando Wi-Fi con iwd e IP estática"
            echo -e "[!] - Cambiando IP fija a ${IP}/${prefijo} en Arch Linux"
            ip addr flush dev "$interfaz"
            ip addr add "$IP/$prefijo" dev "$interfaz"
            ip link set dev "$interfaz" down
            ip link set dev "$interfaz" up
            ip route add default via "$gateway"
            ;;
        netctl)
            echo "[!] - Configurando perfil netctl"
            cat <<EOF >/etc/netctl/$perfil
Description='Static IP on $interfaz'
Interface=$interfaz
Connection=ethernet
IP=static
Address=('$IP/$prefijo')
Gateway='$gateway'
DNS=('8.8.8.8' '1.1.1.1')
EOF
            netctl enable "$perfil"
            netctl start "$perfil"
            ;;
        manual)
            echo "[!] - Aplicando con ip link/addr/manual"
            ip addr flush dev "$interfaz"
            ip addr add "$IP/$prefijo" dev "$interfaz"
            ip link set dev "$interfaz" up
            ip route add default via "$gateway"
            ;;
        *)
            echo "[!] - No se detectó gestor de red compatible"
            return 1
            ;;
        esac
        ;;

    *)
        echo -e "[!] - \"$distro\" aún no soportada"
        return 1
        ;;
    esac
}

detectarGestorRed() {
    # 1) NetworkManager Debian/Arch
    if systemctl is-active --quiet NetworkManager.service; then
        echo "NetworkManager"
        return
    fi

    # 2) iwd (solo Wi‑Fi) Arch
    if systemctl is-active --quiet iwd.service; then
        echo "iwd"
        return
    fi

    # 3) systemd-networkd Debian/Arch
    if systemctl is-active --quiet systemd-networkd.service; then
        echo "systemd-networkd"
        return
    fi

    # 4) netctl Arch
    if command -v netctl >/dev/null 2>&1 && netctl list | grep -q '^\*'; then
        echo "netctl"
        return
    fi

    # 5) ifupdown clásico (legacy Debian) deprecated
    if [ -f /etc/network/interfaces ]; then
        echo "ifupdown"
        return
    fi

    # 5) fallback: configuración manual con ip(8)
    echo "manual"
}

if [[ $EUID -ne 0 ]]; then
    echo -e "${rojoI}[!] - No eres superusuario${reset}"
    exit 1
fi

distro=$(detectarDistro)
nombreDistro=$(detectarNombreDistro)
echo -e "${azul}Distro detectada: ${nombreDistro}, ID=$distro${reset}"

if ! instalarDependencias "$distro"; then
    echo -e "${rojoI}La distro ${rojoUnd}${nombreDistro}${rojoI} no es soportada (aun)${reset}"
    exit 0
fi
clear

configurarMariaDB
instalarFrontAccounting "$distro"

echo "
    ______                 __                                    __  _            
   / ____/________  ____  / /_____ _______________  __  ______  / /_(_)___  ____ _
  / /_  / ___/ __ \/ __ \/ __/ __ '/ ___/ ___/ __ \/ / / / __ \/ __/ / __ \/ __ '/
 / __/ / /  / /_/ / / / / /_/ /_/ / /__/ /__/ /_/ / /_/ / / / / /_/ / / / / /_/ / 
/_/   /_/   \____/_/ /_/\__/\__,_/\___/\___/\____/\__,_/_/ /_/\__/_/_/ /_/\__, /  
                      (_)___  _____/ /_____ _/ / /__  _____              /____/   
                     / / __ \/ ___/ __/ __ '/ / / _ \/ ___/                       
                    / / / / (__  ) /_/ /_/ / / /  __/ /                           
                   /_/_/ /_/____/\__/\__,_/_/_/\___/_/                            
                                                                                  
" | lolcat

interfazActiva=$(ip route get 8.8.8.8 2>/dev/null | awk 'NR==1{print $5}')
gateway=$(ip route | awk '/default/ {print $3}')
ipLocal=$(ip -o -4 addr show dev "$interfazActiva" | awk '{print $4}')

if [[ -z "$ipLocal" ]]; then
    echo -e "${rojo}[!] - No se encontró dirección IPv4 en la interfaz ${rojoI}$interfazActiva.${reset}"
    exit 1
fi

direccionIP=${ipLocal%/*}
longitudPrefijo=${ipLocal#*/}

echo -e "${cyan}[✓] - Interfaz: ${cyanI}$interfazActiva"
echo -e "${cyan}[✓] - IP usada actualmente: ${cyanI}$ipLocal"

# Calcular IP de red y broadcast
decimalIP=$(ipADecimal "$direccionIP")
netMask=$((0xFFFFFFFF << (32 - longitudPrefijo) & 0xFFFFFFFF))
direccionIP_decimal=$((decimalIP & netMask))
broadcastIP_decimal=$((direccionIP_decimal | ~netMask & 0xFFFFFFFF))

ipDeLaRed=$(convertirEnteroAIP "$direccionIP_decimal")

echo -e "${cyan}[✓] - Red detectada: ${cyanI}${ipDeLaRed}/${longitudPrefijo}${reset}"

# Crear array con IPs dentro del rango usable
ipsUsables=()
for ((i = direccionIP_decimal + 1; i < broadcastIP_decimal; i++)); do
    ipsUsables+=("$(convertirEnteroAIP "$i")")
done

conteoTotalDeIP=${#ipsUsables[@]}

while true; do
    echo -en "${cyan}[?] - ${cyanI}Ingresa la cantidad de procesos de escaneo de host en paralelo (dejalo vacio para tomar su valor por defecto):${reset} "
    read cantidadProcesosParaleloUsuario
    if [[ "$cantidadProcesosParaleloUsuario" =~ ^[0-9]+$ || -z $cantidadProcesosParaleloUsuario ]]; then
        if [[ -z $cantidadProcesosParaleloUsuario ]]; then
            cantidadProcesosParalelo=100
            break
        else
            cantidadProcesosParalelo=$cantidadProcesosParaleloUsuario
            break
        fi
    else
        echo -e "${rojoI}[!] - Coloque una cantidad válida!!${reset}\n"
    fi
done
clear
echo -e "${cyan}[!] - Escaneando $conteoTotalDeIP hosts con $cantidadProcesosParalelo procesos en paralelo...${reset}"

# Crear archivo temporal y declarar arrays para IPs
tempfile=$(mktemp)
ipUsadas=()
ipDisponibles=()

# Ejecutar escaneo en paralelo y guardar salida
printf "%s\n" "${ipsUsables[@]}" | xargs -P $cantidadProcesosParalelo -I {} bash -c 'escanearIPs "$@"' _ {} >"$tempfile"

clear

# Procesar resultados del escaneo
while read -r status ipResult; do
    if [[ "$status" == "UP" ]]; then
        ipUsadas+=("$ipResult")
    else
        ipDisponibles+=("$ipResult")
    fi
done <"$tempfile"

rm -f "$tempfile"

# Mostrar IPs usadas
echo -e "\n${cyan}[+] - IPs usadas (${#ipUsadas[@]}/$conteoTotalDeIP):${reset}"
if ((${#ipUsadas[@]} > 0)); then
    for i in "${!ipUsadas[@]}"; do
        printf "${amarillo}%3d)${reset} %s\n" $((i + 1)) "${ipUsadas[i]}"
    done
else
    echo "${rojo}(ninguna)${reset}"
fi

# Mostrar IPs disponibles con numeración
echo -e "\n${cyan}[+] - IPs disponibles (${#ipDisponibles[@]}/$conteoTotalDeIP):${reset}"
if ((${#ipDisponibles[@]} > 0)); then
    for i in "${!ipDisponibles[@]}"; do
        printf "${verde}%3d)${reset} %s\n" $((i + 1)) "${ipDisponibles[i]}"
    done
else
    echo "${rojo}(ninguna)${reset}"
fi

# Selección de IP disponible
echo
if ((${#ipDisponibles[@]} == 0)); then
    echo -e "${amarillo}[!] - No hay IPs disponibles, usalo más tarde.${reset}"
    exit 1
else
    while true; do
        read -rp $'\n[+] - Seleccione número de IP disponible: ' indiceSeleccion
        if [[ "$indiceSeleccion" =~ ^[0-9]+$ ]] && ((indiceSeleccion >= 1 && indiceSeleccion <= ${#ipDisponibles[@]})); then
            IPSeleccionada="${ipDisponibles[indiceSeleccion - 1]}"
            echo -e "${verde}[✓] - IP seleccionada: ${verdeI}$IPSeleccionada${reset}"
            break
        else
            echo -e "${rojo}[!] - Índice inválido. Intente de nuevo.${reset}"
        fi
    done

    # Confirmar el cambio de IP
    echo
    read -rp $'[?] - ¿Deseas configurar esta IP como estática? [s/N]: ' confirmacion
    if [[ "$confirmacion" =~ ^[Ss]$ ]]; then
        netmask=$(convertirEnteroAIP "$netMask")
        cambiarIP "$interfazActiva" "$IPSeleccionada" "$gateway" "$longitudPrefijo" "$netmask" "$distro" "$ipDeLaRed" "$(convertirEnteroAIP "$broadcastIP_decimal")"
        echo -e "${verdeI}[✓] - IP configurada exitosamente${reset}"
    else
        echo -e "${amarillo}[!] - Operación cancelada por el usuario${reset}"
    fi
fi

echo -e "${cyan}[+] - Verificando conectividad con 8.8.8.8...${reset}"
if ping -c 2 8.8.8.8 &>/dev/null; then
    echo -e "${verdeI}[✓] - ¡Conectividad verificada!${reset}"
else
    echo -e "${rojoI}[X] - No hay conectividad. Revisa configuración.${reset}"
fi
