package com.safepulse.backend.service;

/**
 * FUTURE SCOPE: Emergency Dispatch Integration
 * Planned: Connect to police/ambulance CAD systems via REST webhooks.
 * Extension point: implement dispatch(EmergencyEvent) to POST to gov APIs.
 * Current state: stub — logs dispatch intent, no external call made.
 * Tracked in: GitHub Issues label "future-dispatch"
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
