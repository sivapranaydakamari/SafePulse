package com.safepulse.backend.service;

import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.repository.EmergencyEventRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Handles autonomous emergency dispatch for SafePulse Problem Gap #3.
 *
 * <p>When the on-device SOS triggers without user interaction (injured/unconscious rider),
 * this service creates a persistent dispatch record in MongoDB so that government or
 * third-party emergency APIs can later poll and acknowledge the event. Dispatch
 * recommendations are set based on the computed severity score.
 */
@Service
public class EmergencyDispatchService {

    @Autowired
    private EmergencyEventRepository repository;

    /**
     * Creates an emergency dispatch record for an autonomous SOS event.
     *
     * <p>Converts the raw integer severity score (0–100) to a human-readable
     * severity band, sets {@code dispatchRecommended = true} for scores ≥ 50,
     * and persists the event with status {@code "DISPATCHED"}.
     *
     * @param sosEventId the correlation ID from the originating SOS event
     *                   (matches the Flutter-side event UUID).
     * @param latitude   GPS latitude of the incident in decimal degrees [-90, 90].
     * @param longitude  GPS longitude of the incident in decimal degrees [-180, 180].
     * @param severity   integer priority score in [0, 100]; values ≥ 75 → CRITICAL,
     *                   ≥ 50 → HIGH, ≥ 25 → MEDIUM, otherwise LOW.
     * @return the persisted {@link EmergencyEvent} with status {@code "DISPATCHED"}
     *         and {@code locationStatus} {@code "CONFIRMED"}.
     */
    public EmergencyEvent dispatchEmergency(String sosEventId, double latitude, double longitude, int severity) {
        EmergencyEvent event = new EmergencyEvent();
        event.setEventId(sosEventId);
        event.setLatitude(latitude);
        event.setLongitude(longitude);
        event.setSeverity(severity >= 75 ? "CRITICAL" : severity >= 50 ? "HIGH" : severity >= 25 ? "MEDIUM" : "LOW");
        event.setPriorityScore(severity);
        event.setDispatchRecommended(severity >= 50);
        event.setStatus("DISPATCHED");
        event.setLocationStatus("CONFIRMED");
        return repository.save(event);
    }
}
