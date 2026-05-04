const express = require('express');
const router = express.Router();
const Circle = require('../models/Circle');
const User = require('../models/User');
const { requireAuth } = require('../middleware/auth');


router.post('/create', requireAuth, async (req, res) => {
  const { name } = req.body;
  const userId = req.userId; 
  console.log(`[CIRCLE] Creating circle: ${name} for user: ${userId}`);
  
  if (!name) return res.status(400).json({ success: false, message: 'Circle name is required' });

  const inviteCode = Math.random().toString(36).substring(2, 7).toUpperCase();
  try {
    const circle = new Circle({
      name,
      owner: userId,
      members: [userId],
      inviteCode
    });
    await circle.save();
    
    
    await User.findByIdAndUpdate(userId, { $push: { circles: circle._id } });
    
    console.log(`[CIRCLE] Circle created successfully: ${circle._id} code: ${inviteCode}`);
    res.json({ success: true, circle });
  } catch (error) {
    console.error(`[CIRCLE] Create Error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Join Circle
router.post('/join', requireAuth, async (req, res) => {
  const { inviteCode } = req.body;
  const userId = req.userId;
  try {
    const circle = await Circle.findOne({ inviteCode });
    if (!circle) return res.status(404).json({ success: false, message: 'Invalid invite code' });
    
    if (circle.members.includes(userId)) {
      return res.status(400).json({ success: false, message: 'Already a member' });
    }
    
    circle.members.push(userId);
    await circle.save();
    
    await User.findByIdAndUpdate(userId, { $push: { circles: circle._id } });
    
    res.json({ success: true, circle });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});


router.get('/my', requireAuth, async (req, res) => {
  try {
    const user = await User.findById(req.userId).populate({
      path: 'circles',
      populate: { 
        path: 'members', 
        select: 'name phone batteryLevel isDriving currentSpeed location lastSeen' 
      }
    });
    res.json({ success: true, circles: user.circles || [] });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ===== NEW: Update User Location (called every 10s from Flutter app) =====
router.put('/update-location', requireAuth, async (req, res) => {
  try {
    const { lat, lng } = req.body;
    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'lat and lng are required' });
    }
    await User.findByIdAndUpdate(req.userId, {
      lastLocation: { lat, lng, updatedAt: new Date() }
    });
    res.json({ success: true });
  } catch (err) {
    console.error(`[CIRCLE] update-location error: ${err.message}`);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ===== NEW: Get Circle Members with their Locations (for Map screen) =====

router.get('/:circleId/members-location', requireAuth, async (req, res) => {
  try {
    const circle = await Circle.findById(req.params.circleId)
      .populate('members', 'name email profilePic location lastLocation');
    if (!circle) {
      return res.status(404).json({ success: false, message: 'Circle not found' });
    }
    res.json({ success: true, members: circle.members });
  } catch (err) {
    console.error(`[CIRCLE] members-location error: ${err.message}`);
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;