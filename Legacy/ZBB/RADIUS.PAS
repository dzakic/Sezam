(*
 *
 *  RADIUS
 *  Remote Authentication Dial In User Service
 *
 *
 *  Livingston Enterprises, Inc.
 *  6920 Koll Center Parkway
 *  Pleasanton, CA   94566
 *
 *  Copyright 1992 Livingston Enterprises, Inc.
 *
 *  Permission to use, copy, modify, and distribute this software for any
 *  purpose and without fee is hereby granted, provided that this
 *  copyright and permission notice appear on all copies and supporting
 *  documentation, the name of Livingston Enterprises, Inc. not be used
 *  in advertising or publicity pertaining to distribution of the
 *  program without specific prior permission, and notice be given
 *  in supporting documentation that copying and distribution is by
 *  permission of Livingston Enterprises, Inc.
 *
 *  Livingston Enterprises, Inc. makes no representations about
 *  the suitability of this software for any purpose.  It is
 *  provided "as is" without express or implied warranty.
 *
 *)

/*************************************************************************
 *
 *  Function: radrecv
 *
 *  Purpose: Receive UDP client requests, build an authorization request
 *     structure, and attach attribute-value pairs contained in
 *     the request to the new structure.
 *
 *************************************************************************/

  authreq->ipaddr = host;
  authreq->udp_port = udp_port;
  authreq->id = auth->id;
  authreq->code = auth->code;
  memcpy(authreq->vector, auth->vector, AUTH_VECTOR_LEN);

  /*
   * Extract attribute-value pairs
   */
  ptr = auth->data;
  length -= AUTH_HDR_LEN;
  first_pair = (VALUE_PAIR *)NULL;
  prev = (VALUE_PAIR *)NULL;

  while(length > 0) {

    attribute = *ptr++;
    attrlen = *ptr++;
    if(attrlen < 2) {
      length = 0;
      continue;
    }
    attrlen -= 2;
    if((attr = dict_attrget(attribute)) == (DICT_ATTR *)NULL) {
      DEBUG("Received unknown attribute %d\n", attribute);
    }
    else if ( attrlen >= AUTH_STRING_LEN ) {
      DEBUG("attribute %d too long, %d >= %d\n", attribute,
        attrlen, AUTH_STRING_LEN);
    }
    else {
      if((pair = (VALUE_PAIR *)malloc(sizeof(VALUE_PAIR))) ==
            (VALUE_PAIR *)NULL) {
        fprintf(stderr, "%s: no memory\n",
            progname);
        exit(-1);
      }
      strcpy(pair->name, attr->name);
      pair->attribute = attr->value;
      pair->type = attr->type;
      pair->next = (VALUE_PAIR *)NULL;

      switch(attr->type) {

      case PW_TYPE_STRING:
        memcpy(pair->strvalue, ptr, attrlen);
        pair->strvalue[attrlen] = '\0';
        debug_pair(stdout, pair);
        if(first_pair == (VALUE_PAIR *)NULL) {
          first_pair = pair;
        }
        else {
          prev->next = pair;
        }
        prev = pair;
        break;

      case PW_TYPE_INTEGER:
      case PW_TYPE_IPADDR:
        memcpy(&lvalue, ptr, sizeof(UINT4));
        pair->lvalue = ntohl(lvalue);
        debug_pair(stdout, pair);
        if(first_pair == (VALUE_PAIR *)NULL) {
          first_pair = pair;
        }
        else {
          prev->next = pair;
        }
        prev = pair;
        break;

      default:
        DEBUG("    %s (Unknown Type %d)\n", attr->name,attr->type);
        free(pair);
        break;
      }

    }
    ptr += attrlen;
    length -= attrlen + 2;
  }
  authreq->request = first_pair;
  return(authreq);
}

/*************************************************************************
 *
 *  Function: radrespond
 *
 *  Purpose: Respond to supported requests:
 *
 *     PW_AUTHENTICATION_REQUEST - Authentication request from
 *        a client network access server.
 *
 *     PW_ACCOUNTING_REQUEST - Accounting request from
 *        a client network access server.
 *
 *     PW_PASSWORD_REQUEST - User request to change a password.
 *
 *************************************************************************/

radrespond(authreq, activefd)
AUTH_REQ  *authreq;
int   activefd;
{
  switch(authreq->code) {

  case PW_AUTHENTICATION_REQUEST:
    if(spawn_flag) {
      rad_spawn_child(authreq, activefd);
    }
    else {
      rad_authenticate(authreq, activefd);
    }
    break;

  case PW_ACCOUNTING_REQUEST:
    rad_accounting(authreq, activefd);
    break;

  case PW_PASSWORD_REQUEST:
    rad_passchange(authreq, activefd);
    break;

  default:
    break;
  }
  return(0);
}



/*************************************************************************
 *
 *  Function: rad_spawn_child
 *
 *  Purpose: Spawns child processes to perform password authentication
 *     and respond to RADIUS clients.  This functions also
 *     cleans up complete child requests, and verifies that there
 *     is only one process responding to each request (duplicate
 *     requests are filtered out.
 *
 *************************************************************************/

