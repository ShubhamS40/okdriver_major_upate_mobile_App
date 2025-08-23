# ---- Base Image ----
FROM node:18-alpine AS base

# Set working directory inside container
WORKDIR /usr/src/app

# Install pnpm globally
RUN npm install -g pnpm

# Copy only package.json and lockfile first (better caching)
COPY package*.json pnpm-lock.yaml* ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# ---- Copy App Files ----
COPY . .

# ---- Prisma Generate ----
# Ensure prisma schema is available before generate
RUN npx prisma generate

# ---- Expose Port ----
EXPOSE 3000

# ---- Start Command ----
CMD ["node", "index.js"]
