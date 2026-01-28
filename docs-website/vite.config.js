import { defineConfig } from "vite"

export default defineConfig({
  base: "/rescript-signals/",
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  server: {
    port: 3000,
  },
})
