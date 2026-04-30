const express = require('express');
const router = express.Router();
const axios = require('axios');


// Returns India-focused location suggestions using Nominatim.
router.get('/search', async (req, res) => {
  const { q } = req.query;
  if (!q || q.trim().length < 3) {
    return res.status(400).json({ error: 'Search query must be at least 3 characters' });
  }

  try {
    const url = 'https://nominatim.openstreetmap.org/search';
    const params = {
      q: q,
      format: 'json',
      addressdetails: 1,
      limit: 8,
      countrycodes: 'in',
      viewbox: '68.176645,37.090240,97.402561,6.554607',
      bounded: 1 
    };

    const response = await axios.get(url, {
      params,
      headers: {
        'User-Agent': 'SafePulse/2.0' 
      }
    });

    const results = response.data.map(item => ({
      displayName: item.display_name,
      lat: parseFloat(item.lat),
      lng: parseFloat(item.lon),
      address: item.address
    }));

    res.json(results);
  } catch (error) {
    console.error('[PLACES] Search error:', error.message);
    res.status(500).json({ error: 'Failed to fetch location suggestions' });
  }
});

module.exports = router;
