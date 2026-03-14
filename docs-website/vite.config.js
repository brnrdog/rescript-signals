import { defineConfig } from "vite"

export default defineConfig({
  base: "/rescript-signals/",
  build: {
    outDir: "build/client",
    emptyOutDir: true,
  },
  server: {
    port: 3000,
  },
})
