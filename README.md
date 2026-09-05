# TaskApp Docker Containerization & Orchestration

A containerized full-stack TaskApp environment demonstrating
production-oriented Docker practices, multi-stage image builds,
Nginx-based frontend serving, Flask backend containerization, PostgreSQL
integration, Docker networking, persistent storage, health checks, and
multi-container orchestration with Docker Compose.

## Project Overview

This project packages and orchestrates a full-stack TaskApp application
using Docker. The implementation covers the application container
lifecycle from image construction and runtime configuration through
multi-container orchestration and environment-specific Compose
configurations.

## Key Objectives

-   Containerize the React frontend using a multi-stage Docker build.
-   Serve the production frontend with Nginx.
-   Containerize the Flask backend with Gunicorn.
-   Run PostgreSQL as a containerized database service.
-   Configure service-to-service communication using a custom Docker
    network.
-   Persist PostgreSQL data with a Docker volume.
-   Implement database health checks and service dependencies.
-   Automate database readiness checks and migrations during backend
    startup.
-   Separate development and production-like Compose behavior.
-   Use environment variables for environment-specific configuration.
-   Verify the running application through containers, logs, and the
    browser.


## Architecture

``` text
                         ┌─────────────────────┐
                         │       Browser       │
                         │   localhost:8080    │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │      Frontend       │
                         │   Nginx Container   │
                         │       Port 80       │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │       Backend       │
                         │ Flask + Gunicorn    │
                         │      Port 5000      │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │      PostgreSQL     │
                         │    postgres:15      │
                         │      Port 5432      │
                         └──────────┬──────────┘
                                    │
                                    ▼
                         ┌─────────────────────┐
                         │   postgres_data     │
                         │   Docker Volume     │
                         └─────────────────────┘

                    All services communicate through
                         taskapp-network
```

The frontend, backend, and database communicate through the custom
`taskapp-network` bridge network. PostgreSQL data is persisted through
the `postgres_data` Docker volume.


## Project Structure

``` text
taskapp-docker-containerization/
├── images/
│   ├── backend-runtime-logs.png
│   ├── development-override.png
│   ├── docker-compose-config.png
│   └── taskapp-running.png
│
├── dockercompose/
│   ├── docker-compose.yml
│   ├── taskapp_backend_cicd/
│   └── taskapp_frontend_cicd/
│
├── dockercompose-override/
│   ├── docker-compose.yml
│   ├── docker-compose.override.yml
│   ├── docker-compose.prod-like.yml
│   ├── taskapp_backend_cicd/
│   └── taskapp_frontend_cicd/
│
├── taskapp_backend_cicd/
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   ├── .dockerignore
│   └── ...
│
├── taskapp_frontend_cicd/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── .dockerignore
│   └── ...
│
├── .gitignore
└── README.md
```

## Technology Stack

| Technology | Purpose |
|---|---|
| Docker | Application containerization |
| Docker Compose | Multi-container orchestration |
| React / Vite | Frontend application |
| Nginx | Frontend production runtime |
| Python 3.11 | Backend runtime |
| Flask | Backend API |
| Gunicorn | Production WSGI server |
| PostgreSQL 15 | Relational database |
| Alembic | Database migrations |
| Bash / Netcat | Startup and database readiness checks |

## Frontend Containerization

The React frontend uses a two-stage Docker build.

### Build Stage

The first stage uses Node.js to install dependencies and build the
application:

``` dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --frozen-lockfile

COPY . .
RUN npm run build
```

Using a separate build stage keeps the Node.js build environment
separate from the final runtime image.

### Runtime Stage

The production image uses Nginx:

``` dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
```

This keeps the runtime focused on serving the generated frontend assets
rather than carrying the Node.js build environment into production.

### Nginx Configuration

The Nginx configuration provides:

-   Static asset caching
-   Gzip compression
-   SPA routing through `try_files`
-   HTML cache control
-   A `/health` endpoint
-   Nginx access logging optimization for static assets

