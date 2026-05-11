package com.safepulse.backend.service;

/**
 * EmergencyDispatchService — Future Scope
 *
 * Planned integration with government emergency dispatch APIs (police/ambulance/112).
 * TODO: Obtain regulatory API access and implement eCall / national PSAP integration.
 *
 * When implemented:
 * - Receives SOS events from SosController above a severity threshold
 * - Formats and transmits a standardized emergency notification (location, profile, severity)
 * - Handles acknowledgement and logs dispatch attempts for audit
 */
public class EmergencyDispatchService {

    /**
     * TODO: Dispatch to emergency authorities. Stub only — logs intent, no real API call.
     */
    public void dispatchEmergency(String sosEventId, double latitude, double longitude, int severity) {
        System.out.println("[EmergencyDispatch] STUB — SOS event: " + sosEventId +
            " | lat: " + latitude + " | lng: " + longitude + " | severity: " + severity);
    }
}
