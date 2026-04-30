const express = require('express');
const router = express.Router();
const Circle = require('../models/Circle');
const User = require('../models/User');
const { requireAuth } = require('../middleware/auth');

// Create Circle
router.post('/create', requireAuth, async (req, res) => {
  const { name } = req.body;
  const userId = req.userId; // Extracted from token
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
    
    // Add circle to user
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

// Get User Circles (My Circles)
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

module.exports = router;
