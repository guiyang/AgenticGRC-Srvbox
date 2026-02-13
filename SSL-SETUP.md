# Authentik SSL/TLS Configuration Guide

This guide explains how to configure SSL/TLS certificates for Authentik to ensure secure communication, especially for Electron desktop applications that require HTTPS.

## Why SSL/TLS is Important

- **Security**: Encrypts all traffic between clients and Authentik
- **Electron Compatibility**: Many Electron apps require HTTPS for OAuth/OIDC flows
- **Trust**: Users see a valid certificate from a trusted CA
- **Compliance**: Meets security requirements for production deployments

## Quick Start

### Option 1: Using the Setup Script (Recommended)

Run the interactive setup script:

```bash
./ssl-setup.sh
```

The script will guide you through:
1. Generating a self-signed certificate (testing)
2. Obtaining a Let's Encrypt certificate (production)
3. Using your own custom certificate

### Option 2: Manual Configuration

Follow the detailed instructions below for your specific use case.

---

## Development/Test Environment

### Self-Signed Certificate

For testing and development, you can generate a self-signed certificate:

```bash
# Create certs directory
mkdir -p certs

# Generate private key
openssl genrsa -out certs/privkey.pem 4096

# Generate self-signed certificate
openssl req -new -x509 -key certs/privkey.pem -out certs/fullchain.pem -days 365 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=authentik.local" \
    -addext "subjectAltName=DNS:authentik.local,DNS:localhost,IP:127.0.0.1"

# Set proper permissions
chmod 600 certs/privkey.pem
chmod 644 certs/fullchain.pem
```

**Enable SSL in docker-compose.yml:**

```yaml
server:
  # ... other config ...
  environment:
    AUTHENTIK_SSL_CERTIFICATE: /certs/fullchain.pem
    AUTHENTIK_SSL_KEY: /certs/privkey.pem
```

**Trust the certificate (for Electron apps):**

Since self-signed certificates are not trusted by default, you'll need to:

1. **For testing only**: Disable SSL verification in your Electron app (not recommended for production)
2. **Better approach**: Add the certificate to your system's trust store

**Adding to trust store:**

```bash
# On Linux (Ubuntu/Debian)
sudo cp certs/fullchain.pem /usr/local/share/ca-certificates/authentik.crt
sudo update-ca-certificates

# On macOS
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/fullchain.pem

# On Windows
certutil -addstore -f "ROOT" certs\fullchain.pem
```

---

## Production Environment

### Option 1: Let's Encrypt (Recommended)

Let's Encrypt provides free, trusted SSL certificates.

**Prerequisites:**
- Domain name pointing to your server
- Port 80 accessible from the internet
- `certbot` installed

**Install certbot:**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install certbot

# CentOS/RHEL
sudo yum install certbot

# macOS
brew install certbot
```

**Obtain certificate:**

```bash
# Stop Authentik to free port 80
docker compose down

# Obtain certificate
sudo certbot certonly --standalone -d authentik.example.com --email your-email@example.com --agree-tos

# Start Authentik
docker compose up -d
```

**Copy certificates:**

```bash
mkdir -p certs
sudo cp /etc/letsencrypt/live/authentik.example.com/privkey.pem certs/privkey.pem
sudo cp /etc/letsencrypt/live/authentik.example.com/fullchain.pem certs/fullchain.pem
sudo cp /etc/letsencrypt/live/authentik.example.com/chain.pem certs/chain.pem

