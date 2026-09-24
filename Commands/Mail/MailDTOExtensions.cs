using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.EntityFrameworkCore;
using Sezam.Data;
using Sezam.Data.EF;

namespace Sezam.Commands
{
    // Client-side formatting helpers for mail DTOs. The query is filtered and streamed
    // server-side; these methods only format the already-loaded entity for display.
    public static class MailDTOExtensions
    {
        // Accepts the Guid directly (never .ToString() inside a LINQ projection): EF Core
        // would translate Guid.ToString() to MySQL CONVERT(Id, CHAR(36)), which returns the
        // raw binary bytes as a Latin1 string, not the GUID string form. Evaluating in C#
        // after materialization yields the real GUID string, so the last-4-hex moniker is correct.
        public static string GetGuidSuffix(Guid guid)
        {
            if (guid == default(Guid))
            {
                return "0000";
            }

            string guidString = guid.ToString();
            return guidString.Length >= 4
                ? guidString.Substring(guidString.Length - 4)
                : guidString;
        }

        public static string GetHeaderPrefix(int senderId, int recipientId, string senderUsername, string recipientUsername, int currentUserId)
        {
            if (senderId == currentUserId)
            {
                return $"To: {recipientUsername}";
            }

            if (recipientId == currentUserId)
            {
                return $"From: {senderUsername}";
            }

            return "Unknown Party";
        }

        public static string GetUsernameSafe(User user)
        {
            if (user == null) return "Unknown";
            return user.Username;
        }
    }
}
