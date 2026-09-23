# Child image for the wayfinder-dashboard feature: stock Deno plus the
# dashboard server. Rebuilds when server.ts changes (the systemd unit tags the
# image with this directory as its build label and rebuilds on mismatch).
#
#   docker rmi wayfinder-dashboard
#   sudo systemctl restart wayfinder-dashboard-image docker-wayfinder-dashboard
FROM denoland/deno:2

WORKDIR /app
COPY deno.json server.ts ./

EXPOSE 8787

# Least privilege: net (serve + bridge proxy), read/write (history under
# /data), env (PORT, DATA_ROOT). No run permissions beyond the server.
CMD ["run", "--allow-net", "--allow-read", "--allow-write", "--allow-env", "server.ts"]