# Set permissions
sudo chown $USER:$USER certs/*.pem
chmod 600 certs/privkey.pem
chmod 644 certs/fullchain.pem certs/chain.pem
```

**Auto-renewal setup:**

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to crontab (runs daily)
crontab -e
```

Add this line:
```
0 0 * * * certbot renew --quiet --post-hook "docker compose restart server"
```

### Option 2: Commercial Certificate

If you have a commercial SSL certificate:

1. **Place your certificate files** in the `certs/` directory:
   - `privkey.pem` - Your private key
   - `fullchain.pem` - Your certificate + CA chain
   - `chain.pem` - (Optional) CA chain only

2. **Set permissions:**
   ```bash
   chmod 600 certs/privkey.pem
   chmod 644 certs/fullchain.pem certs/chain.pem
   ```

3. **Enable in docker-compose.yml** (see below)

---

## Enabling SSL in Docker Compose

### Step 1: Update docker-compose.yml

Uncomment the SSL environment variables in the `server` service:

```yaml
server:
  # ... other config ...
  volumes:
    - ./media:/media
    - ./custom-templates:/templates
    - ./geoip:/geoip
    - ./certs:/certs
  environment:
    # SSL certificate configuration
    AUTHENTIK_SSL_CERTIFICATE: /certs/fullchain.pem
    AUTHENTIK_SSL_KEY: /certs/privkey.pem
```

### Step 2: Restart Authentik

```bash
docker compose down
docker compose up -d
```

### Step 3: Verify SSL is working

```bash
# Check if HTTPS port is listening
netstat -tlnp | grep 9443

# Test with curl
curl -v https://localhost:9443/-/health/

# Check certificate
openssl s_client -connect localhost:9443 -showcerts
```

---

## Using a Reverse Proxy (Recommended for Production)

For production deployments, it's recommended to use a reverse proxy like Nginx or Traefik:

### Nginx Reverse Proxy

1. **Use the provided Nginx configuration:**
   ```bash
   cp nginx-conf/authentik.conf /etc/nginx/sites-available/authentik
   ln -s /etc/nginx/sites-available/authentik /etc/nginx/sites-enabled/
   ```

2. **Update domain name** in the configuration

3. **Obtain Let's Encrypt certificate:**
   ```bash
   sudo certbot --nginx -d authentik.example.com
   ```

4. **Test and reload Nginx:**
   ```bash
   sudo nginx -t
   sudo nginx -s reload
   ```

5. **Update docker-compose.yml** to remove HTTPS port mapping (Nginx handles it):
   ```yaml
   server:
     ports:
       - "127.0.0.1:9000:9000"
       # Remove or comment out the 9443 port
   ```

### Traefik Reverse Proxy

The provided `traefik-conf/traefik-dynamic.yml` configuration includes:

- Automatic Let's Encrypt certificate management
- SSL termination at Traefik
- Security headers
- WebSocket support

Traefik will automatically obtain and renew certificates.

---

## Troubleshooting

### Certificate not trusted error

**Problem**: Browser or Electron app shows certificate warning

**Solutions**:
1. **Self-signed certs**: Add certificate to system trust store (see above)
2. **Domain mismatch**: Ensure certificate CN/SAN matches your domain
3. **Expired cert**: Check expiration with `openssl x509 -in certs/fullchain.pem -noout -dates`

### Port 9443 not accessible

**Problem**: Cannot connect to HTTPS port

**Solutions**:
1. Check if port is exposed: `docker compose ps`
2. Check firewall: `sudo ufw status` / `sudo firewall-cmd --list-all`
3. Check container logs: `docker compose logs server`

### Permission denied reading certificate

**Problem**: Authentik cannot read certificate files

**Solutions**:
```bash
# Fix permissions
chmod 644 certs/fullchain.pem
chmod 600 certs/privkey.pem

# Or run as root in container (already configured in docker-compose.yml)
```

### Electron app still refuses connection

**Problem**: Electron app won't connect even with valid certificate

**Solutions**:
1. Ensure you're using HTTPS, not HTTP
2. Check Electron app's certificate validation settings
3. For development: `app.commandLine.appendSwitch('ignore-certificate-errors', 'true')`
4. Verify certificate chain is complete: `openssl s_client -connect your-domain:9443 -showcerts`

---

## Security Best Practices

1. **Use strong certificates**: 2048-bit or higher
2. **Keep certificates updated**: Set up auto-renewal
3. **Use a reverse proxy**: For better security and flexibility
4. **Monitor expiration**: Set alerts for certificate expiration
5. **Use HSTS**: Enable HTTP Strict Transport Security headers
6. **Test certificate**: Use SSL Labs test: https://www.ssllabs.com/ssltest/

---

## File Structure After SSL Setup

```
.
├── docker-compose.yml
├── certs/
│   ├── privkey.pem          # Private key (600 permissions)
│   ├── fullchain.pem        # Full certificate chain
│   ├── chain.pem            # CA chain only (optional)
│   └── dhparam.pem          # DH parameters (optional)
├── ssl-setup.sh             # Setup script
└── SSL-SETUP.md            # This file
```

---

## Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)
- [Authentik Documentation](https://docs.goauthentik.io/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Traefik TLS Documentation](https://doc.traefik.io/traefik/https/tls/)
