import type { NextConfig } from "next";

// Fully static: `bun run build` writes plain HTML/CSS/JS to ./out.
// Set BASE_PATH (e.g. "/allhours-bar") when hosting under a sub-path such as GitHub Pages.
const config: NextConfig = {
  output: "export",
  basePath: process.env.BASE_PATH || undefined,
  images: { unoptimized: true },
  trailingSlash: true,
};

export default config;
