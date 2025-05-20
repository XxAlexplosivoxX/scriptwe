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
negroUnd='\e[0;30m'
rojoUnd='\e[0;31m'
verdeUnd='\e[0;32m'
amarilloUnd='\e[0;33m' 
azulUnd='\e[0;34m' 
moradoUnd='\e[0;35m' 
cyanUnd='\e[0;36m' 
blancoUnd='\e[0;37m'
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
        debian)
            arrDependencias=("hping3" "lolcat" "aircrack-ng" "nmap" "php" "php-cli" "php-common" "php-fpm" "php-mysql" "libapache2-mod-php")
            echo -e "${verde}[!] - Instalando paquetes para Debian${reset}"
            apt update &> /dev/null
            comandoInstalar="apt install -y"
            ;;
        ubuntu)
            arrDependencias=("hping3" "lolcat" "aircrack-ng" "nmap")
            echo -e "${verde}[!] - Instalando paquetes para Ubuntu${reset}"
            apt update &> /dev/null
            comandoInstalar="apt install -y"
            ;;
        arch)
            arrDependencias=("hping" "lolcat" "aircrack-ng" "nmap")
            echo -e "${verde}[!] - Instalando paquetes para Arch linux${reset}"
            echo -e "${cyan}Actualizando repositorios${reset}"
            pacman -Sy --noconfirm
            comandoInstalar="pacman -S --noconfirm"
            ;;
        *)
            return 1
            ;;
    esac

    for paquete in "${arrDependencias[@]}"; do
        if ! command -v "$paquete" &> /dev/null; then
            echo -e "${verde}[!] - Instalando paquete $paquete${reset}"
            if $comandoInstalar "$paquete" &> /dev/null; then
                echo -e "${verdeI}    - $paquete instalado correctamente${reset}"
            else
                echo -e "${rojoI}[!] - Ha fallado la instalación de $paquete${reset}"
            fi
        else
            echo -e "${verde}[!] - ${verdeUnd}$paquete${verde} ya está instalado${reset}"
        fi
    done
    sleep 1
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
        $(( (IPinteger >> 24) & 255 )) \
        $(( (IPinteger >> 16) & 255 )) \
        $(( (IPinteger >> 8) & 255 )) \
        $(( IPinteger & 255 ))
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

    case "$distro" in
        debian)
            echo -e "[!] - Cambiando IP fija a ${IP}/${prefijo}"
            echo "auto $interfaz
            iface $interfaz inet static
                address $IP
                netmask $netmask
                network $red
                broadcast $broadcast
                gateway $gateway
                dns-nameservers 1.1.1.1 8.8.8.8" >> /etc/interfaces
            if ! systemctl restart networking; then
                return  1
            else
                return 0
            fi
            ;;
        *)
            echo -e "${rojo}[!] - \"$distro\" aùn no soportada${reset}"
            return 1
            ;;
    esac
}

if [[ $EUID -ne 0 ]]; then 
    echo -e "${rojoI}[!] - No eres superusuario${reset}"
    exit 1
fi

distro=$(detectarDistro);
nombreDistro=$(detectarNombreDistro)
echo -e "${azul}Distro detectada: ${nombreDistro}, ID=$distro${reset}"

if ! instalarDependencias "$distro"; then
    echo -e "${rojoI}La distro ${rojoUnd}${nombreDistro}${rojoI} no es soportada (aun)${reset}"
    exit 0
fi
clear

