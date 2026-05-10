-- ============================================================
-- Migration: Add User Profile Fields
-- Run this against [MangaLibrary] database
-- Safe: Uses IF NOT EXISTS checks, no data loss
-- ============================================================

-- Add Bio column
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'User' AND COLUMN_NAME = 'Bio'
)
BEGIN
    ALTER TABLE dbo.[User] ADD Bio NVARCHAR(500) NULL;
    PRINT 'Added Bio column';
END;

-- Add DisplayName column
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'User' AND COLUMN_NAME = 'DisplayName'
)
BEGIN
    ALTER TABLE dbo.[User] ADD DisplayName NVARCHAR(100) NULL;
    PRINT 'Added DisplayName column';
END;

-- Add AvatarObjectKey column (MinIO object key)
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'User' AND COLUMN_NAME = 'AvatarObjectKey'
)
BEGIN
    ALTER TABLE dbo.[User] ADD AvatarObjectKey NVARCHAR(500) NULL;
    PRINT 'Added AvatarObjectKey column';
END;

-- Add UpdatedAt column
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'User' AND COLUMN_NAME = 'UpdatedAt'
)
BEGIN
    ALTER TABLE dbo.[User] ADD UpdatedAt DATETIME2 NULL;
    PRINT 'Added UpdatedAt column';
END;

PRINT 'User profile migration complete.';
