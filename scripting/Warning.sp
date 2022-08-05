#include <sourcemod>
#include <sdktools>
#include <adt_array>
#include <dbi>

#pragma semicolon 1
#pragma newdecls required

char names[MAXPLAYERS+1][MAX_NAME_LENGTH]; // List of all online players
char playerWarns[32][50]; // Used to store warning reasons from database
char disconnected_steamid[100][40]; // List of all disconnected players SteamID
char disconnected_names[100][40]; // List of all disconnected players usernames


char check[40]; // String used to double check menu choice
char errorString[255]; // Error String for database
char finalName[40]; // Username given to database
char steamid[40]; // SteamID of target user given to database
char disc_steamid[40]; // SteamID of disconnected player
char conn_steamid[40]; // SteamID of newly connected player


int playercount; // Online playercount
int saveIndex; // Int used to save targeted players client index
int indexInt; // Used to get player name list
int admin; // Used to store client index of admin currently using command
int count = 0; // Used as increment for disconnected players
int tempint;


Database db;


public Plugin myinfo = 
{
	name = "Warning System",
	author = "CLNissen (fuck dig nobbe)",
	description = "Kan bruges til at give og fjerne advarsler på spillere",
	version = "1.1.2",
	url = "hjemezez.dk"
}

public void OnPluginStart()
{
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Post);
	
	
	RegConsoleCmd("sm_warn", Command_WarnMenu, "Warn Menu");
	
	//RegConsoleCmd("sm_gwarn", Command_GiveWarn, "Giv en advarsel til en spiller");
	//RegConsoleCmd("sm_rwarn", Command_RemoveWarn, "Fjern en advarsel fra en spiller");
	//RegConsoleCmd("sm_swarn", Command_CheckWarns, "Tjek en spillers advarsler");
	//RegConsoleCmd("sm_dis", Command_DisconnectedPlayers, "See disconnected players");

	
	db = SQL_Connect("default", true, errorString, sizeof(errorString));
	
	if (db == null)
	{
		PrintToServer("Could not connect to database: %s", errorString);
	}
	else
	{
		PrintToServer("Connection to Database Successful");
	}
}
	
public Action Command_WarnMenu(int client, int args)
{
	if (args == 0)
	{
		Menu warnMenu = new Menu(WarnMenu_Callback);
		warnMenu.SetTitle("Vælg Handling");
		warnMenu.AddItem("give", "Giv Advarsel"); // Tilføj access alt efter admin flags
		warnMenu.AddItem("remove", "Fjern Advarsel"); // same
		warnMenu.AddItem("check", "Se Advarsler"); // same
		warnMenu.AddItem("disc", "Giv Advarsel til Disconnected Players"); // same
		warnMenu.Display(client, 30);
		return Plugin_Handled;
	}
	if (args >= 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_warn");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public int WarnMenu_Callback(Menu warnMenu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
			case MenuAction_Select:
			{
				char choice[64];
				warnMenu.GetItem(param2, choice, sizeof(choice));
				
				if (StrEqual(choice, "give"))
				{
					Command_GiveWarn(param1);
				}
				if (StrEqual(choice, "remove"))
				{
					Command_RemoveWarn(param1);
				}
				if (StrEqual(choice, "check"))
				{
					Command_CheckWarns(param1);
				}
				if (StrEqual(choice, "disc"))
				{
					Command_DisconnectedPlayers(param1);
				}
			}
			case MenuAction_End:
			{
				delete warnMenu;
			}
	}
}

public Action Command_DisconnectedPlayers(int client)
{
	Menu disc = new Menu(GiveWarn_Callback);
	disc.SetTitle("Giv Advarsel: Vælg Spiller");
	for (int i = 1; i <= count;i++)
	{
		disc.AddItem(disconnected_steamid[i], disconnected_names[i]);
	}
	disc.Display(client, 30);
	return Plugin_Handled;
}

public Action Command_GiveWarn(int client)
	{
		Command_GetPlayerList();
		Command_GetPlayerCount();
		
		admin = client;
		
		Menu givewarn = new Menu(GiveWarn_Callback);
		givewarn.SetTitle("Giv Advarsel: Vælg Spiller");
		
		for (int i = 1; i <= playercount;i++) 
		{
			char option[40];
			IntToString(i, option, sizeof(option));
			
			givewarn.AddItem(option, names[i]);
		}
		givewarn.Display(client, 30);
		return Plugin_Handled;
	}
	
