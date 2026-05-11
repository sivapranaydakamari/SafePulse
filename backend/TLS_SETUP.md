# TLS Setup for SafePulse API Gateway

SafePulse's Node.js process listens on HTTP. TLS termination is handled by an
nginx reverse proxy sitting in front of it. The Node process is never exposed
directly on port 443.

## Recommended nginx configuration

```nginx
server {
    listen 80;
    server_name api.safepulse.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.safepulse.example.com;

    ssl_certificate     /etc/letsencrypt/live/api.safepulse.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.safepulse.example.com/privkey.pem;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # HSTS — instruct browsers to always use HTTPS for this domain
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    location / {
        proxy_pass         http://127.0.0.1:5000;
        proxy_http_version 1.1;

        # Required for WebSocket upgrade (/ws/tracking)
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";

        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

## Certificate provisioning

Use [Certbot](https://certbot.eff.org/) with the nginx plugin:

```bash
certbot --nginx -d api.safepulse.example.com
```

Certificates auto-renew via the certbot systemd timer. Verify with:

```bash
certbot renew --dry-run
```

## Notes

- Replace `api.safepulse.example.com` with your actual domain.
- The `Upgrade` / `Connection` headers are required to proxy WebSocket
  connections for the `/ws/tracking` real-time hub.
- Node's `helmet()` middleware sets additional security headers (CSP, X-Frame-Options,
  etc.) on responses after the proxy forwards them.
