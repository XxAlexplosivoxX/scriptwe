#!/usr/bin/env bash
instalarDependencias() {
    local dependencias=("wget" "git" "wireshark" "nmap" "net-tools" "build-essential" "dkms" "linux-headers-$(uname -r)" "virtualbox-dkms")
    for paquete in "${dependencias[@]}"; do
        if ! dpkg -s "$paquete" &>/dev/null; then
            echo "Instalando paquete $paquete..."
            if apt install -y "$paquete" &>/dev/null; then
                echo "[✓] - $paquete instalado correctamente"
            else
                echo "[✗] - Error al instalar $paquete"
            fi
        else
            echo "[✓] - $paquete ya está instalado"
        fi
    done
}

derivadosUbuntu() {
    if [[ -r /etc/os-release ]]; then
        source /etc/os-release
        echo "${NAME}|${ID}|${VERSION}|${VERSION_CODENAME}"
    else
        return 1
    fi
}

if [[ ! $EUID -eq 0 ]]; then
	echo "ejecuta el script como superusuario."
	exit 1
fi

info=$(derivadosUbuntu)
IFS="|" read -r nombre id version codename <<< "$info"

echo "[!] - Información del sistema:"
echo "- distro: $nombre"
echo "- version: $version"

# Instalar dependencias básicas
instalarDependencias

# Agregar clave pública solo una vez
clave_path="/usr/share/keyrings/oracle-virtualbox-2016.gpg"
if [ ! -f "$clave_path" ]; then
    echo "Importando clave pública de Oracle VirtualBox..."
    wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc | \
        gpg --dearmor --output "$clave_path"
else
    echo "[✓] - Clave pública de Oracle VirtualBox ya importada"
fi

# Agregar repositorio si no existe
repo_file="/etc/apt/sources.list.d/virtualbox.list"
if [ ! -f "$repo_file" ]; then
    echo "Agregando repositorio de Oracle VirtualBox..."
    echo "deb [signed-by=${clave_path}] https://download.virtualbox.org/virtualbox/debian $codename contrib" > "$repo_file"
    apt update
else
    echo "[✓] - Repositorio de Oracle VirtualBox ya está presente"
fi

# Instalar VirtualBox
paquete="virtualbox-7.1"
if ! dpkg -s "$paquete" &>/dev/null; then
    echo "Instalando $paquete..."
    if apt install -y "$paquete" &>/dev/null; then
        echo "[✓] - $paquete instalado correctamente"
    else
        echo "[✗] - Error al instalar $paquete"
        exit 1
    fi
else
    echo "[✓] - $paquete ya está instalado"
fi

usuario_real=$(logname)

# Añadir usuario al grupo vboxusers
echo "Configurando grupo vboxusers..."
if id -nG "$usuario_real" | grep -qw vboxusers; then
    echo "[✓] - El usuario $USER ya pertenece al grupo vboxusers"
else
    if gpasswd -a "$usuario_real" vboxusers; then
        echo "[✓] - Usuario $usuario_real añadido al grupo vboxusers"
    else
        echo "[✗] - Error al añadir al usuario $usuario_real al grupo vboxusers"
        exit 1
    fi
fi

echo "Ejecutando vboxconfig..."
if ! command -v vboxmanage &>/dev/null; then
    echo "[✗] - No se encontró 'vboxmanage', asegúrate que VirtualBox está instalado"
    exit 1
fi

if /sbin/vboxconfig &>/dev/null; then
    echo "[✓] - vboxconfig ejecutado correctamente"
else
    echo "[✗] - Fallo al ejecutar vboxconfig"
    exit 1
fi

# Obtener versión de VirtualBox
vboxVersion=$(vboxmanage -v | cut -d 'r' -f1)

# Descargar e instalar Extension Pack
extpack_file="Oracle_VirtualBox_Extension_Pack-${vboxVersion}.vbox-extpack"
if [ ! -f "$extpack_file" ]; then
    echo "Descargando Extension Pack versión $vboxVersion..."
    wget https://download.virtualbox.org/virtualbox/${vboxVersion}/${extpack_file}
fi

echo "Instalando Extension Pack..."
vboxmanage extpack install --replace "$extpack_file"
