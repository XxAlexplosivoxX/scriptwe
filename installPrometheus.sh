#!/usr/bin/env bash

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

if [[ $EUID -ne 0 ]]; then
	echo -e "${rojoI}[!] - Este script debe ejecutarse como root${reset}"
	exit 1
fi

MovidasDeLaDistro() {
	if [[ -f /etc/os-release ]]; then
		source /etc/os-release
		echo -e "${ID}:${NAME}:${PRETTY_NAME}:${VERSION}:${VERSION_ID}:${VERSION_CODENAME}"
	fi
}
export -f MovidasDeLaDistro

InstalarDependencias() {
	local distro=$1

	case $distro in
	debian | ubuntu)
		echo -e "${verde}[+] - actualizando repositorios${reset}"
		apt update &>/dev/null

		local packages=("shfmt" "wget" "adduser" "libfontconfig1" "musl" "tar" "plocate" "gedit-plugins")
		local total=${#packages[@]}
		local step=0

		for package in "${packages[@]}"; do
			if dpkg -s "$package" &>/dev/null; then
				echo -e "${verdeI}[✓] - $package ya está instalado${reset}"
			else
				echo -e "${verde}[+] - Instalando $package..."
				if apt install "$package" -y &>/dev/null; then
					echo -e "${verdeI}[✓] - $package instalado correctamente${reset}"
				else
					echo -e "${rojoI}[!] - error al instalar $package${reset}"
				fi
			fi
		done
		;;
	*)
		echo -e "${rojoI}[!] - ${rojoUnd}${distro}${rojoI} no es compatible con este script aún.${reset}"
		;;
	esac
}

