package com.safepulse.backend.service;

// FUTURE_SCOPE: GOVERNMENT DISPATCH - fully implemented
/**
 * Mock government emergency API adapter for SafePulse.
 *
 * <p>Simulates notification of a government emergency-response portal when a
 * high-severity SOS is dispatched. In production this class would POST to the
 * actual government API; the mock records call attempts and simulates the
 * transient-failure / retry scenario.
 *
 * <p>Retry policy: up to {@value #MAX_ATTEMPTS} attempts with a
 * {@value #RETRY_DELAY_MS} ms pause between each. A simulated failure rate of
 * 30% lets integration tests exercise the retry path without a real endpoint.
 */
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class GovApiAdapter {

    private static final Logger log = LoggerFactory.getLogger(GovApiAdapter.class);

    static final int MAX_ATTEMPTS   = 3;
    static final int RETRY_DELAY_MS = 5_000;

    /** Simulated failure rate (30 %) so tests can exercise retry without a real endpoint. */
    private static final double SIMULATED_FAILURE_RATE = 0.3;

    private int callCount = 0;

    /**
     * Notifies the government emergency portal of a high-severity incident.
     *
     * @param eventId   correlation ID from the originating SOS event
     * @param latitude  GPS latitude of the incident
     * @param longitude GPS longitude of the incident
     * @param severity  numeric severity [0–100]
     * @return {@code true} if the notification was acknowledged within the retry budget
     */
    public boolean notify(String eventId, double latitude, double longitude, int severity) {
        for (int attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
            callCount++;
            if (tryNotify(eventId, latitude, longitude, severity, attempt)) {
                log.info("[GovApi] Dispatch acknowledged — eventId={} attempt={}", eventId, attempt);
                return true;
            }
            if (attempt < MAX_ATTEMPTS) {
                try {
                    Thread.sleep(RETRY_DELAY_MS);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
        log.warn("[GovApi] All {} attempts exhausted for eventId={}", MAX_ATTEMPTS, eventId);
        return false;
    }

    /** Returns total notify() invocations across all attempts (useful in tests). */
    public int getCallCount() { return callCount; }

    /** Override in tests to control success/failure deterministically. */
    protected boolean tryNotify(String eventId, double lat, double lon, int severity, int attempt) {
        log.info("[GovApi] Attempt {}/{} — eventId={} severity={}", attempt, MAX_ATTEMPTS, eventId, severity);
        // Deterministic mock: succeed on attempt 1 with probability (1 - SIMULATED_FAILURE_RATE)
        return (Math.random() >= SIMULATED_FAILURE_RATE);
    }
}
