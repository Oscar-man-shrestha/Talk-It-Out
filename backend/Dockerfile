# Multi-stage build: compile with dev deps, ship production deps only.
# node:22-slim (glibc) is used instead of alpine so argon2's prebuilt
# binaries install and run without a musl toolchain.
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node migrations ./migrations
# Run as the unprivileged image user, never root.
USER node
EXPOSE 3000
# Liveness inside the container: curl/wget are absent on slim, node's fetch is not.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
# Migrations are NEVER run automatically on start; run them explicitly with:
#   docker run --rm <image> node dist/migrate-cli.js
CMD ["node", "dist/server.js"]