echo "
._____________________________________________________________________________________.
| _______   _______  __ ___________  ______ ____   _____________  _______  ______.__. |
| \_  __ \_/ __ \  \/ // __ \_  __ \/  ___// __ \  \____ \_  __ \/  _ \  \/  <   |  | |
|  |  | \/\  ___/\   /\  ___/|  | \\/\\___ \\\\  ___/  |  |_> >  |  (  <_> >    < \\___  | |
|  |__|    \___  >\_/  \___  >__|  /____  >\___  > |   __/|__|   \____/__/\_ \/ ____| |
|              \/          \/           \/     \/  |__|                     \/\/      |
|_____________________________________________________________________________________|
" | lolcat

interfazActiva=$(ip route get 8.8.8.8 2>/dev/null | awk 'NR==1{print $5}')
gateway=$(ip route | awk '/default/ {print $3}')
ipLocal=$(ip -o -4 addr show dev "$interfazActiva" | awk '{print $4}')

if [[ -z "$ipLocal" ]]; then
    echo -e "${rojo}[!] - No se encontró dirección IPv4 en la interfaz ${rojoI}$interfazActiva.${reset}" >&2
    exit 1
fi

direccionIP=${ipLocal%/*}
longitudPrefijo=${ipLocal#*/}

echo -e "${cyan}[+] - Interfaz: ${cyanI}$interfazActiva"
echo -e "${cyan}[+] - IP usada actualmente: ${cyanI}$ipLocal"

# Calcular IP de red y broadcast
IFS=. read -r oct1 oct2 oct3 oct4 <<< "$direccionIP"
decimalIP=$(( (oct1 << 24) + (oct2 << 16) + (oct3 << 8) + oct4 ))
netMask=$(( 0xFFFFFFFF << (32 - longitudPrefijo) & 0xFFFFFFFF ))
direccionIP_decimal=$(( decimalIP & netMask ))
broadcastIP_decimal=$(( direccionIP_decimal | ~netMask & 0xFFFFFFFF ))

ipDeLaRed=$(convertirEnteroAIP "$direccionIP_decimal")

echo -e "${cyan}[+] - Red detectada: ${cyanI}${ipDeLaRed}/${longitudPrefijo}${reset}"

# Crear array con IPs dentro del rango usable
ipsUsables=()
for (( i = direccionIP_decimal + 1; i < broadcastIP_decimal; i++ )); do
    ipsUsables+=("$(convertirEnteroAIP "$i")")
done

conteoTotalDeIP=${#ipsUsables[@]}

while true; do
    echo -en "${cyan}[?] - ${cyanI}Ingresa la cantidad de procesos de escaneo de host en paralelo (dejalo vacio para tomar su valor por defecto):${reset} "
    read cantidadProcesosParaleloUsuario
    if [[ "$cantidadProcesosParaleloUsuario" =~ ^[0-9]+$ || -z $cantidadProcesosParaleloUsuario ]]; then
        if [[ -z $cantidadProcesosParaleloUsuario ]];then
            cantidadProcesosParalelo=100
            break
        else
            cantidadProcesosParalelo=$cantidadProcesosParaleloUsuario
            break
        fi
    else
        echo -e "${rojoI}[!] - Coloque una cantidad válida!!${reset}/n"
    fi
done
clear
echo -e "${cyan}[!] - Escaneando $conteoTotalDeIP hosts con $cantidadProcesosParalelo procesos en paralelo...${reset}"

# Crear archivo temporal y declarar arrays para IPs
tempfile=$(mktemp)
ipUsadas=()
ipDisponibles=()

# Ejecutar escaneo en paralelo y guardar salida
printf "%s\n" "${ipsUsables[@]}" | xargs -P $cantidadProcesosParalelo -I {} bash -c 'escanearIPs "$@"' _ {} > "$tempfile"

clear

# Procesar resultados del escaneo
while read -r status ipResult; do
    if [[ "$status" == "UP" ]]; then
        ipUsadas+=("$ipResult")
    else
        ipDisponibles+=("$ipResult")
    fi
done < "$tempfile"

rm -f "$tempfile"

# Mostrar IPs usadas
echo -e "\n${cyan}[+] - IPs usadas (${#ipUsadas[@]}/$conteoTotalDeIP):${reset}"
if (( ${#ipUsadas[@]} > 0 )); then
    for i in "${!ipUsadas[@]}"; do
        printf "${amarillo}%3d)${reset} %s\n" $((i + 1)) "${ipUsadas[i]}"
    done
else
    echo "${rojo}(ninguna)${reset}"
fi

# Mostrar IPs disponibles con numeración
echo -e "\n${cyan}[+] - IPs disponibles (${#ipDisponibles[@]}/$conteoTotalDeIP):${reset}"
if (( ${#ipDisponibles[@]} > 0 )); then
    for i in "${!ipDisponibles[@]}"; do
        printf "${verde}%3d)${reset} %s\n" $((i + 1)) "${ipDisponibles[i]}"
    done
else
    echo "${rojo}(ninguna)${reset}"
fi

# Selección de IP disponible
echo
if (( ${#ipDisponibles[@]} == 0 )); then
    echo -e "${amarillo}[!] - No hay IPs disponibles, pero selecciona una de las IPs usadas.${reset}"
    listoPaRobar=true
    while true; do
        read -rp $'\n[+] - Seleccione número de IP en uso (pa robarla w): ' indiceSeleccion
        if [[ "$indiceSeleccion" =~ ^[0-9]+$ ]] && (( indiceSeleccion >= 1 && indiceSeleccion <= ${#ipUsadas[@]} )); then
            ipSeleccionada="${ipUsadas[indiceSeleccion - 1]}"
            break
        else
            echo -e  "${rojo}[!] - Selección inválida. Introduzca un número entre 1 y ${#ipUsadas[@]}.${reset}"
        fi
    done
else
    listoPaRobar=false
    while true; do
        read -rp $'\n[+] - Seleccione número de IP disponible: ' indiceSeleccion
        if [[ "$indiceSeleccion" =~ ^[0-9]+$ ]] && (( indiceSeleccion >= 1 && indiceSeleccion <= ${#ipDisponibles[@]} )); then
            ipSeleccionada="${ipDisponibles[indiceSeleccion - 1]}"
            break
        else
            echo -e  "${rojo}[!] - Selección inválida. Introduzca un número entre 1 y ${#ipDisponibles[@]}.${reset}"
        fi
    done
fi

if $listoPaRobar; then
    echo -e "${cyan}[+] - IP seleccionada: ${ipSeleccionada}, ${rojoI}robando la ip >:3${reset}"
else
    echo -e "${cyan}[+] - IP seleccionada: ${ipSeleccionada}, ${amarillo}verificando que no este nadie usandola...${reset}"
    if verificarIP "$ipSeleccionada"; then
        echo -e "${rojo}[!] - Alguien la esta usando, ${rojoI}robando la ip >:3${reset}"
    else
        echo -e "${verde}[+] - Todo limpio, prosiguiendo...${reset}"
        echo -e "${amarillo}[!] - Cambiando la ip de ${direccionIP}/${longitudPrefijo} a ${ipSeleccionada}/${longitudPrefijo} en ${interfazActiva}!${reset}"
        netmaskIP=$(convertirEnteroAIP "$netMask")
        broadcastIP=$(convertirEnteroAIP "$broadcastIP_decimal")
        if ! cambiarIP "$interfazActiva" "$ipSeleccionada" "$gateway" "$longitudPrefijo" "$netmaskIP" "$distro" "$ipDeLaRed" "$broadcastIP"; then
            echo -e "${rojo}[!] - Esta mal en algoo${reset}"
        else
            echo -e "[!] - Ahora tu ip es $ipSeleccionada :D"
        fi
        
    fi
fi
