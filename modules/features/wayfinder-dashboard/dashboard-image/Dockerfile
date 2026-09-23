# Child image for the wayfinder-dashboard feature: stock Deno plus the
# dashboard server. Rebuilds when server.ts changes (the systemd unit tags the
# image with this directory as its build label and rebuilds on mismatch).
#
#   docker rmi wayfinder-dashboard
#   sudo systemctl restart wayfinder-dashboard-image docker-wayfinder-dashboard
FROM denoland/deno:2

WORKDIR /app
COPY deno.json server.ts ./
# Material 3 web components, vendored at build time so the page needs no CDN
# at runtime (loopback only). Served from disk as /m3e.js.
ADD https://cdn.jsdelivr.net/npm/@m3e/web@2.8.2/dist/all.min.js ./m3e.js

EXPOSE 8787

# Least privilege: net (serve), read (server source, /proc/stat for boot
# time), write (history under /data), env (PORT, DATA_ROOT, M3_* theme).
CMD ["run", "--allow-net", "--allow-read", "--allow-write", "--allow-env", "server.ts"]
