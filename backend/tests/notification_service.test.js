jest.mock('firebase-admin');
jest.mock('twilio', () => () => ({}));

const {
  sendSMS,
  sendPushNotification,
  sendToUser,
  broadcastToCircle,
  isFcmReady,
} = require('../services/notification_service');

describe('Notification Service', () => {
  describe('isFcmReady', () => {
    it('returns false when FIREBASE_SERVICE_ACCOUNT_PATH is not configured', () => {
      expect(isFcmReady()).toBe(false);
    });
  });

  describe('sendPushNotification', () => {
    it('returns skipped result when tokens array is empty', async () => {
      const result = await sendPushNotification([], 'SOS Alert', 'User needs help');
      expect(result).toMatchObject({ success: true, skipped: 'no_tokens' });
    });

    it('returns skipped result when tokens is null', async () => {
      const result = await sendPushNotification(null, 'SOS Alert', 'User needs help');
      expect(result).toMatchObject({ success: true, skipped: 'no_tokens' });
    });

    it('returns not_configured when FCM is not initialised', async () => {
      const result = await sendPushNotification(
        ['device-token-abc'],
        'SOS Alert',
        'User needs help',
        { type: 'sos', eventId: 'EVT-001' }
      );
      expect(result).toMatchObject({ success: false, reason: 'not_configured' });
    });
  });

  describe('sendToUser', () => {
    it('returns undefined when token is falsy', async () => {
      const result = await sendToUser(null, 'Test', 'Body');
      expect(result).toBeUndefined();
    });

    it('returns not_configured for a real token when FCM is not initialised', async () => {
      const result = await sendToUser('device-token-xyz', 'Alert', 'Message');
      expect(result).toMatchObject({ success: false, reason: 'not_configured' });
    });
  });

  describe('broadcastToCircle', () => {
    it('returns skipped when circle has no tokens', async () => {
      const result = await broadcastToCircle([], 'Circle Alert', 'Someone triggered SOS');
      expect(result).toMatchObject({ success: true, skipped: 'no_tokens' });
    });
  });

  describe('sendSMS', () => {
    it('returns not_configured when Twilio credentials are absent', async () => {
      const result = await sendSMS('+919999999999', 'SOS from SafePulse');
      expect(result).toMatchObject({ success: false, reason: 'not_configured' });
    });
  });
});
