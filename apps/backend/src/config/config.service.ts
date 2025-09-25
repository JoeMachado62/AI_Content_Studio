import { Injectable } from '@nestjs/common';
import { ConfigService as NestConfigService } from '@nestjs/config';
import {
  AppConfig,
  DatabaseConfig,
  RedisConfig,
  EmailConfig,
  StorageConfig,
  OAuthConfig,
  SecurityConfig,
  ServerConfig
} from './config.interface';

@Injectable()
export class AppConfigService {
  private config: AppConfig;

  constructor(private configService: NestConfigService) {
    this.config = this.loadConfig();
    this.validateConfig();
  }

  private loadConfig(): AppConfig {
    return {
      server: this.loadServerConfig(),
      database: this.loadDatabaseConfig(),
      redis: this.loadRedisConfig(),
      email: this.loadEmailConfig(),
      storage: this.loadStorageConfig(),
      oauth: this.loadOAuthConfig(),
      security: this.loadSecurityConfig(),
      features: {
        disableRegistration: this.configService.get<boolean>('DISABLE_REGISTRATION', false),
        isGeneral: this.configService.get<boolean>('IS_GENERAL', true),
        billingEnabled: this.configService.get<boolean>('BILLING_ENABLED', true),
      }
    };
  }

  private loadServerConfig(): ServerConfig {
    return {
      port: this.configService.get<number>('PORT', 3000),
      frontendUrl: this.configService.get<string>('FRONTEND_URL', 'http://localhost:4200'),
      backendUrl: this.configService.get<string>('NEXT_PUBLIC_BACKEND_URL', 'http://localhost:3000'),
      backendInternalUrl: this.configService.get<string>('BACKEND_INTERNAL_URL', 'http://localhost:3000'),
      nodeEnv: this.configService.get<'development' | 'production' | 'test'>('NODE_ENV', 'development'),
    };
  }

  private loadDatabaseConfig(): DatabaseConfig {
    const url = this.configService.get<string>('DATABASE_URL');
    if (!url) {
      throw new Error('DATABASE_URL is required');
    }

    return {
      url,
      ssl: this.configService.get<boolean>('DATABASE_SSL', false),
      logging: this.configService.get<boolean>('DATABASE_LOGGING', false),
      maxConnections: this.configService.get<number>('DATABASE_MAX_CONNECTIONS', 10),
    };
  }

  private loadRedisConfig(): RedisConfig {
    const url = this.configService.get<string>('REDIS_URL');
    if (!url) {
      throw new Error('REDIS_URL is required');
    }

    return {
      url,
      maxRetriesPerRequest: this.configService.get<number>('REDIS_MAX_RETRIES', 3),
      retryDelayOnFailover: this.configService.get<number>('REDIS_RETRY_DELAY', 100),
    };
  }

  private loadEmailConfig(): EmailConfig {
    const resendApiKey = this.configService.get<string>('RESEND_API_KEY');

    if (!resendApiKey) {
      console.log('[CONFIG] Email service disabled - no RESEND_API_KEY provided');
      return { provider: 'none' };
    }

    const fromAddress = this.configService.get<string>('EMAIL_FROM_ADDRESS');
    const fromName = this.configService.get<string>('EMAIL_FROM_NAME');

    if (!fromAddress || !fromName) {
      console.warn('[CONFIG] Email service partially configured - missing EMAIL_FROM_ADDRESS or EMAIL_FROM_NAME');
      return { provider: 'none' };
    }

    console.log('[CONFIG] Email service enabled with Resend');
    return {
      provider: 'resend',
      resend: {
        apiKey: resendApiKey,
        fromAddress,
        fromName,
      }
    };
  }

  private loadStorageConfig(): StorageConfig {
    const provider = this.configService.get<'local' | 'cloudflare'>('STORAGE_PROVIDER', 'local');

    if (provider === 'cloudflare') {
      return {
        provider: 'cloudflare',
        cloudflare: {
          accountId: this.configService.get<string>('CLOUDFLARE_ACCOUNT_ID', ''),
          accessKey: this.configService.get<string>('CLOUDFLARE_ACCESS_KEY', ''),
          secretAccessKey: this.configService.get<string>('CLOUDFLARE_SECRET_ACCESS_KEY', ''),
          bucketName: this.configService.get<string>('CLOUDFLARE_BUCKETNAME', ''),
          bucketUrl: this.configService.get<string>('CLOUDFLARE_BUCKET_URL', ''),
          region: this.configService.get<string>('CLOUDFLARE_REGION', 'auto'),
        }
      };
    }

    return {
      provider: 'local',
      local: {
        uploadDirectory: this.configService.get<string>('UPLOAD_DIRECTORY', './uploads'),
        staticDirectory: this.configService.get<string>('NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY', '/uploads'),
      }
    };
  }

