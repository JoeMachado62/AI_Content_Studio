export interface DatabaseConfig {
  url: string;
  ssl?: boolean;
  logging?: boolean;
  maxConnections?: number;
}

export interface RedisConfig {
  url: string;
  maxRetriesPerRequest?: number;
  retryDelayOnFailover?: number;
}

export interface EmailConfig {
  provider: 'resend' | 'none';
  resend?: {
    apiKey: string;
    fromAddress: string;
    fromName: string;
  };
}

export interface StorageConfig {
  provider: 'local' | 'cloudflare';
  local?: {
    uploadDirectory: string;
    staticDirectory: string;
  };
  cloudflare?: {
    accountId: string;
    accessKey: string;
    secretAccessKey: string;
    bucketName: string;
    bucketUrl: string;
    region: string;
  };
}

export interface OAuthConfig {
  google?: {
    clientId: string;
    clientSecret: string;
  };
  github?: {
    clientId: string;
    clientSecret: string;
  };
  generic?: {
    displayName: string;
    logoUrl: string;
    authUrl: string;
    tokenUrl: string;
    userInfoUrl: string;
    clientId: string;
    clientSecret: string;
    scope: string;
  };
}

export interface SecurityConfig {
  jwtSecret: string;
  isSecured: boolean;
  corsOrigins: string[];
}

export interface ServerConfig {
  port: number;
  frontendUrl: string;
  backendUrl: string;
  backendInternalUrl: string;
  nodeEnv: 'development' | 'production' | 'test';
}

export interface AppConfig {
  server: ServerConfig;
  database: DatabaseConfig;
  redis: RedisConfig;
  email: EmailConfig;
  storage: StorageConfig;
  oauth: OAuthConfig;
  security: SecurityConfig;
  features: {
    disableRegistration: boolean;
    isGeneral: boolean;
    billingEnabled: boolean;
  };
}