# SafePulse Project Review Details

Use this content for the Project Space submission fields. It is written to match the implementation currently in this repository.

## Project Title

SafePulse

## GitHub URL

Add your GitHub repository link here after pushing the latest code.

## Project Description

SafePulse is an AI-powered travel safety companion that monitors journeys in real time, detects unsafe driving patterns, analyzes crash-like sensor events, scores route safety, and triggers emergency response workflows for trusted contacts.

The system combines a Flutter mobile app, a Node.js API gateway, a Spring Boot emergency-event microservice, a Python AI accident-analysis microservice, MongoDB geospatial data, OpenStreetMap/OSRM route data, Firebase push notification support, SMS notification support, REST APIs, and WebSocket realtime communication.

## Problem Statement

Most navigation applications optimize for time and distance but do not actively monitor safety during a journey. Solo travelers and commuters can face over-speeding, sudden crashes, unsafe routes, poor lighting zones, and delayed emergency response. SafePulse addresses this gap by continuously monitoring route, motion, speed, and emergency signals and by notifying trusted contacts when risk becomes critical.

## Proposed Solution

SafePulse provides a mobile safety ecosystem with:

- Realtime GPS and speed monitoring.
- WebSocket-based live journey status and emergency broadcasts.
- Safety Circle management for trusted contacts.
- Safe-vs-short route comparison using route scoring.
- Dynamic incident-backed risk zones using MongoDB-ready geospatial models and seed data.
- Python AI accident analysis using TensorFlow Lite when available and a calibrated fallback model for phone-drop filtering.
- Automated SOS creation, notification, responder tracking, and Spring Boot emergency-event persistence.

## Technical Stack

- Frontend: Flutter, Dart, Provider, REST clients, WebSocket client.
- API Gateway: Node.js, Express, JWT, Jest, Supertest.
- Realtime Layer: WebSocket server using `ws`.
- Emergency Microservice: Spring Boot, Java 17, JPA, H2 for local tests, SQL-ready configuration.
- AI/ML Microservice: Python, FastAPI, TensorFlow Lite model loading, calibrated heuristic fallback.
- Database: MongoDB for users, circles, SOS records, and geospatial risk incidents; SQL persistence for Spring Boot emergency events.
- Maps/Routes: OpenStreetMap, OSRM, Overpass/Nominatim integrations.
- Notifications: Firebase Cloud Messaging adapter and SMS adapter.

## System Architecture

SafePulse follows a multi-service architecture:

1. Flutter App  
   Handles authentication UI, tracking screens, route suggestions, SOS flows, sensor capture, and realtime WebSocket updates.

2. Node.js API Gateway  
   Handles OTP/JWT auth, Safety Circles, SOS coordination, route scoring, risk-zone APIs, AI proxy calls, notification adapters, and WebSocket realtime tracking.

3. Python AI Service  
   Receives accelerometer/gyroscope/speed windows and returns crash probability, severity, false-positive risk, and calibration notes.

4. Spring Boot Emergency Service  
   Stores emergency events, calculates priority scores, exposes active emergency queues, and resolves SOS events.

5. Data Layer  
   MongoDB stores operational app data and geospatial risk incidents. Spring Boot uses JPA with H2 locally and can be configured for MySQL/PostgreSQL in production.

## Requirements Fulfilled

- OTP/JWT authentication.
- Safety Circle creation, join, and member retrieval.
- Emergency contacts and SOS start/cancel/respond flows.
- Nearby hospitals/police lookup through OpenStreetMap data.
- Safe route suggestions using OSRM and route-risk scoring.
- Dynamic risk-zone data model and API.
- Realtime WebSocket tracking and SOS alert broadcasting.
- Flutter readable source code committed under `frontend/lib/`.
- Python AI microservice for server-side crash analysis.
- Spring Boot microservice with real business logic and persistence.
- Automated tests for Node.js routes/services, Spring Boot emergency flows, and Python accident analysis.

## Testing And Coverage

The repository includes automated tests across all major services:

- Node.js: Jest and Supertest route/service coverage.
- Spring Boot: JUnit, MockMvc, Spring context, JPA persistence, emergency priority scoring, active event listing, and resolve flow tests.
- Python AI: Unit tests for high-speed impact detection and stationary phone-drop filtering.

Validated commands:

```powershell
cd backend
npm test

cd backend-springboot
.\mvnw.cmd test

cd ai-service
$env:PYTHONPATH='P:\SafePulse\ai-service'
python -m unittest discover -s tests
```

## Production Readiness

SafePulse is structured for production hardening:

- Environment-variable configuration for service URLs and credentials.
- JWT-protected APIs.
- MongoDB geospatial indexes for location and incident search.
- SQL-ready Spring Boot emergency service.
- WebSocket realtime alert layer.
- AI service isolated from core API traffic.
- Clear test commands and CI workflow.
- Reviewable source code without binary source archives.

## Future Scope

- Replace seed risk-zone data with live incident feeds and community moderation.
- Add wearable/vitals integration for driver health monitoring.
- Add offline emergency queueing.
- Add richer AI model telemetry and drift monitoring.
- Add admin dashboard for emergency operators.
- Add production observability with structured logs, metrics, and tracing.

## Conclusion

SafePulse implements a realistic multi-service safety platform with mobile sensing, AI accident analysis, realtime monitoring, route safety scoring, emergency response, and automated testing. The latest repository version directly addresses code review concerns by keeping Flutter source readable, adding Python and Spring Boot microservices with functional logic, using WebSockets for realtime communication, replacing hardcoded route-risk logic with data-backed risk zones, and providing automated tests across the system.