rad_spawn_child(authreq, activefd)
AUTH_REQ  *authreq;
int   activefd;
{
  AUTH_REQ  *curreq;
  AUTH_REQ  *prevreq;
  UINT4   curtime;
  int   request_count;
  char    msg[128];
  char    *ip_hostname();
  int   child_pid;

  curtime = (UINT4)time(0);
  request_count = 0;
  curreq = first_request;
  prevreq = (AUTH_REQ *)NULL;
  while(curreq != (AUTH_REQ *)NULL) {
    if(curreq->child_pid == -1 &&
        curreq->timestamp + CLEANUP_DELAY <= curtime) {
      /* Request completed, delete it */
      if(prevreq == (AUTH_REQ *)NULL) {
        first_request = curreq->next;
        pairfree(curreq->request);
        free(curreq);
        curreq = first_request;
      }
      else {
        prevreq->next = curreq->next;
        pairfree(curreq->request);
        free(curreq);
        curreq = prevreq->next;
      }
    }
    else if(curreq->ipaddr == authreq->ipaddr &&
          curreq->id == authreq->id) {
      /* This is a duplicate request - just drop it */
      sprintf(msg, "Dropping duplicate: from %s - ID: %d\n",
        ip_hostname(authreq->ipaddr), authreq->id);
      log_err(msg);
      pairfree(authreq->request);
      free(authreq);
      return(0);
    }
    else {
      if(curreq->timestamp + MAX_REQUEST_TIME <= curtime &&
            curreq->child_pid != -1) {
        /* This request seems to have hung - kill it */
        child_pid = curreq->child_pid;
        sprintf(msg,
          "Killing unresponsive child pid %d\n",
                child_pid);
        log_err(msg);
        curreq->child_pid = -1;
        kill(child_pid, SIGHUP);
      }
      prevreq = curreq;
      curreq = curreq->next;
      request_count++;
    }
  }

  /* This is a new request */
  if(request_count > MAX_REQUESTS) {
    sprintf(msg, "Dropping request (too many): from %s - ID: %d\n",
        ip_hostname(authreq->ipaddr), authreq->id);
    log_err(msg);
    pairfree(authreq->request);
    free(authreq);
    return(0);
  }

  /* Add this request to the list */
  authreq->next = (AUTH_REQ *)NULL;
  authreq->child_pid = -1;
  authreq->timestamp = curtime;

  if(prevreq == (AUTH_REQ *)NULL) {
    first_request = authreq;
  }
  else {
    prevreq->next = authreq;
  }

  /* fork our child */
  child_pid = fork();
  if(child_pid < 0) {
    sprintf(msg, "Fork failed for request from %s - ID: %d\n",
        ip_hostname(authreq->ipaddr), authreq->id);
    log_err(msg);
  }
  if(child_pid == 0) {
    /* This is the child, it should go ahead and respond */
    rad_authenticate(authreq, activefd);
    exit(0);
  }

  /* Register the Child */
  authreq->child_pid = child_pid;
  return(0);
}

void
sig_cleanup()
{
  int   status;
        pid_t   pid;
  AUTH_REQ  *curreq;

        for (;;) {
    pid = waitpid((pid_t)-1,&status,WNOHANG);
    signal(SIGCHLD, sig_cleanup);
                if (pid <= 0)
                        return;

#if defined (aix)
    kill(pid, SIGKILL);
#endif

    if(pid == acct_pid) {
      sig_fatal(100);
    }
    curreq = first_request;
    while(curreq != (AUTH_REQ *)NULL) {
      if(curreq->child_pid == pid) {
        curreq->child_pid = -1;
        curreq->timestamp = (UINT4)time(0);
        break;
      }
      curreq = curreq->next;
    }
        }
}

/*************************************************************************
 *
 *  Function: rad_passchange
 *
 *  Purpose: Change a users password
 *
 *************************************************************************/

