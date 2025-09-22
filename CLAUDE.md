# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Postiz is an AI-powered social media scheduling tool built as a monorepo using NX. It supports multiple social platforms (X/Twitter, Instagram, Facebook, LinkedIn, Reddit, TikTok, etc.) with features for scheduling, analytics, team collaboration, and AI content generation.

## Architecture

### Monorepo Structure
- **apps/** - Main applications
  - `backend/` - NestJS API server
  - `frontend/` - Next.js web application
  - `workers/` - Background job processors
  - `cron/` - Scheduled task runner
  - `extension/` - Browser extension
  - `commands/` - CLI tools
  - `sdk/` - TypeScript SDK

- **libraries/** - Shared code
  - `nestjs-libraries/` - NestJS modules, database schema, utilities
  - `react-shared-libraries/` - React components and hooks
  - `helpers/` - Utility functions

### Tech Stack
- **Frontend**: Next.js 14, React 18, TypeScript, Tailwind CSS, Mantine UI
- **Backend**: NestJS, Prisma ORM, PostgreSQL
- **Queue System**: Redis with BullMQ
- **Authentication**: JWT, OAuth integrations
- **Email**: Resend
- **Monitoring**: Sentry
- **Package Manager**: pnpm with workspaces

## Development Commands

### Setup
```bash
pnpm install                    # Install dependencies
pnpm run prisma-generate        # Generate Prisma client
pnpm run prisma-db-push         # Push schema to database
```

### Development
```bash
pnpm run dev                    # Start all services in development
pnpm run dev:backend            # Backend only
pnpm run dev:frontend           # Frontend only
pnpm run dev:workers            # Workers only
pnpm run dev:cron              # Cron jobs only
```

### Building
```bash
pnpm run build                  # Build all apps
pnpm run build:backend          # Build backend only
pnpm run build:frontend         # Build frontend only
```

### Testing
```bash
pnpm test                       # Run Jest tests with coverage
```

### Database
```bash
pnpm run prisma-db-push         # Apply schema changes
pnpm run prisma-reset           # Reset database
```

### Production
```bash
pnpm run start:prod:backend     # Start backend in production
pnpm run start:prod:frontend    # Start frontend in production
pnpm run pm2                    # Run with PM2 process manager
```

## Key Conventions

### Code Style
- Use TypeScript for all new code
- Follow conventional commits (`feat:`, `fix:`, `chore:`)
- Use Sentry for logging with structured format:
  ```typescript
  import * as Sentry from "@sentry/nextjs";
  const { logger } = Sentry;
  logger.info("Action completed", { userId, action });
  ```

### Database
- Schema located at `libraries/nestjs-libraries/src/database/prisma/schema.prisma`
- Use Prisma client for all database operations
- PostgreSQL is the default database

### Environment
- Environment variables defined in `.env` (copy from `.env.example`)
- Update `.env.example` when adding new environment variables
- Use `dotenv` for loading in development

### Integrations
- Social media APIs (Instagram, Facebook, X/Twitter, etc.)
- Make.com and N8N for automation
- Stripe for payments
- OAuth for social login

## Development Notes

### Local Development
- Use Node.js 20.17.0
- PostgreSQL and Redis required (use `docker-compose.dev.yaml` for quick setup)
- Frontend runs on port 4200, backend on port 3000

### File Locations
- Database schema: `libraries/nestjs-libraries/src/database/prisma/schema.prisma`
- Shared components: `libraries/react-shared-libraries/`
- API routes: `apps/backend/src/`
- Frontend pages: `apps/frontend/src/`

### Testing
- Jest configuration in `jest.config.ts`
- Coverage reports in `reports/` directory
- Use `jest-junit` for CI integration

## Useful Resources
- Main documentation: https://docs.postiz.com/
- Developer guide: https://docs.postiz.com/developer-guide
- Public API: https://docs.postiz.com/public-api