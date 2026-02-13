#!/bin/bash
# =============================================================================
# Authentik SSL Certificate Setup Script
# =============================================================================
# This script helps generate self-signed certificates for testing/development
# or provides guidance for production Let's Encrypt certificates.
#
# Features:
# - Generate self-signed certificates with custom parameters
# - Setup Let's Encrypt certificates
# - Import custom certificates
# - Display certificate information
# - Clean and regenerate all certificates
# - Export .crt files for system installation
#
# WARNING: Self-signed certificates are NOT recommended for production use.
# Use Let's Encrypt or a proper CA certificate for production deployments.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CERT_DIR="./certs"
CERT_VALIDITY_DAYS=3650  # 10 years
DOMAIN="${AUTHENTIK_DOMAIN:-authentik.local}"
COUNTRY="${CERT_COUNTRY:-CN}"
STATE="${CERT_STATE:-Beijing}"
CITY="${CERT_CITY:-Beijing}"
ORG="${CERT_ORG:-AgenticGRC}"
ORG_UNIT="${CERT_ORG_UNIT:-IT}"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo "============================================================================"
    echo " $1"
    echo "============================================================================"
    echo ""
}

print_step() {
    echo -e "${GREEN}[$1]${NC} $2"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools exist
check_dependencies() {
    local missing=0

    if ! command -v openssl &> /dev/null; then
        print_error "openssl is not installed"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        print_info "Install missing tools:"
        echo "  Ubuntu/Debian: sudo apt-get install openssl"
        echo "  CentOS/RHEL:   sudo yum install openssl"
        echo "  macOS:         brew install openssl"
        exit 1
    fi
}

# Create certificate directory
setup_cert_dir() {
    mkdir -p "$CERT_DIR"
    chmod 755 "$CERT_DIR"
}

# Display certificate information
show_cert_info() {
    print_header "Certificate Information"

    if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
        print_error "No certificate found at $CERT_DIR/fullchain.pem"
        echo ""
        print_info "Generate certificates first by choosing option 1 from the main menu."
        return 1
    fi

    print_info "Certificate Details:"
    echo ""
    openssl x509 -in "$CERT_DIR/fullchain.pem" -noout -text | grep -E "(Subject:|Issuer:|DNS:|Not Before|Not After)" || true

    echo ""
    print_info "Files in $CERT_DIR:"
    ls -lh "$CERT_DIR" | grep -E "\.(pem|crt|key)$" || true

    return 0
}

# Clean all certificates
clean_certs() {
    print_header "Clean Certificates"

    print_warning "This will delete all certificate files in $CERT_DIR"
    echo ""
    read -p "Are you sure? This cannot be undone. (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        print_info "Cancelled."
        return 0
    fi

    print_step "1/1" "Removing certificate files..."

    cd "$CERT_DIR"
    rm -f privkey.pem fullchain.pem chain.pem dhparam.pem *.crt 2>/dev/null || true
    cd - > /dev/null

    print_info "All certificate files have been removed."
    print_info "You can now regenerate them by choosing option 1 from the main menu."
}

# Generate self-signed certificate
generate_self_signed() {
    print_header "Generate Self-Signed Certificate"

    print_warning "Self-signed certificates are NOT recommended for production use."
    echo ""

    # Certificate configuration
    echo "Certificate Configuration (press Enter for default value):"
    echo ""

    read -p "Domain or IP [$DOMAIN]: " input_domain
    DOMAIN=${input_domain:-$DOMAIN}

    read -p "Country Code (2 letters) [$COUNTRY]: " input_country
    COUNTRY=${input_country:-$COUNTRY}

    read -p "State/Province [$STATE]: " input_state
    STATE=${input_state:-$STATE}

    read -p "City [$CITY]: " input_city
    CITY=${input_city:-$CITY}

    read -p "Organization [$ORG]: " input_org
    ORG=${input_org:-$ORG}

    read -p "Organizational Unit [$ORG_UNIT]: " input_org_unit
    ORG_UNIT=${input_org_unit:-$ORG_UNIT}

    read -p "Validity (days) [$CERT_VALIDITY_DAYS]: " input_days
    CERT_VALIDITY_DAYS=${input_days:-$CERT_VALIDITY_DAYS}

    echo ""

    # Check for existing certificates
    if [ -f "$CERT_DIR/privkey.pem" ]; then
        print_warning "Existing certificates found!"
        echo ""
        read -p "Overwrite existing certificates? (yes/no): " overwrite
        if [ "$overwrite" != "yes" ]; then
            print_info "Cancelled."
            return 0
        fi
        echo ""
    fi

    # Generate certificates
    print_step "1/5" "Creating certificate directory..."
    setup_cert_dir

    print_step "2/5" "Generating 4096-bit RSA private key..."
    openssl genrsa -out "$CERT_DIR/privkey.pem" 4096

    print_step "3/5" "Generating self-signed certificate..."
    openssl req -new -x509 -key "$CERT_DIR/privkey.pem" -out "$CERT_DIR/fullchain.pem" -days "$CERT_VALIDITY_DAYS" \
        -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$ORG_UNIT/CN=$DOMAIN" \
        -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,DNS:*.$DOMAIN,IP:127.0.0.1"

    print_step "4/5" "Creating additional certificate files..."

    # Copy to chain.pem (same as fullchain for self-signed)
    cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem"

    # Create .crt file for system installation
    cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/$DOMAIN.crt"

    # Create .crt file with generic name
    cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/authentik-local.crt"

    print_step "5/5" "Generating DH parameters (this may take a minute)..."
    openssl dhparam -out "$CERT_DIR/dhparam.pem" 2048 2>/dev/null || {
        print_warning "DH param generation failed, continuing without it."
    }

    # Set permissions
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem" "$CERT_DIR"/*.crt

    echo ""
    print_info "Certificates generated successfully!"
    echo ""
    show_cert_info

    show_install_instructions
}

# Setup Let's Encrypt certificate
setup_letsencrypt() {
    print_header "Setup Let's Encrypt Certificate"

    print_info "Requirements:"
    echo "  - Domain name pointing to this server"
    echo "  - Port 80 must be accessible from internet"
    echo "  - certbot installed"
    echo ""

    read -p "Enter your domain name: " domain
    read -p "Enter email for Let's Encrypt notifications: " email

    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_error "certbot is not installed."
        echo ""
        print_info "Install certbot:"
        echo "  Ubuntu/Debian: sudo apt-get install certbot"
        echo "  CentOS/RHEL:   sudo yum install certbot"
        echo "  macOS:         brew install certbot"
        exit 1
    fi

    print_step "1/4" "Stopping Authentik to free port 80..."
    docker compose down 2>/dev/null || true

    print_step "2/4" "Obtaining certificate from Let's Encrypt..."
    certbot certonly --standalone -d "$domain" --email "$email" --agree-tos --non-interactive

    print_step "3/4" "Copying certificates to certs directory..."
    setup_cert_dir

    cp "/etc/letsencrypt/live/$domain/privkey.pem" "$CERT_DIR/privkey.pem"
    cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$CERT_DIR/fullchain.pem"
    cp "/etc/letsencrypt/live/$domain/chain.pem" "$CERT_DIR/chain.pem"

    # Create .crt file for system installation
    cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/$domain.crt"

    # Set permissions
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem" "$CERT_DIR"/*.crt

    print_step "4/4" "Starting Authentik..."
    docker compose up -d 2>/dev/null || true

    echo ""
    print_info "Certificate setup complete!"
    echo ""
    print_info "To auto-renew certificates, add this to crontab:"
    echo "  0 0 * * * certbot renew --quiet --post-hook 'docker compose restart server'"

    show_install_instructions
}

# Import custom certificate
import_custom() {
    print_header "Import Custom Certificate"

    echo "Please provide the paths to your certificate files."
    echo ""

    read -e -p "Private key path (.key or .pem): " key_path
    read -e -p "Certificate path (.crt or .pem): " cert_path
    read -e -p "CA chain path (optional, press Enter to skip): " chain_path

    # Validate files exist
    if [ ! -f "$key_path" ]; then
        print_error "Private key file not found: $key_path"
        exit 1
    fi

    if [ ! -f "$cert_path" ]; then
        print_error "Certificate file not found: $cert_path"
        exit 1
    fi

    print_step "1/3" "Creating certificate directory..."
    setup_cert_dir

    print_step "2/3" "Copying certificate files..."
    cp "$key_path" "$CERT_DIR/privkey.pem"
    cp "$cert_path" "$CERT_DIR/fullchain.pem"

    if [ -n "$chain_path" ] && [ -f "$chain_path" ]; then
        cp "$chain_path" "$CERT_DIR/chain.pem"
    else
        # Copy fullchain as chain if not provided
        cp "$cert_path" "$CERT_DIR/chain.pem"
    fi

    # Create .crt file for system installation
    cp "$CERT_DIR/fullchain.pem" "$CERT_DIR/authentik-custom.crt"

    print_step "3/3" "Setting permissions..."
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/fullchain.pem" "$CERT_DIR/chain.pem" "$CERT_DIR"/*.crt

    echo ""
    print_info "Custom certificate imported successfully!"
    echo ""
    show_cert_info

    show_install_instructions
}

# Show installation instructions
show_install_instructions() {
    echo ""
    print_header "System Certificate Installation"

    print_info "To trust this certificate on your system:"
    echo ""

    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "Ubuntu/Debian:"
            echo "  sudo cp $CERT_DIR/*.crt /usr/local/share/ca-certificates/"
            echo "  sudo update-ca-certificates"
        elif [ -f /etc/redhat-release ]; then
            echo "CentOS/RHEL:"
            echo "  sudo cp $CERT_DIR/*.crt /etc/pki/ca-trust/source/anchors/"
            echo "  sudo update-ca-trust"
        else
            echo "Linux:"
            echo "  sudo cp $CERT_DIR/*.crt /usr/local/share/ca-certificates/"
            echo "  sudo update-ca-certificates"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS:"
        echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $CERT_DIR/*.crt"
    else
        echo "Windows (WSL):"
        echo "  certutil -addstore -f \"ROOT\" $CERT_DIR/*.crt"
    fi

    echo ""
    print_header "Docker Compose Configuration"

    print_info "The SSL environment variables are already configured in docker-compose.yml."
    echo ""
    print_info "Restart Authentik to apply certificates:"
    echo "  docker compose down"
    echo "  docker compose up -d"
    echo ""
    print_info "Then access via HTTPS:"
    echo "  https://$DOMAIN:9443/if/flow/initial-setup/"

    echo ""
    print_info "For Electron apps, the certificate must be added to the system trust store."
}

# Regenerate all files
regenerate_all() {
    print_header "Regenerate All Certificates"

    print_warning "This will clean and regenerate ALL certificate files."
    echo ""

    # First clean
    clean_certs

    # Check if user cancelled
    if [ -f "$CERT_DIR/privkey.pem" ]; then
        print_info "Regeneration cancelled."
        return 0
    fi

    # Then generate new
    generate_self_signed
}

# Main menu
show_menu() {
    echo ""
    print_header "Authentik SSL Certificate Management"
    echo ""
    echo "Choose an option:"
    echo ""
    echo "  ${GREEN}1${NC}) Generate self-signed certificate (for testing/development)"
    echo "  ${GREEN}2${NC}) Setup Let's Encrypt certificate (production)"
    echo "  ${GREEN}3${NC}) Import custom certificate"
    echo "  ${GREEN}4${NC}) View certificate information"
    echo "  ${GREEN}5${NC}) Clean all certificates"
    echo "  ${GREEN}6${NC}) ${YELLOW}Regenerate all certificates (clean + generate)${NC}"
    echo "  ${GREEN}0${NC}) Exit"
    echo ""
}

# =============================================================================
# Main Script
# =============================================================================

# Check dependencies
check_dependencies

# Create certificate directory if it doesn't exist
setup_cert_dir

# Main loop
while true; do
    show_menu
    read -p "Enter choice [0-6]: " choice

    case $choice in
        1)
            generate_self_signed
            ;;
        2)
            setup_letsencrypt
            ;;
        3)
            import_custom
            ;;
        4)
            show_cert_info
            ;;
        5)
            clean_certs
            ;;
        6)
            regenerate_all
            ;;
        0)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please try again."
            ;;
    esac

    echo ""
    read -p "Press Enter to continue..." dummy
done
