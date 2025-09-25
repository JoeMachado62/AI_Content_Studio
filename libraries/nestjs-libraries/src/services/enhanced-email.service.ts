import { Injectable, Inject } from '@nestjs/common';
import { EmailInterface } from '@gitroom/nestjs-libraries/emails/email.interface';
import { ResendProvider } from '@gitroom/nestjs-libraries/emails/resend.provider';
import { EmptyProvider } from '@gitroom/nestjs-libraries/emails/empty.provider';
import { AppConfigService } from '../../../../apps/backend/src/config/config.service';

@Injectable()
export class EnhancedEmailService {
  private emailService: EmailInterface;

  constructor(private configService: AppConfigService) {
    this.emailService = this.initializeEmailProvider();
    this.logConfiguration();
  }

  private initializeEmailProvider(): EmailInterface {
    const emailConfig = this.configService.getEmail();

    if (emailConfig.provider === 'none') {
      console.log('[EMAIL] Email service disabled - no provider configured');
      return new EmptyProvider();
    }

    if (emailConfig.provider === 'resend' && emailConfig.resend) {
      console.log('[EMAIL] Email service enabled with Resend provider');
      return new ResendProvider();
    }

    console.warn('[EMAIL] Email provider configured but missing required settings, using empty provider');
    return new EmptyProvider();
  }

  private logConfiguration(): void {
    const emailConfig = this.configService.getEmail();
    console.log(`[EMAIL] Provider: ${emailConfig.provider}`);

    if (emailConfig.provider === 'resend' && emailConfig.resend) {
      console.log(`[EMAIL] From: ${emailConfig.resend.fromName} <${emailConfig.resend.fromAddress}>`);
      console.log(`[EMAIL] API Key: ${emailConfig.resend.apiKey.substring(0, 10)}...`);
    }
  }

  hasProvider(): boolean {
    return !(this.emailService instanceof EmptyProvider);
  }

  getProviderName(): string {
    return this.emailService.name || 'none';
  }

  async sendEmail(to: string, subject: string, html: string, replyTo?: string): Promise<void> {
    // Validate email address
    if (!to || to.indexOf('@') === -1) {
      console.warn(`[EMAIL] Invalid email address: ${to}`);
      return;
    }

    // Check if provider is configured
    if (!this.hasProvider()) {
      console.warn('[EMAIL] Email service not configured, skipping email send');
      return;
    }

    const emailConfig = this.configService.getEmail();

    // Only proceed if we have proper configuration
    if (emailConfig.provider !== 'resend' || !emailConfig.resend) {
      console.warn('[EMAIL] Email configuration invalid, skipping email send');
      return;
    }

    const { fromAddress, fromName } = emailConfig.resend;

    try {
      console.log(`[EMAIL] Sending email to ${to} with subject: ${subject}`);

      const modifiedHtml = `
        <div style="
            background: linear-gradient(to bottom right, #e6f2ff, #f0e6ff);
            padding: 20px;
            font-family: Arial, sans-serif;
        ">
            ${html}
            <div style="
                margin-top: 30px;
                padding-top: 20px;
                border-top: 1px solid #ddd;
                font-size: 12px;
                color: #666;
                text-align: center;
            ">
                This email was sent by AI Content Studio
            </div>
        </div>
      `;

      await this.emailService.sendEmail(
        to,
        subject,
        modifiedHtml,
        fromName,
        fromAddress,
        replyTo
      );

      console.log(`[EMAIL] Email sent successfully to ${to}`);
    } catch (error) {
      console.error(`[EMAIL] Failed to send email to ${to}:`, (error as Error).message);
      throw error;
    }
  }

  async sendActivationEmail(to: string, activationCode: string): Promise<void> {
    const serverConfig = this.configService.getServer();
    const activationLink = `${serverConfig.frontendUrl}/auth/activate?code=${activationCode}`;

    const html = `
      <div style="max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333; text-align: center;">Welcome to AI Content Studio!</h1>

        <p>Thank you for registering with AI Content Studio. To complete your registration and activate your account, please click the button below:</p>

        <div style="text-align: center; margin: 30px 0;">
          <a href="${activationLink}"
             style="
               background-color: #007bff;
               color: white;
               padding: 12px 30px;
               text-decoration: none;
               border-radius: 5px;
               display: inline-block;
               font-weight: bold;
             ">
            Activate Your Account
          </a>
        </div>

        <p>If the button above doesn't work, you can copy and paste the following link into your browser:</p>
        <p style="word-break: break-all; background: #f8f9fa; padding: 10px; border-radius: 4px;">
          ${activationLink}
        </p>

        <p><strong>This activation link will expire in 24 hours.</strong></p>

        <p>If you didn't create an account with AI Content Studio, please ignore this email.</p>

        <hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">

        <p style="font-size: 12px; color: #666;">
          Best regards,<br>
          The AI Content Studio Team
        </p>
      </div>
    `;

    await this.sendEmail(to, 'Activate Your AI Content Studio Account', html);
  }

  async sendPasswordResetEmail(to: string, resetToken: string): Promise<void> {
    const serverConfig = this.configService.getServer();
    const resetLink = `${serverConfig.frontendUrl}/auth/reset-password?token=${resetToken}`;

    const html = `
      <div style="max-width: 600px; margin: 0 auto;">
        <h1 style="color: #333; text-align: center;">Password Reset Request</h1>

        <p>You requested to reset your password for your AI Content Studio account. Click the button below to set a new password:</p>

        <div style="text-align: center; margin: 30px 0;">
          <a href="${resetLink}"
             style="
               background-color: #dc3545;
               color: white;
               padding: 12px 30px;
               text-decoration: none;
               border-radius: 5px;
               display: inline-block;
               font-weight: bold;
             ">
            Reset Password
          </a>
        </div>

        <p>If the button above doesn't work, you can copy and paste the following link into your browser:</p>
        <p style="word-break: break-all; background: #f8f9fa; padding: 10px; border-radius: 4px;">
          ${resetLink}
        </p>

        <p><strong>This reset link will expire in 1 hour.</strong></p>

        <p>If you didn't request a password reset, please ignore this email. Your password will remain unchanged.</p>

        <hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">

        <p style="font-size: 12px; color: #666;">
          Best regards,<br>
          The AI Content Studio Team
        </p>
      </div>
    `;

    await this.sendEmail(to, 'Reset Your AI Content Studio Password', html);
  }

  async testEmailConfiguration(): Promise<{ success: boolean; error?: string }> {
    try {
      if (!this.hasProvider()) {
        return { success: false, error: 'No email provider configured' };
      }

      const emailConfig = this.configService.getEmail();
      if (emailConfig.provider !== 'resend' || !emailConfig.resend) {
        return { success: false, error: 'Invalid email configuration' };
      }

      // Test email configuration by attempting to validate the API key
      console.log('[EMAIL] Testing email configuration...');

      // For now, just return success if we have the configuration
      // In production, you might want to make a test API call
      return { success: true };
    } catch (error) {
      return { success: false, error: (error as Error).message };
    }
  }
}