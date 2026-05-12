// FUTURE_SCOPE: COMMUNITY REPORTING - fully implemented
/**
 * Community safety reporting endpoints.
 *
 * POST /api/community/report  — submit a hazard report (auth required)
 * GET  /api/community/reports — fetch reports near a coordinate (auth required)
 */
'use strict';

const express = require('express');
const router  = express.Router();
const CommunityReport = require('../models/CommunityReport');
const { requireAuth }  = require('../middleware/auth');

/**
 * POST /api/community/report
 * Body: { latitude, longitude, hazardType, description? }
 */
router.post('/report', requireAuth, async (req, res) => {
  const { latitude, longitude, hazardType, description } = req.body;

  if (!latitude || !longitude || !hazardType) {
    return res.status(400).json({ message: 'latitude, longitude, and hazardType are required' });
  }
  if (!['accident', 'hazard', 'roadblock'].includes(hazardType)) {
    return res.status(400).json({ message: 'hazardType must be accident, hazard, or roadblock' });
  }

  const severityMap = { accident: 80, hazard: 50, roadblock: 30 };

  try {
    const report = await CommunityReport.create({
      userId:    req.userId,
      hazardType,
      description: description ?? '',
      latitude:  Number(latitude),
      longitude: Number(longitude),
      locationPoint: { type: 'Point', coordinates: [Number(longitude), Number(latitude)] },
      severity:  severityMap[hazardType],
    });
    res.status(201).json({ success: true, reportId: report._id });
  } catch (err) {
    console.error('[CommunityReport] POST /report error:', err);
    res.status(500).json({ message: 'Failed to save report' });
  }
});

/**
 * GET /api/community/reports?lat=&lng=&radiusKm=
 * Returns reports within radiusKm of the given coordinate (default 5 km).
 */
router.get('/reports', requireAuth, async (req, res) => {
  const { lat, lng, radiusKm = '5' } = req.query;
  if (!lat || !lng) {
    return res.status(400).json({ message: 'lat and lng query params are required' });
  }
  const radiusM = parseFloat(radiusKm) * 1000;
  try {
    const reports = await CommunityReport.find({
      locationPoint: {
        $near: {
          $geometry: { type: 'Point', coordinates: [Number(lng), Number(lat)] },
          $maxDistance: radiusM,
        },
      },
      resolved: false,
    })
      .select('-__v -userId')
      .limit(50)
      .lean();

    res.json({ success: true, reports });
  } catch (err) {
    console.error('[CommunityReport] GET /reports error:', err);
    res.status(500).json({ message: 'Failed to fetch reports' });
  }
});

module.exports = router;
