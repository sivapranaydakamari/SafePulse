// SafePulse Problem Gap #4: safety-scored route recommendations backed by incident data.
/**
 * Scores candidate routes against risk zones supplied by the repository layer.
 * The scoring logic is deterministic and pure; data can come from MongoDB,
 * seed JSON, or future external incident feeds.
 */
const trafficWeather = require('./traffic_weather_service');
// TODO (future scope): const weatherRisk = await trafficWeather.getWeatherRisk(lat, lng);
// Incorporate weatherRisk.severity into riskScore when implemented.

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = d => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function pointRiskScore(lat, lng, riskZones = []) {
  let maxScore = 0;

  for (const zone of riskZones) {
    const dist = haversineMeters(lat, lng, zone.lat, zone.lng);
    if (dist <= zone.radiusM) {
      const proximity = 1 - dist / zone.radiusM;
      const contribution = zone.severity * proximity;
      if (contribution > maxScore) maxScore = contribution;
    }
  }

  return maxScore;
}

function routeRiskScore(polylinePoints, riskZones = [], samples = 20) {
  if (!polylinePoints || polylinePoints.length === 0) return 0;

  const step = Math.max(1, Math.floor(polylinePoints.length / samples));
  let totalRisk = 0;
  let count = 0;

  for (let i = 0; i < polylinePoints.length; i += step) {
    const [lat, lng] = polylinePoints[i];
    totalRisk += pointRiskScore(lat, lng, riskZones);
    count++;
  }

  return Math.round(totalRisk / count);
}

function riskLabel(score) {
  if (score <= 30) return { type: 'SAFEST', color: 'green', label: 'Safest' };
  if (score <= 65) return { type: 'BALANCED', color: 'yellow', label: 'Balanced' };
  return { type: 'RISKY', color: 'red', label: 'Risky' };
}

// Rank-index labels guarantee uniqueness regardless of clustered scores.
const RANK_LABELS  = ['SAFEST',  'BALANCED', 'RISKY'];
const RANK_COLORS  = ['green',   'yellow',   'red'];
const RANK_DISPLAY = ['Safest',  'Balanced', 'Risky'];

// SafePulse Problem Gap #4: weather multiplier raises risk scores when conditions are adverse.
async function scoreRoutesWithWeather(routes, riskZones = [], centerLat = null, centerLng = null) {
  let riskMultiplier = 1.0;
  if (centerLat !== null && centerLng !== null) {
    try {
      const weather = await trafficWeather.getWeatherRisk(centerLat, centerLng);
      if (weather && weather.severity > 0) {
        riskMultiplier = 1 + (weather.severity / 200); // max +50% at severity=100
      }
    } catch (_) {}
  }

  const scored = routes.map(route => ({
    ...route,
    riskScore: Math.min(100, Math.round(routeRiskScore(route.polyline, riskZones) * riskMultiplier)),
  }));

  scored.sort((a, b) => a.riskScore - b.riskScore);

  return scored.slice(0, 3).map((route, index) => ({
    ...route,
    riskLabel: RANK_LABELS[index],
    type:       RANK_LABELS[index],
    color:      RANK_COLORS[index],
    label:      RANK_DISPLAY[index],
  }));
}

// Only real OSRM routes are returned; no synthetic variants are fabricated.
function scoreRoutes(routes, riskZones = []) {
  const scored = routes.map(route => ({
    ...route,
    riskScore: routeRiskScore(route.polyline, riskZones),
  }));

  scored.sort((a, b) => a.riskScore - b.riskScore);

  return scored.slice(0, 3).map((route, index) => ({
    ...route,
    riskLabel: RANK_LABELS[index],
    type:       RANK_LABELS[index],
    color:      RANK_COLORS[index],
    label:      RANK_DISPLAY[index],
  }));
}

module.exports = {
  haversineMeters,
  pointRiskScore,
  riskLabel,
  routeRiskScore,
  scoreRoutes,
  scoreRoutesWithWeather,
};
