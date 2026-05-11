// PM2 Ecosystem Config — SafePulse API Gateway
// Enables Node.js cluster mode for load balancing across CPU cores.
// Usage: pm2 start ecosystem.config.js --env production
module.exports = {
  apps: [
    {
      name: 'safepulse-gateway',
      script: './index.js',
      instances: 'max',       // cluster across all available CPU cores
      exec_mode: 'cluster',
      watch: false,
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
        USE_HTTPS: 'false',
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
        USE_HTTPS: 'true',
        HTTPS_PORT: 443,
      },
    },
  ],
};