![Running TaskApp Application](images/taskapp-running.png)

The running application demonstrates the containerized frontend being
served successfully.

## Backend Containerization

The backend uses Python 3.11 Slim and runs Flask through Gunicorn.

Key Docker configuration includes:

-   Python runtime environment variables
-   System packages required by the application
-   Dependency installation from `requirements.txt`
-   Non-root application user
-   Port 5000 exposure
-   Startup automation through `docker-entrypoint.sh`

The container creates an `appuser` account and switches away from root
before starting the application:

``` dockerfile
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app

USER appuser
```

### Backend Startup Process

The entrypoint script:

1.  Starts the backend container.
2.  Waits for PostgreSQL to accept connections.
3.  Runs Alembic database migrations.
4.  Starts Gunicorn.
5.  Streams application logs to the container output.

``` text
Container start
      │
      ▼
Wait for PostgreSQL
      │
      ▼
Database ready
      │
      ▼
Run Alembic migrations
      │
      ▼
Start Gunicorn
      │
      ▼
Serve Flask API
```

![Backend Runtime Logs](images/backend-runtime-logs.png)

The runtime logs show the database readiness check, successful
migration, Gunicorn startup, worker processes, and API requests.

## Docker Compose

Docker Compose orchestrates three services:

-   `frontend`
-   `backend`
-   `db`

The services share the `taskapp-network` bridge network.

The database uses a persistent named volume:

``` yaml
volumes:
  postgres_data:
    driver: local
```

The backend waits for the database health check before starting:

``` yaml
depends_on:
  db:
    condition: service_healthy
```

The PostgreSQL service uses `pg_isready` for its health check.

![Docker Compose Configuration](images/docker-compose-config.png)

The Compose configuration shows the relationship between the backend,
database, network, health check, and environment configuration.

## Development Environment

The project includes a Docker Compose override configuration for
development.

The development override:

-   Exposes PostgreSQL on the host.
-   Exposes the backend on port 5000.
-   Mounts the backend source directory into the container.
-   Enables Flask development mode.
-   Enables automatic reload.
-   Exposes the frontend on port 8080.

Example:

``` yaml
backend:
  ports:
    - "5000:5000"
  volumes:
    - ./taskapp_backend_cicd:/app
  environment:
    FLASK_ENV: development
    DEBUG: 1
  command: flask run --host=0.0.0.0 --reload
```

![Development Docker Compose Override](images/development-override.png)

The development override demonstrates how Docker Compose can change
runtime behavior without modifying the base Compose configuration.

## Production-Like Configuration

A separate `docker-compose.prod-like.yml` configuration provides a
closer approximation of production behavior.

It demonstrates:

-   No host port exposure for PostgreSQL.
-   Localhost-only binding for frontend and backend.
-   No source-code volume mounts.
-   Production Flask configuration.
-   Reduced Gunicorn worker count.
-   Container restart policies.
-   CPU and memory resource limits for the backend.

Example resource configuration:

``` yaml
deploy:
  resources:
    limits:
      cpus: "0.5"
      memory: 512M
```

The production-like configuration demonstrates how the same application
stack can be adapted for a more controlled runtime environment.

## Database & Persistence

PostgreSQL runs as a dedicated container using the `postgres:15-alpine`
image.

The database is configured with:

-   Dedicated database user
-   Dedicated database
-   Environment-based password configuration
-   Health checks
-   Persistent Docker volume storage

The named `postgres_data` volume allows database data to survive
container recreation.

## Docker Networking

The application services communicate through a custom bridge network:

``` yaml
networks:
  taskapp-network:
    driver: bridge
```

Within the Compose network, the backend reaches PostgreSQL through the
service name:

``` text
db:5432
```

This avoids hard-coding container IP addresses and allows Docker's
internal service discovery to resolve the database service.

## Health Checks & Startup Dependencies

