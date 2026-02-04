# Las Prendas - Project Infrastructure

This document provides a comprehensive overview of the technical architecture and infrastructure of the **Las Prendas** virtual try-on application.

## High-Level Architecture

The project follows a modern client-server architecture with a clear separation of concerns, utilizing **Hexagonal Architecture (Ports & Adapters)** on the backend for scalability and maintainability.

```mermaid
graph TD
    subgraph "Frontend (Flutter App)"
        UI[UI/Screens]
        Prov[Provider State Management]
        Local[Secure Storage]
    end

    subgraph "Backend (NestJS API)"
        API[Auth/Try-On Controllers]
        UC[Use Cases]
        Queue[BullMQ / Background Jobs]
    end

    subgraph "Infrastructure"
        DB[(PostgreSQL)]
        Cache[(Redis)]
        S3[DigitalOcean Spaces (S3)]
        Gemini[Google Gemini API]
    end

    UI <--> Prov
    Prov <--> API
    API --> Local
    UC --> DB
    UC --> Queue
    Queue --> Gemini
    Queue --> S3
    S3 <--> Cache
```

---

## Component Details

### 1. Frontend (Mobile App)
*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **State Management**: `Provider` package for reactive UI and global data flow.
*   **Security**: `flutter_secure_storage` for persistsing JWT tokens and user session data.
*   **Network**: Custom `ApiService` built on top of the `http` package, handling automated token attachment and error management.
*   **Key Features**:
    *   Image picking (Gallery/Camera) and Clipboard support.
    *   Interactive Viewer with zoom/pan for try-on results.
    *   Dynamic closet management with soft-delete logic.

### 2. Backend (REST API & Services)
*   **Framework**: [NestJS](https://nestjs.com/) (TypeScript)
*   **Pattern**: Hexagonal Architecture.
*   **Storage**: TypeORM with PostgreSQL.
*   **Authentication**: JWT-based security using Passport.js strategies.
*   **Background Jobs**: BullMQ + Redis for asynchronous processing of AI try-on tasks, ensuring the API remains responsive.
*   **AI Integration**: Custom adapter for **Google Gemini Pro Vision** to perform high-fidelity virtual try-ons.
*   **Storage (Unified)**: [DigitalOcean Spaces](https://www.digitalocean.com/products/spaces/) (S3-compatible) for all image assets, including garment uploads and try-on results.
*   **Image Handling**: `sharp` for high-performance image resizing, normalization, and aspect-ratio adjustment before uploading to S3.

### 3. Infrastructure & DevOps
*   **Containerization**: [Docker](https://www.docker.com/) and `docker-compose` for local development orchestration.
*   **Database**: PostgreSQL for persistent storage (Users, Garments, Sessions).
*   **Caching/Message Broker**: Redis for job queuing and potentially caching.
*   **Deployment Environment**: Designed to be portable across cloud providers (AWS, GCP, etc.).

---

## Data Flow: Virtual Try-On Process

```mermaid
sequenceDiagram
    box "Client Instance (Mobile)" #2a2a2a
        participant User as User App
    end
    box "Backend API Instance (NestJS)" #2a2a2a
        participant API as Storage/TryOnController
        participant UC as VirtualTryOnUseCase
        participant BQP as BullMQ Producer
    end
    box "Infrastructure" #1e1e1e
        participant S3 as DigitalOcean Spaces (S3)
        participant DB as PostgreSQL
        participant Q as Redis (Queue Storage)
    end
    box "Worker Instance (NestJS)" #2a2a2a
        participant BQW as BullMQ Worker/Engine
        participant Proc as TryOnProcessor
    end
    box "External AI" #1e1e1e
        participant AI as Gemini API
    end

    Note over User, S3: 1. Direct Upload Flow
    User->>API: GET /storage/upload-params
    API->>S3: Generate Presigned URL
    S3-->>API: URL
    API-->>User: { uploadUrl, key, downloadUrl }
    User->>S3: [HTTP PUT] Upload Image
    
    Note over User, API: 2. Create Try-On Session
    User->>API: POST /try-on { garmentKeys, ... }
    activate API
    API->>UC: execute(garmentKeys, userId, ...)
    activate UC
    UC->>DB: saveSession(pending)
    UC->>BQP: addJob('process-try-on', sessionId)
    BQP->>Q: [HTTP/TCP] Push Job to Redis
    UC-->>API: sessionId
    deactivate UC
    API-->>User: { success: true, sessionId }
    deactivate API

    Note over BQW,Proc: 3. Async Background Processing
    Q->>BQW: [Polling/Event] New Job Available
    activate BQW
    BQW->>Proc: process(jobData)
    activate Proc
    Proc->>DB: findSessionById(sessionId)
    Proc->>S3: [HTTP GET] Fetch Garments
    Proc->>AI: performTryOn(images, prompt)
    activate AI
    AI-->>Proc: resultImageBytes
    deactivate AI
    Proc->>S3: [HTTP PUT] Upload Result Image
    Proc->>DB: updateSession(resultUrl, completed)
    Proc-->>BQW: task completed
    deactivate Proc
    BQW-->>Q: mark job as finished
    deactivate BQW

    loop Every 2-3 seconds
        User->>API: GET /sessions/:id
        API->>DB: findById(id)
        DB-->>API: session (status)
        API-->>User: status (completed? resultUrl)
    end
```

1.  **Request**: User selects garments on the mobile app and triggers "Try-On".
2.  **Upload**: Frontend requests a Presigned URL from the API and uploads files directly to **DigitalOcean Spaces**.
3.  **Queue**: Backend saves the session in DB (status: pending) and pushes a job to **BullMQ**.
4.  **Process**: The worker (TryOnProcessor) picks up the job, fetches the artifacts from S3, and calls the Gemini API.
5.  **Store**: Result image is uploaded directly to **DigitalOcean Spaces**, and the session status is updated in the DB with the S3 URL.
6.  **View**: Frontend displays the results directly from DigitalOcean Spaces URLs.

---

## Project Structure

```text
lasprendas/
├── backend/                # NestJS Source
│   ├── src/
│   │   ├── application/    # Use Cases & Services
│   │   ├── domain/         # Entities & Port Definitions
│   │   └── infrastructure/ # Database, Auth & API Adapters
│   └── assets/             # Mannequin base anchors
├── frontend/               # Flutter Source
│   ├── lib/
│   │   ├── providers/      # Global state
│   │   ├── screens/        # UI Views
│   │   └── services/       # API integration
│   └── assets/             # Mobile assets
└── docker-compose.yml      # Service orchestration
```
