FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    DISPLAY=:99

RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium xvfb git ca-certificates procps \
    && printf '#!/bin/sh\nexec /usr/bin/chromium --no-sandbox "$@"\n' > /usr/local/bin/google-chrome \
    && chmod +x /usr/local/bin/google-chrome \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/agentwebsearch
RUN git clone --depth 1 https://github.com/insung8150/AgentWebSearch-MCP.git . \
    && sed -i 's/^mcp>=1\.0\.0/mcp>=1.0.0,<2/' requirements.txt \
    && pip install --no-cache-dir -r requirements.txt \
    && sed -i '/from starlette.routing import Route/a\        from starlette.responses import Response' mcp_server.py \
    && sed -i '/await server.run(streams\[0\], streams\[1\], server.create_initialization_options())/a\            return Response()' mcp_server.py \
    && sed -i 's/host="127.0.0.1", port=port/host="0.0.0.0", port=port/' mcp_server.py

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8902
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
