// PM2 Ecosystem Config — SafePulse Services
// Usage: pm2 start ecosystem.config.js --env production
module.exports = {
  apps: [
    {
      name: 'safepulse-proxy-gateway',
      script: './gateway/index.js',
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      env: {
        NODE_ENV: 'development',
        GATEWAY_PORT: 3000,
        BACKEND_URL: 'http://localhost:3001',
        SPRINGBOOT_URL: 'http://localhost:8080',
        AI_SERVICE_URL: 'http://localhost:8000',
      },
      env_production: {
        NODE_ENV: 'production',
        GATEWAY_PORT: 3000,
        BACKEND_URL: 'http://localhost:3001',
        SPRINGBOOT_URL: 'http://localhost:8080',
        AI_SERVICE_URL: 'http://localhost:8000',
      },
    },
    {
      name: 'safepulse-gateway',
      script: './index.js',
      instances: 'max',
      exec_mode: 'cluster',
      watch: false,
      env: {
        NODE_ENV: 'development',
        PORT: 3001,
        USE_HTTPS: 'false',
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3001,
        USE_HTTPS: 'false',
      },
    },
  ],
};
