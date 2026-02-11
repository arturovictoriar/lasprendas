import { Inject, Injectable, UnauthorizedException, ConflictException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { I_USER_REPOSITORY } from '../../domain/ports/user.repository.port';
import type { IUserRepository } from '../../domain/ports/user.repository.port';
import { User } from '../../domain/entities/user.entity';
import { RedisService } from '../../infrastructure/adapters/persistence/redis.service';
import { MailService } from '../../infrastructure/adapters/mail/mail.service';

@Injectable()
export class AuthService {
    constructor(
        @Inject(I_USER_REPOSITORY)
        private readonly userRepository: IUserRepository,
        private readonly jwtService: JwtService,
        private readonly redisService: RedisService,
        private readonly mailService: MailService,
    ) { }

    async register(email: string, pass: string, name: string): Promise<any> {
        const existingUser = await this.userRepository.findByEmail(email);
        if (existingUser) {
            throw new ConflictException('User already exists');
        }

        const salt = await bcrypt.genSalt();
        const hashedPassword = await bcrypt.hash(pass, salt);

        const newUser = new User(
            email,
            hashedPassword,
            name,
            new Date(),
            undefined, // id
            false,     // isVerified
            undefined, // lastCodeSentAt
            0,         // verificationAttempts
            undefined, // blockedUntil
            new Date(), // termsAcceptedAt
        );
        const savedUser = await this.userRepository.save(newUser);

        // Generar y enviar código de verificación
        await this.sendVerificationCode(savedUser);

        const { password, ...result } = savedUser;
        return result;
    }

    private async sendVerificationCode(user: User): Promise<void> {
        const code = this.generateCode();
        const hashedCode = await bcrypt.hash(code, 10);

        // Guardar hash en Redis con TTL de 10 min
        await this.redisService.setWithTTL(`verify:${user.id}`, hashedCode, 600);

        // Actualizar último envío
        user.lastCodeSentAt = new Date();
        await this.userRepository.save(user);

        // Enviar correo
        await this.mailService.sendVerificationCode(user.email, code, user.name);
    }

    private generateCode(): string {
        return Math.floor(100000 + Math.random() * 900000).toString();
    }

    async login(email: string, pass: string): Promise<{ access_token: string }> {
        const user = await this.userRepository.findByEmail(email);
        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }

        if (!user.isVerified) {
            throw new ForbiddenException('Account not verified');
        }

        if (user.blockedUntil && user.blockedUntil > new Date()) {
            throw new ForbiddenException(`Account blocked until ${user.blockedUntil.toISOString()}`);
        }

        const isMatch = await bcrypt.compare(pass, user.password);
        if (!isMatch) {
            throw new UnauthorizedException('Invalid credentials');
        }

        const payload = { email: user.email, sub: user.id, name: user.name };
        return {
            access_token: this.jwtService.sign(payload),
        };
    }

    async verify(email: string, code: string): Promise<any> {
        const user = await this.userRepository.findByEmail(email);
        if (!user) throw new BadRequestException('User not found');

        if (user.blockedUntil && user.blockedUntil > new Date()) {
            throw new ForbiddenException(`Account blocked until ${user.blockedUntil.toISOString()}`);
        }

        const hashedCode = await this.redisService.get(`verify:${user.id}`);
        if (!hashedCode) throw new BadRequestException('Code expired or invalid');

        const isMatch = await bcrypt.compare(code, hashedCode);
        if (!isMatch) {
            user.verificationAttempts++;
            if (user.verificationAttempts >= 3) {
                user.blockedUntil = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h
                user.verificationAttempts = 0;
                await this.redisService.delete(`verify:${user.id}`);
            }
            await this.userRepository.save(user);
            throw new BadRequestException('Invalid verification code');
        }

        user.isVerified = true;
        user.verificationAttempts = 0;
        user.blockedUntil = undefined;
        await this.userRepository.save(user);
        await this.redisService.delete(`verify:${user.id}`);

        // Devolver token para login automático tras verificación
        const payload = { email: user.email, sub: user.id, name: user.name };
        return {
            access_token: this.jwtService.sign(payload),
        };
    }

    async resendCode(email: string): Promise<void> {
        const user = await this.userRepository.findByEmail(email);
        if (!user) throw new BadRequestException('User not found');

        if (user.lastCodeSentAt && Date.now() - user.lastCodeSentAt.getTime() < 24 * 60 * 60 * 1000) {
            // Check if it's already been sent today (simple daily limit as requested)
            // But let's be more specific: "at least once a day" could mean "only once a day" or "one resend available per day"
            // The requirement was: "reenviar el codigo una vez al dia?"
            throw new BadRequestException('Code can only be resent once every 24 hours');
        }

        await this.sendVerificationCode(user);
    }

    async forgotPassword(email: string): Promise<void> {
        const user = await this.userRepository.findByEmail(email);
        if (!user) return; // Silent return for security

        // Reiniciar intentos cuando se genera un nuevo código
        user.verificationAttempts = 0;
        await this.userRepository.save(user);

        const code = this.generateCode();
        const hashedCode = await bcrypt.hash(code, 10);
        await this.redisService.setWithTTL(`reset:${user.id}`, hashedCode, 600);
        await this.mailService.sendPasswordResetCode(user.email, code, user.name);
    }

    async verifyResetCode(email: string, code: string): Promise<void> {
        const user = await this.userRepository.findByEmail(email);
        if (!user) throw new BadRequestException('User not found');

        const hashedCode = await this.redisService.get(`reset:${user.id}`);
        if (!hashedCode) throw new BadRequestException('Code expired or invalid');

        const isMatch = await bcrypt.compare(code, hashedCode);
        if (!isMatch) {
            user.verificationAttempts++;
            if (user.verificationAttempts >= 3) {
                user.verificationAttempts = 0;
                await this.redisService.delete(`reset:${user.id}`);
                await this.userRepository.save(user);
                throw new BadRequestException('Too many failed attempts. Code invalidated.');
            }
            await this.userRepository.save(user);
            throw new BadRequestException('Invalid code');
        }

        user.verificationAttempts = 0;
        await this.userRepository.save(user);

        // Reiniciar TTL a 10 minutos para dar tiempo a escribir la nueva contraseña
        await this.redisService.setWithTTL(`reset:${user.id}`, hashedCode, 600);
    }

    async resetPassword(email: string, code: string, newPass: string): Promise<void> {
        const user = await this.userRepository.findByEmail(email);
        if (!user) throw new BadRequestException('User not found');

        const hashedCode = await this.redisService.get(`reset:${user.id}`);
        if (!hashedCode) throw new BadRequestException('Code expired or invalid');

        const isMatch = await bcrypt.compare(code, hashedCode);
        if (!isMatch) {
            user.verificationAttempts++;
            if (user.verificationAttempts >= 3) {
                user.verificationAttempts = 0;
                await this.redisService.delete(`reset:${user.id}`);
                await this.userRepository.save(user);
                throw new BadRequestException('Too many failed attempts. Code invalidated.');
            }
            await this.userRepository.save(user);
            throw new BadRequestException('Invalid code');
        }

        const salt = await bcrypt.genSalt();
        const hashedPassword = await bcrypt.hash(newPass, salt);

        user.password = hashedPassword;
        user.isVerified = true;
        user.verificationAttempts = 0;
        await this.userRepository.save(user);
        await this.redisService.delete(`reset:${user.id}`);
    }

    async validateUser(payload: any): Promise<any> {
        return await this.userRepository.findById(payload.sub);
    }

    async getProfile(userId: string): Promise<any> {
        const user = await this.userRepository.findById(userId);
        if (!user) {
            throw new UnauthorizedException('User not found');
        }
        const { password, ...result } = user;
        return result;
    }
}
