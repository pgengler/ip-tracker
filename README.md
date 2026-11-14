# ip-tracker

This is a small Sinatra app to keep track of IP addresses for remote systems. Basically it's useful if you have one or more computers that could end up changing their IP address and you want to know what the latest it. It's sort of a poor-man's dynamic DNS.

## Updating
Make a POST request to `/ip/<host>`, where <host> is the name of the machine you want to record. (I use the system's hostname but this can be anything.) You don't need to give any POST parameters; the IP address is obtained from the `REMOTE_ADDR` environment variable.

I have a cron entry set up to update the IP for a host every 15 minutes:

    */15 *    *       *       *       POST http://<server>/ip/`hostname` </dev/null >/dev/null
    @reboot                           POST http://<server>/ip/`hostname` </dev/null >/dev/null

## Viewing
By default, the index page shows you the IP address of the computer you're connecting from, and doesn't record this.

You can see the saved IP for a machine by visiting `/ip/<host>`, which will tell you the last recorded IP and when it was recorded. (You can use `/ip/<host>.txt` to get just the IP address in plain-text.)

## Notes
There's no authentication, so there's nothing to stop someone from adding their hosts or overwriting yours. This is meant to be for personal use only and this arrangement suits me just fine. (You could probably configure your web server to require HTTP authentication to be able to access this app, if you so desired.)

## Deployment
The app is deployed with [Kamal](https://kamal-deploy.org) as a Docker container on `hyperion.pgengler.net`, served at `https://ip.pgengler.net`.

Architecture:

```
nginx (SSL termination)
  -> kamal-proxy (shared, port 8081)
    -> Puma container (port 3000)
      -> postgres16 Docker container (shared PostgreSQL 16)
```

- **nginx** terminates SSL and proxies requests for `ip.pgengler.net` to `127.0.0.1:8081`.
- **kamal-proxy** is shared with the other apps on the server, runs on port `8081`, routes by `Host` header, and manages zero-downtime deploys.
- **Puma** runs inside the app container on port `3000`. `bin/docker-entrypoint` runs `rake db:migrate` before starting the server.
- **PostgreSQL 16** runs in the `postgres16` Docker container on the shared `kamal` Docker network (reachable by container name on port 5432). The `ip_tracker` role and `ip_tracker_production` database live alongside the other apps' databases inside it.

### Prerequisites

#### 1. Container registry access
The image is pushed to GitHub Container Registry (ghcr.io). You need a GitHub Personal Access Token with `write:packages` scope, available as `KAMAL_REGISTRY_PASSWORD`. The `.kamal/secrets` file resolves it from 1Password (`op read "op://Private/ghcr.io token/credential"`); if you don't use 1Password, export it yourself:

```bash
export KAMAL_REGISTRY_PASSWORD=<your GitHub PAT>
```

#### 2. SSH access
Your SSH key must be authorized for the `apps` user on `hyperion.pgengler.net`:

```bash
ssh-copy-id apps@hyperion.pgengler.net
```

#### 3. Database role and database
The `ip_tracker` role and `ip_tracker_production` database must exist inside the `postgres16` container (the container's default superuser is `postgres`):

```bash
ssh apps@hyperion.pgengler.net
docker exec -i postgres16 psql -U postgres -c "CREATE USER ip_tracker WITH PASSWORD '<password>';"
docker exec -i postgres16 psql -U postgres -c "CREATE DATABASE ip_tracker_production OWNER ip_tracker;"
```

The password must be available locally as `POSTGRES_PASSWORD` when deploying:

```bash
export POSTGRES_PASSWORD=<password>
```

#### 4. kamal-proxy
kamal-proxy must be running on port `8081` (not the default 80/443). Other apps on the server already share it, so it should be. If not:

```bash
bundle exec kamal proxy boot_config set --http-port 8081 --https-port 8443
bundle exec kamal proxy reboot
```

#### 5. nginx
nginx terminates SSL and proxies to kamal-proxy. A typical server block:

```nginx
server {
    listen 443 ssl;
    server_name ip.pgengler.net;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Important:** the app reads the client IP from Cloudflare's `CF-Connecting-IP` header, then the first entry of `X-Forwarded-For`, then `REMOTE_ADDR`. nginx forwards `CF-Connecting-IP` by default; don't override or clear it. If neither header reaches the app, every recorded IP will be the proxy's address. DNS for `ip.pgengler.net` must point at the server.

### First-time setup

```bash
export POSTGRES_PASSWORD=<postgres ip_tracker user password>
bundle exec kamal setup
```

`kamal setup` installs Docker on the server if needed, boots kamal-proxy, builds and pushes the image to ghcr.io, pulls it on the server, and starts the container (running `rake db:migrate` first via the entrypoint).

### Deploying a new version

```bash
export POSTGRES_PASSWORD=<postgres ip_tracker user password>
bundle exec kamal deploy
```

Kamal does a zero-downtime deploy: it boots the new container, health-checks it via `/up`, then switches traffic and drains the old container.

### Common commands

```bash
bundle exec kamal app logs -f                  # app logs (live)
bundle exec kamal app exec 'rake db:migrate:status'  # run a command in the app container
bundle exec kamal app rollback                 # roll back to the previous version
bundle exec kamal details                      # proxy + app details
bundle exec kamal proxy logs                   # kamal-proxy logs
bundle exec kamal config                       # show the resolved deploy config
```

### Troubleshooting

- **Container won't start / unhealthy:** `bundle exec kamal app logs`. The health check hits `/up` on the app; it returns `200 ok` for any `Host` header. Also verify the `postgres16` container is running and the `ip_tracker` role can connect:
  ```bash
  ssh apps@hyperion.pgengler.net docker exec -i postgres16 pg_isready -U ip_tracker -d ip_tracker_production
  ```
- **403 "Host not permitted":** Sinatra only permits `Host` headers for `ip.pgengler.net`, `localhost`, and `127.0.0.1` (plus anything in the `PERMITTED_HOSTS` env var, comma-separated). `/up` is exempt.
- **Wrong IPs recorded:** make sure nginx sends `X-Forwarded-For` (see the server block above) and kamal-proxy has `forward_headers: true` (set in `config/deploy.yml`).
- **Proxy issues:** `bundle exec kamal proxy logs` / `bundle exec kamal proxy boot`.
