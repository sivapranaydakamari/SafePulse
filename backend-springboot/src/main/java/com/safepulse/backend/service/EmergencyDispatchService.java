package com.safepulse.backend.service;

import com.safepulse.backend.model.EmergencyEvent;
import com.safepulse.backend.repository.EmergencyEventRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

// SafePulse Problem Gap #3: autonomous SOS needs a persistent dispatch record.
@Service
public class EmergencyDispatchService {

    @Autowired
    private EmergencyEventRepository repository;

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
