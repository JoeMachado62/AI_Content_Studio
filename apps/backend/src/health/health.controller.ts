import { Controller, Get, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import {
  HealthCheckService,
  HealthCheck,
  TypeOrmHealthIndicator,
  HealthCheckResult,
} from '@nestjs/terminus';
import { AppConfigService } from '../config/config.service';
import { EnhancedEmailService } from '@gitroom/nestjs-libraries/services/enhanced-email.service';
import { PrismaService } from '@gitroom/nestjs-libraries/database/prisma/prisma.service';

interface HealthStatus {
  status: 'ok' | 'error' | 'shutting_down';
  timestamp: string;
  uptime: number;
  environment: string;
  version: string;
  services: {
    database: ServiceStatus;
    redis: ServiceStatus;
    email: ServiceStatus;
    storage: ServiceStatus;
  };
  configuration: {
    emailEnabled: boolean;
    oauthProviders: string[];
    storageProvider: string;
    securityMode: string;
  };
  memory: {
    used: number;
    free: number;
    total: number;
  };
}

interface ServiceStatus {
  status: 'healthy' | 'unhealthy' | 'degraded';
  responseTime?: number;
  error?: string;
  details?: any;
}

@ApiTags('Health')
@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private configService: AppConfigService,
    private emailService: EnhancedEmailService,
    private prisma: PrismaService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Get application health status' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Health check successful' })
  @ApiResponse({ status: HttpStatus.SERVICE_UNAVAILABLE, description: 'Health check failed' })
  @HealthCheck()
  async check(): Promise<HealthCheckResult> {
    return this.health.check([
      () => this.checkDatabase(),
      () => this.checkRedis(),
      () => this.checkEmail(),
    ]);
  }

  @Get('detailed')
  @ApiOperation({ summary: 'Get detailed application health status' })
  @ApiResponse({ status: HttpStatus.OK, description: 'Detailed health status' })
  async detailedCheck(): Promise<HealthStatus> {
    const startTime = Date.now();

    const [databaseStatus, redisStatus, emailStatus, storageStatus] = await Promise.allSettled([
      this.checkDatabaseDetailed(),
      this.checkRedisDetailed(),
      this.checkEmailDetailed(),
      this.checkStorageDetailed(),
    ]);

    const config = this.configService.get();
    const memoryUsage = process.memoryUsage();

    return {
      status: this.determineOverallStatus(databaseStatus, redisStatus, emailStatus, storageStatus),
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: config.server.nodeEnv,
      version: process.env.npm_package_version || '1.0.0',
      services: {
        database: this.extractServiceStatus(databaseStatus),
        redis: this.extractServiceStatus(redisStatus),
        email: this.extractServiceStatus(emailStatus),
        storage: this.extractServiceStatus(storageStatus),
      },
      configuration: {
        emailEnabled: this.configService.isEmailEnabled(),
        oauthProviders: Object.keys(config.oauth),
        storageProvider: config.storage.provider,
        securityMode: config.security.isSecured ? 'secured' : 'open',
      },
      memory: {
        used: Math.round(memoryUsage.heapUsed / 1024 / 1024),
        free: Math.round((memoryUsage.heapTotal - memoryUsage.heapUsed) / 1024 / 1024),
        total: Math.round(memoryUsage.heapTotal / 1024 / 1024),
      },
    };
  }

  @Get('ready')
  @ApiOperation({ summary: 'Readiness probe for Kubernetes/Docker' })
  async readiness() {
    const databaseHealthy = await this.isDatabaseHealthy();
    const redisHealthy = await this.isRedisHealthy();

    if (databaseHealthy && redisHealthy) {
      return { status: 'ready', timestamp: new Date().toISOString() };
    }

    throw new Error('Application not ready');
  }

  @Get('live')
  @ApiOperation({ summary: 'Liveness probe for Kubernetes/Docker' })
  async liveness() {
    return {
      status: 'alive',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    };
  }

  private async checkDatabase() {
    const startTime = Date.now();
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return {
        database: {
          status: 'up' as const,
          responseTime: Date.now() - startTime,
        },
      };
    } catch (error) {
      return {
        database: {
          status: 'down' as const,
          error: (error as Error).message,
          responseTime: Date.now() - startTime,
        },
      };
    }
  }

  private async checkRedis() {
    const startTime = Date.now();
    try {
      // Simple Redis health check - you might need to implement this based on your Redis setup
      return {
        redis: {
          status: 'up' as const,
          responseTime: Date.now() - startTime,
        },
      };
    } catch (error) {
      return {
        redis: {
          status: 'down' as const,
          error: (error as Error).message,
          responseTime: Date.now() - startTime,
        },
      };
    }
  }

  private async checkEmail() {
    try {
      const testResult = await this.emailService.testEmailConfiguration();
      if (testResult.success) {
        return {
          email: {
            status: 'up' as const,
            provider: this.emailService.getProviderName(),
          },
        };
      } else {
        return {
          email: {
            status: 'down' as const,
            provider: this.emailService.getProviderName(),
            ...(testResult.error && { error: testResult.error }),
          },
        };
      }
    } catch (error) {
      return {
        email: {
          status: 'down' as const,
          error: (error as Error).message,
        },
      };
    }
  }

  private async checkDatabaseDetailed(): Promise<ServiceStatus> {
    const startTime = Date.now();
    try {
      await this.prisma.$queryRaw`SELECT 1`;

      // Get additional database info
      const userCount = await this.prisma.user.count();
      const orgCount = await this.prisma.organization.count();

      return {
        status: 'healthy',
        responseTime: Date.now() - startTime,
        details: {
          users: userCount,
          organizations: orgCount,
        },
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        responseTime: Date.now() - startTime,
        error: (error as Error).message,
      };
    }
  }

  private async checkRedisDetailed(): Promise<ServiceStatus> {
    const startTime = Date.now();
    try {
      // TODO: Implement actual Redis health check when Redis client is available
      return {
        status: 'healthy',
        responseTime: Date.now() - startTime,
        details: {
          connected: true,
        },
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        responseTime: Date.now() - startTime,
        error: (error as Error).message,
      };
    }
  }

  private async checkEmailDetailed(): Promise<ServiceStatus> {
    try {
      const testResult = await this.emailService.testEmailConfiguration();
      return {
        status: testResult.success ? 'healthy' : 'unhealthy',
        details: {
          provider: this.emailService.getProviderName(),
          enabled: this.configService.isEmailEnabled(),
        },
        ...(testResult.error && { error: testResult.error }),
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: (error as Error).message,
      };
    }
  }

  private async checkStorageDetailed(): Promise<ServiceStatus> {
    try {
      const storageConfig = this.configService.getStorage();
      return {
        status: 'healthy',
        details: {
          provider: storageConfig.provider,
          configured: true,
        },
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: (error as Error).message,
      };
    }
  }

  private async isDatabaseHealthy(): Promise<boolean> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }

  private async isRedisHealthy(): Promise<boolean> {
    try {
      // TODO: Implement actual Redis health check
      return true;
    } catch {
      return false;
    }
  }

  private determineOverallStatus(
    ...statuses: PromiseSettledResult<ServiceStatus>[]
  ): 'ok' | 'error' | 'shutting_down' {
    const hasUnhealthy = statuses.some(
      (result) => result.status === 'fulfilled' && result.value.status === 'unhealthy'
    );

    const hasRejected = statuses.some((result) => result.status === 'rejected');

    if (hasUnhealthy || hasRejected) {
      return 'error';
    }

    return 'ok';
  }

  private extractServiceStatus(result: PromiseSettledResult<ServiceStatus>): ServiceStatus {
    if (result.status === 'fulfilled') {
      return result.value;
    } else {
      return {
        status: 'unhealthy',
        error: result.reason?.message || 'Unknown error',
      };
    }
  }
}