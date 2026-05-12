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

      // FUTURE_SCOPE: WEATHER RISK - fully implemented
      // Multipliers: storm=2.0x, fog=1.5x, rain=1.2x, clear=1.0x
      let weatherRiskFactor = 1.0;
      if (condition === 'Thunderstorm') weatherRiskFactor = 2.0;
      else if (condition === 'Fog')     weatherRiskFactor = 1.5;
      else if (['Rain', 'Shower', 'Drizzle'].includes(condition)) weatherRiskFactor = 1.2;

      return { condition, severity, weatherRiskFactor };
    } catch (err) {
      console.error('[WeatherService] getWeatherRisk failed:', err.message);
      return null;
    }
  }

  async getTrafficRisk(lat, lon) {
    // Uses Open-Meteo hourly wind speed as a traffic-risk proxy (free, no key).
    // Returns a 0–100 severity score; higher = more hazardous driving conditions.
    try {
      const url =
        `https://api.open-meteo.com/v1/forecast` +
        `?latitude=${lat}&longitude=${lon}` +
        `&current=windspeed_10m,precipitation,visibility&forecast_days=1`;
      const { data } = await axios.get(url, { timeout: 5000 });
      const { windspeed_10m: wind = 0, precipitation = 0 } = data.current ?? {};

      let severity = 0;
      if (wind > 80)         severity = Math.min(100, severity + 40);
      else if (wind > 50)    severity = Math.min(100, severity + 20);
      else if (wind > 30)    severity = Math.min(100, severity + 10);

      if (precipitation > 10) severity = Math.min(100, severity + 30);
      else if (precipitation > 5) severity = Math.min(100, severity + 15);
      else if (precipitation > 1) severity = Math.min(100, severity + 5);

      return { severity, wind, precipitation };
    } catch (err) {
      console.error('[WeatherService] getTrafficRisk failed:', err.message);
      return null;
    }
  }
}
module.exports = new TrafficWeatherService();
