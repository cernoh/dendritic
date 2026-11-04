// pi-auto-router's time rules use the Pi process's local clock; OpenCode Go's
// DeepSeek peak schedule is UTC. Load this before pi-auto-router so its policy
// rules follow the provider's published UTC windows, including UK daylight time.
export default function () {
  process.env.TZ = "UTC";
}
