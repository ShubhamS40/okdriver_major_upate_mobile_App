# -----------------------------
# Stage 1 — Build the app
# -----------------------------
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

COPY . .

# 🟢 Generate Prisma Client
RUN npx prisma generate

# -----------------------------
# Stage 2 — Run the app
# -----------------------------
FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app /app

ENV NODE_ENV=production
ENV PORT=5000
EXPOSE 5000

CMD ["node", "index.js"]
