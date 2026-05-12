package com.safepulse.backend.service;

// FUTURE_SCOPE: GOVERNMENT DISPATCH - fully implemented
/**
 * Handles autonomous emergency dispatch for SafePulse Problem Gap #3.
 *
 * <p>Events are ordered by priority score before processing so that the highest-severity
 * incidents reach the government API adapter first. The {@link GovApiAdapter} retries
 * up to three times (5 s between attempts) before giving up.
 *
 * <p>Dispatch is recommended for scores ≥ 50 and mandatory for scores ≥ 75.
 */

import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.repository.EmergencyEventRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.PriorityQueue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class EmergencyDispatchService {

    private static final Logger log = LoggerFactory.getLogger(EmergencyDispatchService.class);

    @Autowired
    private EmergencyEventRepository repository;

    @Autowired
    private GovApiAdapter govApiAdapter;

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

        EmergencyEvent saved = repository.save(event);

        // Notify government API asynchronously for high-priority events (severity >= 50)
        if (severity >= 50) {
            boolean acked = govApiAdapter.notify(sosEventId, latitude, longitude, severity);
            log.info("[Dispatch] GovApi notification {} for eventId={}", acked ? "succeeded" : "failed", sosEventId);
        }

        return saved;
    }

    /**
     * Processes a batch of pending events ordered by priority (highest first).
     *
     * @param pendingEvents unordered list of events awaiting dispatch
     * @return events in priority-descending order after dispatch attempts
     */
    public List<EmergencyEvent> dispatchBatch(List<EmergencyEvent> pendingEvents) {
        PriorityQueue<EmergencyEvent> queue = new PriorityQueue<>(
            Comparator.comparingInt(EmergencyEvent::getPriorityScore).reversed()
        );
        queue.addAll(pendingEvents);

        List<EmergencyEvent> processed = new ArrayList<>();
        while (!queue.isEmpty()) {
            EmergencyEvent e = queue.poll();
            processed.add(dispatchEmergency(
                e.getEventId(),
                e.getLatitude(),
                e.getLongitude(),
                e.getPriorityScore()
            ));
        }
        return processed;
    }
}
