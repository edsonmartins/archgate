# syntax=docker/dockerfile:1.7
# Build context: archguard-console/ source tree (from archguard repo).
# VITE_ARCHGUARD_ID_URL is baked into the client at build time.

ARG NODE_IMAGE=node:22-alpine

FROM ${NODE_IMAGE} AS deps
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
# package-lock may lag package.json in the ArchGuard repo; npm install is safer for lab builds
RUN npm install

FROM ${NODE_IMAGE} AS build
WORKDIR /app
ENV NODE_ENV=production
ARG VITE_ARCHGUARD_ID_URL=https://id.archgate.com.br
ENV VITE_ARCHGUARD_ID_URL=${VITE_ARCHGUARD_ID_URL}
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build
RUN npm prune --omit=dev

FROM ${NODE_IMAGE} AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0
RUN addgroup -S app && adduser -S -G app app
COPY --from=build --chown=app:app /app/package.json ./package.json
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/dist ./dist
COPY --from=build --chown=app:app /app/server ./server
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT}/ || exit 1
CMD ["node", "server/index.mjs"]
