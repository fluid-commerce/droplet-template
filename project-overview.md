
# Droplet-ShipStation Project Overview

## Introduction
Droplet-ShipStation is an integration between ShipStation (an e-commerce shipping solution) and Fluid Commerce (an e-commerce platform). This application serves as a bridge, automating the flow of order and shipping data between these platforms.

## Technology Stack
- **Backend**: Ruby on Rails 8.0.2 with Ruby 3.4.2
- **Frontend**: TypeScript/React 19 with Tailwind CSS 4.0
- **Database**: PostgreSQL 17
- **Package Management**: Yarn 4.7.0
- **Other Libraries**:
  - Font Awesome 6.7.2
  - TanStack React Table
  - React JSON Schema Form

## Project Structure

### Backend Components
- **Controllers**:
  - `ShipstationController`: Handles communication with ShipStation
    - Export endpoint fetches orders from Fluid Commerce and formats them for ShipStation
    - Notification endpoint receives updates from ShipStation
  - `WebhooksController`: Processes webhooks for company droplet lifecycle events
  - `AdminController`: Admin-specific functionality
  - `HomeController`: Handles home page rendering

- **Models**:
  - `Company`: Represents companies using the integration
  - `Setting`: Application settings and configuration
  - `User`: User authentication and management
  - `Webhook`: Handles webhook data
  - `Event`: Tracks system events

- **Clients**:
  - `FluidClient`: API client for interacting with Fluid Commerce API
    - Uses HTTParty for HTTP requests
    - Implements standard REST methods (GET, POST, PUT, DELETE)
    - Error handling for various API responses

### Frontend Components
- React/TypeScript frontend integrated with Rails
- Single identified component:
  - `JsonEditor`: Likely used for editing JSON configuration

### Key Functionality
1. **Order Export**:
   - Fetches orders from Fluid Commerce API
   - Transforms order data into ShipStation XML format
   - Implements CDATA sections for proper XML formatting
   - Maps order statuses between systems

2. **Company Lifecycle Management**:
   - Creation of new company integrations
   - Installation/uninstallation tracking
   - Authentication token management

3. **ShipStation Integration**:
   - Webhooks for receiving shipping updates
   - Basic authentication for API endpoints
   - XML generation for ShipStation compatibility

## Deployment Options
- Standard Rails server: `bin/rails server` (port 3000)
- Full development environment: `bin/dev` (port 3200)
- Docker containerization: `docker compose up` (port 3600)
- Heroku deployment supported via one-click deploy

## Project Purpose
This "Droplet" serves as an integration point between ShipStation and Fluid Commerce, enabling:
- Automated order synchronization
- Shipping status updates
- Company-specific configuration and management
- Secure authentication between platforms

The project follows Fluid Commerce's "Droplet" pattern for third-party service integrations.
