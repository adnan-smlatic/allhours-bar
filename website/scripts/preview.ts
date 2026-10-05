// Serves the static export in ./out exactly as a static host would, then opens it.
// Usage: bun run build && bun run preview   (PORT=… to change the port)
import { existsSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dir, "..", "out");
if (!existsSync(join(root, "index.html"))) {
  console.error("No build found in ./out. Run `bun run build` first.");
  process.exit(1);
}

function resolveFile(pathname: string): string | undefined {
  const target = resolve(root, "." + decodeURIComponent(pathname));
  if (!target.startsWith(root)) return undefined; // no escaping ./out
  for (const candidate of [target, join(target, "index.html"), `${target}.html`]) {
    if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  }
}

const server = Bun.serve({
  port: Number(process.env.PORT ?? 4173),
  fetch(request) {
    const file = resolveFile(new URL(request.url).pathname);
    return file
      ? new Response(Bun.file(file))
      : new Response(Bun.file(join(root, "404.html")), { status: 404, headers: { "Content-Type": "text/html" } });
  },
});

const url = `http://localhost:${server.port}/`;
console.log(`Serving ./out at ${url}  (Ctrl+C to stop)`);
if (process.platform === "darwin" && !process.env.CI) Bun.spawn(["open", url]);
