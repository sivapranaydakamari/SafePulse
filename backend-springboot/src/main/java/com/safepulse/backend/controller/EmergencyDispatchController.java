package com.safepulse.backend.controller;

// FUTURE_SCOPE: GOVERNMENT DISPATCH - fully implemented
/**
 * Exposes the emergency dispatch workflow via REST.
 *
 * <p>{@code POST /api/emergency/dispatch} is called <em>server-to-server</em> from the
 * Node.js SOS handler whenever {@code severity > 0.8}. The endpoint delegates to
 * {@link com.safepulse.backend.service.EmergencyDispatchService#dispatchEmergency},
 * which orders events by priority score and invokes the {@link com.safepulse.backend.service.GovApiAdapter}
 * with up to 3 retries.
 */

import com.safepulse.backend.dto.EmergencyEventResponse;
import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.service.EmergencyDispatchService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/emergency")
public class EmergencyDispatchController {

    private final EmergencyDispatchService dispatchService;

    public EmergencyDispatchController(EmergencyDispatchService dispatchService) {
        this.dispatchService = dispatchService;
    }

    /**
     * Triggers government dispatch for a high-severity SOS event.
     *
     * <p>Called by Node.js {@code routes/sos.js} when {@code severity > 0.8}.
     * Never called directly by the Flutter mobile app.
     *
     * @param body map containing {@code sosEventId}, {@code latitude}, {@code longitude},
     *             and {@code severity} (0–100 integer).
     * @return 201 Created with the persisted dispatch record.
     * @throws IllegalArgumentException if required fields are missing or invalid.
     */
    @PostMapping("/dispatch")
    public ResponseEntity<EmergencyEventResponse> dispatch(@RequestBody Map<String, Object> body) {
        Object rawId  = body.get("sosEventId");
        Object rawLat = body.get("latitude");
        Object rawLng = body.get("longitude");
        Object rawSev = body.get("severity");

        if (!(rawId  instanceof String))  throw new IllegalArgumentException("sosEventId must be a non-null string");
        if (!(rawLat instanceof Number))   throw new IllegalArgumentException("latitude must be a valid number");
        if (!(rawLng instanceof Number))   throw new IllegalArgumentException("longitude must be a valid number");
        if (!(rawSev instanceof Number))   throw new IllegalArgumentException("severity must be a valid number");

        String sosEventId = (String) rawId;
        double latitude   = ((Number) rawLat).doubleValue();
        double longitude  = ((Number) rawLng).doubleValue();
        int    severity   = ((Number) rawSev).intValue();

        EmergencyEvent event = dispatchService.dispatchEmergency(sosEventId, latitude, longitude, severity);
        return ResponseEntity.status(201).body(EmergencyEventResponse.from(event));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<String> handleBadRequest(IllegalArgumentException ex) {
        return ResponseEntity.badRequest().body(ex.getMessage());
    }
}
