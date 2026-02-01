import { Controller, Post, Body, HttpCode, HttpStatus, UseGuards, Get, Request } from '@nestjs/common';
import { AuthService } from '../../application/services/auth.service';
import { ThrottlerGuard, Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../adapters/auth/jwt-auth.guard';

@Controller('auth')
@UseGuards(ThrottlerGuard)
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    @Throttle({ default: { limit: 3, ttl: 60000 } })
    @Post('register')
    async register(@Body() body: any) {
        return await this.authService.register(body.email, body.password, body.name);
    }

    @HttpCode(HttpStatus.OK)
    @Post('login')
    async login(@Body() body: any) {
        return await this.authService.login(body.email, body.password);
    }

    @UseGuards(JwtAuthGuard)
    @Get('me')
    async getProfile(@Request() req: any) {
        return await this.authService.getProfile(req.user.userId);
    }
}
