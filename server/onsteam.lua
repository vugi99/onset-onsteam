
function string:split(sep) -- http://lua-users.org/wiki/SplitJoin
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

local function getOS()
   local raw_os_name, raw_arch_name = '', ''
           -- Unix-based OS
           raw_os_name = io.popen('uname -s','r'):read('*l')
           raw_arch_name = io.popen('uname -m','r'):read('*l')
           if raw_os_name == nil and raw_arch_name == nil then
              -- Windows
               local env_OS = os.getenv('OS')
               local env_ARCH = os.getenv('PROCESSOR_ARCHITECTURE')
               if env_OS and env_ARCH then
                   raw_os_name, raw_arch_name = env_OS, env_ARCH
               end
           end
   raw_os_name = (raw_os_name):lower()
   raw_arch_name = (raw_arch_name):lower()

   local os_patterns = {
       ['windows'] = 'Windows',
       ['linux'] = 'Linux',
       ['mac'] = 'Mac',
       ['darwin'] = 'Mac',
       ['^mingw'] = 'Windows',
       ['^cygwin'] = 'Windows',
       ['bsd$'] = 'BSD',
       ['SunOS'] = 'Solaris',
   }
   
   local arch_patterns = {
       ['^x86$'] = 'x86',
       ['i[%d]86'] = 'x86',
       ['amd64'] = 'x86_64',
       ['x86_64'] = 'x86_64',
       ['Power Macintosh'] = 'powerpc',
       ['^arm'] = 'arm',
       ['^mips'] = 'mips',
   }

   local os_name, arch_name = 'unknown', 'unknown'

   for pattern, name in pairs(os_patterns) do
       if raw_os_name:match(pattern) then
           os_name = name
           break
       end
   end
   for pattern, name in pairs(arch_patterns) do
       if raw_arch_name:match(pattern) then
           arch_name = name
           break
       end
   end
   return os_name, arch_name
end

local function GetServerPath()
   local os_name, arch_name = getOS()
   local get_working_dir = nil
   if os_name == "Windows" then
       get_working_dir = io.popen("cd")
   else
       get_working_dir = io.popen("pwd")
   end
   local server_path = get_working_dir:read("*a")
   if os_name ~= "Windows" then
      server_path = server_path:split("\n")[1]
   end
   io.close(get_working_dir)
   if (server_path and server_path ~= "") then
      local server_path_new = server_path:split("\n")[1]
      local server_path_new = '"' .. server_path_new .. '"'
      return server_path_new
   else
      print("Can't get server path")
   end
end

local function SearchSteamcmdWindows()
   local get_working_dir = io.popen("cd .. && cd")
   local _steamcmd_path = get_working_dir:read("*a")
   io.close(get_working_dir)
   if (_steamcmd_path and _steamcmd_path ~= "") then
      local steamcmd_path_new = _steamcmd_path:split("\n")[1]
      steamcmd_path_new = steamcmd_path_new .. "\\steamcmd.exe"
      return steamcmd_path_new
   else
      print("Can't get server parent folder")
   end
   return ""
end

local function IsSteamCmd()
   local steamcmd_check_log
   if steamcmd_path ~= "" then
      local steamcmd_check = io.popen(steamcmd_path .. " +quit")
      steamcmd_check_log = steamcmd_check:read("*a")
      io.close(steamcmd_check)
   else
      print("Searching Steamcmd")
      local os_name, arch_name = getOS()
      local steamcmd_check
      if os_name == "Windows" then
          local steamcmd_path_new = SearchSteamcmdWindows()
          steamcmd_check = io.popen(steamcmd_path_new .. " +quit")
          steamcmd_path = steamcmd_path_new
      else
          steamcmd_check = io.popen("../steamcmd.sh +quit")
          steamcmd_path = "../steamcmd.sh"
      end
      if steamcmd_check then
         steamcmd_check_log = steamcmd_check:read("*a")
         io.close(steamcmd_check)
      end
   end
   if steamcmd_check_log then
      for i,v in ipairs(steamcmd_check_log:split("\n")) do
         if v == "Steam Console Client (c) Valve Corporation" then
            return true
         end
      end
   end
   print("Can't find steamcmd, please change steamcmd_path in the config.lua")
   steamcmd_path = ""
   return false
end

