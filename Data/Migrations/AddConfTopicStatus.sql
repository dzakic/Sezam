-- Migration: Add Status column to ConfTopics table
-- This enables tracking topic status (Deleted, Private, ReadOnly, Closed)

ALTER TABLE `ConfTopics` 
ADD COLUMN `Status` INT NOT NULL DEFAULT 0 AFTER `TopicNo`;

