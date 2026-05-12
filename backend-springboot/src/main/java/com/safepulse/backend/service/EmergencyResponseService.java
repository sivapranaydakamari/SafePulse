package com.safepulse.backend.service;

import com.safepulse.backend.dto.SosRequest;
import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.repository.EmergencyEventRepository;
import java.util.List;
import java.util.Locale;
import java.util.NoSuchElementException;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class EmergencyResponseService {

    private final EmergencyEventRepository repository;

    /**
     * Constructs the service with the required repository dependency.
     *
     * @param repository MongoDB repository for persisting and querying emergency events.
     */
    public EmergencyResponseService(EmergencyEventRepository repository) {
        this.repository = repository;
    }

    /**
     * Creates and persists a new emergency event from an inbound SOS request.
     *
     * <p>Validates GPS coordinates, normalises severity and location-status strings,
     * computes a priority score, and sets {@code dispatchRecommended = true} when
     * the score reaches or exceeds 80.
     *
     * @param request the SOS payload from the mobile client or gateway; must contain
     *                valid latitude/longitude values.
     * @return the persisted {@link EmergencyEvent} with a generated event ID and
     *         status {@code "ACTIVE"}.
     * @throws IllegalArgumentException if latitude or longitude are outside valid ranges.
     */
    public EmergencyEvent createEvent(SosRequest request) {
        validateCoordinates(request.getLatitude(), request.getLongitude());

        EmergencyEvent event = new EmergencyEvent();
        event.setEventId(normalizeEventId(request.getEventId()));
        event.setLatitude(request.getLatitude());
        event.setLongitude(request.getLongitude());
        event.setSeverity(normalizeSeverity(request.getSeverity()));
        event.setLocationStatus(normalizeLocationStatus(request.getLocationStatus()));
        event.setStatus("ACTIVE");
        event.setPriorityScore(priorityScore(event.getSeverity(), event.getLocationStatus()));
        event.setDispatchRecommended(event.getPriorityScore() >= 80);

        return repository.save(event);
    }

    /**
     * Retrieves an existing emergency event by its event ID.
     *
     * @param eventId the unique event identifier (e.g. {@code "EVT-<UUID>"}).
     * @return the matching {@link EmergencyEvent}.
     * @throws NoSuchElementException if no event with the given ID exists in the database.
     */
    public EmergencyEvent getEvent(String eventId) {
        return repository.findByEventId(eventId)
                .orElseThrow(() -> new NoSuchElementException("Emergency event not found"));
    }

    /**
     * Returns all events currently in {@code ACTIVE} status, ordered by creation time
     * descending (most recent first).
     *
     * @return a list of active {@link EmergencyEvent} objects; never {@code null}.
     */
    public List<EmergencyEvent> getActiveEvents() {
        return repository.findByStatusOrderByCreatedAtDesc("ACTIVE");
    }

    /**
     * Marks an emergency event as resolved, clears the dispatch recommendation flag,
     * and persists the update.
     *
     * @param eventId the unique identifier of the event to resolve.
     * @return the updated {@link EmergencyEvent} with status {@code "RESOLVED"}.
     * @throws NoSuchElementException if no event with the given ID exists.
     */
    public EmergencyEvent resolveEvent(String eventId) {
        EmergencyEvent event = getEvent(eventId);
        event.setStatus("RESOLVED");
        event.setDispatchRecommended(false);
        return repository.save(event);
    }

    /**
     * Validates that the supplied coordinates are within legal geographic bounds.
     *
     * @param latitude  decimal degrees, must be in [-90, 90].
     * @param longitude decimal degrees, must be in [-180, 180].
     * @throws IllegalArgumentException if either value is out of range.
     */
    private void validateCoordinates(double latitude, double longitude) {
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new IllegalArgumentException("latitude/longitude are outside valid ranges");
        }
    }

    /**
     * Returns a trimmed, non-blank event ID, generating a UUID-based fallback when
     * the supplied value is null or blank.
     *
     * @param eventId the raw event ID from the request; may be {@code null}.
     * @return a non-null, non-blank event ID string.
     */
    private String normalizeEventId(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            return "EVT-" + UUID.randomUUID();
        }
        return eventId.trim();
    }

    /**
     * Upper-cases and trims the severity string, defaulting to {@code "MEDIUM"} when absent.
     *
     * @param severity raw severity from the request; may be {@code null}.
     * @return normalised severity string (e.g. {@code "HIGH"}, {@code "CRITICAL"}).
     */
    private String normalizeSeverity(String severity) {
        if (severity == null || severity.isBlank()) {
            return "MEDIUM";
        }
        return severity.trim().toUpperCase(Locale.ROOT);
    }

    /**
     * Upper-cases and trims the location-status string, defaulting to {@code "UNKNOWN"} when absent.
     *
     * @param locationStatus raw location status from the request; may be {@code null}.
     * @return normalised location status (e.g. {@code "CONFIRMED"}, {@code "STALE"}).
     */
    private String normalizeLocationStatus(String locationStatus) {
        if (locationStatus == null || locationStatus.isBlank()) {
            return "UNKNOWN";
        }
        return locationStatus.trim().toUpperCase(Locale.ROOT);
    }

    /**
     * Computes a 0–100 priority score from severity and location status.
     *
     * <p>Base scores: CRITICAL=100, HIGH=85, MEDIUM=60, LOW=35, unknown=50.
     * A penalty of 15 points is applied when the GPS location is {@code "UNAVAILABLE"}
     * or {@code "STALE"}, reflecting reduced dispatch confidence.
     *
     * @param severity       normalised severity string.
     * @param locationStatus normalised location status string.
     * @return integer priority score in [0, 100].
     */
    private int priorityScore(String severity, String locationStatus) {
        int base = switch (severity) {
            case "CRITICAL" -> 100;
            case "HIGH" -> 85;
            case "MEDIUM" -> 60;
            case "LOW" -> 35;
            default -> 50;
        };

        if ("UNAVAILABLE".equals(locationStatus) || "STALE".equals(locationStatus)) {
            return Math.max(0, base - 15);
        }
        return base;
    }
}