DescargarPrometheus() {
	local base_url="https://github.com/prometheus/prometheus/releases/download/v3.4.1"
	local arch=$(uname -m)
	local file=""

	case "$arch" in
	x86_64) file="prometheus-3.4.1.linux-amd64.tar.gz" ;;
	i386 | i686) file="prometheus-3.4.1.linux-386.tar.gz" ;;
	aarch64) file="prometheus-3.4.1.linux-arm64.tar.gz" ;;
	armv7l) file="prometheus-3.4.1.linux-armv7.tar.gz" ;;
	armv6l) file="prometheus-3.4.1.linux-armv6.tar.gz" ;;
	armv5l) file="prometheus-3.4.1.linux-armv5.tar.gz" ;;
	mips) file="prometheus-3.4.1.linux-mips.tar.gz" ;;
	mips64) file="prometheus-3.4.1.linux-mips64.tar.gz" ;;
	mips64el) file="prometheus-3.4.1.linux-mips64el.tar.gz" ;;
	mipsel) file="prometheus-3.4.1.linux-mipsle.tar.gz" ;;
	ppc64) file="prometheus-3.4.1.linux-ppc64.tar.gz" ;;
	ppc64le) file="prometheus-3.4.1.linux-ppc64le.tar.gz" ;;
	riscv64) file="prometheus-3.4.1.linux-riscv64.tar.gz" ;;
	s390x) file="prometheus-3.4.1.linux-s390x.tar.gz" ;;
	*)
		echo -e "${rojoI}[!] - No se pudo encontrar una versión compatible de Prometheus para '$arch'.${reset}"
		return 1
		;;
	esac

	local url="$base_url/$file"

	if [[ $arch == "x86_64" ]]; then
		echo -e "${cyanI}[+] - Verificando si el paquete grafana-enterprise esta instalado${reset}"
		if ! dpkg -s grafana-enterprise &>/dev/null; then
			echo -e "${amarilloI}[!] - grafana no está instalado..."
			echo -e "${verde}[+] - Descargando grafana... (solo si la arquitectura es de 64 bits)${verdeI}"
			wget -q --show-progress https://dl.grafana.com/enterprise/release/grafana-enterprise_12.0.1_amd64.deb
			echo -e "${verde}[+] - instalando grafana${reset}"
			dpkg -i grafana-enterprise_12.0.1_amd64.deb &>/dev/null
			echo -e "${verdeI}[✓] - grafana instalado correctamente${reset}"
		else
			echo -e "${amarilloI}[!] - Grafana ya está instalado... saltando a la descarga de Prometheus.${reset}"
			sleep 0.2
		fi
		echo -e "${cyanI}[+] - Buscando si el archivo $file ya esta descargado...${reset}"
		updatedb
		testFile=$(locate $file)
		if [[ -z "$testFile" ]]; then
			echo -e "${amarilloI}[!] - Archivo no encontrado...${reset}"
			respuestaValida=false
			while ! $respuestaValida; do
				echo -e -n "${cyanI}[?] - ¿Dónde quieres descargar Prometheus?\n(coloca un directorio existente o deja en blanco para usar $(pwd)): ${reset}"
				read directorioProm
				if [[ -z "$directorioProm" ]]; then
					directorioProm="$(pwd)"
				fi
				if [[ -d "$directorioProm" ]]; then
					respuestaValida=true
					echo -e "${verde}[+] - Descargando Prometheus para arquitectura: $arch${reset}"
					wget -q --show-progress "$url" -O "${directorioProm}/$file"
					if [[ $? -eq 0 ]]; then
						echo -e "${verdeI}[✓] - Descarga completada en: ${directorioProm}/$file${reset}"
						testFile="${directorioProm}/$file"
					else
						echo -e "${rojoI}[!] - Error al descargar Prometheus. Revisa tu conexión.${reset}"
						return 1
					fi
				else
					echo -e "${rojoI}[!] - Ruta no válida. Intenta de nuevo.${reset}"
				fi
			done
		else
			echo -e "${amarilloI}[!] - Prometheus ya está descargado en: $testFile${reset}"
		fi
	fi

	# Preguntar si desea descomprimir
	respuestaValida=false
	while ! $respuestaValida; do
		echo -e -n "${cyanI}[?] - ¿Deseas descomprimir automáticamente el archivo en $(pwd)/? [s,y o n]: ${reset}"
		read ans
		if [[ $ans =~ ^[YySs]$ ]]; then
			respuestaValida=true
			echo -e "${verde}[+] - Extrayendo archivos de $testFile...${reset}"
			tar -xvf "$testFile"
			local Dir=$(tar -tf "$testFile" | head -n 1 | cut -d/ -f1)
			if [[ -d "$Dir" ]]; then
				echo -e "${verde}[+] - Cambiando propietario a $SUDO_USER...${reset}"
				chown -R "$SUDO_USER:$SUDO_USER" "$Dir"
				echo -e "${verdeI}[✓] - Prometheus extraído correctamente en: ${verde}$(pwd)/$Dir"
				echo -e "\n${verdeI} + Puedes iniciarlo ejecutando:${reset}"
				echo -e "   cd $Dir"
				echo -e "   ./prometheus --config.file=prometheus.yml"
			else
				echo -e "${rojoI}[!] - No se pudo detectar el directorio extraído.${reset}"
			fi
		elif [[ $ans =~ ^[Nn]$ ]]; then
			respuestaValida=true
			echo -e "${rojoI}[!] - Operación cancelada por el usuario.${reset}"
		else
			echo -e "${rojoI}[!] - Respuesta no válida. Usa 's' para sí o 'n' para no.${reset}"
		fi
	done
}

