# Child image for the paseo feature: the official daemon image plus the agent
# CLIs the daemon spawns. The official image ships none of them.
#
# The `paseo-image` systemd unit in the parent directory passes this directory
# as the build context and tags the result `paseo-with-agents`. It rebuilds
# when this file changes. To pick up a new upstream base image, pull it and
# rebuild by hand:
#
#   docker pull ghcr.io/getpaseo/paseo:latest
#   docker rmi paseo-with-agents
#   sudo systemctl restart paseo-image docker-paseo
FROM ghcr.io/getpaseo/paseo:latest

# The base entrypoint prepares the mounted volumes as root, then drops the
# daemon and every agent it launches to the non-root `paseo` user. Keep root
# as the image user.
USER root

RUN npm install -g \
  @anthropic-ai/claude-code \
  @openai/codex \
  opencode-ai
