-- ============================================================
-- Migration: Chat System Tables
-- Run this against [MangaLibrary] database
-- Safe: Uses IF NOT EXISTS checks
-- ============================================================

-- ChatRoom
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChatRoom')
BEGIN
    CREATE TABLE dbo.ChatRoom (
        RoomId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        Type NVARCHAR(20) NOT NULL DEFAULT 'direct',  -- 'direct', 'group'
        Name NVARCHAR(200) NULL,
        AvatarUrl NVARCHAR(500) NULL,
        CreatedBy UNIQUEIDENTIFIER NULL REFERENCES dbo.[User](UserId),
        CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created ChatRoom table';
END;

-- ChatRoomMember
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChatRoomMember')
BEGIN
    CREATE TABLE dbo.ChatRoomMember (
        RoomId UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.ChatRoom(RoomId) ON DELETE CASCADE,
        UserId UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.[User](UserId),
        JoinedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
        Role NVARCHAR(20) DEFAULT 'member',  -- 'admin', 'member'
        LastReadAt DATETIME2 NULL,
        Nickname NVARCHAR(100) NULL,
        IsMuted BIT DEFAULT 0,
        PRIMARY KEY (RoomId, UserId)
    );
    PRINT 'Created ChatRoomMember table';
END;

-- ChatMessage
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'ChatMessage')
BEGIN
    CREATE TABLE dbo.ChatMessage (
        MessageId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        RoomId UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.ChatRoom(RoomId) ON DELETE CASCADE,
        SenderId UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.[User](UserId),
        Content NVARCHAR(MAX) NULL,
        MessageType NVARCHAR(20) DEFAULT 'text',  -- 'text', 'image', 'system'
        MediaUrl NVARCHAR(500) NULL,
        ReplyToId UNIQUEIDENTIFIER NULL,  -- Self-reference for replies
        Status NVARCHAR(20) DEFAULT 'sent',  -- 'sent', 'delivered', 'read'
        CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
        EditedAt DATETIME2 NULL,
        IsDeleted BIT DEFAULT 0
    );
    PRINT 'Created ChatMessage table';
    
    -- Index for message history queries
    CREATE INDEX IX_ChatMessage_RoomId_CreatedAt ON dbo.ChatMessage(RoomId, CreatedAt DESC);
    CREATE INDEX IX_ChatMessage_SenderId ON dbo.ChatMessage(SenderId);
END;

-- Friendship
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Friendship')
BEGIN
    CREATE TABLE dbo.Friendship (
        UserId UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.[User](UserId),
        FriendId UNIQUEIDENTIFIER NOT NULL REFERENCES dbo.[User](UserId),
        Status NVARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending', 'accepted', 'blocked'
        CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME(),
        PRIMARY KEY (UserId, FriendId)
    );
    PRINT 'Created Friendship table';
END;

-- UserPresence
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'UserPresence')
BEGIN
    CREATE TABLE dbo.UserPresence (
        UserId UNIQUEIDENTIFIER PRIMARY KEY REFERENCES dbo.[User](UserId),
        IsOnline BIT DEFAULT 0,
        LastSeenAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );
    PRINT 'Created UserPresence table';
END;

PRINT 'Chat system migration complete.';
