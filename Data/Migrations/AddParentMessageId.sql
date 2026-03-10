-- Migration: Add ParentMessageId column to ConfMessages table
-- This enables the self-referencing relationship for replies

ALTER TABLE `ConfMessages` 
ADD COLUMN `ParentMessageId` INT NULL AFTER `MsgNo`,
ADD INDEX `IX_ConfMessages_ParentMessageId` (`ParentMessageId`),
ADD CONSTRAINT `FK_ConfMessages_ConfMessages_ParentMessageId` 
    FOREIGN KEY (`ParentMessageId`) 
    REFERENCES `ConfMessages` (`Id`) 
    ON DELETE RESTRICT;
