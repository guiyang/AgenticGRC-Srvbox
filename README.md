# Authentik Docker Compose Deployment

Production-ready Docker Compose configuration for [Authentik](https://goauthentik.io/), an open-source Identity Provider focused on flexibility and versatility.

## About Authentik

Authentik is a modern authentication and authorization solution that provides:
- **Single Sign-On (SSO)** across multiple applications
- **Multi-Factor Authentication (MFA)** with TOTP, WebAuthn, and more
- **Protocol Support**: OAuth2, OpenID Connect (OIDC), SAML, LDAP
- **User Federation** with external identity providers
- **Access Control** with fine-grained policies
- **Web-based Administration** interface

## Architecture

This deployment consists of four services:

| Service | Description |
|---------|-------------|
| **PostgreSQL** | Primary database for all configuration and user data |
| **Redis** | Cache layer for improved performance |
| **Server** | Main Authentik server handling HTTP(S), API, SSO requests |
| **Worker** | Background task processor (emails, notifications, etc.) |

## Requirements

- **Docker** Engine 20.10 or later
- **Docker Compose** v2 (see [upgrade instructions](https://docs.docker.com/compose/install/))
- **Hardware**: Minimum 2 CPU cores, 2GB RAM (4GB+ recommended for production)
- **Disk**: 10GB+ free space for database and media files

## Quick Start

### 1. Clone or Copy This Configuration

```bash
# Copy all files to your deployment directory
cd /path/to/deployment
```

### 2. Generate Secrets

Generate secure random values for the database password and secret key:

```bash
# Generate PostgreSQL password
echo "PG_PASS=$(openssl rand -base64 36 | tr -d '\n')" >> .env

# Generate Authentik secret key
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')" >> .env
```

### 3. Configure Environment

Copy the example environment file and customize it:

```bash
cp .env.example .env
# Edit .env with your preferred editor
nano .env
```

**Required minimum configuration in `.env`:**
- `PG_PASS`: Database password (use the generated value)
- `AUTHENTIK_SECRET_KEY`: Secret key (use the generated value)

**Recommended configuration:**
- Email settings for password recovery and notifications
- Custom ports if needed (default: 9000 for HTTP, 9443 for HTTPS)

### 4. Create Required Directories

```bash
mkdir -p media custom-templates geoip
```

### 5. Start Authentik

```bash
# Pull the latest images
docker compose pull

# Start all services
docker compose up -d

# View logs (optional)
docker compose logs -f worker
```

First startup may take 3-4 minutes as the database is initialized.

### 6. Complete Initial Setup

Navigate to the initial setup URL:

```
http://your-server-ip:9000/if/flow/initial-setup/
```

**Note**: The trailing slash `/` is required.

You will be prompted to create the admin user password for the default `akadmin` account.

## SSL/TLS Configuration

**IMPORTANT**: For Electron desktop applications and production use, you must configure SSL/TLS certificates.

### Quick SSL Setup

Use the interactive setup script:

```bash
./ssl-setup.sh
```

The script supports:
- Self-signed certificates (for testing)
- Let's Encrypt certificates (for production)
- Custom certificates (your own CA/commercial certs)

### Manual SSL Configuration

For detailed SSL setup instructions, including reverse proxy configuration with Nginx or Traefik, see [SSL-SETUP.md](SSL-SETUP.md).

### Basic Direct SSL (Authentik on port 9443)

1. Place certificates in the `certs/` directory:
   - `certs/privkey.pem` - Private key
   - `certs/fullchain.pem` - Certificate chain

2. Uncomment SSL environment variables in [docker-compose.yml](docker-compose.yml):

```yaml
server:
  environment:
    AUTHENTIK_SSL_CERTIFICATE: /certs/fullchain.pem
    AUTHENTIK_SSL_KEY: /certs/privkey.pem
```

3. Restart and access via HTTPS:
   ```bash
   docker compose restart server
   # Access: https://your-server:9443/if/flow/initial-setup/
   ```

### Electron Desktop App Compatibility

Electron applications require HTTPS for secure OAuth/OIDC flows. Configure SSL using one of these methods:

1. **Let's Encrypt with Reverse Proxy** (Recommended)
   - See [SSL-SETUP.md](SSL-SETUP.md) for Nginx/Traefik setup
   - Provides trusted certificates automatically renewed

2. **Direct SSL on Authentik**
   - Use Let's Encrypt or commercial certificate
   - Self-signed certs require trust store configuration

3. **Development Only** - Self-signed certificate:
   ```bash
   ./ssl-setup.sh  # Choose option 1
   ```
   Then add the certificate to your system trust store (see [SSL-SETUP.md](SSL-SETUP.md)).

## Production Considerations

### Security Best Practices

1. **Use strong, unique secrets** - Generate with `openssl rand -base64 60`
2. **Enable HTTPS** - Use a reverse proxy (Traefik, Nginx) with SSL/TLS
3. **Restrict network access** - Use firewall rules to limit access
4. **Regular backups** - Backup the PostgreSQL volume regularly
5. **Keep updated** - Subscribe to Authentik release announcements

### Reverse Proxy Configuration

For production deployments, place Authentik behind a reverse proxy:

**Traefik Example:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.authentik.rule=Host(`authentik.example.com`)"
  - "traefik.http.routers.authentik.entrypoints=websecure"
  - "traefik.http.routers.authentik.tls.certresolver=letsencrypt"
  - "traefik.http.services.authentik.loadbalancer.server.port=9000"
```

**Nginx Example:**
```nginx
location / {
    proxy_pass http://localhost:9000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Backup Strategy

Backup the PostgreSQL volume:

```bash
# Create backup
docker compose exec postgresql pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql

# Backup media files
tar -czf media-backup-$(date +%Y%m%d).tar.gz media/
```

### Resource Limits

Default resource limits are configured in `docker-compose.yml`:

- **PostgreSQL**: 512MB memory, 1 CPU
- **Redis**: 256MB memory, 0.5 CPU
- **Server/Worker**: 1GB memory, 2 CPUs each

Adjust based on your load and available resources.

### Docker Socket Security

By default, the Docker socket is mounted to the worker for automatic outpost management. For enhanced security:

1. **Remove the socket mount** if not using outposts
2. **Use a Docker Socket Proxy** (see `docker-compose.socket-proxy.yml`)

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PG_DB` | `authentik` | PostgreSQL database name |
| `PG_USER` | `authentik` | PostgreSQL user |
| `PG_PASS` | *required* | PostgreSQL password |
| `AUTHENTIK_SECRET_KEY` | *required* | Cryptographic signing key |
| `COMPOSE_PORT_HTTP` | `9000` | HTTP port |
| `COMPOSE_PORT_HTTPS` | `9443` | HTTPS port |
| `AUTHENTIK_LOG_LEVEL` | `info` | Logging verbosity |
| `AUTHENTIK_EMAIL__*` | - | Email configuration |

### Volumes

| Volume | Purpose |
|--------|---------|
| `pg_data` | PostgreSQL database persistence |
| `./media` | User-uploaded media files |
| `./custom-templates` | Custom UI templates |
| `./geoip` | MaxMind GeoIP databases |
| `./certs` | Custom SSL certificates |

## Maintenance

### Upgrading Authentik

1. **Check release notes** for breaking changes
2. **Update the version tag** in `.env`:
   ```
   AUTHENTIK_TAG=2025.10.4
   ```
3. **Pull new images**:
   ```bash
   docker compose pull
   ```
4. **Restart services**:
   ```bash
   docker compose up -d
   ```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f server
docker compose logs -f worker
```

### Database Management

```bash
# Access PostgreSQL shell
docker compose exec postgresql psql -U authentik -d authentik

# Create database backup
docker compose exec postgresql pg_dump -U authentik authentik > backup.sql

# Restore database
docker compose exec -T postgresql psql -U authentik authentik < backup.sql
```

## Troubleshooting

### Common Issues

**Service won't start:**
- Check logs: `docker compose logs worker`
- Verify database password in `.env` matches generated secret
- Ensure ports are not already in use

**Initial setup page not accessible:**
- Verify trailing slash in URL: `.../initial-setup/`
- Check firewall allows port 9000
- Review server logs for errors

**Email not working:**
- Verify SMTP settings in `.env`
- Check email provider allows relays from your IP
- Test with `AUTHENTIK_LOG_LEVEL=debug`

### Health Checks

All services include health checks. View status:

```bash
docker compose ps
```

## Additional Resources

- [Official Documentation](https://docs.goauthentik.io/)
- [Docker Compose Installation Guide](https://docs.goauthentik.io/install-config/install/docker-compose/)
- [SSL/TLS Configuration Guide](SSL-SETUP.md) - Comprehensive SSL certificate setup
- [GitHub Repository](https://github.com/goauthentik/authentik)
- [Community Forum](https://goauthentik.io/discord)

## License

This Docker Compose configuration is provided as-is for deployment of Authentik, which is licensed under the [MIT License](https://github.com/goauthentik/authentik/blob/main/LICENSE).