  private loadOAuthConfig(): OAuthConfig {
    const config: OAuthConfig = {};

    // Google OAuth
    const googleClientId = this.configService.get<string>('GOOGLE_CLIENT_ID');
    const googleClientSecret = this.configService.get<string>('GOOGLE_CLIENT_SECRET');
    if (googleClientId && googleClientSecret) {
      config.google = { clientId: googleClientId, clientSecret: googleClientSecret };
    }

    // GitHub OAuth
    const githubClientId = this.configService.get<string>('GITHUB_CLIENT_ID');
    const githubClientSecret = this.configService.get<string>('GITHUB_CLIENT_SECRET');
    if (githubClientId && githubClientSecret) {
      config.github = { clientId: githubClientId, clientSecret: githubClientSecret };
    }

    // Generic OAuth (Postiz custom)
    const genericEnabled = this.configService.get<boolean>('POSTIZ_GENERIC_OAUTH', false);
    if (genericEnabled) {
      const genericClientId = this.configService.get<string>('POSTIZ_OAUTH_CLIENT_ID');
      const genericClientSecret = this.configService.get<string>('POSTIZ_OAUTH_CLIENT_SECRET');

      if (genericClientId && genericClientSecret) {
        config.generic = {
          displayName: this.configService.get<string>('NEXT_PUBLIC_POSTIZ_OAUTH_DISPLAY_NAME', 'OAuth'),
          logoUrl: this.configService.get<string>('NEXT_PUBLIC_POSTIZ_OAUTH_LOGO_URL', ''),
          authUrl: this.configService.get<string>('POSTIZ_OAUTH_AUTH_URL', ''),
          tokenUrl: this.configService.get<string>('POSTIZ_OAUTH_TOKEN_URL', ''),
          userInfoUrl: this.configService.get<string>('POSTIZ_OAUTH_USERINFO_URL', ''),
          clientId: genericClientId,
          clientSecret: genericClientSecret,
          scope: this.configService.get<string>('POSTIZ_OAUTH_SCOPE', 'openid profile email'),
        };
      }
    }

    return config;
  }

  private loadSecurityConfig(): SecurityConfig {
    const jwtSecret = this.configService.get<string>('JWT_SECRET');
    if (!jwtSecret) {
      throw new Error('JWT_SECRET is required');
    }

    return {
      jwtSecret,
      isSecured: !this.configService.get<boolean>('NOT_SECURED', false),
      corsOrigins: this.configService.get<string>('CORS_ORIGINS', '')
        .split(',')
        .filter(Boolean)
        .map(origin => origin.trim()),
    };
  }

  private validateConfig(): void {
    const errors: string[] = [];

    // Validate required configurations
    if (!this.config.database.url) {
      errors.push('DATABASE_URL is required');
    }

    if (!this.config.redis.url) {
      errors.push('REDIS_URL is required');
    }

    if (!this.config.security.jwtSecret) {
      errors.push('JWT_SECRET is required');
    }

    if (this.config.email.provider === 'resend' && !this.config.email.resend?.apiKey) {
      errors.push('RESEND_API_KEY is required when email provider is resend');
    }

    if (errors.length > 0) {
      throw new Error(`Configuration validation failed:\n${errors.join('\n')}`);
    }

    console.log('[CONFIG] Configuration validation passed');
    this.logConfigSummary();
  }

  private logConfigSummary(): void {
    console.log('[CONFIG] Application Configuration Summary:');
    console.log(`  Environment: ${this.config.server.nodeEnv}`);
    console.log(`  Port: ${this.config.server.port}`);
    console.log(`  Database: ${this.config.database.url.replace(/:[^:@]*@/, ':***@')}`);
    console.log(`  Redis: ${this.config.redis.url.replace(/:[^:@]*@/, ':***@')}`);
    console.log(`  Email: ${this.config.email.provider}`);
    console.log(`  Storage: ${this.config.storage.provider}`);
    console.log(`  Security: ${this.config.security.isSecured ? 'Secured' : 'Not Secured'}`);

    const oauthProviders = Object.keys(this.config.oauth);
    console.log(`  OAuth Providers: ${oauthProviders.length > 0 ? oauthProviders.join(', ') : 'None'}`);
  }

  // Getter methods
  get(): AppConfig {
    return this.config;
  }

  getServer(): ServerConfig {
    return this.config.server;
  }

  getDatabase(): DatabaseConfig {
    return this.config.database;
  }

  getRedis(): RedisConfig {
    return this.config.redis;
  }

  getEmail(): EmailConfig {
    return this.config.email;
  }

  getStorage(): StorageConfig {
    return this.config.storage;
  }

  getOAuth(): OAuthConfig {
    return this.config.oauth;
  }

  getSecurity(): SecurityConfig {
    return this.config.security;
  }

  isEmailEnabled(): boolean {
    return this.config.email.provider !== 'none';
  }

  isOAuthEnabled(provider: 'google' | 'github' | 'generic'): boolean {
    return !!this.config.oauth[provider];
  }
}