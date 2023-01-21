#include <sourcemod> 
#include <multicolors>
#include <warden>



Database h_dbConnection = null;
int sure[MAXPLAYERS+1] = 0;
ConVar g_Tag;
char Taga[64];
int g_saat;
int g_dakika;


public Plugin myinfo = { 
    name = "Komutçu Süre", 
    author = "akosetr", 
    description = "Komutçu, komut verdiği saati görüntüler.", 
    url = "https://csgomerkezi.online/" 
}; 

public void OnPluginStart()
{ 
	RegConsoleCmd("sm_komsurem", Command_KomTime);
	g_Tag = CreateConVar("csgomerkezi_tag", "csgomerkezi.online", "Eklenti taginizi giriniz.");
	GetConVarString(g_Tag, Taga, sizeof(Taga));
        dbConnect();
        AutoExecConfig(true, "csgomerkezi_akosetr", "csgomerkezi_topkom");
}



public void dbConnect() {
		char szError[200];		
		KeyValues hKv = CreateKeyValues("storage-local", "", "");
		hKv.SetString("driver", "sqlite");
		hKv.SetString("database", "sourcemod-local");		
		h_dbConnection = SQL_ConnectCustom(hKv, szError, 200, false); delete hKv;		
		if (h_dbConnection != null) 
		{
			LogError("topkom :: %s", szError);
			dbCreateTables();
		}
}

public void dbConnectCallback(Database dbConn, const char[] error, any data) {
	
	if (dbConn != null) 
	{
		LogMessage("SQL Connect Callback");
		h_dbConnection = dbConn;
		dbCreateTables();
	} 
	else 
	{
		h_dbConnection = null;
		LogError("topkom :: %s", error);
	}
}

public void dbCreateTables() {
	
	char query[512];
	
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `akose_topkom` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `name` VARCHAR(255), `steamid` VARCHAR(18), `sure` INTEGER DEFAULT 0, `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP);");
	SQL_FastQuery(h_dbConnection, query);
}

public void dbCreateTablesCallback(Database dbConn, DBResultSet results, const char[] error, any data) {
	
	if (results == null) {
		h_dbConnection = null;
		LogError("topkom :: %s", error);
	}
}

public void dbGetClientData(int client) {
	
	if (!IsValidClient(client) || h_dbConnection == null)
		return;
	
	char query[512];
	char steamId[18];
	
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
	
	Format(query, sizeof(query), "SELECT sure FROM akose_topkom WHERE steamid = '%s'", steamId);
	h_dbConnection.Query(dbGetClientDataCallback, query, client);
}

public void dbGetClientDataCallback(Database dbConn, DBResultSet results, const char[] error, int client) {
	
	if (results.FetchRow()) {
		
		sure[client] = results.FetchInt(0);
		
	} else {
		
		dbCreateNewUser(client);
	}
}



public void dbCreateNewUser(int client) {
	
	if (!IsValidClient(client) || h_dbConnection == null)
		return;
	
	char query[512];
	char steamId[18];
	char clientName[255];
	char escapedClientName[255];
	
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
	GetClientName(client, clientName, sizeof(clientName));
	
	h_dbConnection.Escape(clientName, escapedClientName, sizeof(escapedClientName));
	
	Format(query, sizeof(query), "INSERT INTO akose_topkom (`name`, `steamid`, `sure`) VALUES ('%s', '%s', '0')", escapedClientName, steamId);
	h_dbConnection.Query(dbNothingCallback, query, client);
	sure[client] = 0;
}


public void dbSaveClientData(int client) {
	
	if (IsValidClient(client, false) && h_dbConnection != null) {
		
		char query[512];
		char steamId[18];
		char clientName[255];
		char escapedClientName[255];
		
		GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));
		GetClientName(client, clientName, sizeof(clientName));
		
		h_dbConnection.Escape(clientName, escapedClientName, sizeof(escapedClientName));
		
		Format(query, sizeof(query), "UPDATE `akose_topkom` SET `name`= '%s', `sure`= %i, `updated_at` = datetime('now') WHERE steamid = '%s'", escapedClientName, sure[client], steamId);
		h_dbConnection.Query(dbNothingCallback, query, client);
		
	}
}

public void dbNothingCallback(Database dbConn, DBResultSet results, const char[] error, int client) {
	
	if (results == null) {
		
		LogError("topkom :: %s", error);
	}
}


public void OnClientPostAdminCheck(int client) {

    dbGetClientData(client);
}


public void OnMapStart()
{
	CreateTimer(60.0, Sure_Ekle, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client)) dbSaveClientData(client);
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientDisconnect(client);
		}
	}
}


public Action Sure_Ekle(Handle timer, client)
{
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(IsClientInGame(i))
		{
		   if(warden_iswarden(i))
		     {
			   ++sure[i];
			}
		}
	}
}

public Action Command_KomTime(int client, int args) 
{
	g_saat = 0;
	g_dakika = sure[client];
	char zaman[128];
	while(g_dakika > 60)
	{
		g_saat++;
		g_dakika -= 60;
	}
	if(g_saat >= 1)
	{
		Format(zaman, sizeof(zaman), "%d saat %d dakika", g_saat, g_dakika);
    }
    else if(g_dakika >= 1)
    {
	    Format(zaman, sizeof(zaman), "%d dakika", g_dakika);
    }
	else
	{
		Format(zaman, sizeof(zaman), "0 dakika");
	}
	CPrintToChat(client, "{darkred}[%s] {darkblue}Toplam da {orchid}%s {darkblue}komut süreniz var.", Taga, zaman);
}   


bool IsValidClient(int client, bool connected = true)
{
  return (client > 0 && client <= MaxClients && (connected  == false || IsClientConnected(client))  && IsClientInGame(client) && !IsFakeClient(client));
}