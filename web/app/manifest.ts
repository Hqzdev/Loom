import type { MetadataRoute } from "next";

/**
 * Returns installable web app metadata and icon entries.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Tether",
    short_name: "Tether",
    description:
      "Local-first trace debugging, replay, and mocking for AI agents and LLM applications on macOS.",
    start_url: "/",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#18181b",
    icons: [
      {
        src: "/icon-192.png",
        sizes: "192x192",
        type: "image/png",
      },
      {
        src: "/icon-512.png",
        sizes: "512x512",
        type: "image/png",
      },
      {
        src: "/icon-1024.png",
        sizes: "1024x1024",
        type: "image/png",
      },
    ],
  };
}
