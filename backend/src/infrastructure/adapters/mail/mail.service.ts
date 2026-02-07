import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Mailgun from 'mailgun.js';
import FormData from 'form-data';

@Injectable()
export class MailService {
    private mg;

    constructor(private readonly configService: ConfigService) {
        const apiKey = this.configService.get<string>('MAILGUN_API_KEY');
        if (apiKey) {
            const mailgun = new Mailgun(FormData);
            this.mg = mailgun.client({
                username: 'api',
                key: apiKey,
            });
        }
    }

    async sendVerificationCode(email: string, code: string, name: string): Promise<void> {
        if (!this.mg) {
            console.warn('Mailgun client not initialized. Skipping email.');
            return;
        }

        const domain = this.configService.get<string>('MAILGUN_DOMAIN');
        if (!domain) {
            console.warn('MAILGUN_DOMAIN not configured. Skipping email.');
            return;
        }

        const data = {
            from: `LasPrendas <notifications@${domain}>`,
            to: email, // Usar string directamente
            subject: 'Tu código de verificación - Las Prendas',
            text: `Hola ${name},\n\nTu código de verificación es: ${code}\n\nEste código expirará en 10 minutos.`,
            html: `<div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2>Hola ${name},</h2>
                    <p>Gracias por registrarte en <b>Las Prendas</b>.</p>
                    <p>Tu código de verificación es:</p>
                    <h1 style="color: #6200EE; font-size: 32px; letter-spacing: 5px;">${code}</h1>
                    <p>Este código expirará en 10 minutos. Si no solicitaste este código, puedes ignorar este mensaje.</p>
                   </div>`,
        };

        try {
            await this.mg.messages.create(domain, data);
        } catch (error) {
            console.error('Error sending email via Mailgun:', error);
            throw new Error('Could not send verification email');
        }
    }

    async sendPasswordResetCode(email: string, code: string, name: string): Promise<void> {
        if (!this.mg) {
            console.warn('Mailgun client not initialized. Skipping email.');
            return;
        }

        const domain = this.configService.get<string>('MAILGUN_DOMAIN');
        if (!domain) {
            console.warn('MAILGUN_DOMAIN not configured. Skipping email.');
            return;
        }

        const data = {
            from: `LasPrendas <notifications@${domain}>`,
            to: email,
            subject: 'Restablecer contraseña - Las Prendas',
            text: `Hola ${name},\n\nHas solicitado restablecer tu contraseña. Tu código de verificación es: ${code}\n\nEste código expirará en 10 minutos.`,
            html: `<div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
                    <h2>Hola ${name},</h2>
                    <p>Has solicitado restablecer tu contraseña en <b>Las Prendas</b>.</p>
                    <p>Tu código de verificación es:</p>
                    <h1 style="color: #6200EE; font-size: 32px; letter-spacing: 5px;">${code}</h1>
                    <p>Este código expirará en 10 minutos. Si no solicitaste este cambio, te recomendamos cambiar tu contraseña actual.</p>
                   </div>`,
        };

        try {
            await this.mg.messages.create(domain, data);
        } catch (error) {
            console.error('Error sending reset email via Mailgun:', error);
            throw new Error('Could not send reset email');
        }
    }
}