local function UpdateServer()
   local server_config = io.open("server_config.json", 'r')
   if server_config then
      local contents = server_config:read("*a")
      local server_config_tbl_old = json_decode(contents);
      io.close(server_config)
      local server_path_new = GetServerPath()
      local update_server = io.popen(steamcmd_path .. " +login anonymous +force_install_dir " .. server_path_new .. " +app_update 1204170 +quit")
      local update_server_log = update_server:read("*a")
      io.close(update_server)
      local success = false
      for i,v in ipairs(update_server_log:split("\n")) do
         if v == "Success! App '1204170' fully installed." then
            success = true
         end
      end
      if success then
         print("Server Updated")
         local server_config = io.open("server_config.json", 'r')
         if server_config then
             local contents = server_config:read("*a")
             local server_config_tbl = json_decode(contents);
             io.close(server_config)
             for k,v in pairs(server_config_tbl_old) do
                if server_config_tbl[k] then
                   server_config_tbl[k] = server_config_tbl_old[k]
                end
             end
             local server_config_w = io.open("server_config.json", 'w')
             if server_config_w then
                 local contents = json_encode(server_config_tbl)
                 server_config_w:write(contents)
                 io.close(server_config_w)
                 ServerExit("Server Updated")
             else
                 print("Can't write on server config")
             end
         else
             print("Can't find server config")
         end
      else
         print("Error when updating server")
      end
   else
      print("Can't find server config")
   end
end

local function IsServerUpdate()
    if IsSteamCmd() then
    local server_path_new = GetServerPath()
    if server_path_new then
    local manifest_file = io.open("steamapps/appmanifest_1204170.acf", "r")
    if manifest_file then
    local onset_server_status = manifest_file:read("*a")
    io.close(manifest_file)
    local buildid = nil
    for i,v in ipairs(onset_server_status:split("\n")) do
       for i2,v2 in ipairs(v:split('"')) do
          if (i2 == 2 and v2 == "buildid") then
             if v:split('"')[4] then
                buildid = v:split('"')[4]
             end
          end
       end
    end
    if buildid then
       local info_request = io.popen(steamcmd_path .. " +login anonymous +app_info_update 1 +app_info_print 1204170 +quit")
       local app_info = info_request:read("*a")
       io.close(info_request) 
       local buildid_latest = nil
       for i,v in ipairs(app_info:split("\n")) do
          if v:split('"')[2] then
             if v:split('"')[2] == "public" then
                if app_info:split("\n")[i+2]:split('"')[2] then
                  if app_info:split("\n")[i+2]:split('"')[2] == "buildid" then
                     buildid_latest = app_info:split("\n")[i+2]:split('"')[4]
                  end
                end
             end
          end
       end
       if buildid_latest then
           if buildid ~= buildid_latest then
              return true, buildid, buildid_latest
           end
       else
          print("Can't find build id in app_info_print")
       end
    else
        print("Can't find build id in appmanifest_1204170.acf")
    end
   else
      print("Can't find appmanifest_1204170.acf")
   end
   end
   end
   return false
end

if update_on_start then
   AddEvent("OnPackageStart",function()
       local server_update, buildid, buildid_latest = IsServerUpdate()
       if not server_update then
          print("No Updates for Onset Server")
       else
          print("Current build : " .. buildid .. " Latest build : ".. buildid_latest)
          print("Update Available for Onset Server")
          UpdateServer()
       end
   end)
end

local function IsAdmin(ply)
   for i,v in ipairs(admins) do
      if v == tostring(GetPlayerSteamId(ply)) then
         return true
      end
   end
   return false
end

local function Command_search_updates(ply)
   if IsAdmin(ply) then
      AddPlayerChat(ply,"Searching for updates")
      local server_update, buildid, buildid_latest = IsServerUpdate()
      if not server_update then
          AddPlayerChat(ply,"No Updates for Onset Server")
      else
         AddPlayerChat(ply,"Update Available for Onset Server")
         AddPlayerChat(ply,"Current build : " .. buildid .. " Latest build : ".. buildid_latest)
      end
      return server_update
   end
   AddPlayerChat(ply,"Your are not admin")
end

AddCommand("onsteam_search_updates",Command_search_updates)

AddCommand("onsteam_update_server",function(ply)
    local server_update = Command_search_updates(ply)
    if server_update then
       UpdateServer()
    end
end)