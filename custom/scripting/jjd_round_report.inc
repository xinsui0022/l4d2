// Included by the maintained l4d2_playstats overlay: reuse its damage accounting.
ConVar jjdReport;
bool jjdReportLive;
int jjdReports;

void JJD_ReportInit()
{
    jjdReport = CreateConVar("jjd_round_report", "1", "Chinese half-round MVP/LVP report", _, true, 0.0, true, 1.0);
    RegConsoleCmd("sm_lvp", JJD_ReportCommand, "Show current MVP/LVP and both teams' round damage");
    RegConsoleCmd("sm_roundstats", JJD_ReportCommand, "Show both teams' current round statistics");
    RegServerCmd("sm_jjd_report_status", JJD_ReportStatus);
}

public Action JJD_ReportStatus(int args)
{
    PrintToServer("JJD_REPORT enabled=%d live=%d reports=%d", jjdReport.BoolValue, jjdReportLive, jjdReports);
    return Plugin_Handled;
}
public Action JJD_ReportCommand(int client, int args)
{
    if (client > 0 && IsClientInGame(client)) JJD_Report(client);
    return Plugin_Handled;
}

void JJD_ReportLine(int client, const char[] line)
{
    if (client > 0) { PrintToChat(client, "%s", line); PrintToConsole(client, "%s", line); }
    else { PrintToChatAll("%s", line); PrintToConsoleAll("%s", line); LogMessage("%s", line); }
}

void JJD_Report(int client = 0)
{
    if (!jjdReport.BoolValue) return;
    int team = g_iCurTeam;
    char line[250], nick[48], mark[32];
    for (int side = 0; side < 2; side++)
    {
        int best = -1, worst = -1, participants;
        int scores[MAXTRACKED], ff[MAXTRACKED];
        bool present[MAXTRACKED];
        for (int i = FIRST_NON_BOT; i < g_iPlayers; i++)
        {
            present[i] = side == 0 ? g_strRoundPlayerData[i][team][plyTimeStartPresent] > 0
                : g_strRoundPlayerInfData[i][team][infTimeStartPresent] > 0;
            if (!present[i]) continue;
            participants++;
            scores[i] = side == 0 ? g_strRoundPlayerData[i][team][plySIDamage]
                : g_strRoundPlayerInfData[i][team][infDmgUpright] + g_strRoundPlayerInfData[i][team][infDmgTank];
            ff[i] = g_strRoundPlayerData[i][team][plyFFGivenTotal] - g_strRoundPlayerData[i][team][plyFFGivenSelf];
            if (best == -1 || scores[i] > scores[best]) best = i;
            if (worst == -1 || (side == 0 ? ff[i] > ff[worst] : scores[i] < scores[worst])) worst = i;
        }
        FormatEx(line, sizeof(line), "[结算·%s] %s", side == 0 ? "生还" : "感染", side == 0
            ? "MVP=特感伤害最多；LVP=友伤最多（并列均标）"
            : "MVP/LVP=站立生还伤害最高/最低；克伤单列");
        JJD_ReportLine(client, line);
        if (!participants) { JJD_ReportLine(client, "[结算] 本半场暂无真人数据。"); continue; }
        for (int i = FIRST_NON_BOT; i < g_iPlayers; i++)
        {
            if (!present[i]) continue;
            strcopy(nick, sizeof(nick), g_sPlayerName[i]);
            for (int k = 0; nick[k]; k++) if (nick[k] > 0 && nick[k] < 32) nick[k] = ' ';
            mark[0] = '\0';
            if (scores[best] > 0 && scores[i] == scores[best]) StrCat(mark, sizeof(mark), "[MVP]");
            if (side == 0 && ff[worst] > 0 && ff[i] == ff[worst]) StrCat(mark, sizeof(mark), "[LVP]");
            if (side == 1 && participants > 1 && scores[best] > scores[worst] && scores[i] == scores[worst]) StrCat(mark, sizeof(mark), "[LVP]");
            if (side == 0)
                FormatEx(line, sizeof(line), "%s%s：特感 %d | 克 %d | 小丧尸 %d | 友伤 %d/受 %d", mark, nick,
                    scores[i], g_strRoundPlayerData[i][team][plyTankDamage], g_strRoundPlayerData[i][team][plyCommon],
                    ff[i], g_strRoundPlayerData[i][team][plyFFTakenTotal]);
            else
                FormatEx(line, sizeof(line), "%s%s：输出 %d（克 %d）| 倒地 %d | 喷中 %d", mark, nick,
                    scores[i], g_strRoundPlayerInfData[i][team][infDmgTank],
                    g_strRoundPlayerInfData[i][team][infDmgTotal] - g_strRoundPlayerInfData[i][team][infDmgUpright]
                        + g_strRoundPlayerInfData[i][team][infDmgTankIncap], g_strRoundPlayerInfData[i][team][infBooms]);
            JJD_ReportLine(client, line);
        }
        if (side == 0 && ff[worst] == 0) JJD_ReportLine(client, "[生还 LVP] 无友伤，无人上榜。");
    }
    JJD_ReportLine(client, "[结算] 感染者友伤沿用模式禁用；统计含中途加入/退出，数值不代表综合水平。");
}
