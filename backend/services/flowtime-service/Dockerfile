FROM node:18-alpine

WORKDIR /app

RUN apk add --no-cache curl

# Install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy source code
COPY . .

EXPOSE 3000

CMD ["node", "src/index.js"]