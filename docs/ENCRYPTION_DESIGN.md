# SafePulse — Encryption Design

## Overview

SafePulse encrypts sensitive FCM data payloads (SOS events, crash alerts, live-location updates sent to Safety Circle members) using **AES-256-CBC** symmetric encryption. This document describes key derivation, IV handling, and the integration path for end-to-end emergency communication.

---

## Implementation Reference

**Server-side (Node.js):** `backend/services/notification_service.js` — `encryptMessage(plaintext)`

```javascript
function encryptMessage(plaintext) {
  // Key: 32-byte (256-bit) value from FCM_PAYLOAD_KEY env var (64 hex chars)
  // IV:  16 random bytes generated per message (prepended to ciphertext)
  // Mode: AES-256-CBC
  const key = Buffer.from(FCM_PAYLOAD_KEY, 'hex');
  const iv  = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return iv.toString('base64') + ':' + encrypted.toString('base64');
}
```

**Output format:** `base64(IV) + ':' + base64(ciphertext)`

**Mobile-side (Dart — planned):** The Flutter app will implement the corresponding AES-256-CBC decryption using `pointycastle` or `encrypt` package, reading the key from Flutter Secure Storage.

---

## Key Management

| Environment | Key Source | Rotation |
|-------------|-----------|---------|
| Development | Not set — `encryptMessage()` returns plaintext unchanged | N/A |
| Production | `FCM_PAYLOAD_KEY` environment variable (64 hex chars = 32 bytes) | Quarterly |
| Key storage (server) | Secret Manager (GCP / AWS) or Railway/Render env vars | Out-of-band |
| Key storage (mobile) | `flutter_secure_storage` (Android Keystore / iOS Secure Enclave) | On server rotation |

### Key Derivation (production recommendation)

Rather than a static shared secret, derive the encryption key per user session using HKDF:

```
input_key_material = ECDH(server_private_key, user_public_key)
key = HKDF-SHA256(ikm=input_key_material, salt=userId, info="safepulse-fcm-v1", length=32)
```

This gives each user a unique key — a compromised key for one user does not affect others.

---

## IV Handling

- A fresh **128-bit random IV** is generated for every `encryptMessage()` call using `crypto.randomBytes(16)`.
- The IV is **not secret** — it is prepended to the ciphertext as `base64(IV):base64(ciphertext)`.
- The mobile client splits on `:` to recover IV and ciphertext before decrypting.
- IV reuse would break CBC confidentiality; `crypto.randomBytes` is cryptographically secure.

---

## What Is Encrypted

| Payload field | Encrypted? | Reason |
|---------------|-----------|--------|
| FCM notification `title` / `body` | No | Required by FCM for display |
| FCM `data.sos_payload` | Yes | Contains GPS coordinates + contact details |
| FCM `data.location_update` | Yes | Live location of tracked user |
| FCM `data.crash_alert` | Yes | Crash probability + severity |
| REST API responses | No (TLS) | Transport-layer encryption is sufficient |

---

## End-to-End Emergency Communication Path

```
SosService (Flutter)
  → POST /api/sos/start
  → Node.js SOS handler
  → broadcastToCircle(tokens, title, body, data)
       ↓ data.sos_payload = encryptMessage(JSON.stringify({lat, lng, time, severity}))
  → FCM multicast → Safety Circle devices
  → Flutter FCM handler decrypts data.sos_payload
  → Displays emergency location on CircleMapPage
```

---

## Future: Asymmetric Encryption

For true end-to-end encryption where the server cannot read payloads:

1. Each device generates an **X25519 key pair** at first launch; the public key is uploaded to the user profile in MongoDB.
2. The server fetches recipient public keys and uses **ECIES** (ECDH + AES-GCM) to encrypt per-recipient.
3. The private key never leaves the device (stored in Secure Enclave / Android Keystore).

This requires rearchitecting the current FCM multicast path to per-device targeted messages, increasing cost but providing true E2E guarantees.

---

## Security Notes

- `FCM_PAYLOAD_KEY` must be **at least 64 hex characters** (32 bytes). The server checks `FCM_PAYLOAD_KEY.length < 64` and falls back to plaintext if the key is invalid — this is intentional for development environments but must not reach production.
- Do not log the plaintext payload or the key in production. Current implementation silently swallows encryption errors and returns plaintext as a safe fallback.
- TLS (HTTPS/WSS) is always required between client and gateway, regardless of payload encryption.
