FROM node:24.19.0-bookworm-slim

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY protocol.js relay.js store.js ./

ENV HOST=0.0.0.0 PORT=8080 DATA_DIR=/data
EXPOSE 8080
CMD ["npm", "start"]
