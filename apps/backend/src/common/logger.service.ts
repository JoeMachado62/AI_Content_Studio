import { Injectable, LoggerService, Scope } from '@nestjs/common';
import { AppConfigService } from '../config/config.service';

export enum LogLevel {
  ERROR = 0,
  WARN = 1,
  INFO = 2,
  DEBUG = 3,
  VERBOSE = 4,
}

export interface LogContext {
  userId?: string;
  orgId?: string;
  requestId?: string;
  component?: string;
  action?: string;
  [key: string]: any;
}

@Injectable({ scope: Scope.TRANSIENT })
export class AppLoggerService implements LoggerService {
  private context: string;
  private logLevel: LogLevel;

  constructor(private configService?: AppConfigService) {
    const nodeEnv = this.configService?.getServer().nodeEnv || process.env.NODE_ENV || 'development';
    this.logLevel = nodeEnv === 'production' ? LogLevel.INFO : LogLevel.DEBUG;
  }

  setContext(context: string) {
    this.context = context;
  }

  private shouldLog(level: LogLevel): boolean {
    return level <= this.logLevel;
  }

  private formatMessage(level: string, message: string, context?: LogContext): string {
    const timestamp = new Date().toISOString();
    const ctx = this.context ? `[${this.context}]` : '';

    let formatted = `[${timestamp}] [${level}]${ctx} ${message}`;

    if (context && Object.keys(context).length > 0) {
      const contextStr = Object.entries(context)
        .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
        .join(' ');
      formatted += ` | ${contextStr}`;
    }

    return formatted;
  }

  error(message: string, trace?: string, context?: LogContext) {
    if (!this.shouldLog(LogLevel.ERROR)) return;

    const formatted = this.formatMessage('ERROR', message, context);
    console.error(formatted);

    if (trace) {
      console.error('Stack trace:', trace);
    }
  }

  warn(message: string, context?: LogContext) {
    if (!this.shouldLog(LogLevel.WARN)) return;
    console.warn(this.formatMessage('WARN', message, context));
  }

  log(message: string, context?: LogContext) {
    if (!this.shouldLog(LogLevel.INFO)) return;
    console.log(this.formatMessage('INFO', message, context));
  }

  debug(message: string, context?: LogContext) {
    if (!this.shouldLog(LogLevel.DEBUG)) return;
    console.debug(this.formatMessage('DEBUG', message, context));
  }

  verbose(message: string, context?: LogContext) {
    if (!this.shouldLog(LogLevel.VERBOSE)) return;
    console.log(this.formatMessage('VERBOSE', message, context));
  }

  // Utility methods for structured logging

  logUserAction(action: string, userId: string, details?: any) {
    this.log(`User action: ${action}`, {
      userId,
      action,
      component: 'user',
      ...details,
    });
  }

  logSystemEvent(event: string, details?: any) {
    this.log(`System event: ${event}`, {
      component: 'system',
      event,
      ...details,
    });
  }

  logApiCall(method: string, url: string, statusCode: number, responseTime: number, context?: LogContext) {
    this.log(`API ${method} ${url} - ${statusCode} (${responseTime}ms)`, {
      component: 'api',
      method,
      url,
      statusCode,
      responseTime,
      ...context,
    });
  }

  logDatabaseOperation(operation: string, table: string, duration: number, context?: LogContext) {
    this.debug(`DB ${operation} on ${table} (${duration}ms)`, {
      component: 'database',
      operation,
      table,
      duration,
      ...context,
    });
  }

  logEmailEvent(event: string, to: string, subject: string, success: boolean, error?: string) {
    const level = success ? 'INFO' : 'ERROR';
    const message = `Email ${event}: ${subject} to ${to} - ${success ? 'SUCCESS' : 'FAILED'}`;

    if (success) {
      this.log(message, { component: 'email', event, to, subject });
    } else {
      this.error(message, error, { component: 'email', event, to, subject });
    }
  }

  logAuthEvent(event: string, userId?: string, email?: string, success?: boolean, error?: string) {
    const message = `Auth ${event}${userId ? ` for user ${userId}` : ''}${email ? ` (${email})` : ''} - ${success ? 'SUCCESS' : 'FAILED'}`;

    if (success) {
      this.log(message, { component: 'auth', event, userId, email });
    } else {
      this.warn(message, { component: 'auth', event, userId, email, error });
    }
  }

  logConfigurationEvent(event: string, details: any) {
    this.log(`Configuration ${event}`, {
      component: 'config',
      event,
      ...details,
    });
  }

  // Performance logging
  createTimer(name: string) {
    const startTime = Date.now();
    return {
      end: (context?: LogContext) => {
        const duration = Date.now() - startTime;
        this.debug(`Timer ${name}: ${duration}ms`, {
          component: 'performance',
          timer: name,
          duration,
          ...context,
        });
        return duration;
      },
    };
  }
}