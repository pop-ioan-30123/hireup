export declare class PostMessageDto {
    messageKind?: 'text' | 'system';
    ciphertext: string;
    algorithm?: string;
    nonce?: string;
    metadata?: string;
    clientMessageId?: string;
}