void
rad_passchange(authreq, activefd)
AUTH_REQ  *authreq;
int   activefd;
{
  VALUE_PAIR  *namepair;
  VALUE_PAIR  *check_item;
  VALUE_PAIR  *newpasspair;
  VALUE_PAIR  *oldpasspair;
  VALUE_PAIR  *curpass;
  VALUE_PAIR  *user_check;
  VALUE_PAIR  *user_reply;
  char    pw_digest[16];
  char    string[64];
  char    passbuf[AUTH_PASS_LEN];
  int   i;
  int   secretlen;
  char    msg[128];
  char    *ip_hostname();

  /* Get the username */
  namepair = authreq->request;
  while(namepair != (VALUE_PAIR *)NULL) {
    if(namepair->attribute == PW_USER_NAME) {
      break;
    }
    namepair = namepair->next;
  }
  if(namepair == (VALUE_PAIR *)NULL) {
    sprintf(msg,
      "Passchange: from %s - No User name supplied\n",
      ip_hostname(authreq->ipaddr));
    log_err(msg);
    pairfree(authreq->request);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /*
   * Look the user up in the database
   */
  if(user_find(namepair->strvalue, &user_check, &user_reply) != 0) {
    sprintf(msg,
      "Passchange: from %s - Invalid User: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    send_reject(authreq, (char *)NULL, activefd);
    pairfree(authreq->request);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /*
   * Validate the user -
   *
   * We have to unwrap this in a special way to decrypt the
   * old and new passwords.  The MD5 calculation is based
   * on the old password.  The vector is different.  The old
   * password is encrypted using the encrypted new password
   * as its vector.  The new password is encrypted using the
   * random encryption vector in the request header.
   */

  /* Extract the attr-value pairs for the old and new passwords */
  check_item = authreq->request;
  while(check_item != (VALUE_PAIR *)NULL) {
    if(check_item->attribute == PW_PASSWORD) {
      newpasspair = check_item;
    }
    else if(check_item->attribute == PW_OLD_PASSWORD) {
      oldpasspair = check_item;
    }
    check_item = check_item->next;
  }

  /* Verify that both encrypted passwords were supplied */
  if(newpasspair == (VALUE_PAIR *)NULL ||
          oldpasspair == (VALUE_PAIR *)NULL) {
    /* Missing one of the passwords */
    sprintf(msg,
      "Passchange: from %s - Missing Password: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    send_reject(authreq, (char *)NULL, activefd);
    pairfree(authreq->request);
    pairfree(user_check);
    pairfree(user_reply);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /* Get the current password from the database */
  curpass = user_check;
  while(curpass != (VALUE_PAIR *)NULL) {
    if(curpass->attribute == PW_PASSWORD) {
      break;
    }
    curpass = curpass->next;
  }
  if((curpass == (VALUE_PAIR *)NULL) || curpass->strvalue == (char *)NULL) {
    /* Missing our local copy of the password */
    sprintf(msg,
      "Passchange: from %s - Missing Local Password: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    send_reject(authreq, (char *)NULL, activefd);
    pairfree(authreq->request);
    pairfree(user_check);
    pairfree(user_reply);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }
  if(strcmp(curpass->strvalue,"UNIX") == 0) {
    /* Can't change passwords that aren't in users file */
    sprintf(msg,
      "Passchange: from %s - system password change not allowed: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    send_reject(authreq, (char *)NULL, activefd);
    pairfree(authreq->request);
    pairfree(user_check);
    pairfree(user_reply);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /* Decrypt the old password */
  secretlen = strlen(curpass->strvalue);
  memcpy(string, curpass->strvalue, secretlen);
  memcpy(string + secretlen, newpasspair->strvalue, AUTH_VECTOR_LEN);
  md5_calc(pw_digest, string, AUTH_VECTOR_LEN + secretlen);
  memcpy(passbuf, oldpasspair->strvalue, AUTH_PASS_LEN);
  for(i = 0;i < AUTH_PASS_LEN;i++) {
    passbuf[i] ^= pw_digest[i];
  }

  /* Did they supply the correct password ??? */
  if(strncmp(passbuf, curpass->strvalue, AUTH_PASS_LEN) != 0) {
    sprintf(msg,
      "Passchange: from %s - Incorrect Password: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    send_reject(authreq, (char *)NULL, activefd);
    pairfree(authreq->request);
    pairfree(user_check);
    pairfree(user_reply);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /* Decrypt the new password */
  memcpy(string, curpass->strvalue, secretlen);
  memcpy(string + secretlen, authreq->vector, AUTH_VECTOR_LEN);
  md5_calc(pw_digest, string, AUTH_VECTOR_LEN + secretlen);
  memcpy(passbuf, newpasspair->strvalue, AUTH_PASS_LEN);
  for(i = 0;i < AUTH_PASS_LEN;i++) {
    passbuf[i] ^= pw_digest[i];
  }

  /* Update the users password */
  strncpy(curpass->strvalue, passbuf, AUTH_PASS_LEN);

  /* Add a new expiration date if we are aging passwords */
  if(expiration_seconds != (UINT4)0) {
    set_expiration(user_check, expiration_seconds);
  }

  /* Update the database */
  if(user_update(namepair->strvalue, user_check, user_reply) != 0) {
    send_reject(authreq, (char *)NULL, activefd);
    sprintf(msg,
      "Passchange: unable to update password for %s\n",
      namepair->strvalue);
    log_err(msg);

  }
  else {
    send_pwack(authreq, activefd);
  }
  pairfree(authreq->request);
  pairfree(user_check);
  pairfree(user_reply);
  memset(authreq, 0, sizeof(AUTH_REQ));
  free(authreq);
  return;
}

/*************************************************************************
 *
 *  Function: rad_authenticate
 *
 *  Purpose: Process and reply to an authentication request
 *
 *************************************************************************/

rad_authenticate(authreq, activefd)
AUTH_REQ  *authreq;
int   activefd;
{
  VALUE_PAIR  *namepair;
  VALUE_PAIR  *check_item;
  VALUE_PAIR  *auth_item;
  VALUE_PAIR  *user_check;
  VALUE_PAIR  *user_reply;
  int   result;
  char    pw_digest[16];
  char    string[128];
  int   i;
  char    msg[128];
  char    umsg[128];
  char    *user_msg;
  char    *ip_hostname();
  int   retval;
  char    *ptr;

  /* Get the username from the request */
  namepair = authreq->request;
  while(namepair != (VALUE_PAIR *)NULL) {
    if(namepair->attribute == PW_USER_NAME) {
      break;
    }
    namepair = namepair->next;
  }
  if((namepair == (VALUE_PAIR *)NULL) ||
     (strlen(namepair->strvalue) <= 0)) {
    sprintf(msg, "Authenticate: from %s - No User Name\n",
      ip_hostname(authreq->ipaddr));
    log_err(msg);
    pairfree(authreq->request);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /* Verify the client and Calculate the MD5 Password Digest */
  if(calc_digest(pw_digest, authreq) != 0) {
    /* We dont respond when this fails */
    sprintf(msg, "Authenticate: from %s - Security Breach: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    pairfree(authreq->request);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /* Get the user from the database */
  if(user_find(namepair->strvalue, &user_check, &user_reply) != 0) {
    sprintf(msg, "Authenticate: from %s - Invalid User: %s\n",
      ip_hostname(authreq->ipaddr), namepair->strvalue);
    log_err(msg);
    send_reject(authreq, (char *)NULL, activefd);
    pairfree(authreq->request);
    memset(authreq, 0, sizeof(AUTH_REQ));
    free(authreq);
    return;
  }

  /* Validate the user */

  /* Look for matching check items */
  result = 0;
  user_msg = (char *)NULL;
  check_item = user_check;
  while(result == 0 && check_item != (VALUE_PAIR *)NULL) {

    /*
     * Check expiration date if we are doing password aging.
     */
    if(check_item->attribute == PW_EXPIRATION) {
      /* Has this user's password expired */
      retval = pw_expired(check_item->lvalue);
      if(retval < 0) {
        result = -1;
        user_msg = "Password Has Expired\r\n";
      }
      else {
        if(retval > 0) {
          sprintf(umsg,
            "Password Will Expire in %d Days\r\n",
            retval);
          user_msg = umsg;
        }
        check_item = check_item->next;
      }
      continue;
    }

    /*
     * Look for the matching attribute in the request.
     */
    auth_item = authreq->request;
    while(auth_item != (VALUE_PAIR *)NULL) {
      if(check_item->attribute == auth_item->attribute) {
        break;
      }
      if(check_item->attribute == PW_PASSWORD &&
             auth_item->attribute == PW_CHAP_PASSWORD) {
        break;
      }

      auth_item = auth_item->next;
    }
    if(auth_item == (VALUE_PAIR *)NULL) {
      result = -1;
      continue;
    }

    /*
     * Special handling for passwords which are encrypted,
     * and sometimes authenticated against the UNIX passwd database.
     * Also they can come using the Three-Way CHAP.
     *
     */
    if(check_item->attribute == PW_PASSWORD) {
      if(auth_item->attribute == PW_CHAP_PASSWORD) {
        /* Use MD5 to verify */
        ptr = string;
        *ptr++ = *auth_item->strvalue;
        strcpy(ptr, check_item->strvalue);
        ptr += strlen(check_item->strvalue);
        memcpy(ptr, authreq->vector, AUTH_VECTOR_LEN);
        md5_calc(pw_digest, string,
          1 + CHAP_VALUE_LENGTH +
          strlen(check_item->strvalue));
        /* Compare them */
        if(memcmp(pw_digest, auth_item->strvalue + 1,
            CHAP_VALUE_LENGTH) != 0) {
          result = -1;
        }
      }
      else {
        /* Decrypt the password */
        memcpy(string,
          auth_item->strvalue, AUTH_PASS_LEN);
        for(i = 0;i < AUTH_PASS_LEN;i++) {
          string[i] ^= pw_digest[i];
        }
        string[AUTH_PASS_LEN] = '\0';
        /* Test Code for Challenge */
        if(strcmp(string, "challenge") == 0) {
          send_challenge(authreq,
        "You want me to challenge you??\r\nOkay I will",
            "1",activefd);
          pairfree(authreq->request);
          memset(authreq, 0, sizeof(AUTH_REQ));
          free(authreq);
          return;
        }
        if(strcmp(check_item->strvalue, "UNIX") == 0) {
          if(unix_pass(namepair->strvalue,
                string) != 0) {
            result = -1;
            user_msg = (char *)NULL;
          }
        }
        else if(strcmp(check_item->strvalue,
                string) != 0) {
          result = -1;
          user_msg = (char *)NULL;
        }
      }
    }
    else {
      switch(check_item->type) {

      case PW_TYPE_STRING:
        if(strcmp(check_item->strvalue,
            auth_item->strvalue) != 0) {
          result = -1;
        }
        break;

      case PW_TYPE_INTEGER:
      case PW_TYPE_IPADDR:
        if(check_item->lvalue != auth_item->lvalue) {
          result = -1;
        }
        break;

      default:
        result = -1;
        break;
      }
    }
    check_item = check_item->next;
  }
  if(result != 0) {
    send_reject(authreq, user_msg, activefd);
  }
  else {
    send_accept(authreq, user_reply, user_msg, activefd);
  }
  pairfree(authreq->request);
  memset(authreq, 0, sizeof(AUTH_REQ));
  free(authreq);
  pairfree(user_check);
  pairfree(user_reply);
  return;
}

/*************************************************************************
 *
 *  Function: send_reject
 *
 *  Purpose: Reply to the request with a REJECT.  Also attach
 *     any user message provided.
 *
 *************************************************************************/

send_reject(authreq, msg, activefd)
AUTH_REQ  *authreq;
char    *msg;
int   activefd;
{
  AUTH_HDR    *auth;
  struct  sockaddr  saremote;
  struct  sockaddr_in *sin;
  char      *ip_hostname();
  char      digest[AUTH_VECTOR_LEN];
  int     secretlen;
  int     total_length;
  u_char      *ptr;
  int     len;

  auth = (AUTH_HDR *)send_buffer;

  /* Build standard response header */
  if(authreq->code == PW_PASSWORD_REQUEST) {
    auth->code = PW_PASSWORD_REJECT;
  }
  else {
    auth->code = PW_AUTHENTICATION_REJECT;
  }
  auth->id = authreq->id;
  memcpy(auth->vector, authreq->vector, AUTH_VECTOR_LEN);
  total_length = AUTH_HDR_LEN;

  /* Append the user message */
  if(msg != (char *)NULL) {
    len = strlen(msg);
    if(len > 0 && len < AUTH_STRING_LEN) {
      ptr = auth->data;
      *ptr++ = PW_PORT_MESSAGE;
      *ptr++ = len + 2;
      memcpy(ptr, msg, len);
      ptr += len;
      total_length += len + 2;
    }
  }

  /* Set total length in the header */
  auth->length = htons(total_length);

  /* Calculate the response digest */
  secretlen = strlen(authreq->secret);
  memcpy(send_buffer + total_length, authreq->secret, secretlen);
  md5_calc(digest, (char *)auth, total_length + secretlen);
  memcpy(auth->vector, digest, AUTH_VECTOR_LEN);
  memset(send_buffer + total_length, 0, secretlen);

  sin = (struct sockaddr_in *) &saremote;
        memset ((char *) sin, '\0', sizeof (saremote));
  sin->sin_family = AF_INET;
  sin->sin_addr.s_addr = htonl(authreq->ipaddr);
  sin->sin_port = htons(authreq->udp_port);

  DEBUG("Sending Reject of id %d to %lx (%s)\n",
    authreq->id, (u_long)authreq->ipaddr,
    ip_hostname(authreq->ipaddr));

  /* Send it to the user */
  sendto(activefd, (char *)auth, (int)total_length, (int)0,
      (struct sockaddr *) &saremote, sizeof(struct sockaddr_in));
}

/*************************************************************************
 *
 *  Function: send_challenge
 *
 *  Purpose: Reply to the request with a CHALLENGE.  Also attach
 *     any user message provided and a state value.
 *
 *************************************************************************/

send_challenge(authreq, msg, state, activefd)
AUTH_REQ  *authreq;
char    *msg;
char    *state;
int   activefd;
{
  AUTH_HDR    *auth;
  struct  sockaddr_in saremote;
  struct  sockaddr_in *sin;
  char      *ip_hostname();
  char      digest[AUTH_VECTOR_LEN];
  int     secretlen;
  int     total_length;
  u_char      *ptr;
  int     len;

  auth = (AUTH_HDR *)send_buffer;

  /* Build standard response header */
  auth->code = PW_ACCESS_CHALLENGE;
  auth->id = authreq->id;
  memcpy(auth->vector, authreq->vector, AUTH_VECTOR_LEN);
  total_length = AUTH_HDR_LEN;

  /* Append the user message */
  if(msg != (char *)NULL) {
    len = strlen(msg);
    if(len > 0 && len < AUTH_STRING_LEN) {
      ptr = auth->data;
      *ptr++ = PW_PORT_MESSAGE;
      *ptr++ = len + 2;
      memcpy(ptr, msg, len);
      ptr += len;
      total_length += len + 2;
    }
  }

  /* Append the state info */
  if((state != (char *)NULL) && (strlen(state) > 0)) {
    len = strlen(state);
    *ptr++ = PW_STATE;
    *ptr++ = len + 2;
    memcpy(ptr, state, len);
    ptr += len;
    total_length += len + 2;
  }

  /* Set total length in the header */
  auth->length = htons(total_length);

  /* Calculate the response digest */
  secretlen = strlen(authreq->secret);
  memcpy(send_buffer + total_length, authreq->secret, secretlen);
  md5_calc(digest, (char *)auth, total_length + secretlen);
  memcpy(auth->vector, digest, AUTH_VECTOR_LEN);
  memset(send_buffer + total_length, 0, secretlen);

  sin = (struct sockaddr_in *) &saremote;
        memset ((char *) sin, '\0', sizeof (saremote));
  sin->sin_family = AF_INET;
  sin->sin_addr.s_addr = htonl(authreq->ipaddr);
  sin->sin_port = htons(authreq->udp_port);

  DEBUG("Sending Challenge of id %d to %lx (%s)\n",
    authreq->id, (u_long)authreq->ipaddr,
    ip_hostname(authreq->ipaddr));

  /* Send it to the user */
  sendto(activefd, (char *)auth, (int)total_length, (int)0,
      (struct sockaddr *) &saremote, sizeof(struct sockaddr_in));
}

/*************************************************************************
 *
 *  Function: send_pwack
 *
 *  Purpose: Reply to the request with an ACKNOWLEDGE.
 *     User password has been successfully changed.
 *
 *************************************************************************/

send_pwack(authreq, activefd)
AUTH_REQ  *authreq;
int   activefd;
{
  AUTH_HDR    *auth;
  struct  sockaddr  saremote;
  struct  sockaddr_in *sin;
  char      *ip_hostname();
  char      digest[AUTH_VECTOR_LEN];
  int     secretlen;

  auth = (AUTH_HDR *)send_buffer;

  /* Build standard response header */
  auth->code = PW_PASSWORD_ACK;
  auth->id = authreq->id;
  memcpy(auth->vector, authreq->vector, AUTH_VECTOR_LEN);
  auth->length = htons(AUTH_HDR_LEN);

  /* Calculate the response digest */
  secretlen = strlen(authreq->secret);
  memcpy(send_buffer + AUTH_HDR_LEN, authreq->secret, secretlen);
  md5_calc(digest, (char *)auth, AUTH_HDR_LEN + secretlen);
  memcpy(auth->vector, digest, AUTH_VECTOR_LEN);
  memset(send_buffer + AUTH_HDR_LEN, 0, secretlen);

  sin = (struct sockaddr_in *) &saremote;
        memset ((char *) sin, '\0', sizeof (saremote));
  sin->sin_family = AF_INET;
  sin->sin_addr.s_addr = htonl(authreq->ipaddr);
  sin->sin_port = htons(authreq->udp_port);

  DEBUG("Sending PW Ack of id %d to %lx (%s)\n",
    authreq->id, (u_long)authreq->ipaddr,
    ip_hostname(authreq->ipaddr));

  /* Send it to the user */
  sendto(activefd, (char *)auth, (int)AUTH_HDR_LEN, (int)0,
      &saremote, sizeof(struct sockaddr_in));
}

/*************************************************************************
 *
 *  Function: send_accept
 *
 *  Purpose: Reply to the request with an ACKNOWLEDGE.  Also attach
 *     reply attribute value pairs and any user message provided.
 *
 *************************************************************************/

send_accept(authreq, reply, msg, activefd)
AUTH_REQ  *authreq;
VALUE_PAIR  *reply;
char    *msg;
int   activefd;
{
  AUTH_HDR    *auth;
  u_short     total_length;
  struct  sockaddr  saremote;
  struct  sockaddr_in *sin;
  u_char      *ptr;
  int     len;
  UINT4     lvalue;
  u_char      digest[16];
  int     secretlen;
  char      *ip_hostname();

  auth = (AUTH_HDR *)send_buffer;

  /* Build standard header */
  auth->code = PW_AUTHENTICATION_ACK;
  auth->id = authreq->id;
  memcpy(auth->vector, authreq->vector, AUTH_VECTOR_LEN);

  DEBUG("Sending Ack of id %d to %lx (%s)\n",
    authreq->id, (u_long)authreq->ipaddr,
    ip_hostname(authreq->ipaddr));

  total_length = AUTH_HDR_LEN;

  /* Load up the configuration values for the user */
  ptr = auth->data;
  while(reply != (VALUE_PAIR *)NULL) {
    debug_pair(stdout, reply);
    *ptr++ = reply->attribute;

    switch(reply->type) {

    case PW_TYPE_STRING:
      len = strlen(reply->strvalue);
      if (len >= AUTH_STRING_LEN) {
        len = AUTH_STRING_LEN - 1;
      }
      *ptr++ = len + 2;
      memcpy(ptr, reply->strvalue,len);
      ptr += len;
      total_length += len + 2;
      break;

    case PW_TYPE_INTEGER:
    case PW_TYPE_IPADDR:
      *ptr++ = sizeof(UINT4) + 2;
      lvalue = htonl(reply->lvalue);
      memcpy(ptr, &lvalue, sizeof(UINT4));
      ptr += sizeof(UINT4);
      total_length += sizeof(UINT4) + 2;
      break;

    default:
      break;
    }

    reply = reply->next;
  }

  /* Append the user message */
  if(msg != (char *)NULL) {
    len = strlen(msg);
    if(len > 0 && len < AUTH_STRING_LEN) {
      *ptr++ = PW_PORT_MESSAGE;
      *ptr++ = len + 2;
      memcpy(ptr, msg, len);
      ptr += len;
      total_length += len + 2;
    }
  }

  auth->length = htons(total_length);

  /* Append secret and calculate the response digest */
  secretlen = strlen(authreq->secret);
  memcpy(send_buffer + total_length, authreq->secret, secretlen);
  md5_calc(digest, (char *)auth, total_length + secretlen);
  memcpy(auth->vector, digest, AUTH_VECTOR_LEN);
  memset(send_buffer + total_length, 0, secretlen);

  sin = (struct sockaddr_in *) &saremote;
        memset ((char *) sin, '\0', sizeof (saremote));
  sin->sin_family = AF_INET;
  sin->sin_addr.s_addr = htonl(authreq->ipaddr);
  sin->sin_port = htons(authreq->udp_port);

  /* Send it to the user */
  sendto(activefd, (char *)auth, (int)total_length, (int)0,
      &saremote, sizeof(struct sockaddr_in));
}

/*************************************************************************
 *
 *  Function: unix_pass
 *
 *  Purpose: Check the users password against the standard UNIX
 *     password table.
 *
 *************************************************************************/

unix_pass(name, passwd)
char  *name;
char  *passwd;
{
  struct passwd *pwd;
  struct passwd *getpwnam();
  char    *encpw;
  char    *crypt();
  char    *encrypted_pass;
#if !defined(NOSHADOW)
#if defined(M_UNIX)
  struct passwd *spwd;
#else
  struct spwd *spwd;
#endif
#endif /* !NOSHADOW */

  /* Get encrypted password from password file */
  if((pwd = getpwnam(name)) == NULL) {
    return(-1);
  }

  encrypted_pass = pwd->pw_passwd;

#if !defined(NOSHADOW)
  if(strcmp(pwd->pw_passwd, "x") == 0) {
    if((spwd = getspnam(name)) == NULL) {
      return(-1);
    }
#if defined(M_UNIX)
    encrypted_pass = spwd->pw_passwd;
#else
    encrypted_pass = spwd->sp_pwdp;
#endif  /* M_UNIX */
  }
#endif  /* !NOSHADOW */

  /* Run encryption algorythm */
  encpw = crypt(passwd, encrypted_pass);

  /* Check it */
  if(strcmp(encpw, encrypted_pass)) {
    return(-1);
  }
  return(0);
}

/*************************************************************************
 *
 *  Function: calc_digest
 *
 *  Purpose: Validates the requesting client NAS.  Calculates the
 *     digest to be used for decrypting the users password
 *     based on the clients private key.
 *
 *************************************************************************/

calc_digest(digest, authreq)
u_char    *digest;
AUTH_REQ  *authreq;
{
  FILE  *clientfd;
  u_char  buffer[128];
  u_char  secret[64];
  char  hostnm[256];
  char  msg[128];
  char  *ip_hostname();
  int secretlen;
  UINT4 ipaddr;
  UINT4 get_ipaddr();

  /* Find the client in the database */
  sprintf(buffer, "%s/%s", radius_dir, RADIUS_CLIENTS);
  if((clientfd = fopen(buffer, "r")) == (FILE *)NULL) {
    fprintf(stderr, "%s: couldn't open %s to find clients\n",
        progname, buffer);
    return(-1);
  }
  ipaddr = (UINT4)0;
  while(fgets(buffer, sizeof(buffer), clientfd) != (char *)NULL) {
    if(*buffer == '#') {
      continue;
    }
    if(sscanf(buffer, "%s%s", hostnm, secret) != 2) {
      continue;
    }
    ipaddr = get_ipaddr(hostnm);
    if(ipaddr == authreq->ipaddr) {
      break;
    }
  }
  fclose(clientfd);
  memset(buffer, 0, sizeof(buffer));

  /*
   * Validate the requesting IP address -
   * Not secure, but worth the check for accidental requests
   */
  if(ipaddr != authreq->ipaddr) {
    strcpy(hostnm,ip_hostname(ipaddr));
    sprintf(msg, "requester address mismatch: %s != %s\n",
      hostnm,
      ip_hostname(authreq->ipaddr));
    log_err(msg);
    memset(secret, 0, sizeof(secret));
    return(-1);
  }

  /* Use the secret to setup the decryption digest */
  secretlen = strlen(secret);
  strcpy(buffer, secret);
  memcpy(buffer + secretlen, authreq->vector, AUTH_VECTOR_LEN);
  md5_calc(digest, buffer, secretlen + AUTH_VECTOR_LEN);
  strcpy(authreq->secret, secret);
  memset(buffer, 0, sizeof(buffer));
  memset(secret, 0, sizeof(secret));
  return(0);
}

/*************************************************************************
 *
 *  Function: debug_pair
 *
 *  Purpose: Print the Attribute-value pair to the desired File.
 *
 *************************************************************************/

debug_pair(fd, pair)
FILE    *fd;
VALUE_PAIR  *pair;
{
  if(debug_flag) {
    fputs("    ", fd);
    fprint_attr_val(fd, pair);
    fputs("\n", fd);
  }
}

/*************************************************************************
 *
 *  Function: usage
 *
 *  Purpose: Display the syntax for starting this program.
 *
 *************************************************************************/

usage()
{
  fprintf(stderr, "Usage: %s [ -a acct_dir ] [ -s ] [ -x ] [ -d db_dir ]\n",progname);
  exit(-1);
}

/*************************************************************************
 *
 *  Function: log_err
 *
 *  Purpose: Log the error message provided to the error log with
     a time stamp.
 *
 *************************************************************************/

log_err(msg)
char  *msg;
{
  FILE  *msgfd;
  char  buffer[128];
  time_t  timeval;

  sprintf(buffer, "%s/%s", radius_dir, RADIUS_LOG);
  if((msgfd = fopen(buffer, "a")) == (FILE *)NULL) {
    fprintf(stderr, "%s:Couldn't open %s for logging\n",
        progname, buffer);
    return(-1);
  }
  timeval = time(0);
  fprintf(msgfd, "%-24.24s: %s", ctime(&timeval), msg);
  fclose(msgfd);
  return(0);
}

/*************************************************************************
 *
 *  Function: config_init
 *
 *  Purpose: intializes configuration values:
 *
 *     expiration_seconds - When updating a user password,
 *      the amount of time to add to the current time
 *      to set the time when the password will expire.
 *      This is stored as the VALUE Password-Expiration
 *      in the dictionary as number of days.
 *
 *    warning_seconds - When acknowledging a user authentication
 *      time remaining for valid password to notify user
 *      of password expiration.
 *
 *************************************************************************/

config_init()
{
  DICT_VALUE  *dval;
  DICT_VALUE  *dict_valfind();

  if((dval = dict_valfind("Password-Expiration")) == (DICT_VALUE *)NULL) {
    expiration_seconds = (UINT4)0;
  }
  else {
    expiration_seconds = dval->value * (UINT4)SECONDS_PER_DAY;
  }
  if((dval = dict_valfind("Password-Warning")) == (DICT_VALUE *)NULL) {
    warning_seconds = (UINT4)0;
  }
  else {
    warning_seconds = dval->value * (UINT4)SECONDS_PER_DAY;
  }
  return(0);
}

/*************************************************************************
 *
 *  Function: set_expiration
 *
 *  Purpose: Set the new expiration time by updating or adding
     the Expiration attribute-value pair.
 *
 *************************************************************************/

set_expiration(user_check, expiration)
VALUE_PAIR  *user_check;
UINT4   expiration;
{
  VALUE_PAIR  *exppair;
  VALUE_PAIR  *prev;
  struct timeval  tp;
  struct timezone tzp;

  if(user_check == (VALUE_PAIR *)NULL) {
    return(-1);
  }

  /* Look for an existing expiration entry */
  exppair = user_check;
  prev = (VALUE_PAIR *)NULL;
  while(exppair != (VALUE_PAIR *)NULL) {
    if(exppair->attribute == PW_EXPIRATION) {
      break;
    }
    prev = exppair;
    exppair = exppair->next;
  }
  if(exppair == (VALUE_PAIR *)NULL) {
    /* Add a new attr-value pair */
    if((exppair = (VALUE_PAIR *)malloc(sizeof(VALUE_PAIR))) ==
          (VALUE_PAIR *)NULL) {
      fprintf(stderr, "%s: no memory\n", progname);
      exit(-1);
    }
    /* Initialize it */
    strcpy(exppair->name, "Expiration");
    exppair->attribute = PW_EXPIRATION;
    exppair->type = PW_TYPE_DATE;
    *exppair->strvalue = '\0';
    exppair->lvalue = (UINT4)0;
    exppair->next = (VALUE_PAIR *)NULL;

    /* Attach it to the list. */
    prev->next = exppair;
  }

  /* calculate a new expiration */
  gettimeofday(&tp, &tzp);
  exppair->lvalue = tp.tv_sec + expiration;
  return(0);
}

/*************************************************************************
 *
 *  Function: pw_expired
 *
 *  Purpose: Tests to see if the users password has expired.
 *
 *  Return: Number of days before expiration if a warning is required
 8    otherwise 0 for success and -1 for failure.
 *
 *************************************************************************/

pw_expired(exptime)
UINT4 exptime;
{
  struct timeval  tp;
  struct timezone tzp;
  UINT4   exp_remain;
  int   exp_remain_int;

  if(expiration_seconds == (UINT4)0) {
    return(0);
  }

  gettimeofday(&tp, &tzp);
  if(tp.tv_sec > exptime) {
    return(-1);
  }
  if(warning_seconds != (UINT4)0) {
    if(tp.tv_sec > exptime - warning_seconds) {
      exp_remain = exptime - tp.tv_sec;
      exp_remain /= (UINT4)SECONDS_PER_DAY;
      exp_remain_int = exp_remain;
      return(exp_remain_int);
    }
  }
  return(0);
}

void
sig_fatal(sig)
int sig;
{
  if(acct_pid > 0) {
    kill(acct_pid, SIGKILL);
  }

  fprintf(stderr, "%s: exit on signal (%d)\n", progname, sig);
  fflush(stderr);
  exit(1);
}

void
sig_hup(sig)
int sig;
{
  return;
}

begin
  int     salen;
  int     result;
  struct  sockaddr  salocal;
  struct  sockaddr  saremote;
  struct  sockaddr_in *sin;
  struct  servent   *svp;
  u_short lport;
  AUTH_REQ  *authreq;
  AUTH_REQ  *radrecv();
  char    argval;
  int     t;
  int     pid;
  int     cons;
  fd_set  readfds;
  int     status;

  progname = *argv++;
  argc--;

  debug_flag = 0;
  spawn_flag = 1;
  radacct_dir = RADACCT_DIR;
  radius_dir = RADIUS_DIR;

{
  signal(SIGHUP, sig_hup);
  signal(SIGINT, sig_fatal);
  signal(SIGQUIT, sig_fatal);
  signal(SIGILL, sig_fatal);
  signal(SIGTRAP, sig_fatal);
  signal(SIGFPE, sig_fatal);
  signal(SIGTERM, sig_fatal);
  signal(SIGCHLD, sig_cleanup);
}


  while(argc) {

    if(**argv != '-') {
      usage();
    }

    argval = *(*argv + 1);
    argc--;
    argv++;

    switch(argval) {

    case 'a':
      if(argc == 0) {
        usage();
      }
      radacct_dir = *argv;
      argc--;
      argv++;
      break;

    case 'd':
      if(argc == 0) {
        usage();
      }
      radius_dir = *argv;
      argc--;
      argv++;
      break;

    case 's': /* Single process mode */
      spawn_flag = 0;
      break;

    case 'v':
      version();
      break;

    case 'x':
      debug_flag = 1;
      break;

    default:
      usage();
      break;
    }
  }

  // Initialize the dictionary
  if dict_init<>0 then Halt(-1);
  // Initialize Configuration Values
  if config_init<>0 then Halt(-1);

  lport:=htons(1645);

  sockfd:=socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0) {
    (void) perror ("auth socket");
    exit(-1);
  }

  sin = (struct sockaddr_in *) &salocal;
  FillChar(sin,0,sizeof (salocal));
  sin^.sin_family = AF_INET;
  sin^.sin_addr.s_addr = INADDR_ANY;
  sin^.sin_port = lport;


  result = bind (sockfd, & salocal, sizeof ( *sin));
  if (result < 0) {
    (void) perror ("auth bind");
    exit(-1);
  }

  // Open Accounting Socket.
  svp = getservbyname ("radacct", "udp");
  (*
  if svp = NIL then
  begin
    writeln(stderr, "%s: No such service: %s/%s\n",
      progname, "radacct", "udp");
    exit(-1);
  end; *)
  lport := htons(ntohs(lport) +1);
  acctfd := socket (AF_INET, SOCK_DGRAM, 0);
  if acctfd<0 then
  begin
    perror('acct socket');
    Halt(-1);
  end;

  sin:=salocal;
  FillChar(sin^,0,sizeof(salocal));
  sin^.sin_family      := AF_INET;
  sin^.sin_addr.s_addr := INADDR_ANY;
  sin^.sin_port        := lport;

  result = bind (acctfd,salocal,sizeof(sin^));
  if result<0 then
  begin
    perror('acct bind');
    Halt(-1);
  end;

  // Disconnect from session
  if debug_flag=0
  begin
    pid = fork();
    if(pid < 0) {
      fprintf(stderr, "%s: Couldn't fork\n",
            progname);
      exit(-1);
    }
    if(pid > 0) {
      exit(0);
    }
  }

  /*
   * If we are able to spawn processes, we will start a child
   * to listen for Accounting requests.  If not, we will
   * listen for them ourself.
   */
  if(spawn_flag) {
    acct_pid = fork();
    if(acct_pid < 0) {
      fprintf(stderr, "%s: Couldn't fork\n",
            progname);
      exit(-1);
    }
    if(acct_pid > 0) {
      close(acctfd);
      acctfd = -1;
    }
    else {
      close(sockfd);
      sockfd = -1;
    }
  }


  // Receive user requests
  sin = (struct sockaddr_in *) & saremote;

  for(;;) {

    FD_ZERO(&readfds);
    if(sockfd >= 0) {
      FD_SET(sockfd, &readfds);
    }
    if(acctfd >= 0) {
      FD_SET(acctfd, &readfds);
    }

    status = select(32, &readfds, NULL, NULL, NULL);
    if(status == -1) {
      if (errno == EINTR)
        continue;
      sig_fatal(101);
    }
    if(sockfd >= 0 && FD_ISSET(sockfd, &readfds)) {
      salen = sizeof (saremote);
      result = recvfrom (sockfd, (char *) recv_buffer,
        (int) sizeof(recv_buffer),
        (int) 0, & saremote, & salen);

      if(result > 0) {
        authreq = radrecv(
          ntohl(sin->sin_addr.s_addr),
          ntohs(sin->sin_port),
          recv_buffer, result);
        radrespond(authreq, sockfd);
      }
      else if(result < 0 && errno == EINTR) {
        result = 0;
      }
    }
    if(acctfd >=0 && FD_ISSET(acctfd, &readfds)) {
      salen = sizeof (saremote);
      result = recvfrom (acctfd, (char *) recv_buffer,
        (int) sizeof(recv_buffer),
        (int) 0, & saremote, & salen);

      if(result > 0) {
        authreq = radrecv(
          ntohl(sin->sin_addr.s_addr),
          ntohs(sin->sin_port),
          recv_buffer, result);
        radrespond(authreq, acctfd);
      }
      else if(result < 0 && errno == EINTR) {
        result = 0;
      }
    }
  }
}

