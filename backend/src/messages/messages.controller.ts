import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedRequest, JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateDmConversationDto } from './dto/create-dm-conversation.dto';
import { CreateGroupConversationDto } from './dto/create-group-conversation.dto';
import { ListMessagesQueryDto } from './dto/list-messages-query.dto';
import { PostMessageDto } from './dto/post-message.dto';
import { SetMessageReactionDto } from './dto/set-message-reaction.dto';
import { UpdateMessageDto } from './dto/update-message.dto';
import { MessagesService } from './messages.service';

@Controller('messages')
@UseGuards(JwtAuthGuard)
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get('conversations')
  async listConversations(@Req() req: AuthenticatedRequest) {
    return this.messagesService.listConversations(req.user!.id, req.auditContext);
  }

  @Post('conversations/dm')
  async createDirectConversation(
    @Req() req: AuthenticatedRequest,
    @Body() payload: CreateDmConversationDto,
  ) {
    return this.messagesService.createDirectConversation(
      req.user!.id,
      payload,
      req.auditContext,
    );
  }

  @Post('conversations/group')
  async createGroupConversation(
    @Req() req: AuthenticatedRequest,
    @Body() payload: CreateGroupConversationDto,
  ) {
    return this.messagesService.createGroupConversation(
      req.user!.id,
      payload,
      req.auditContext,
    );
  }

  @Get('conversations/:conversationId/messages')
  async listMessages(
    @Req() req: AuthenticatedRequest,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Query() query: ListMessagesQueryDto,
  ) {
    return this.messagesService.listMessages(
      req.user!.id,
      conversationId,
      query,
      req.auditContext,
    );
  }

  @Post('conversations/:conversationId/messages')
  async postMessage(
    @Req() req: AuthenticatedRequest,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Body() payload: PostMessageDto,
  ) {
    return this.messagesService.postMessage(
      req.user!.id,
      conversationId,
      payload,
      req.auditContext,
    );
  }

  @Patch('conversations/:conversationId/messages/:messageId')
  async updateMessage(
    @Req() req: AuthenticatedRequest,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
    @Body() payload: UpdateMessageDto,
  ) {
    return this.messagesService.updateMessage(
      req.user!.id,
      conversationId,
      messageId,
      payload,
      req.auditContext,
    );
  }

  @Post('conversations/:conversationId/messages/:messageId/reaction')
  async setMessageReaction(
    @Req() req: AuthenticatedRequest,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
    @Body() payload: SetMessageReactionDto,
  ) {
    return this.messagesService.setMessageReaction(
      req.user!.id,
      conversationId,
      messageId,
      payload,
      req.auditContext,
    );
  }

  @Delete('conversations/:conversationId/messages/:messageId')
  async deleteMessage(
    @Req() req: AuthenticatedRequest,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
    @Param('messageId', new ParseUUIDPipe()) messageId: string,
    @Query('scope') scope?: string,
  ) {
    return this.messagesService.deleteMessage(
      req.user!.id,
      conversationId,
      messageId,
      scope,
      req.auditContext,
    );
  }

  @Post('conversations/:conversationId/read')
  async markConversationRead(
    @Req() req: AuthenticatedRequest,
    @Param('conversationId', new ParseUUIDPipe()) conversationId: string,
  ) {
    return this.messagesService.markConversationRead(
      req.user!.id,
      conversationId,
      req.auditContext,
    );
  }
}
