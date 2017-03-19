public Action Command_AdminForceReady(int client, int args) {
  if (g_GameState != GameState_PreVeto && g_GameState != GameState_Warmup) {
    return Plugin_Handled;
  }

  Get5_MessageToAll("%t", "AdminForceReadyInfoMessage");
  LOOP_TEAMS(team) {
    g_TeamReadyOverride[team] = true;
  }
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      g_ClientReady[i] = true;
    }
  }
  SetMatchTeamCvars();

  return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
  if (g_GameState != GameState_PreVeto && g_GameState != GameState_Warmup) {
    return Plugin_Handled;
  }

  MatchTeam team = GetClientMatchTeam(client);
  if (team == MatchTeam_TeamNone || team == MatchTeam_TeamSpec) {
    return Plugin_Handled;
  }

  Get5_Message(client, "%t", "YouAreReady");
  g_ClientReady[client] = true;
  if (IsTeamReady(team)) {
    SetMatchTeamCvars();
    PrintReadyMessage(team);
  }

  return Plugin_Handled;
}

static void PrintReadyMessage(MatchTeam team) {
  CheckTeamNameStatus(team);

  if (g_GameState == GameState_PreVeto) {
    Get5_MessageToAll("%t", "TeamReadyToVetoInfoMessage", g_FormattedTeamNames[team]);
  } else if (g_GameState == GameState_Warmup) {
    SideChoice sides = view_as<SideChoice>(g_MapSides.Get(GetMapNumber()));
    if (g_WaitingForRoundBackup)
      Get5_MessageToAll("%t", "TeamReadyToRestoreBackupInfoMessage", g_FormattedTeamNames[team]);
    else if (sides == SideChoice_KnifeRound)
      Get5_MessageToAll("%t", "TeamReadyToKnifeInfoMessage", g_FormattedTeamNames[team]);
    else
      Get5_MessageToAll("%t", "TeamReadyToBeginInfoMessage", g_FormattedTeamNames[team]);
  }
}

public Action Command_NotReady(int client, int args) {
  if (g_GameState != GameState_PreVeto && g_GameState != GameState_Warmup) {
    return Plugin_Handled;
  }

  MatchTeam team = GetClientMatchTeam(client);
  if (team == MatchTeam_TeamNone || team == MatchTeam_TeamSpec) {
    return Plugin_Handled;
  }

  bool teamWasReady = IsTeamReady(team);
  g_ClientReady[client] = false;
  g_TeamReadyOverride[team] = false;
  Get5_Message(client, "%t", "YouAreNotReady");

  if (teamWasReady) {
    SetMatchTeamCvars();
    Get5_MessageToAll("%t", "TeamNotReadyInfoMessage", g_FormattedTeamNames[team]);
  }

  return Plugin_Handled;
}

public Action Command_ForceReadyClient(int client, int args) {
  if (g_GameState != GameState_PreVeto && g_GameState != GameState_Warmup) {
    return Plugin_Handled;
  }

  MatchTeam team = GetClientMatchTeam(client);
  if (team == MatchTeam_TeamNone || team == MatchTeam_TeamSpec) {
    return Plugin_Handled;
  }

  if (team == team && !IsTeamReady(team)) {
    int playerCount = CountPlayersOnMatchTeam(team);
    if (playerCount >= g_MinPlayersToReady) {
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && GetClientMatchTeam(i) == team) {
          g_ClientReady[i] = true;
          Get5_Message(i, "%t", "TeammateForceReadied", client);
        }
      }
      g_TeamReadyOverride[team] = true;
      SetMatchTeamCvars();
      PrintReadyMessage(team);

    } else {
      Get5_Message(client, "%t", "TeamFailToReadyMinPlayerCheck", g_MinPlayersToReady);
    }
  }

  return Plugin_Handled;
}

stock bool AllTeamsReady(bool includeSpec = true) {
  bool playersReady = IsTeamReady(MatchTeam_Team1) && IsTeamReady(MatchTeam_Team2);
  if (GetTeamAuths(MatchTeam_TeamSpec).Length == 0 || !includeSpec) {
    return playersReady;
  } else {
    return playersReady && IsTeamReady(MatchTeam_TeamSpec);
  }
}

public bool IsTeamReady(MatchTeam team) {
  if (g_GameState == GameState_Live) {
    return true;
  }

  if (team == MatchTeam_TeamNone || team == MatchTeam_TeamSpec) {
    return true;
  }

  int playerCount = 0;
  int readyCount = 0;
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team) {
      playerCount++;
      if (g_ClientReady[i]) {
        readyCount++;
      }
    }
  }

  if (playerCount == readyCount && readyCount >= g_PlayersPerTeam) {
    return true;
  }

  if (g_TeamReadyOverride[team] && readyCount >= g_MinPlayersToReady) {
    return true;
  }

  return false;
}

public void MissingPlayerInfoMessage() {
  if (IsTeamReadyButMissingPlayers(MatchTeam_Team1)) {
    Get5_MessageToTeam(MatchTeam_Team1, "%t", "ForceReadyInfoMessage", g_PlayersPerTeam);
  }
  if (IsTeamReadyButMissingPlayers(MatchTeam_Team2)) {
    Get5_MessageToTeam(MatchTeam_Team2, "%t", "ForceReadyInfoMessage", g_PlayersPerTeam);
  }
}

public bool IsTeamReadyButMissingPlayers(MatchTeam team) {
  if (team == MatchTeam_TeamNone || team == MatchTeam_TeamSpec) {
    return false;
  }

  int playerCount = 0;
  int readyCount = 0;
  for (int i = 0; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && !IsClientCoaching(i)) {
      playerCount++;
      if (g_ClientReady[i]) {
        readyCount++;
      }
    }
  }

  if (!g_TeamReadyOverride[team] && readyCount >= g_MinPlayersToReady &&
      readyCount < g_PlayersPerTeam && playerCount == readyCount) {
    return true;
  }

  return false;
}

public void ResetReadyStatus() {
  LOOP_TEAMS(team) {
    g_TeamReadyOverride[team] = false;
  }
  for (int i = 0; i <= MaxClients; i++) {
    g_ClientReady[i] = false;
  }
}

public void UpdateClanTags() {
  if (g_GameState == GameState_Warmup || g_GameState == GameState_PreVeto) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        if (GetClientTeam(i) == CS_TEAM_SPECTATOR) {
          CS_SetClientClanTag(i, "");
        } else {
          char tag[32];
          Format(tag, sizeof(tag), "%T", g_ClientReady[i] ? "ReadyTag" : "NotReadyTag",
                 LANG_SERVER);
          CS_SetClientClanTag(i, tag);
        }
      }
    }
  }

  if (g_GameState >= GameState_KnifeRound) {
    for (int i = 0; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        CS_SetClientClanTag(i, g_TeamTags[GetClientMatchTeam(i)]);
      }
    }
  }
}
