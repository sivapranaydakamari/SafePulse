// FUTURE_SCOPE: COMMUNITY REPORTING - fully implemented
/**
 * Jest tests for POST /api/community/report and GET /api/community/reports.
 * Uses supertest against the Express app with a mocked CommunityReport model.
 */
'use strict';

const request = require('supertest');

// ── Mock MongoDB model before requiring the app ──────────────────────────────
jest.mock('../models/CommunityReport', () => {
  const saved = [];
  const Model = {
    create: jest.fn(async (data) => {
      const doc = { _id: 'report-001', ...data };
      saved.push(doc);
      return doc;
    }),
    find: jest.fn(() => ({
      select: () => ({
        limit: () => ({
          lean: async () => saved.filter(r => !r.resolved),
        }),
      }),
    })),
  };
  return Model;
});

// ── Auth middleware stub ──────────────────────────────────────────────────────
jest.mock('../middleware/auth', () => ({
  requireAuth: (req, _res, next) => { req.userId = 'user-abc'; next(); },
}));

const app = require('../index');
const CommunityReport = require('../models/CommunityReport');

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('POST /api/community/report', () => {
  beforeEach(() => jest.clearAllMocks());

  it('creates a hazard report and returns 201', async () => {
    const res = await request(app)
      .post('/api/community/report')
      .send({ latitude: 17.385, longitude: 78.487, hazardType: 'accident' });

    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.reportId).toBeDefined();
    expect(CommunityReport.create).toHaveBeenCalledTimes(1);
  });

  it('returns 400 when hazardType is missing', async () => {
    const res = await request(app)
      .post('/api/community/report')
      .send({ latitude: 17.385, longitude: 78.487 });

    expect(res.statusCode).toBe(400);
  });

  it('returns 400 for an invalid hazardType', async () => {
    const res = await request(app)
      .post('/api/community/report')
      .send({ latitude: 17.385, longitude: 78.487, hazardType: 'unknown' });

    expect(res.statusCode).toBe(400);
  });

  it('assigns correct severity for each hazard type', async () => {
    const cases = [
      { hazardType: 'accident',   expectedSeverity: 80 },
      { hazardType: 'hazard',     expectedSeverity: 50 },
      { hazardType: 'roadblock',  expectedSeverity: 30 },
    ];

    for (const { hazardType, expectedSeverity } of cases) {
      CommunityReport.create.mockClear();
      await request(app)
        .post('/api/community/report')
        .send({ latitude: 17.0, longitude: 78.0, hazardType });
      expect(CommunityReport.create).toHaveBeenCalledWith(
        expect.objectContaining({ severity: expectedSeverity }),
      );
    }
  });
});

describe('GET /api/community/reports', () => {
  it('returns 200 with reports array', async () => {
    const res = await request(app)
      .get('/api/community/reports')
      .query({ lat: 17.385, lng: 78.487 });

    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.reports)).toBe(true);
  });

  it('returns 400 when lat/lng are missing', async () => {
    const res = await request(app).get('/api/community/reports');
    expect(res.statusCode).toBe(400);
  });
});
