FROM node:20-alpine AS frontend-build
WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm install

COPY frontend ./
RUN npm run build

FROM node:20-alpine AS backend-build
WORKDIR /app/backend

COPY backend/package*.json ./
RUN npm install

COPY backend ./
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app

COPY --from=backend-build /app/backend ./backend
COPY --from=frontend-build /app/frontend/dist ./frontend/dist

WORKDIR /app/backend
RUN npm prune --omit=dev

ENV NODE_ENV=production
ENV PORT=8080
ENV FRONTEND_DIST=/app/frontend/dist
EXPOSE 8080

CMD ["node", "dist/server.js"]
