const { CrimeDataService } = require('./crime_data_service');

class RouteScoring {
  constructor() {
    this.crimeService = new CrimeDataService();
  }

  async scoreRoutes(routes) {
    const scoredRoutes = [];
    let rank = 1;

    for (const route of routes) {
      // Downsample points to avoid massive DB queries
      const MAX_SAMPLES = 20;
      let sampledPoints = route.points;
      if (route.points.length > MAX_SAMPLES) {
        const step = Math.ceil(route.points.length / MAX_SAMPLES);
        sampledPoints = route.points.filter((_, i) => i % step === 0);
      }
      
      const analysis = await this.crimeService.analyzeRoute(sampledPoints);
      
      const safetyScore = analysis.safetyScore !== undefined ? analysis.safetyScore : 50;
      const riskScore = analysis.averageRisk !== undefined ? analysis.averageRisk : 50;
      const safetyLevel = analysis.overallLevel || 'moderate';
      
      scoredRoutes.push({
        ...route,
        routeId: route.id,
        rank: rank++,
        recommended: rank === 1,
        safetyScore: safetyScore,
        safetyLevel: safetyLevel,
        riskScore: riskScore,
        breakdown: {
          maxRisk: analysis.maxRisk || 0,
          highRiskSegments: analysis.highRiskSegments ? analysis.highRiskSegments.length : 0
        },
        warnings: (analysis.highRiskSegments || []).map(seg => ({
          type: 'high_risk_area',
          severity: 'high',
          message: `High risk area detected on route`
        })),
        recommendations: rank === 1 ? [{
          priority: 'high',
          message: 'This is the safest route',
          reason: 'Lowest average risk score'
        }] : []
      });
    }

    // Sort by safetyScore descending (highest is safest)
    scoredRoutes.sort((a, b) => b.safetyScore - a.safetyScore);

    // Update ranks after sorting
    scoredRoutes.forEach((route, index) => {
      route.rank = index + 1;
      route.recommended = index === 0;
    });

    return scoredRoutes;
  }
}

module.exports = { RouteScoring };