public int GiveWarn_Callback(Menu givewarn, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Select:
			{
				Menu player = new Menu(Player_Callback);
				
				char choice[40];
				givewarn.GetItem(param2, choice, sizeof(choice));
			
				if (strncmp(choice, "STEAM_", 6) != 0)
				{
					saveIndex = StringToInt(choice);
					int targetid = FindTarget(param1, names[saveIndex], true, false);
				
					GetClientAuthId(targetid, AuthId_Steam2, steamid, sizeof(steamid));
					
					player.SetTitle(names[saveIndex]); 
					
					finalName = names[saveIndex];
				}
				else if (strncmp(choice, "STEAM_", 6) == 0)
				{
					steamid = choice;	
					player.SetTitle(choice); 
					
					finalName = "//UKENDT//";
				}
				char query[100];
				Format(query, sizeof(query), "SELECT Reason FROM Warnings WHERE SteamID = '%s'", steamid);
				DBResultSet hQuery = SQL_Query(db, query);
				int rowCount = SQL_GetRowCount(hQuery);
			
				for (int x = 1; x <= rowCount;x++)
				{
					SQL_FetchRow(hQuery);
					SQL_FetchString(hQuery, 0, playerWarns[x], 50);
				}
				delete hQuery;
				
				player.AddItem("Language", "Language", (hasTargetReason("Language", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Admin Disrespect", "Admin Disrespect", (hasTargetReason("Admin Disrespect", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Abuse", "Abuse", (hasTargetReason("Abuse", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Mic/Chat spam", "Mic/Chat spam", (hasTargetReason("Mic/Chat spam", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Ghosting", "Ghosting", (hasTargetReason("Ghosting", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Free Credits/Elo", "Free Credits/Elo", (hasTargetReason("Free Credits/Elo", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Personal Information", "Personal Information", (hasTargetReason("Personal Information", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Advertising", "Advertising", (hasTargetReason("Advertising", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("!Calladmin/!Bug Abuse", "!Calladmin/!Bug Abuse", (hasTargetReason("!Calladmin/!Bug Abuse", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Asking for Credits", "Asking for Credits", (hasTargetReason("Asking for Credits", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Not Participating", "Not Participating", (hasTargetReason("Not Participating", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Impersonate Staff", "Impersonate Staff", (hasTargetReason("Impersonate Staff", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Insensitive Comments", "Insensitive Comments", (hasTargetReason("Insensitive Comments", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				player.AddItem("Disrespectful towards other players", "Disrespectful towards other players", (hasTargetReason("Disrespectful towards other players", rowCount) == true)?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
				
				
				player.Display(param1, 60);
			}	
		case MenuAction_End:
		{
			delete givewarn;
		}
	}
}

public int Player_Callback(Menu player, MenuAction action, int param1, int param2)
{
	switch (action) {
			case MenuAction_Select:
			{
				char choice[40];
				char adminName[40];
				
				player.GetItem(param2, choice, sizeof(choice));
				
				GetClientName(admin, adminName, sizeof(adminName));
			
				char query[300];
					
				Format(query, sizeof(query), "INSERT INTO Warnings (Username, SteamID, Reason, Admin) VALUES ('%s', '%s', '%s', '%s')", finalName, steamid, choice, adminName);
					
				//ReplyToCommand(param1, query);
				DBResultSet queryH = SQL_Query(db, query);
				
				if (queryH != INVALID_HANDLE)
				{
					PrintToChat(admin, "Player has been warned");
					
					delete queryH;
					finalName = "";
				}
			}
			case MenuAction_End:
			{
				delete player;
			}
		}
}

	
public Action Command_RemoveWarn(int client)
	{
		Command_GetPlayerList();
		Command_GetPlayerCount();
		
		Menu removewarn = new Menu(RemoveWarn_Callback);
		removewarn.SetTitle("Fjern Advarsel: Vælg Spiller");

		for (int i = 1; i <= playercount;i++) 
		{
			char option[40];
			IntToString(i, option, sizeof(option));
			
			removewarn.AddItem(option, names[i]);
		}
		removewarn.Display(client, 30);
		return Plugin_Handled;
	}
	

public int RemoveWarn_Callback(Menu removewarn, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Select:
			{
				char choice[40];
				removewarn.GetItem(param2, choice, sizeof(choice));
			
				for (int i = 1; i <= playercount;i++) 
				{
					IntToString(i, check, sizeof(check));
					
					if (StrEqual(choice, check)) {
						
						saveIndex = i;
						tempint = StringToInt(choice);
						
						char checkname[40];
						checkname = names[tempint];
						
						int curr_clientid;
						char tempname[40];
						
						for (int x = 1; x <= MaxClients;x++)
						{
							if (IsClientConnected(x) == true)
							{
								GetClientName(x, tempname, sizeof(tempname));
								if (StrEqual(tempname, checkname))
								{
									curr_clientid = x;
									break;
								}
							}
						}
						char tempSteamID[40];
						GetClientAuthId(curr_clientid, AuthId_Steam2, tempSteamID, sizeof(tempSteamID));
						
						char query[100];
						Format(query, sizeof(query), "SELECT Reason FROM Warnings WHERE SteamID = '%s'", tempSteamID);
						DBResultSet hQuery = SQL_Query(db, query);
						int rowCount = SQL_GetRowCount(hQuery);
						
						char rowCount2[40];
						IntToString(rowCount, rowCount2, sizeof(rowCount2));
						//ReplyToCommand(param1, rowCount2);
						
						for (int x = 1; x <= rowCount;x++)
						{
							SQL_FetchRow(hQuery);
							SQL_FetchString(hQuery, 0, playerWarns[x], 50);
						}
						
						Menu RemoveSQL = new Menu(RemoveSQL_Callback);
					
						RemoveSQL.SetTitle(names[i]);
					
						RemoveSQL.AddItem("Language", "Language", (hasTargetReason("Language", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Admin Disrespect", "Admin Disrespect", (hasTargetReason("Admin Disrespect", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Abuse", "Abuse", (hasTargetReason("Abuse", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Mic/Chat spam", "Mic/Chat spam", (hasTargetReason("Mic/Chat spam", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Ghosting", "Ghosting", (hasTargetReason("Ghosting", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Free Credits/Elo", "Free Credits/Elo", (hasTargetReason("Free Credits/Elo", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Personal Information", "Personal Information", (hasTargetReason("Personal Information", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Advertising", "Advertising", (hasTargetReason("Advertising", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("!Calladmin/!Bug Abuse", "!Calladmin/!Bug Abuse", (hasTargetReason("!Calladmin/!Bug Abuse", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Asking for Credits", "Asking for Credits", (hasTargetReason("Asking for Credits", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Not Participating", "Not Participating", (hasTargetReason("Not Participating", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Impersonate Staff", "Impersonate Staff", (hasTargetReason("Impersonate Staff", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Insensitive Comments", "Insensitive Comments", (hasTargetReason("Insensitive Comments", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						RemoveSQL.AddItem("Disrespectful towards other players", "Disrespectful towards other players", (hasTargetReason("Disrespectful towards other players", rowCount) == true)?ITEMDRAW_DEFAULT:ITEMDRAW_IGNORE);
						
						RemoveSQL.Display(param1, 60);
					}
				}
			}
			case MenuAction_End:
			{
				delete removewarn;
			}
		}
	}
	
	
public int RemoveSQL_Callback(Menu RemoveSQL, MenuAction action, int param1, int param2)
{
	switch (action) {
			case MenuAction_Select:
			{
				char choice[40];
				RemoveSQL.GetItem(param2, choice, sizeof(choice));
				
				GetClientAuthId(saveIndex, AuthId_Steam2, steamid, sizeof(steamid));
				
				char query[300];
				Format(query, sizeof(query), "DELETE FROM Warnings WHERE SteamID = '%s' AND Reason = '%s'", steamid, choice);
				DBResultSet hQuery = SQL_Query(db, query);
				
				if (!StrEqual(query, ""))
				{
					delete hQuery;
					ReplyToCommand(param1, "Warning has been deleted");
				}
			}
			case MenuAction_End:
			{
				delete RemoveSQL;
			}
		}
}
	
	
public Action Command_CheckWarns(int client)
	{
		Command_GetPlayerList();
		Command_GetPlayerCount();

		Menu checkwarn = new Menu(CheckWarn_Callback);
		checkwarn.SetTitle("Tjek Advarsler: Vælg Spiller");

		for (int i = 1; i <= playercount;i++) 
		{
			char option[40];
			IntToString(i, option, sizeof(option));
			
			checkwarn.AddItem(option, names[i]);
		}
		checkwarn.Display(client, 30);
		return Plugin_Handled;
	}

public int CheckWarn_Callback(Menu checkwarn, MenuAction action, int param1, int param2)
	{
		switch (action) {
			case MenuAction_Select:
			{
				char choice[40];
				checkwarn.GetItem(param2, choice, sizeof(choice));
			
				for (int i = 1; i <= playercount;i++) 
				{
					IntToString(i, check, sizeof(check));
					
					if (StrEqual(choice, check)) {
						
						steamid = "";
						
						tempint = StringToInt(choice);
						
						char checkname[40];
						checkname = names[tempint];
						
						int curr_clientid;
						char tempname[40];
						
						for (int x = 1; x <= MaxClients;x++)
						{
							if (IsClientConnected(x) == true)
							{
								GetClientName(x, tempname, sizeof(tempname));
								if (StrEqual(tempname, checkname))
								{
									curr_clientid = x;
									break;
								}
							}
						}
						
						GetClientAuthId(curr_clientid, AuthId_Steam2, steamid, sizeof(steamid));
						
						char query[100];
						Format(query, sizeof(query), "SELECT Reason FROM Warnings WHERE SteamID = '%s'", steamid);
						
					 
						DBResultSet hQuery = SQL_Query(db, query);
						int rowCount = SQL_GetRowCount(hQuery);
						
						char rowCount2[40];
						IntToString(rowCount, rowCount2, sizeof(rowCount2));
						//ReplyToCommand(param1, rowCount2);
						
						for (int x = 1; x <= rowCount;x++)
						{
							SQL_FetchRow(hQuery);
							SQL_FetchString(hQuery, 0, playerWarns[x], 50);
						}
						
						Menu cwCB = new Menu(SQL_Callback);
					
						cwCB.SetTitle(names[i]);
					
						for (int y = 1; y <= rowCount;y++)
						{
							cwCB.AddItem(playerWarns[y], playerWarns[y]);
						}
						cwCB.Display(param1, 60);
						delete hQuery;
					}
				}
			}
			case MenuAction_End:
			{
				delete checkwarn;
			}
		}
	}


public int SQL_Callback(Menu cwCB, MenuAction action, int param1, int param2)
{
	// Tom, skal bare være her for at checkwarns menuen virker
}

/* Events */

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	GetEventString(event, "networkid", disc_steamid, 40);
	
	if (strncmp(disc_steamid, "STEAM_", 6) == 0)
	{
		count++;
		strcopy(disconnected_steamid[count], 40, disc_steamid);
		GetEventString(event, "name", disconnected_names[count], 40);
	}
	if (count >= 40)
	{
		for (int x = 0; x <= count;x++)
		{	
			disconnected_steamid[count] = "'\0'";
			disconnected_names[count] = "'\0'";
		}
		count = 0;
	}
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	GetEventString(event, "networkid", conn_steamid, 40);
	
	char query[300];
	Format(query, sizeof(query), "SELECT Reason FROM Warnings WHERE SteamID = '%s'", conn_steamid);
	DBResultSet hQuery = SQL_Query(db, query);
	int rowCount = SQL_GetRowCount(hQuery);
	
	if (rowCount < 1 && strncmp(conn_steamid, "STEAM_", 6) == 0)
	{
		finalName = "//UKENDT//";
		char choice[50];
		choice = "TEST";
		char adminName[40] = "//UKENDT//";
		
		Format(query, sizeof(query), "INSERT INTO Warnings (Username, SteamID, Reason, Admin) VALUES ('%s', '%s', '%s', '%s')", finalName, conn_steamid, choice, adminName);
		DBResultSet hQuery2 = SQL_Query(db, query);
		PrintToServer("First Time Entry added for %s", conn_steamid);
		
		delete hQuery2;
	}
	delete hQuery;
}


/* Helpers */


stock char Command_GetPlayerList() 
	{
		indexInt = 0;
		for (int i = 1; i <= MaxClients;i++) 
		{ 
		    if (IsClientConnected(i) && !IsFakeClient(i)) 
		  	{
		  		indexInt++;
		  		GetClientName(i, names[indexInt], 40);
		 	}
		}
	}

stock int Command_GetPlayerCount()
	{
		playercount = 0;
		
		for(int i = 1; i <= MaxClients; i++)
		{
		    if(IsClientConnected(i) && !IsFakeClient(i)) playercount++;
		}
	}

public bool hasTargetReason(const char[] reason, int rowCount)
{
	for (int y = 1; y <= rowCount;y++)
	{
		if (StrEqual(playerWarns[y], reason))
		{
			return true;
		}
		else if (rowCount == y)
		{
			return false;
		}
	}
	return false;
}