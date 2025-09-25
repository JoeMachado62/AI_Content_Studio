import { Module } from '@nestjs/common';
import { TerminusModule } from '@nestjs/terminus';
import { HealthController } from './health.controller';
import { EnhancedEmailService } from '@gitroom/nestjs-libraries/services/enhanced-email.service';

@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
  providers: [EnhancedEmailService],
})
export class HealthModule {}