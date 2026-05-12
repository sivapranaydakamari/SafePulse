const axios = require('axios');

// SafePulse Problem Gap #4: safety-scored routes benefit from real-time weather.
// Open-Meteo is free, no API key required. WMO weathercode → severity mapping below.
class TrafficWeatherService {
  async getWeatherRisk(lat, lng) {
    try {
      const url =
        `https://api.open-meteo.com/v1/forecast` +
        `?latitude=${lat}&longitude=${lng}` +
        `&current=weathercode,windspeed_10m,precipitation&forecast_days=1`;
      const { data } = await axios.get(url, { timeout: 5000 });
      const { weathercode = 0, windspeed_10m: wind = 0, precipitation = 0 } = data.current ?? {};

      let severity = 0;
      let condition = 'Clear';
      if (weathercode >= 95)      { severity = 80; condition = 'Thunderstorm'; }
      else if (weathercode >= 80) { severity = 60; condition = 'Shower'; }
      else if (weathercode >= 61) { severity = 50; condition = 'Rain'; }
      else if (weathercode >= 51) { severity = 30; condition = 'Drizzle'; }
      else if (weathercode >= 45) { severity = 40; condition = 'Fog'; }
      else if (weathercode >= 1)  { severity = 10; condition = 'Cloudy'; }

      if (wind > 50)         severity = Math.min(100, severity + 20);
      if (precipitation > 5) severity = Math.min(100, severity + 15);

      return { condition, severity };
    } catch (_) {
      return null;
    }
  }

  async getTrafficRisk(polyline) {
    // FUTURE SCOPE: HERE Traffic Flow API v3
    return null;
  }
}
module.exports = new TrafficWeatherService();
