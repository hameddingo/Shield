package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "Boobs",
    "Feedback",
    "lock_join",
    "antilink",
    "antitag",
    "gps",
    "auto_leave",
    "block",
    "tagall",
    "arabic_lock",
    "welcome",
    "google",
    "sms",
    "Debian_service",
    "sudoers",
    "add_admin",
    "anti_spam",
    "add_bot",
    "owners",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban"
    },
    sudo_users = {138012635,114671225},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[Shield bot 2.3
    
     Hello my Good friends 
     
    ‼️ this bot is made by : @KinG_SuPeR_AdMiN_SHIELD
   〰〰〰〰〰〰〰〰
   ߔࠀ   our admins are : 
   ߔࠀ   @KinG_SuPeR_AdMiN_SHIELD
   ߔࠀ   @persian_king_hackers
   〰〰〰〰〰〰〰〰
  ♻️ You can send your Ideas and messages to Us By sending them into bots account by this command :
   تمامی درخواست ها و همه ی انتقادات و حرفاتونو با دستور زیر بفرستین به ما
   !feedback (your ideas and messages)
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
Create a group
گروه جدیدی بسازید

!createrealm [Name]
Create a realm
گروه مادر جدیدی بسازید

!setname [Name]
Set realm name
اسم گروه مادر را تغییر بدهید

!setabout [GroupID] [Text]
Set a group's about text
در مورد  آن گروه توضیحاتی را بنویسید (ای دی گروه را بدهید )

!setrules [GroupID] [Text]
Set a group's rules
در مورد آن گروه قوانینی تعیین کنید ( ای دی گروه را بدهید )

!lock [GroupID] [setting]
Lock a group's setting
تنظیکات گروهی را قفل بکنید

!unlock [GroupID] [setting]
Unock a group's setting
تنظیمات گروهی را از قفل در بیاورید 

!wholist
Get a list of members in group/realm
لیست تمامی اعضای گروه رو با ای دی شون نشون میده

!who
Get a file of members in group/realm
لیست تمامی اعضای گروه را با ای دی در فایل متنی دریافت کنید

!type
Get group type
در مورد نقش گروه بگیرید

!kill chat [GroupID]
Kick all memebers and delete group 
️تمامی اعضای گروه را حذف میکند 

!kill realm [RealmID]
Kick all members and delete realm
تمامی اعضای گروه مارد را حذف میکند

!addadmin [id|username]
Promote an admin by id OR username *Sudo only
ادمینی را اضافه بکنید


!removeadmin [id|username]
Demote an admin by id OR username *Sudo only
️ادمینی را با این دستور صلب مقام میکنید 

!list groups
Get a list of all groups
لیست تمامی گروه هارو میده

!list realms
Get a list of all realms
لیست گروه های مادر را میدهد


!log
Get a logfile of current group or realm
تمامی عملیات گروه را میدهد

!broadcast [text]
Send text to all groups ✉️
✉️ با این دستور به تمامی گروه ها متنی را همزمان میفرستید  .

!br [group_id] [text]
This command will send text to [group_id]✉️
با این دستور میتونید به گروه توسط ربات متنی را بفرستید 

You Can user both "!" & "/" for them
میتوانید از هردوی کاراکتر های ! و / برای دستورات استفاده کنید


]],
    help_text = [[
bots Help for mods : Plugins

Banhammer : 


Help For Banhammer دستوراتی برای کنترل گروه

!Kick @UserName or ID 
شخصی را از گروه حذف کنید . همچنین با ریپلی هم میشه

!Ban @UserName or ID
برای بن کردن شخص اسفاده میشود . با ریپلی هم میشه


!Unban @UserName
برای آنبن کردن شخصی استفاده میشود . همچنین با ریپلی هم میشه

For Admins :

!banall ID
برای بن گلوبال کردن از تمامی گروه هاست باید ای دی بدین با ریپلی هم میشه

!unbanall ID
برای آنبن کردن استفاده میشود ولی فقط با ای دی میشود

〰〰〰〰〰〰〰〰〰〰
2. GroupManager :

!lock leave
اگر کسی از گروه برود نمیتواند برگردد

!lock tag
برای مجوز ندادن به اعضا از استفاده کردن @  و #  برای تگ


!Creategp "GroupName"
you can Create group with this comman
با این دستور برای ساخت گروه استفاده بکنید


!lock member
For locking Inviting users
برای جلوگیری از آمدن اعضای جدید استفاده میشود


!lock bots
for Locking Bots invitation
برای جلوگیری از ادد کردن ربا استفاده میشود


!lock name
To lock the group name for every bodey
برای قفل کردن اسم استفاده میشود

!setflood set the group flood control  
تعداد اسپم را در گروه تعیین میکنید

!settings
Watch group settings
تنظیمات فعلی گروه را میبینید

!owner
watch group owner
آیدی سازنده گروه رو میبینید

!setowner user_id
You can set someone to the group owner‼️
برای گروه سازنده تعیین میکنید 

!modlist
catch Group mods
لیست مدیران گروه را میگیرید

!lock adds 
to lock commercial Breaks and Other group links in group
از دادن لینک گروه یا سایت یا هرچیز دیگه توی گروه جلوگیری میکند .

!lock eng
You cannot speak english in group
از حرف زدن انگلیسی توی گروه جلوگیری میکند

!lock settings
To lock settings of group and unchange able
برای قفل کردن تنظیمات گروه به کار میره

!lock badw
To lock using badwords in group
برای جلوگیری از استفاده کردن حرف های رکیک استفاده میشود


!lock join 
to lock joining the group by link
برای جلوگیری از وارد شدن به کروه با لینک


!lock flood
lock group flood
از اسپم دادن در گروه جلوگیری کنید

!unlock (bots-member-flood-photo-name-tag-link-join-Arabic)
Unlock Something
موارد بالا را با این دستور آزاد میسازید

!rules  && !set rules
TO see group rules or set rules
برای دیدن قوانین گروه و یا انتخاب قوانین 

!about or !set about
watch about group or set about
در مورد توضیحات گروه میدهد و یا توضیحات گروه رو تعیین کنید 

!res @username
see Username INfo
در مورد اسم و ای دی شخص بهتون میده 

!who
Get Ids Chat
همه ی ای دی های موجود در چت رو بهتون میده

!log 
get members id
تمامی فعالیت های انجام یافته توسط شما و یا مدیران رو نشون میده

!all
Says every thing he knows about a group
در مورد تمامی اطلاعات ثبت شده در مورد گروه میدهد


!newlink
Changes or Makes new group link
لینک گروه رو عوض میکنه 

!link
gets The Group link
لینک گروه را در گروه نمایش میده

!linkpv
sends the group link to the PV
برای دریافت لینک در پیوی استفاده میشه 
〰〰〰〰〰〰〰〰
Admins :

!add
to add the group as knows
برای مجوز دادن به ربات برای استفاده در گروه


!rem
to remove the group and be unknown
برای ناشناس کردن گروه برای ربات توسط مدیران اصلی

!setgpowner (Gpid) user_id
For Set a Owner of group from realm
 برای تعیین سازنده ای برای گروه  از گروه مادر

!addadmin [Username]
to add a Global admin to the bot
برای ادد کردن ادمین اصلی ربات


!removeadmin [username]
to remove an admin from global admins
برای صلب ادمینی از ادمینای اصلی

!sms [id] (text)
To send a message to an account by his/her ID
برای فرستادن متنی توسط ربات به شخصی با ای دی اون


〰〰〰〰〰〰〰〰〰〰〰
3.!stats
To see the group stats
برای دیدن آمار گروه 

〰〰〰〰〰〰〰〰
4. Feedback
!feedback (text)
To send your ideas to the Moderation group
برای فرستادن انتقادات و پیشنهادات و حرف خود با مدیر ها استفاده میشه

〰〰〰〰〰〰〰〰〰〰〰
5. Tagall
!tagall (text)
To tags the every one and sends your message at bottom
تگ کردن همه ی اعضای گروه و نوشتن پیام شما زیرش


You Can user both "!" & "/" for them
می توانید از دو شکلک !  و / برای دادن دستورات استفاده کنید

@tel_shield
به کانال اتحاد شیلد بپیوندید

🇸 🇭 🇮 🇪 🇱 🇩 ™

]]

  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