DescargarNodeExporter() {
	local base_url="https://github.com/prometheus/node_exporter/releases/download/v1.9.1/"
	local arch=$(uname -m)
	local file=""

	case "$arch" in
	x86_64) file="node_exporter-1.9.1.linux-amd64.tar.gz" ;;
	i386 | i686) file="node_exporter-1.9.1.linux-386.tar.gz" ;;
	aarch64) file="node_exporter-1.9.1.linux-arm64.tar.gz" ;;
	armv7l) file="node_exporter-1.9.1.linux-armv7.tar.gz" ;;
	armv6l) file="node_exporter-1.9.1.linux-armv6.tar.gz" ;;
	armv5l) file="node_exporter-1.9.1.linux-armv5.tar.gz" ;;
	mips) file="node_exporter-1.9.1.linux-mips.tar.gz" ;;
	mips64) file="node_exporter-1.9.1.linux-mips64.tar.gz " ;;
	*)
		echo -e "${rojoI}[!] - No se pudo encontrar una versión compatible de Prometheus para '$arch'.${reset}"
		return 1
		;;
	esac

	local url="$base_url/$file"

	echo -e "${cyanI}[+] - Buscando si el archivo $file ya esta descargado...${reset}"
	updatedb
	testFile=$(locate $file)
	if [[ -z "$testFile" ]]; then
		echo -e "${amarilloI}[!] - Archivo no encontrado...${reset}"
		respuestaValida=false
		while ! $respuestaValida; do
			echo -e -n "${cyanI}[?] - ¿Dónde quieres descargar node_exporter?\n(coloca un directorio existente o deja en blanco para usar $(pwd)): ${reset}"
			read directorioProm
			if [[ -z "$directorioNode" ]]; then
				directorioNode="$(pwd)"
			fi
			if [[ -d "$directorioNode" ]]; then
				respuestaValida=true
				echo -e "${verde}[+] - Descargando node_exporter para arquitectura: $arch${reset}"
				wget -q --show-progress "$url" -O "${directorioNode}/$file"
				if [[ $? -eq 0 ]]; then
					echo -e "${verdeI}[✓] - Descarga completada en: ${directorioNode}/$file${reset}"
					testFile="${directorioNode}/$file"
				else
					echo -e "${rojoI}[!] - Error al descargar node_exporter. Revisa tu conexión.${reset}"
					return 1
				fi
			else
				echo -e "${rojoI}[!] - Ruta no válida. Intenta de nuevo.${reset}"
			fi
		done
	else
		echo -e "${amarilloI}[!] - node_exporter ya está descargado en: $testFile${reset}"
	fi

	# Preguntar si desea descomprimir
	respuestaValida=false
	while ! $respuestaValida; do
		echo -e -n "${cyanI}[?] - ¿Deseas descomprimir automáticamente el archivo en $(pwd)/? [s,y o n]: ${reset}"
		read ans
		if [[ $ans =~ ^[YySs]$ ]]; then
			respuestaValida=true
			echo -e "${verde}[+] - Extrayendo archivos de $testFile...${reset}"
			tar -xvf "$testFile"
			local Dir=$(tar -tf "$testFile" | head -n 1 | cut -d/ -f1)
			if [[ -d "$Dir" ]]; then
				echo -e "${verde}[+] - Cambiando propietario a $SUDO_USER...${reset}"
				chown -R "$SUDO_USER:$SUDO_USER" "$Dir"
				echo -e "${verdeI}[✓] - node_exporter extraído correctamente en: ${verde}$(pwd)/$Dir"
				echo -e "\n${verdeI} + Puedes iniciarlo ejecutando:${reset}"
				echo -e "   cd $Dir"
				echo -e "   ./node_exporter"
				if [[ -d "/usr/local/bin" ]]; then
					echo -en "$cyanI[?] - Quieres mover node_exporter a /usr/local/bin?${reset}"
					read seleccion
					if [[ "$seleccion" =~ ^[SsYy] ]]; then
						mv $Dir/node_exporter /usr/local/bin
						echo -e "$cyanI[!] - ok$reset"
					elif [[ "$seleccion" =~ ^[Nn] ]]; then
						echo -e "$cyanI[!] - ok$reset"
					fi
				fi
			else
				echo -e "${rojoI}[!] - No se pudo detectar el directorio extraído.${reset}"
			fi
		elif [[ $ans =~ ^[Nn]$ ]]; then
			respuestaValida=true
			echo -e "${rojoI}[!] - Operación cancelada por el usuario.${reset}"
		else
			echo -e "${rojoI}[!] - Respuesta no válida. Usa 's' para sí o 'n' para no.${reset}"
		fi
	done
}

# Detectar distribución
Movidas=$(MovidasDeLaDistro)
IFS=: read -r id name prettyName version versionID versionCodename <<<"$Movidas"

InstalarDependencias "$id"

respuestaValida=false
while ! $respuestaValida; do
	clear
	echo -en "${cyan}\
[+] - selecciona una opción:

1 - instalar prometheus (monitor).
2 - instalar node_exporter (cliente).
3 - salir.

[?] - seleccion:${reset} "
	read seleccion
	case "$seleccion" in
	1)
		respuestaValida=true
		DescargarPrometheus
		;;
	2)
		respuestaValida=true
		DescargarNodeExporter

		;;
	3)
		echo -e "${cyan}[!] -  ta bn..."
		exit 0
		;;
	*)
		echo -e "${rojoI}[!] - Respuesta no válida. seleciona una opción...${reset}"
		;;
	esac
done
