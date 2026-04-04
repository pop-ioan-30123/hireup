import { Module } from '@nestjs/common';
import { MessagesController } from './messages.controller';
import { MessagesService } from './messages.service';
import { SocialModule } from '../social/social.module';

@Module({
  imports: [SocialModule],
  controllers: [MessagesController],
  providers: [MessagesService],
})
export class MessagesModule {}
