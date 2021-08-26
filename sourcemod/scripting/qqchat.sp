/**
 * QQChat - Have a chat between CS:GO Server and QQ.
 *          Makesure [message channel] has been deployed!
 * by CarOL
 * visit https://docs.csgowiki.top/message-channel
 * 
 * Changelog:
 * 0.1   - 25.08.2021: Functional testing
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <socket>

#define LENGTH_NAME 32
#define LENGTH_MESSAGE 128
#define LENGTH_IP 32
#define LENGTH_URL 128
#define LENGTH_TOKEN 64

ConVar g_QQChatHostCvar;
ConVar g_QQChatPortCvar;
ConVar g_QQChatRemarkCvar;
ConVar g_QQChatQQGroupCvar;
ConVar g_QQChatTriggerCvar;
ConVar g_MessageChannelApiCvar;
ConVar g_MessageChannelTokenCvar;

public Plugin myinfo = {
	name = "[CSGOWiki] QQChat",
	author = "CarOL",
	description = "Just Chat!",
    version = "v0.1",
	url = "https://docs.csgowiki.top/message-channel"
}

public void OnPluginStart() {
    // ConVar settings
    {
        ConVar serverHostCvar = FindConVar("net_public_adr");
        char serverip[LENGTH_IP] = "unknown";
        if (serverHostCvar != INVALID_HANDLE) {
            GetConVarString(serverHostCvar, serverip, sizeof(serverip));
        }
        g_QQChatHostCvar = CreateConVar("sm_qqchat_host", serverip, "[IP] or [Domain] of the current server");
        g_QQChatPortCvar = CreateConVar("sm_qqchat_port", "54321", "[TCP port] of the current server using for message channel");
        g_QQChatRemarkCvar = CreateConVar("sm_qqchat_remark", "unknown", "[Remark] of the current server, shown as [unknown] by default");
        g_QQChatQQGroupCvar = CreateConVar("sm_qqchat_qqgroup", "", "[QQ Group] which current server is connected to");
        g_QQChatTriggerCvar = CreateConVar("sm_qqchat_trigger", ".。!", "Each trigger takes one char");
        g_MessageChannelApiCvar = CreateConVar("sm_message_channel_api", "http://example.com:9090", "Set message channel api url");
        g_MessageChannelTokenCvar = CreateConVar("sm_message_channel_token", "", "[Access token] for message channel authentication. maxlength=64", FCVAR_PROTECTED);

        AutoExecConfig(true, "qqchat");
    }
    // Command register
    {

    }
}

public void OnConfigsExecuted() {
    // init socket
    Handle hSocket = SocketCreate(SOCKET_TCP, OnSocketError);
    SocketSetOption(hSocket, SocketReuseAddr, 1);
    SocketBind(hSocket, "0.0.0.0", GetConVarInt(g_QQChatPortCvar));
    SocketListen(hSocket, OnSocketIncoming);
    // register message channel
    RegisterOrLogoutMessageChannel(true);
}

public void OnPluginEnd() {
    OnMapEnd();
}

public void OnMapEnd() {
    // logout message channel
    RegisterOrLogoutMessageChannel(false);
}

void RegisterOrLogoutMessageChannel(bool isRegister=true) {
    // init request
    char url[LENGTH_URL];
    if (isRegister) {
        FormatURL(url, "api/register");
    }
    else {
        FormatURL(url, "api/logout");
    }
    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("Content-Type", "application/json");

    // init post data
    char svHost[LENGTH_IP];
    char svRemark[LENGTH_NAME];
    int svPort = 0;
    int qqgroup = 0;
    FetchConVarStrings(svHost, svPort, svRemark, qqgroup);
    JSONObject postData = new JSONObject();
    postData.SetString("sv_host", svHost);
    postData.SetInt("sv_port", svPort);
    postData.SetString("sv_remark", svRemark);
    postData.SetInt("qq_group", qqgroup);

    request.Post(postData, RegisterOrLogoutRequestCallback, isRegister);
    delete postData;
}

void RegisterOrLogoutRequestCallback(HTTPResponse response, bool isRegister) {
    if (response.Status == HTTPStatus_OK) {
        if (isRegister) {
            PrintToServer("[QQChat] 消息通道连接成功");
        }
        else {
            PrintToServer("[QQChat] 消息通道注销成功");
        }
    }
    else if (response.Status == HTTPStatus_BadRequest) {
        JSONObject json_obj = view_as<JSONObject>(response.Data);
        char detail[LENGTH_MESSAGE];
        json_obj.GetString("detail", detail, sizeof(detail));
        PrintToServer("[QQChat] 消息通道连接失败：%s", detail);
        delete json_obj;
    }
    else {
        PrintToServer("[QQChat] 消息通道连接失败：%d", response.Status);
    }
}

public Action OnSocketIncoming(Handle socket, Handle newSocket, char[] remoteIP, int remotePort, any arg) {
    SocketSetReceiveCallback(newSocket, OnSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnSocketError);
}

public Action OnSocketError(Handle socket, const int errorType, const int errorNum, any args) {
	LogError("socket error %d (errno %d)", errorType, errorNum);
	CloseHandle(socket);
}

public Action OnSocketReceive(Handle socket, char[] receiveData, const int dataSize, any hFile) {
    if (dataSize <= 1 || receiveData[0] != '{') {
        PrintToServer("[Socket] receive error: %s", receiveData);
        return;
    }
    JSONObject json_obj = JSONObject.FromString(receiveData);
    char sender[LENGTH_NAME];
    char message[LENGTH_MESSAGE];
    int msg_type = json_obj.GetInt("message_type");
    json_obj.GetString("sender", sender, sizeof(sender));
    json_obj.GetString("message", message, sizeof(message));

    if (msg_type == 0) {
        PrintToChatAll("[\x09QQ\x01] \x04%s\x01：%s", sender, message);
        PrintToServer("[QQ] \x04%s\x01：%s", sender, message);
    }
    delete json_obj;
	SocketSend(socket, "ok", -1);
}

public Action OnSocketDisconnected(Handle socket, any arg) {
	CloseHandle(socket);
}

void FormatURL(char[] url, const char[] apiPath, bool withToken=true) {
    char token[LENGTH_TOKEN];
    char format[LENGTH_NAME];
    GetConVarString(g_MessageChannelApiCvar, url, LENGTH_URL);
    GetConVarString(g_MessageChannelTokenCvar, token, sizeof(token));
    if (url[strlen(url) - 1] == '/') {
        strcopy(format, sizeof(format), "%s%s");
    }
    else {
        strcopy(format, sizeof(format), "%s/%s");
    }
    if (withToken) {
        StrCat(format, sizeof(format), "?token=%s");
        Format(url, LENGTH_URL, format, url, apiPath, token);
    }
    else {
        Format(url, LENGTH_URL, format, url, apiPath);
    }
}

void FetchConVarStrings(char[] svHost, int& svPort, char[] svRemark, int& qqgroup) {
    GetConVarString(g_QQChatHostCvar, svHost, LENGTH_IP);
    GetConVarString(g_QQChatRemarkCvar, svRemark, LENGTH_NAME);
    svPort = GetConVarInt(g_QQChatPortCvar);
    qqgroup = GetConVarInt(g_QQChatQQGroupCvar);
}