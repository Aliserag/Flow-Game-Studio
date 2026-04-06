import { defineConfig } from "vite"

export default defineConfig({
  // Vite plain TypeScript app — no framework needed for this demo
  build: {
    outDir: "dist",
    target: "es2020",
  },
  server: {
    port: 3000,
  },
  // ethers and FCL ship CommonJS — tell Vite to pre-bundle them
  optimizeDeps: {
    include: ["ethers", "@onflow/fcl"],
  },
  define: {
    // FCL uses global in some internal paths
    global: "globalThis",
  },
})
