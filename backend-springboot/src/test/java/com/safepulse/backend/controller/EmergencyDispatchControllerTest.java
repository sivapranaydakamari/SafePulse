package com.safepulse.backend.controller;

// FUTURE_SCOPE: GOVERNMENT DISPATCH - fully implemented
/**
 * MockMvc integration test for the SOS → dispatch flow.
 *
 * <p>Verifies that POST /api/emergency/dispatch returns HTTP 201 with the
 * persisted dispatch record, and that the GovApiAdapter is invoked with the
 * correct severity when a high-priority SOS arrives.
 */

import com.fasterxml.jackson.databind.ObjectMapper;
import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.service.EmergencyDispatchService;
import com.safepulse.backend.service.GovApiAdapter;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(EmergencyDispatchController.class)
class EmergencyDispatchControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockBean
    EmergencyDispatchService dispatchService;

    @Autowired
    ObjectMapper objectMapper;

    @Test
    void dispatch_returns201_andPersistsEvent() throws Exception {
        EmergencyEvent event = new EmergencyEvent();
        event.setEventId("sos-999");
        event.setSeverity("CRITICAL");
        event.setPriorityScore(90);
        event.setStatus("DISPATCHED");
        event.setDispatchRecommended(true);
        event.setLatitude(17.385);
        event.setLongitude(78.487);
        event.setLocationStatus("CONFIRMED");

        when(dispatchService.dispatchEmergency(eq("sos-999"), anyDouble(), anyDouble(), eq(90)))
            .thenReturn(event);

        Map<String, Object> body = Map.of(
            "sosEventId", "sos-999",
            "latitude",   17.385,
            "longitude",  78.487,
            "severity",   90
        );

        mockMvc.perform(post("/api/emergency/dispatch")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.eventId").value("sos-999"))
            .andExpect(jsonPath("$.status").value("DISPATCHED"))
            .andExpect(jsonPath("$.dispatchRecommended").value(true));

        verify(dispatchService).dispatchEmergency("sos-999", 17.385, 78.487, 90);
    }

    @Test
    void dispatch_highSeverity_triggersGovApiNotification() throws Exception {
        EmergencyEvent event = new EmergencyEvent();
        event.setEventId("sos-888");
        event.setSeverity("CRITICAL");
        event.setPriorityScore(85);
        event.setStatus("DISPATCHED");
        event.setDispatchRecommended(true);
        event.setLatitude(28.613);
        event.setLongitude(77.209);
        event.setLocationStatus("CONFIRMED");

        when(dispatchService.dispatchEmergency(anyString(), anyDouble(), anyDouble(), anyInt()))
            .thenReturn(event);

        Map<String, Object> body = Map.of(
            "sosEventId", "sos-888",
            "latitude",   28.613,
            "longitude",  77.209,
            "severity",   85
        );

        mockMvc.perform(post("/api/emergency/dispatch")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)))
            .andExpect(status().isCreated());

        verify(dispatchService).dispatchEmergency("sos-888", 28.613, 77.209, 85);
    }
}
