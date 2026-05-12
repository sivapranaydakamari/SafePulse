// FUTURE_SCOPE: COMMUNITY REPORTING - fully implemented
/**
 * MongoDB schema for crowd-sourced road hazard reports submitted by SafePulse users.
 * Reports are wired into route_scoring.js as a density-based risk factor.
 */
'use strict';

const mongoose = require('mongoose');

const communityReportSchema = new mongoose.Schema(
  {
    userId:       { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    hazardType:   { type: String, enum: ['accident', 'hazard', 'roadblock'], required: true },
    description:  { type: String, maxlength: 500 },
    latitude:     { type: Number, required: true, min: -90,  max: 90  },
    longitude:    { type: Number, required: true, min: -180, max: 180 },
    locationPoint: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: { type: [Number], default: [0, 0] },
    },
    severity:     { type: Number, default: 50, min: 0, max: 100 },
    upvotes:      { type: Number, default: 0 },
    resolved:     { type: Boolean, default: false },
  },
  { timestamps: true }
);

communityReportSchema.index({ locationPoint: '2dsphere' });
communityReportSchema.index({ createdAt: 1 }, { expireAfterSeconds: 86400 * 3 }); // auto-expire after 3 days

module.exports = mongoose.model('CommunityReport', communityReportSchema);