The PostgreSQL container uses:

``` yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U taskapp_user -d taskapp"]
  interval: 10s
  timeout: 5s
  retries: 5
```

The backend depends on the database being healthy:

``` yaml
depends_on:
  db:
    condition: service_healthy
```

The backend entrypoint also performs an explicit TCP readiness check
before running migrations.

This creates multiple layers of startup protection:

``` text
PostgreSQL starts
       │
       ▼
PostgreSQL health check
       │
       ▼
Backend waits for database connection
       │
       ▼
Alembic migrations
       │
       ▼
Gunicorn starts
```

## Environment Configuration

Environment-specific values are kept outside the production-like Compose
definition through environment variables.

The override configuration references values such as:

``` yaml
POSTGRES_PASSWORD: ${DB_PASSWORD}
DATABASE_PASSWORD: ${DB_PASSWORD}
SECRET_KEY: ${SECRET_KEY}
VITE_API_URL: ${VITE_API_URL}
```

The local `.env` file is intentionally excluded from version control
through `.gitignore`.

Example configuration:

``` env
DB_PASSWORD=<your-database-password>
SECRET_KEY=<your-application-secret>
VITE_API_URL=<your-api-url>
```

No local `.env` file or private credentials should be committed to the
repository.

## Useful Docker Commands

### Build and start the stack

``` bash
docker compose up --build -d
```

### View running containers

``` bash
docker compose ps
```

### View backend logs

``` bash
docker compose logs -f backend
```

### View all service logs

``` bash
docker compose logs -f
```

### Validate the Compose configuration

``` bash
docker compose config
```

### Stop the application

``` bash
docker compose down
```

### Stop and remove volumes

``` bash
docker compose down -v
```

### Start using the production-like configuration

``` bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod-like.yml \
  up -d
```

## Verification

The deployment was validated through:

-   Docker Compose configuration validation
-   Container status checks
-   PostgreSQL health checks
-   Backend startup logs
-   Database migration execution
-   Gunicorn worker startup
-   Frontend browser access
-   API requests from the frontend
-   Development override configuration

The application was successfully exercised through the browser while the
backend logs showed successful authentication and task API requests.

## Key Technical Highlights

-   Implemented a multi-stage Docker build for the React frontend.
-   Used Nginx as the frontend production runtime.
-   Configured SPA routing, compression, caching, and a health endpoint.
-   Containerized the Flask backend with Python 3.11 Slim.
-   Configured Gunicorn as the backend application server.
-   Ran the backend container as a non-root user.
-   Added automated PostgreSQL readiness checks.
-   Automated Alembic database migrations during backend startup.
-   Containerized PostgreSQL using PostgreSQL 15 Alpine.
-   Implemented persistent database storage with Docker volumes.
-   Created a custom Docker bridge network for service communication.
-   Used Compose health checks and service dependency conditions.
-   Separated development and production-like runtime configurations.
-   Used environment variables for environment-specific configuration.
-   Verified the stack through containers, logs, API requests, and
    browser access.

## Project Context

This project focuses specifically on **Docker containerization and
multi-container orchestration** of a full-stack application.

It demonstrates how application components can be packaged into separate
containers and managed as a single application stack using Docker
Compose, while supporting different runtime configurations for
development and production-like environments.

## Future Improvements

Potential next steps for the project include:

-   Add container image vulnerability scanning.
-   Publish versioned images to a container registry.
-   Add automated Docker image builds through CI/CD.
-   Introduce Docker secrets or a dedicated secrets manager.
-   Add centralized application and container logging.
-   Add Prometheus/Grafana monitoring.
-   Introduce Kubernetes manifests for cluster deployment.
-   Add automated integration tests against the Compose stack.
-   Add reverse-proxy TLS termination for a production deployment.
-   Add resource and availability monitoring.

## Author

**Anthony Chidi**

*DevOps Engineer \| Cloud Engineer \| Docker & Containerization*
