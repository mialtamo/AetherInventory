local _, A = ...
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local tinsert = table.insert
local FRAME_W, FRAME_H = 1110, 720
local GOLD, LIGHT, MUTED, TEAL = {0.93,0.72,0.38}, {0.94,0.90,1}, {0.60,0.56,0.73}, {0.37,0.96,0.76}
local frame, mainText, model, upgradeText, summaryText, statText, scrollFrame, scrollContent
local searchBox, footerText, footerGoldText
local equippedWidgets, bagSections, filterButtons = {}, {}, {}
local currentSnapshot, filter = nil, "All"
local emptyFilterText
local gearElements, characterTabs, characterScroll, characterContent = {}, {}, nil, nil
local settingsPage, settingsSwatches, panelTexture, petPage, petFields
local characterPage="Gear"
local pageRows={}
local keyToggleButton
local toggleBindButtons={}
local categories={"All","Equipment","Consumables","Materials","Quest","Junk","Recent"}
local characterPages={"Gear","Stats","Reputation","Skills","Currency","Titles","Pet","Settings"}
local DEFAULT_BINDING_ACTIONS={B="TOGGLEBACKPACK",C="TOGGLECHARACTER0"}
local slotW,gap,columns=40,5,11
local UIReady=false
local merchantOpenedInventory=false
local autoSortEnabled=true
local autoSortPending,autoSortSettling,autoSortRunning=false,false,false
local autoSortDelay=0
local autoSortSeeded=false
local lastAutoSortSignature
local autoSortWaitForCursor=false
local recentCounts,recentItems={},{}
local recentLifetime=90
local recentSeeded=false
local rightClickDiagnostics=false
local DEFAULT_COLORS={
  window={1,1,1,1}, bag={.10,.078,.15,.75}, header={.18,.11,.27,.96}, slot={.10,.08,.15,.93},
}

local function uiColor(key)
  AetherInventoryDB=AetherInventoryDB or {}
  AetherInventoryDB.colors=AetherInventoryDB.colors or {}
  local color=AetherInventoryDB.colors[key]
  if type(color)~="table" then
    color={DEFAULT_COLORS[key][1],DEFAULT_COLORS[key][2],DEFAULT_COLORS[key][3],DEFAULT_COLORS[key][4]}
    AetherInventoryDB.colors[key]=color
  end
  for i=1,4 do
    if type(color[i])~="number" then color[i]=DEFAULT_COLORS[key][i] end
    color[i]=max(0,min(1,color[i]))
  end
  return color
end

local function applySavedColors()
  if panelTexture then
    local c=uiColor("window")
    panelTexture:SetVertexColor(c[1],c[2],c[3]);panelTexture:SetAlpha(c[4])
  end
  local bag,header,slot=uiColor("bag"),uiColor("header"),uiColor("slot")
  for _,section in pairs(bagSections) do
    if section.bg then section.bg:SetColorTexture(unpack(bag)) end
    if section.header then section.header:SetColorTexture(unpack(header)) end
    for _,button in ipairs(section.slots) do
      if button.bg then button.bg:SetColorTexture(unpack(slot)) end
      if button.core then button.core:SetColorTexture(unpack(slot)) end
    end
  end
  if settingsSwatches then
    for key,swatch in pairs(settingsSwatches) do swatch:SetColorTexture(unpack(uiColor(key))) end
  end
end

local function textLabel(parent,str,size,color)
  local t=parent:CreateFontString(nil,"OVERLAY")
  t:SetFont("Fonts\\FRIZQT__.TTF",size or 12,"OUTLINE")
  t:SetTextColor(unpack(color or LIGHT))
  t:SetText(str or "")
  t:SetJustifyH("LEFT")
  return t
end
local function tint(parent,layer,r,g,b,a)
  local tex=parent:CreateTexture(nil,layer or "BACKGROUND")
  tex:SetColorTexture(r,g,b,a or 1)
  return tex
end
local function line(parent,x,y,w,r,g,b,a)
  local t=tint(parent,"BORDER",r or .77,g or .56,b or .35,a or .70)
  t:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  t:SetSize(w,1)
  return t
end
local function makeButton(parent,str,x,y,w,h,cb,template)
  local b=CreateFrame("Button",nil,parent,template)
  b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
  b:SetSize(w,h)
  local bg=tint(b,"BACKGROUND",.15,.11,.23,.90);bg:SetAllPoints()
  local border=tint(b,"BORDER",.63,.44,.75,.48);border:SetPoint("BOTTOMLEFT",0,0);border:SetPoint("BOTTOMRIGHT",0,0);border:SetHeight(2)
  local label=textLabel(b,str,12,{.94,.82,.58}); label:SetPoint("CENTER")
  b.label=label
  b:SetScript("OnEnter",function() bg:SetColorTexture(.24,.17,.34,.96) end)
  b:SetScript("OnLeave",function() bg:SetColorTexture(.15,.11,.23,.90) end)
  if cb then b:SetScript("OnClick",cb) end
  return b
end
local bagLayoutSignature
local function sortBags()
  if InCombatLockdown() then
    print("Aether Inventory: bags can only be sorted out of combat.")
    return
  end
  local container=C_Container
  if container and type(container.SortBags)=="function" then
    local ok,result=pcall(container.SortBags)
    if ok and result==false then ok=false end
    if ok then return true end
    print("Aether Inventory: the game could not sort your bags.")
  else
    print("Aether Inventory: this WoW Forever build does not expose bag sorting.")
  end
  return false
end
local function setAutoSort(enabled)
  if InCombatLockdown() then
    print("Aether Inventory: auto-sort can only be changed out of combat.")
    return
  end
  autoSortEnabled=enabled
  AetherInventoryDB=AetherInventoryDB or {}
  AetherInventoryDB.autoSortEnabled=enabled
  if A.autoSortButton then A.autoSortButton.label:SetText(enabled and "Auto-sort: On" or "Auto-sort: Off") end
  if enabled then
    lastAutoSortSignature=bagLayoutSignature()
    autoSortSeeded=true
  else
    autoSortPending=false;autoSortSettling=false;autoSortDelay=0
  end
end

bagLayoutSignature=function()
  local entries={}
  for _,bag in ipairs(A.bagIDs) do
    local size=A.BagSize(bag)
    for slot=1,size do
      local item=A.BagInfo(bag,slot)
      if item then
        entries[#entries+1]=bag..":"..slot..":"..tostring(item.itemID or item.hyperlink or "?")..":"..tostring(item.stackCount or 1)
      end
    end
  end
  return table.concat(entries,"|")
end
local function cursorHasItem()
  if type(CursorHasItem)=="function" then
    local ok,hasItem=pcall(CursorHasItem)
    if ok then return hasItem==true end
  end
  if type(GetCursorInfo)=="function" then
    local ok,kind=pcall(GetCursorInfo)
    if ok then return kind~=nil end
  end
  return false
end
local function queueAutoSort()
  if not autoSortEnabled or autoSortRunning then return end
  if not autoSortSeeded then
    lastAutoSortSignature=bagLayoutSignature()
    autoSortSeeded=true
    return
  end
  if not autoSortPending then
    autoSortPending=true;autoSortSettling=false;autoSortDelay=.4
  elseif not autoSortSettling then
    autoSortDelay=.4
  end
end
local function runQueuedAutoSort()
  if autoSortSettling then
    lastAutoSortSignature=bagLayoutSignature()
    autoSortSettling=false;autoSortPending=false
    return
  end
  autoSortPending=false
  if not autoSortEnabled then return end
  if InCombatLockdown() then return end
  if cursorHasItem() then
    autoSortPending=true;autoSortDelay=.6;autoSortWaitForCursor=true
    return
  end
  autoSortWaitForCursor=false
  local signature=bagLayoutSignature()
  if signature==lastAutoSortSignature then return end
  autoSortRunning=true
  local sorted=sortBags()
  autoSortRunning=false
  if sorted then
    autoSortPending=true;autoSortSettling=true;autoSortDelay=.5
  else
    lastAutoSortSignature=signature
  end
end

local function bagItemIdentity(item,bag,slot)
  local key=item and (item.hyperlink or item.itemID)
  if not key then key=A.BagLink(bag,slot) end
  return key and tostring(key) or nil
end
local function itemLockKey(item,bag,slot)
  -- Prefer a per-instance GUID so the lock follows the exact item across moves
  -- and auto-sort. If unavailable, lock by link/ID (safely covering duplicates).
  local location
  if ItemLocation and type(ItemLocation.CreateFromBagAndSlot)=="function" then
    local ok,value=pcall(ItemLocation.CreateFromBagAndSlot,ItemLocation,bag,slot)
    if ok then location=value end
  end
  local getGUID=C_Item and C_Item.GetItemGUID
  if location and type(getGUID)=="function" then
    local ok,guid=pcall(getGUID,location)
    if ok and type(guid)=="string" and guid~="" then return "guid:"..guid end
  end
  local key=item and (item.hyperlink or item.itemID) or A.BagLink(bag,slot)
  return key and ("item:"..tostring(key)) or nil
end
local function isBagItemLocked(item,bag,slot)
  local key=itemLockKey(item,bag,slot)
  return key~=nil and AetherInventoryDB and AetherInventoryDB.lockedItems
    and AetherInventoryDB.lockedItems[key]==true or false
end
local function scanRecentItems()
  local counts={}
  for _,bag in ipairs(A.bagIDs) do
    for slot=1,A.BagSize(bag) do
      local item=A.BagInfo(bag,slot)
      if item then
        local key=bagItemIdentity(item,bag,slot)
        if key then counts[key]=(counts[key] or 0)+(tonumber(item.stackCount) or 1) end
      end
    end
  end
  local now=GetTime()
  if recentSeeded then
    for key,count in pairs(counts) do
      if not recentCounts[key] or count>recentCounts[key] then recentItems[key]=now+recentLifetime end
    end
  end
  recentCounts=counts
  recentSeeded=true
  for key,expires in pairs(recentItems) do if expires<=now then recentItems[key]=nil end end
end
local function isRecentItem(data)
  if not data then return false end
  local key=bagItemIdentity(data.item,data.bag,data.slot)
  return key~=nil and (recentItems[key] or 0)>GetTime()
end

local function merchantIsOpen()
  return MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown() or false
end

local secureItemTargeting=false
local function updateSecureItemTargeting(force)
  if not UIReady or InCombatLockdown() then return end
  local targeting=false
  if not merchantIsOpen() and type(SpellCanTargetItem)=="function" then
    local ok,value=pcall(SpellCanTargetItem)
    targeting=ok and value==true
  end
  if not targeting and not merchantIsOpen() and type(SpellCanTargetItemID)=="function" then
    local ok,value=pcall(SpellCanTargetItemID)
    targeting=ok and value==true
  end
  if secureItemTargeting==targeting and not force then return end
  for _,section in pairs(bagSections) do
    for _,button in ipairs(section.slots) do
      local item=A.BagInfo(button.bagID,button.slotID)
      local locked=item and isBagItemLocked(item,button.bagID,button.slotID)
      if targeting and item and not locked then
        -- Use the physical slot so item-target spells (Feed Pet, etc.) consume
        -- the item under the cursor from this exact bag location.
        button:SetAttribute("type1","item")
        button:SetAttribute("item1",tostring(button.bagID).." "..tostring(button.slotID))
        button:SetAttribute("bag1",button.bagID);button:SetAttribute("slot1",button.slotID)
      else
        button:SetAttribute("type1",nil);button:SetAttribute("item1",nil)
        button:SetAttribute("bag1",nil);button:SetAttribute("slot1",nil)
      end
    end
  end
  secureItemTargeting=targeting
end

-- WoW Forever's MerchantFrame_OnShow explicitly opens Blizzard's physical
-- bags. Let that protected UI flow complete, then close only the native bags
-- it just opened. Aether's own inventory remains visible and interactive.
local function installMerchantBagCloseHook()
  if A.merchantBagCloseHookInstalled or type(hooksecurefunc)~="function" or type(OpenAllBags)~="function" then return end
  A.merchantBagCloseHookInstalled=true
  hooksecurefunc("OpenAllBags",function(owner)
    if owner~=MerchantFrame then return end
    -- This post-hook runs after the vendor's OpenAllBags call has completed,
    -- but still before the next frame is drawn. Closing synchronously avoids
    -- showing the Blizzard bags for a visible frame.
    if not InCombatLockdown() and merchantIsOpen() and type(CloseAllBags)=="function" then
      CloseAllBags(MerchantFrame,true)
    end
  end)
end

local function setBagActionMode()
  if InCombatLockdown() then return end
  local selling=merchantIsOpen()
  for _,section in pairs(bagSections) do
    for _,button in ipairs(section.slots) do
      local item=A.BagInfo(button.bagID,button.slotID)
      local locked=item and isBagItemLocked(item,button.bagID,button.slotID)
      button:SetAttribute("aetherLocked",locked and true or false)
      if item and not locked and not selling then
        -- Resolve normal use by item link inside the secure action handler.
        -- This avoids calling protected item-use APIs from addon click code.
        local link=item.hyperlink or A.BagLink(button.bagID,button.slotID)
        if not link and item.itemID then link="item:"..tostring(item.itemID) end
        button:SetAttribute("type2","item")
        button:SetAttribute("item2",link)
        button:SetAttribute("bag2",button.bagID);button:SetAttribute("slot2",button.slotID)
      else
        button:SetAttribute("type2",nil);button:SetAttribute("item2",nil)
        button:SetAttribute("bag2",nil);button:SetAttribute("slot2",nil)
      end
    end
  end
  updateSecureItemTargeting(true)
end

-- Vendor sales use Blizzard's bag API only while a merchant is open, which
-- the client permits. Normal item use stays on SecureActionButtonTemplate.
local function handleVendorItemClick(button,mouseButton)
  if mouseButton~="RightButton" or not merchantIsOpen() then return end
  local data=button.aetherData
  local item=data and data.item or A.BagInfo(button.bagID,button.slotID)
  if not item then return end
  if isBagItemLocked(item,button.bagID,button.slotID) then
    print("Aether Inventory: that item is locked.")
    return
  end
  if type(UseContainerItem)=="function" then
    UseContainerItem(button.bagID,button.slotID)
  elseif C_Container and type(C_Container.UseContainerItem)=="function" then
    C_Container.UseContainerItem(button.bagID,button.slotID)
  end
end
local function toggleBagItemLock(lockButton)
  if InCombatLockdown() then
    print("Aether Inventory: item locks can only be changed out of combat.")
    return
  end
  local slotButton=lockButton and lockButton:GetParent()
  local data=slotButton and slotButton.aetherData
  if not data or not data.item then return end
  local key=itemLockKey(data.item,data.bag,data.slot)
  if not key then
    print("Aether Inventory: this item could not be identified, so it was not locked.")
    return
  end
  AetherInventoryDB=AetherInventoryDB or {}
  AetherInventoryDB.lockedItems=AetherInventoryDB.lockedItems or {}
  if AetherInventoryDB.lockedItems[key] then AetherInventoryDB.lockedItems[key]=nil
  else AetherInventoryDB.lockedItems[key]=true end
  setBagActionMode()
  if A.Refresh then A.Refresh() end
end
local function apiValue(fn,...)
  if type(fn)~="function" then return nil end
  local ok,a,b,c,d=pcall(fn,...)
  if ok then return a,b,c,d end
end
local DURABILITY_WARNING_PERCENT=20
local function durabilityState(current,maximum)
  local ok,state,percent=pcall(function()
    if type(current)~="number" or type(maximum)~="number" or maximum<=0 then return nil end
    local pct=floor(max(0,min(1,current/maximum))*100+0.5)
    if current<=0 then return "broken",0 end
    if pct<=DURABILITY_WARNING_PERCENT then return "low",pct end
    return nil,pct
  end)
  if ok then return state,percent end
end
local function equipmentDurability(slot)
  local current,maximum=apiValue(GetInventoryItemDurability,"player",slot)
  return durabilityState(current,maximum)
end
local function bagItemDurability(bag,slot)
  local container=C_Container
  local current,maximum=apiValue(container and container.GetContainerItemDurability,bag,slot)
  return durabilityState(current,maximum)
end
local function makeDurabilityBadge(parent)
  local bg=tint(parent,"OVERLAY",.62,.08,.12,.96)
  bg:SetSize(38,10);bg:SetPoint("BOTTOM",parent,"BOTTOM",0,2)
  local label=textLabel(parent,"",7,LIGHT)
  label:SetPoint("CENTER",bg,"CENTER",0,0);label:SetSize(38,10)
  bg:Hide();label:Hide()
  return {bg=bg,label=label}
end
local function showDurabilityBadge(badge,state,percent)
  if not badge then return end
  if state=="broken" then
    badge.bg:SetColorTexture(.68,.07,.12,.98)
    badge.label:SetText("BROKEN");badge.label:SetTextColor(1,.90,.86,1)
    badge.bg:Show();badge.label:Show()
  elseif state=="low" then
    badge.bg:SetColorTexture(.72,.39,.06,.98)
    badge.label:SetText("LOW "..tostring(percent).."%")
    badge.label:SetTextColor(1,.95,.78,1)
    badge.bg:Show();badge.label:Show()
  else
    badge.bg:Hide();badge.label:Hide()
  end
end
local function collectPageLines(page)
  local lines={}
  local function section(s) lines[#lines+1]={text=s,kind="section"} end
  local function row(k,v) lines[#lines+1]={text=k..":  "..tostring(v==nil and "—" or v),kind="row"} end
  if page=="Stats" then
    section("GENERAL")
    local hp,hpm=apiValue(UnitHealth,"player"),apiValue(UnitHealthMax,"player")
    row("Health",hp and hpm and (hp.." / "..hpm) or hp)
    local power,pmax=apiValue(UnitPower,"player"),apiValue(UnitPowerMax,"player")
    row("Mana / Power",power and pmax and (power.." / "..pmax) or power)
    local speed=apiValue(GetUnitSpeed,"player")
    row("Movement speed",speed and (floor(speed/7*100+0.5).."%"))
    section("PRIMARY ATTRIBUTES")
    for i,name in ipairs({"Strength","Agility","Stamina","Intellect","Spirit"}) do
      local _,v=apiValue(UnitStat,"player",i)
      row(name,v)
    end
    section("WEAPONS")
    local mhMin,mhMax,ohMin,ohMax=apiValue(UnitDamage,"player")
    row("Main hand",mhMin and mhMax and (string.format("%.1f – %.1f",mhMin,mhMax)))
    row("Off hand",ohMin and ohMax and ohMax>0 and (string.format("%.1f – %.1f",ohMin,ohMax)))
    local rmin,rmax=apiValue(UnitRangedDamage,"player")
    row("Ranged",rmin and rmax and (string.format("%.1f – %.1f",rmin,rmax)))
    row("Attack power",apiValue(UnitAttackPower,"player"))
    row("Ranged attack power",apiValue(UnitRangedAttackPower,"player"))
    section("DEFENSES")
    local armorBase,armorEffective=apiValue(UnitArmor,"player")
    local armor=armorEffective or armorBase or apiValue(GetArmor,"player") or apiValue(GetArmor)
    row("Armor",armor)
    local dodge=apiValue(GetDodgeChance);row("Dodge",dodge and string.format("%.1f%%",dodge))
    local parry=apiValue(GetParryChance);row("Parry",parry and string.format("%.1f%%",parry))
    local block=apiValue(GetBlockChance);row("Block",block and string.format("%.1f%%",block))
    section("COMBAT")
    local crit=apiValue(GetCritChance);row("Melee crit",crit and string.format("%.1f%%",crit))
    local rangedCrit=apiValue(GetRangedCritChance);row("Ranged crit",rangedCrit and string.format("%.1f%%",rangedCrit))
  elseif page=="Reputation" then
    section("FACTIONS")
    local rep=C_Reputation
    local n=rep and apiValue(rep.GetNumFactions)
    if type(n)=="number" then
      for i=1,n do
        local f=apiValue(rep.GetFactionDataByIndex,i)
        if f and f.name and not f.isHeader then
          local standing=f.reaction or ""
          local value=f.currentStanding and f.currentReactionThreshold and f.nextReactionThreshold and
            (tostring(f.currentStanding-f.currentReactionThreshold).." / "..tostring(f.nextReactionThreshold-f.currentReactionThreshold)) or ""
          row(f.name,(standing~="" and (standing.."  ") or "")..value)
        elseif f and f.name then section(f.name) end
      end
    else row("Reputation","Faction data is unavailable on this client") end
  elseif page=="Skills" then
    section("SKILLS & PROFESSIONS")
    local function skill(name,rank,maxRank)
      rank=tonumber(rank) or 0;maxRank=tonumber(maxRank) or 0
      local value=maxRank>0 and math.max(0,math.min(1,rank/maxRank)) or 0
      lines[#lines+1]={text=name,kind="skill",value=(maxRank>0 and (rank.." / "..maxRank) or tostring(rank)),progress=value}
    end
    local skillAPI=C_SkillInfo
    local n=skillAPI and apiValue(skillAPI.GetNumSkillLines) or apiValue(GetNumSkillLines)
    if type(n)=="number" then
      for i=1,n do
        local info
        if skillAPI and type(skillAPI.GetSkillLineInfo)=="function" then
          info=apiValue(skillAPI.GetSkillLineInfo,i)
        else
          local name,isHeader,_,rank,_,_,maxRank=apiValue(GetSkillLineInfo,i)
          if name then info={name=name,isHeader=isHeader,rank=rank,maxRank=maxRank} end
        end
        local name,isHeader,rank,maxRank
        if info then name,isHeader,rank,maxRank=info.name,info.isHeader,info.rank,info.maxRank end
        if name then
          if isHeader then section(name) else skill(name,rank,maxRank) end
        end
      end
    else row("Skills","Skill data is unavailable on this client") end
  elseif page=="Currency" then
    section("MONEY")
    local money=apiValue(GetMoney)
    if money then row("Carried",string.format("%dg %ds %dc",floor(money/10000),floor(money%10000/100),money%100)) end
    section("CURRENCIES")
    local ci=C_CurrencyInfo
    local n=ci and apiValue(ci.GetCurrencyListSize)
    if type(n)=="number" then
      for i=1,n do
        local info=apiValue(ci.GetCurrencyListInfo,i)
        if info and info.name then row(info.name,info.quantity) end
      end
    else row("Currencies","No currency list API is available") end
  elseif page=="Titles" then
    section("KNOWN TITLES")
    local n=apiValue(GetNumTitles)
    if type(n)=="number" then
      local current=apiValue(GetCurrentTitle)
      for i=1,n do
        if apiValue(IsTitleKnown,i) then
          local title=apiValue(GetTitleName,i)
          if title and title~="" then row(i==current and (title.." (active)") or title) end
        end
      end
    else row("Titles","Title data is unavailable on this client") end
  end
  return lines
end

local function saveUIColor(key,r,g,b,a)
  AetherInventoryDB=AetherInventoryDB or {}
  AetherInventoryDB.colors=AetherInventoryDB.colors or {}
  AetherInventoryDB.colors[key]={r,g,b,a}
  applySavedColors()
end

local function openColorPicker(key)
  local picker=ColorPickerFrame
  if not picker then
    print("Aether Inventory: the color picker is unavailable on this client.")
    return
  end
  local old=uiColor(key)
  old={old[1],old[2],old[3],old[4]}
  local function changed()
    local r,g,b=picker:GetColorRGB()
    local a=type(picker.GetColorAlpha)=="function" and picker:GetColorAlpha() or old[4]
    saveUIColor(key,r,g,b,a)
  end
  local function canceled(previous)
    if type(previous)=="table" then
      saveUIColor(key,previous.r or previous[1] or old[1],previous.g or previous[2] or old[2],
        previous.b or previous[3] or old[3],previous.a or previous.opacity or previous[4] or old[4])
    else
      saveUIColor(key,old[1],old[2],old[3],old[4])
    end
  end
  if type(picker.SetupColorPickerAndShow)=="function" then
    picker:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],opacity=old[4],hasOpacity=true,
      swatchFunc=changed,opacityFunc=changed,cancelFunc=canceled})
  else
    picker.hasOpacity=true;picker.opacity=old[4]
    picker.func=changed;picker.swatchFunc=changed;picker.opacityFunc=changed;picker.cancelFunc=canceled
    picker:SetColorRGB(old[1],old[2],old[3]);picker:Show()
  end
end

local function createSettingsPage()
  settingsPage=CreateFrame("Frame",nil,characterContent)
  settingsPage:SetPoint("TOPLEFT",characterContent,"TOPLEFT",0,0)
  settingsPage:SetSize(368,320)
  local note=textLabel(settingsPage,"Choose a background color. The picker also lets you adjust opacity.",11,MUTED)
  note:SetPoint("TOPLEFT",settingsPage,"TOPLEFT",7,-8);note:SetWidth(348);note:SetWordWrap(true)
  settingsSwatches={}
  local options={
    {"window","Window artwork"},{"bag","Bag section"},{"header","Bag header"},{"slot","Item slots"},
  }
  for i,entry in ipairs(options) do
    local key,label=entry[1],entry[2]
    local y=52+(i-1)*53
    local title=textLabel(settingsPage,label,12,LIGHT)
    title:SetPoint("LEFT",settingsPage,"TOPLEFT",8,-y-14)
    local button=CreateFrame("Button",nil,settingsPage)
    button:SetPoint("TOPLEFT",settingsPage,"TOPLEFT",194,-y)
    button:SetSize(154,30)
    local bg=tint(button,"BACKGROUND",.15,.11,.23,.92);bg:SetAllPoints()
    local border=tint(button,"BORDER",.63,.44,.75,.65);border:SetPoint("TOPLEFT",-1,1);border:SetPoint("BOTTOMRIGHT",1,-1)
    local swatch=tint(button,"ARTWORK",1,1,1,1);swatch:SetPoint("LEFT",button,"LEFT",8,0);swatch:SetSize(18,18)
    local labelText=textLabel(button,"Choose Color",11,{.94,.82,.58});labelText:SetPoint("LEFT",swatch,"RIGHT",8,0)
    settingsSwatches[key]=swatch
    button:SetScript("OnEnter",function() bg:SetColorTexture(.24,.17,.34,.96) end)
    button:SetScript("OnLeave",function() bg:SetColorTexture(.15,.11,.23,.92) end)
    button:SetScript("OnClick",function()openColorPicker(key)end)
  end
  local reset=makeButton(settingsPage,"Reset Purple Colors",194,-270,154,29,function()
    AetherInventoryDB=AetherInventoryDB or {}
    AetherInventoryDB.colors={}
    applySavedColors()
  end)
  local resetNote=textLabel(settingsPage,"Colors are saved automatically.",10,MUTED)
  resetNote:SetPoint("TOPLEFT",settingsPage,"TOPLEFT",8,-278)
  settingsPage:Hide()
end

local function petCall(fn,...)
  if type(fn)~="function" then return nil end
  local ok,a,b,c,d,e,f=pcall(fn,...)
  if ok then return a,b,c,d,e,f end
end
local function createPetPage()
  petPage=CreateFrame("Frame",nil,characterContent)
  petPage:SetPoint("TOPLEFT",characterContent,"TOPLEFT",0,0)
  petPage:SetSize(368,452)
  local title=textLabel(petPage,"PET COMPANION",14,GOLD)
  title:SetPoint("TOPLEFT",petPage,"TOPLEFT",9,-10)
  line(petPage,8,-35,350,.77,.56,.35,.70)
  petFields={}
  local fields={
    {"name","Pet",52},{"family","Family",77},{"level","Level",102},
    {"health","Health",127},{"speed","Movement speed",152},{"armor","Armor",177},
    {"damage","Damage",202},{"attackPower","Attack power",227},{"crit","Critical strike",252},
    {"resist1","Resistances",284},{"resist2","",307},{"happiness","Happiness",333},
    {"loyalty","Loyalty",358},{"diet","Diet",383},{"food","Compatible food",408},
  }
  for _,entry in ipairs(fields) do
    local key,label,y=entry[1],entry[2],entry[3]
    local t=textLabel(petPage,(label~="" and label..": " or "").."—",(key=="resist1" or key=="resist2") and 10 or 12,LIGHT)
    t:SetPoint("TOPLEFT",petPage,"TOPLEFT",12,-y)
    t:SetWidth(342)
    petFields[key]=t
  end
  petPage:Hide()
end
local function updatePetPage(snapshot)
  if not petFields or InCombatLockdown() then return end
  local hasPet=type(UnitExists)=="function" and UnitExists("pet")
  local dead=hasPet and type(UnitIsDead) == "function" and UnitIsDead("pet")
  local petName=hasPet and petCall(UnitName,"pet") or nil
  local family=hasPet and type(UnitCreatureFamily)=="function" and petCall(UnitCreatureFamily,"pet") or nil
  local level=hasPet and petCall(UnitLevel,"pet") or nil
  local hp=hasPet and petCall(UnitHealth,"pet") or nil
  local maxHP=hasPet and petCall(UnitHealthMax,"pet") or nil
  local health=hp and maxHP and (hp.." / "..maxHP) or "—"
  local speed=hasPet and petCall(GetUnitSpeed,"pet") or nil
  local speedText=type(speed)=="number" and (floor(speed/7*100+0.5).."%") or "—"
  local armorBase,armorEffective
  if hasPet then armorBase,armorEffective=petCall(UnitArmor,"pet") end
  local armor=armorEffective or armorBase
  local damageMin,damageMax
  if hasPet then damageMin,damageMax=petCall(UnitDamage,"pet") end
  local damage=damageMin and damageMax and string.format("%.1f – %.1f",damageMin,damageMax) or "—"
  local apBase,apPositive,apNegative
  if hasPet then apBase,apPositive,apNegative=petCall(UnitAttackPower,"pet") end
  local attackPower=(type(apBase)=="number" and (apBase+(apPositive or 0)+(apNegative or 0))) or nil
  local meleeCrit=hasPet and petCall(GetPetCritChance) or nil
  local crit=type(meleeCrit)=="number" and string.format("%.1f%%",meleeCrit) or "—"
  local petInfo=C_PetInfo
  local happy=hasPet and petInfo and petCall(petInfo.GetPetHappiness) or nil
  local happiness=happy and ({[1]="Unhappy",[2]="Content",[3]="Happy"})[happy] or "—"
  local loyalty=hasPet and petInfo and petCall(petInfo.GetPetLoyalty) or nil
  if type(loyalty)~="string" then loyalty=hasPet and petCall(GetPetLoyalty) or nil end
  local diets=hasPet and petInfo and petCall(petInfo.GetPetFoodTypes) or nil
  local diet="—"
  if type(diets)=="table" then
    local names={};for _,v in pairs(diets) do if type(v)=="string" and v~="" then names[#names+1]=v end end
    table.sort(names);if #names>0 then diet=table.concat(names,", ") end
  end
  petFields.name:SetText("Pet:  "..(petName or (hasPet and "Active pet" or "No active pet")))
  petFields.family:SetText("Family:  "..(family or "—"))
  petFields.level:SetText("Level:  "..(level or "—"))
  petFields.health:SetText("Health:  "..health)
  petFields.speed:SetText("Movement speed:  "..speedText)
  petFields.armor:SetText("Armor:  "..(armor or "—"))
  petFields.damage:SetText("Damage:  "..damage)
  petFields.attackPower:SetText("Attack power:  "..(attackPower or "—"))
  petFields.crit:SetText("Critical strike:  "..crit)
  local resistanceNames={"Holy","Fire","Nature","Frost","Shadow","Arcane"}
  local resistanceValues={}
  if hasPet and type(UnitResistance)=="function" then
    for index,name in ipairs(resistanceNames) do
      local _,total=petCall(UnitResistance,"pet",index)
      resistanceValues[index]=type(total)=="number" and (name.." "..tostring(total)) or (name.." —")
    end
  else
    for index,name in ipairs(resistanceNames) do resistanceValues[index]=name.." —" end
  end
  petFields.resist1:SetText("Resistances:  "..table.concat(resistanceValues,"   ",1,3))
  petFields.resist2:SetText(table.concat(resistanceValues,"   ",4,6))
  petFields.happiness:SetText("Happiness:  "..happiness)
  petFields.loyalty:SetText("Loyalty:  "..(loyalty or "—"))
  petFields.diet:SetText("Diet:  "..diet)

  local food
  if hasPet and not dead and petInfo and type(petInfo.CanPetEatItem)=="function" and snapshot and type(snapshot.items)=="table" then
    for _,entry in ipairs(snapshot.items) do
      local itemID=entry.item and entry.item.itemID
      if not itemID and entry.link and C_Item and type(C_Item.GetItemInfoInstant)=="function" then
        itemID=petCall(C_Item.GetItemInfoInstant,entry.link)
      end
      if itemID and petCall(petInfo.CanPetEatItem,itemID) then food=entry;break end
    end
  end
  local merchant=merchantIsOpen()
  if food then
    petFields.food:SetText("Compatible food:  "..food.name)
  elseif not hasPet then
    petFields.food:SetText("Compatible food:  No active pet")
  elseif dead then
    petFields.food:SetText("Compatible food:  Pet must be alive")
  else
    petFields.food:SetText("Compatible food:  None found in your bags")
  end
  if food and not merchant then
    petFields.food:SetText("Food:  "..food.name.." (click Yum, then food)")
  elseif merchant then
    petFields.food:SetText("Compatible food:  Close merchant to feed")
  end
end

local function renderCharacterPage()
  if not characterScroll then return end
  local showGear=(characterPage=="Gear")
  for _,element in ipairs(gearElements) do element:SetShown(showGear) end
  characterScroll:SetShown(not showGear)
  for name,button in pairs(characterTabs) do
    button.label:SetTextColor(name==characterPage and .30 or .82,name==characterPage and 1 or .70,name==characterPage and .78 or .91)
  end
  if showGear then
    if settingsPage then settingsPage:Hide() end
    if petPage then petPage:Hide() end
    return
  end
  if characterPage=="Pet" then
    for _,row in ipairs(pageRows) do row.text:Hide();row.bg:Hide();row.progressBg:Hide();row.progressFill:Hide();row.progressText:Hide() end
    if settingsPage then settingsPage:Hide() end
    if petPage then petPage:Show();updatePetPage(currentSnapshot or A.Snapshot()) end
    characterContent:SetHeight(452)
    return
  end
  if characterPage=="Settings" then
    for _,row in ipairs(pageRows) do row.text:Hide();row.bg:Hide();row.progressBg:Hide();row.progressFill:Hide();row.progressText:Hide() end
    if petPage then petPage:Hide() end
    if settingsPage then settingsPage:Show() end
    characterContent:SetHeight(320)
    return
  end
  if settingsPage then settingsPage:Hide() end
  if petPage then petPage:Hide() end
  local lines=collectPageLines(characterPage)
  local y=0
  for i,entry in ipairs(lines) do
    local h=entry.kind=="section" and 31 or (entry.kind=="skill" and 40 or 26)
    local row=pageRows[i]
    if not row then
      row={text=textLabel(characterContent,"",12,LIGHT),bg=tint(characterContent,"BACKGROUND",.18,.12,.25,.80)}
      row.progressBg=tint(characterContent,"BORDER",.11,.09,.15,.95)
      row.progressFill=tint(characterContent,"ARTWORK",.16,.50,.94,.95)
      row.progressText=textLabel(characterContent,"",10,LIGHT)
      pageRows[i]=row
    end
    local t=row.text
    if entry.kind=="skill" then
      t:ClearAllPoints();t:SetPoint("TOPLEFT",characterContent,"TOPLEFT",12,-y)
      t:SetWidth(250);t:SetWordWrap(false);t:SetFont("Fonts\\FRIZQT__.TTF",12,"OUTLINE")
      t:SetTextColor(unpack(LIGHT));t:SetText(entry.text);t:Show();row.bg:Hide()
      row.progressBg:ClearAllPoints();row.progressBg:SetPoint("TOPLEFT",characterContent,"TOPLEFT",12,-y-21);row.progressBg:SetSize(332,8);row.progressBg:Show()
      row.progressFill:ClearAllPoints();row.progressFill:SetPoint("TOPLEFT",row.progressBg,"TOPLEFT",1,-1);row.progressFill:SetHeight(6);row.progressFill:SetWidth(math.max(0,330*(entry.progress or 0)));row.progressFill:Show()
      row.progressText:ClearAllPoints();row.progressText:SetPoint("TOPRIGHT",characterContent,"TOPLEFT",344,-y);row.progressText:SetText(entry.value or "");row.progressText:Show()
      t:SetDrawLayer("OVERLAY")
    else
      row.progressBg:Hide();row.progressFill:Hide();row.progressText:Hide()
    t:ClearAllPoints();t:SetPoint("TOPLEFT",characterContent,"TOPLEFT",12,-y)
    t:SetWidth(344);t:SetWordWrap(true)
    t:SetFont("Fonts\\FRIZQT__.TTF",entry.kind=="section" and 13 or 12,"OUTLINE")
    t:SetTextColor(unpack(entry.kind=="section" and GOLD or LIGHT));t:SetText(entry.text);t:Show()
    if entry.kind=="section" then
      row.bg:ClearAllPoints();row.bg:SetPoint("TOPLEFT",characterContent,"TOPLEFT",5,-y+3);row.bg:SetSize(350,24);row.bg:Show()
      t:SetDrawLayer("OVERLAY")
    else row.bg:Hide() end
    end
    y=y+h
  end
  for i=#lines+1,#pageRows do pageRows[i].text:Hide();pageRows[i].bg:Hide();pageRows[i].progressBg:Hide();pageRows[i].progressFill:Hide();pageRows[i].progressText:Hide() end
  characterContent:SetHeight(max(1,y+8))
end
local function makeUpgradeBadge(parent,point,relativePoint,x,y)
  local bg=tint(parent,"OVERLAY",.04,.22,.10,.96)
  bg:SetSize(23,14);bg:SetPoint(point,parent,relativePoint,x,y)
  local edge=tint(parent,"OVERLAY",.28,1,.48,1)
  edge:SetPoint("TOPLEFT",bg,"TOPLEFT",-1,1);edge:SetPoint("BOTTOMRIGHT",bg,"BOTTOMRIGHT",1,-1)
  local label=textLabel(parent,"UP",8,{.70,1,.76})
  label:SetPoint("CENTER",bg,"CENTER",0,0)
  bg:Hide();edge:Hide();label:Hide()
  return {bg=bg,edge=edge,label=label}
end
local function showBadge(badge,show)
  badge.bg:SetShown(show);badge.edge:SetShown(show);badge.label:SetShown(show)
end
local function makeGlow(button)
  local glow={}
  local specs={
    {true,"TOPLEFT","TOPRIGHT",0,2,4,.30},{true,"BOTTOMLEFT","BOTTOMRIGHT",0,-2,4,.30},
    {false,"TOPLEFT","BOTTOMLEFT",-2,0,4,.30},{false,"TOPRIGHT","BOTTOMRIGHT",2,0,4,.30},
    {true,"TOPLEFT","TOPRIGHT",0,0,2,.98},{true,"BOTTOMLEFT","BOTTOMRIGHT",0,0,2,.98},
    {false,"TOPLEFT","BOTTOMLEFT",0,0,2,.98},{false,"TOPRIGHT","BOTTOMRIGHT",0,0,2,.98},
  }
  for _,p in ipairs(specs) do
    local edge=tint(button,"OVERLAY",.30,1,.42,p[7])
    if p[1] then edge:SetHeight(p[6]) else edge:SetWidth(p[6]) end
    edge:SetPoint(p[2],button,p[2],p[4],p[5]);edge:SetPoint(p[3],button,p[3],p[4],p[5])
    edge:Hide();tinsert(glow,edge)
  end
  return glow
end
local function setGlow(glow,show)
  for _,edge in ipairs(glow) do edge:SetShown(show) end
end
local function makeSlotBorder(button)
  local edges={}
  local specs={{true,"TOPLEFT","TOPRIGHT"},{true,"BOTTOMLEFT","BOTTOMRIGHT"},{false,"TOPLEFT","BOTTOMLEFT"},{false,"TOPRIGHT","BOTTOMRIGHT"}}
  for _,p in ipairs(specs) do
    local edge=tint(button,"OVERLAY",.48,.36,.60,.8)
    if p[1] then edge:SetHeight(1) else edge:SetWidth(1) end
    edge:SetPoint(p[2],button,p[2]);edge:SetPoint(p[3],button,p[3])
    tinsert(edges,edge)
  end
  return edges
end
local function ensureToggleButton()
  if keyToggleButton then return keyToggleButton end
  keyToggleButton=CreateFrame("Button","AetherInventoryKeyToggle",UIParent,"SecureHandlerClickTemplate")
  keyToggleButton:SetSize(1,1)
  keyToggleButton:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-20,-20)
  keyToggleButton:RegisterForClicks("AnyUp")
  keyToggleButton:Show()
  return keyToggleButton
end

local function setToggleWindowReference()
  if not keyToggleButton or not frame or InCombatLockdown() then return end
  keyToggleButton:SetFrameRef("window",frame)
  keyToggleButton:SetAttribute("_onclick",[[
    local window=self:GetFrameRef("window")
    if window then
      if window:IsShown() then window:Hide() else window:Show() end
    end
  ]])
end

local function setBindButtonLabel(key)
  local button=toggleBindButtons[key]
  if button then
    local active=AetherInventoryDB and AetherInventoryDB.toggleKeys and AetherInventoryDB.toggleKeys[key]
    button.label:SetText((active and "Unbind " or "Bind ")..key)
  end
end

local function saveCurrentBindingSet()
  if type(SaveBindings)~="function" then return end
  local set=type(GetCurrentBindingSet)=="function" and GetCurrentBindingSet() or 1
  pcall(SaveBindings,set or 1)
end

local function applyToggleBinding(key)
  if type(SetBindingClick)~="function" then return false end
  ensureToggleButton()
  local ok,changed=pcall(SetBindingClick,key,"AetherInventoryKeyToggle","LeftButton")
  local action=type(GetBindingAction)=="function" and GetBindingAction(key)
  return ok and (changed or action=="CLICK AetherInventoryKeyToggle:LeftButton")
end

local function restoreToggleBindings()
  AetherInventoryDB=AetherInventoryDB or {}
  local keys=AetherInventoryDB.toggleKeys
  if type(keys)~="table" then keys={};AetherInventoryDB.toggleKeys=keys end
  AetherInventoryDB.previousToggleBindings=AetherInventoryDB.previousToggleBindings or {}
  -- Adopt bindings saved by 0.2.5 so existing users do not need to assign them again.
  if type(GetBindingAction)=="function" then
    for _,key in ipairs({"B","C"}) do
      if GetBindingAction(key)=="CLICK AetherInventoryKeyToggle:LeftButton" then
        keys[key]=true
        if AetherInventoryDB.previousToggleBindings[key]==nil then AetherInventoryDB.previousToggleBindings[key]="" end
      end
    end
  end
  if not keys.B and not keys.C then return end
  if InCombatLockdown() then return end
  local changed=false
  for _,key in ipairs({"B","C"}) do
    if keys[key] and applyToggleBinding(key) then
      changed=true
      setBindButtonLabel(key)
    end
  end
  if changed then saveCurrentBindingSet() end
end

local function bindToggleKey(key)
  if InCombatLockdown() then
    print("Aether Inventory: key bindings can only be changed out of combat.")
    return
  end
  if type(SetBindingClick)~="function" or type(SaveBindings)~="function" then
    print("Aether Inventory: this client does not expose the key binding API.")
    return
  end
  AetherInventoryDB=AetherInventoryDB or {}
  AetherInventoryDB.toggleKeys=AetherInventoryDB.toggleKeys or {}
  AetherInventoryDB.previousToggleBindings=AetherInventoryDB.previousToggleBindings or {}
  if not AetherInventoryDB.toggleKeys[key] then
    local oldAction=type(GetBindingAction)=="function" and GetBindingAction(key)
    if oldAction=="CLICK AetherInventoryKeyToggle:LeftButton" then oldAction=nil end
    AetherInventoryDB.previousToggleBindings[key]=type(oldAction)=="string" and oldAction or ""
  end
  if applyToggleBinding(key) then
    AetherInventoryDB.toggleKeys[key]=true
    saveCurrentBindingSet()
    setBindButtonLabel(key)
    print("Aether Inventory: "..key.." now opens/closes the window and will be restored after reload.")
  else
    print("Aether Inventory: could not bind "..key..".")
  end
end

local function unbindToggleKey(key)
  if InCombatLockdown() then
    print("Aether Inventory: key bindings can only be changed out of combat.")
    return
  end
  if type(SetBinding)~="function" or type(SaveBindings)~="function" then
    print("Aether Inventory: this client does not expose the key binding API.")
    return
  end
  AetherInventoryDB=AetherInventoryDB or {}
  local previous=AetherInventoryDB.previousToggleBindings and AetherInventoryDB.previousToggleBindings[key]
  -- Some earlier addon builds saved an empty previous action for existing
  -- B/C assignments. Restore the standard bag/character actions in that case.
  local restoreAction=(type(previous)=="string" and previous~="") and previous or DEFAULT_BINDING_ACTIONS[key]
  local ok,changed=pcall(SetBinding,key,restoreAction)
  local action=type(GetBindingAction)=="function" and GetBindingAction(key)
  if ok and (changed or action==restoreAction) then
    if AetherInventoryDB.toggleKeys then AetherInventoryDB.toggleKeys[key]=nil end
    if AetherInventoryDB.previousToggleBindings then AetherInventoryDB.previousToggleBindings[key]=nil end
    saveCurrentBindingSet()
    setBindButtonLabel(key)
    local restored=(restoreAction==DEFAULT_BINDING_ACTIONS[key]) and (key=="B" and "the backpack binding" or "the character-panel binding") or "the previous binding"
    print("Aether Inventory: "..key.." toggle removed; "..restored.." was restored.")
  else
    print("Aether Inventory: could not remove the "..key.." toggle.")
  end
end

local function toggleToggleKey(key)
  local active=AetherInventoryDB and AetherInventoryDB.toggleKeys and AetherInventoryDB.toggleKeys[key]
  if active then unbindToggleKey(key) else bindToggleKey(key) end
end
local function savePosition()
  if not frame then return end
  local x,y=frame:GetCenter()
  local px,py=UIParent:GetCenter()
  if x and y then
    AetherInventoryDB.x=x-px; AetherInventoryDB.y=y-py
  end
end
local function placeFrame()
  if not frame then return end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER",UIParent,"CENTER",AetherInventoryDB.x or 0,AetherInventoryDB.y or 0)
end
local function makeEquipSlot(id,label,x,y)
  local b=CreateFrame("Button",nil,frame,"SecureHandlerDragTemplate")
  b:SetSize(39,39);b:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y)
  local bg=tint(b,"BACKGROUND",.08,.065,.13,.92);bg:SetAllPoints()
  local ring=tint(b,"BORDER",.48,.35,.62,.8);ring:SetPoint("TOPLEFT",-1,1);ring:SetPoint("BOTTOMRIGHT",1,-1)
  local inset=tint(b,"ARTWORK",.14,.11,.19,.95);inset:SetPoint("TOPLEFT",1,-1);inset:SetPoint("BOTTOMRIGHT",-1,1)
  local icon=b:CreateTexture(nil,"OVERLAY"); icon:SetPoint("TOPLEFT",3,-3);icon:SetPoint("BOTTOMRIGHT",-3,3)
  local abbrev=textLabel(b,label:sub(1,2):upper(),9,MUTED);abbrev:SetPoint("CENTER")
  local badge=makeUpgradeBadge(b,"TOPRIGHT","TOPRIGHT",6,5)
  b:SetAttribute("inventoryID",id)
  b:RegisterForDrag("LeftButton")
  b:SetAttribute("_ondragstart",[[return "inventory", self:GetAttribute("inventoryID")]])
  b:SetAttribute("_onreceivedrag",[[return "inventory", self:GetAttribute("inventoryID")]])
  b.icon=icon;b.abbrev=abbrev;b.up=badge;b.inventoryID=id;b.label=label;b.ring=ring;b.glow=makeGlow(b)
  b.durability=makeDurabilityBadge(b)
  b:SetScript("OnEnter",function(self)
    if GetInventoryItemLink("player",self.inventoryID) then
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:SetInventoryItem("player",self.inventoryID)
      local state,percent=equipmentDurability(self.inventoryID)
      if state=="broken" then GameTooltip:AddLine("AETHER: BROKEN",1,.34,.30)
      elseif state=="low" then GameTooltip:AddLine("AETHER: LOW DURABILITY ("..percent.."%)",1,.70,.22) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave",function()GameTooltip:Hide()end)
  tinsert(equippedWidgets,b)
end
local function prepareEquipment()
  local left={{1,"Head"},{2,"Neck"},{3,"Shoulder"},{15,"Cloak"},{5,"Chest"},{9,"Wrist"},{10,"Hands"}}
  local right={{6,"Waist"},{7,"Legs"},{8,"Feet"},{11,"Ring 1"},{12,"Ring 2"},{13,"Trinket 1"},{14,"Trinket 2"}}
  for i,p in ipairs(left) do makeEquipSlot(p[1],p[2],25,-183-(i-1)*47) end
  for i,p in ipairs(right) do makeEquipSlot(p[1],p[2],350,-183-(i-1)*47) end
  local bottom={{16,"Main"},{17,"Off"},{18,"Range"},{4,"Shirt"},{19,"Tabard"}}
  for i,p in ipairs(bottom) do makeEquipSlot(p[1],p[2],89+(i-1)*53,-512) end
end
local function makeInventorySlot(section,bag,slot)
  -- Secure handlers let the player's drag perform the move in and out of combat.
  local b=CreateFrame("Button",nil,section,"SecureActionButtonTemplate,SecureHandlerDragTemplate")
  b:RegisterForClicks("AnyUp")
  b:RegisterForDrag("LeftButton")
  b:SetAttribute("type2","item")
  b:SetAttribute("item2",tostring(bag).." "..tostring(slot))
  b:SetAttribute("bag2",bag);b:SetAttribute("slot2",slot)
  b:SetAttribute("bagID",bag);b:SetAttribute("slotID",slot)
  b:SetAttribute("aetherLocked",false)
  b:SetAttribute("_ondragstart",[[if self:GetAttribute("aetherLocked") then return nil end return "bagslot", self:GetAttribute("bagID"), self:GetAttribute("slotID")]])
  b:SetAttribute("_onreceivedrag",[[return "bagslot", self:GetAttribute("bagID"), self:GetAttribute("slotID")]])
  b:HookScript("OnClick",handleVendorItemClick)
  b:HookScript("OnMouseUp",function(self,mouseButton)
    if rightClickDiagnostics and mouseButton=="RightButton" then
      local item=A.BagInfo(self.bagID,self.slotID)
      local itemName=item and (item.name or item.hyperlink) or "empty"
      print("AI clickdiag: bag="..tostring(self.bagID).." slot="..tostring(self.slotID)..
        " item="..tostring(itemName).." type2="..tostring(self:GetAttribute("type2"))..
        " item2="..tostring(self:GetAttribute("item2"))..
        " mode="..(merchantIsOpen() and "vendor" or "secure-use")..
        " locked="..tostring(self:GetAttribute("aetherLocked")))
    end
  end)
  b:SetSize(slotW,slotW)
  b.bagID=bag;b.slotID=slot
  local bg=tint(b,"BACKGROUND",.10,.08,.15,.93);bg:SetAllPoints()
  local under=tint(b,"BORDER",.26,.20,.37,.90);under:SetPoint("TOPLEFT",-1,1);under:SetPoint("BOTTOMRIGHT",1,-1)
  local core=tint(b,"ARTWORK",.10,.09,.15,.96);core:SetPoint("TOPLEFT",1,-1);core:SetPoint("BOTTOMRIGHT",-1,1)
  local icon=b:CreateTexture(nil,"OVERLAY");icon:SetPoint("TOPLEFT",3,-3);icon:SetPoint("BOTTOMRIGHT",-3,3)
  local count=textLabel(b,"",11,{1,1,1});count:SetPoint("BOTTOMRIGHT",-3,2)
  local marker=textLabel(b,"+",15,{.35,.66,.47});marker:SetPoint("CENTER");marker:SetTextColor(.38,.68,.48,.65)
  local recent=tint(b,"OVERLAY",.02,.61,.51,.96);recent:SetSize(23,12);recent:SetPoint("TOPRIGHT",-1,-1);recent:Hide()
  local recentLabel=textLabel(b,"NEW",7,{.91,1,.92});recentLabel:SetPoint("CENTER",recent,"CENTER",0,0);recentLabel:Hide()
  local up=makeUpgradeBadge(b,"TOPLEFT","TOPLEFT",-2,3)
  local border=makeSlotBorder(b)
  local glow=makeGlow(b)
  local lockToggle=CreateFrame("Button",nil,b)
  lockToggle:SetSize(19,19);lockToggle:SetPoint("BOTTOMLEFT",b,"BOTTOMLEFT",0,0)
  lockToggle:SetFrameLevel(b:GetFrameLevel()+8)
  lockToggle:RegisterForClicks("LeftButtonUp")
  local lockPlate=lockToggle:CreateTexture(nil,"BACKGROUND")
  lockPlate:SetAllPoints();lockPlate:SetColorTexture(.025,.035,.06,.92)
  local lockIcon=lockToggle:CreateTexture(nil,"OVERLAY")
  lockIcon:SetAllPoints();lockIcon:SetTexCoord(.1875,.78125,.21875,.78125)
  lockIcon:SetTexture("Interface\\Buttons\\LockButton-Unlocked-Up");lockIcon:SetVertexColor(1,.88,.50,1)
  lockToggle:SetScript("OnClick",toggleBagItemLock)
  lockToggle:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    local slotButton=self:GetParent()
    local locked=slotButton.lockKey and AetherInventoryDB and AetherInventoryDB.lockedItems
      and AetherInventoryDB.lockedItems[slotButton.lockKey]==true
    GameTooltip:SetText(locked and "Item Locked" or "Protect Item",1,.82,.42)
    GameTooltip:AddLine(locked and "Click to unlock. Vendor sale and item-targeting actions are blocked." or "Click to lock against vendor sale and item-targeting salvage.",.88,.84,.94,true)
    GameTooltip:Show()
  end)
  lockToggle:SetScript("OnLeave",function()GameTooltip:Hide()end)
  lockToggle:Hide()
  b.bg=bg;b.core=core;b.icon=icon;b.count=count;b.marker=marker;b.up=up;b.border=border;b.glow=glow;b.recent=recent;b.recentLabel=recentLabel
  b.lockToggle=lockToggle;b.lockIcon=lockIcon
  b.durability=makeDurabilityBadge(b)
  b:SetScript("OnEnter",function(self)
    local it=A.BagInfo(self.bagID,self.slotID)
    if it then
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:SetBagItem(self.bagID,self.slotID)
      local dat=self.aetherData
      if dat and dat.upgrade then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Aether: POSSIBLE UPGRADE",.26,1,.4)
        GameTooltip:AddLine("Stat-weight estimate only. Compare the actual weapon damage and requirements.",.83,.8,.7,true)
      end
      if dat and dat.recent then GameTooltip:AddLine("Recently acquired",.35,1,.80) end
      if self.lockKey and AetherInventoryDB and AetherInventoryDB.lockedItems and AetherInventoryDB.lockedItems[self.lockKey] then
        GameTooltip:AddLine("AETHER: LOCKED",1,.82,.42)
        GameTooltip:AddLine("Cannot be sold to vendors or selected by item-targeting actions.",.88,.84,.94,true)
      end
      local state,percent=bagItemDurability(self.bagID,self.slotID)
      if state=="broken" then GameTooltip:AddLine("AETHER: BROKEN",1,.34,.30)
      elseif state=="low" then GameTooltip:AddLine("AETHER: LOW DURABILITY ("..percent.."%)",1,.70,.22) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave",function()GameTooltip:Hide()end)
  return b
end
local function createBagSection(bag)
  local section=CreateFrame("Frame",nil,scrollContent)
  section:SetSize(562,40)
  local bg=tint(section,"BACKGROUND",.10,.078,.15,.75);bg:SetAllPoints()
  local header=tint(section,"ARTWORK",.18,.11,.27,.96)
  header:SetPoint("TOPLEFT",0,0);header:SetPoint("TOPRIGHT",0,0);header:SetHeight(29)
  local lab=textLabel(section,"",13,{.96,.78,.48});lab:SetPoint("TOPLEFT",10,-7)
  local counter=textLabel(section,"",11,{.50,.92,.70});counter:SetPoint("TOPRIGHT",-12,-8)
  local slots={}
  -- Enough for standard backpacks and bags; hidden unused slots cost no screen space.
  for i=1,36 do slots[i]=makeInventorySlot(section,bag,i) end
  bagSections[bag]={frame=section,slots=slots,title=lab,counter=counter,bg=bg,header=header}
end
local function updateEquipped(snap)
  if not frame then return end
  local upSlots={}
  local brokenCount,lowCount=0,0
  for _,entry in ipairs(snap.upgrades) do upSlots[entry.upgrade.slot]=true end
  for _,w in ipairs(equippedWidgets) do
    local icon=GetInventoryItemTexture("player",w.inventoryID)
    if icon then w.icon:SetTexture(icon);w.icon:Show();w.abbrev:Hide()
    else w.icon:Hide();w.abbrev:Show() end
    local isUpgrade=upSlots[w.inventoryID]
    showBadge(w.up,isUpgrade);setGlow(w.glow,isUpgrade)
    local condition,percent=equipmentDurability(w.inventoryID)
    showDurabilityBadge(w.durability,condition,percent)
    if condition=="broken" then
      brokenCount=brokenCount+1
      w.ring:SetColorTexture(.78,.10,.14,1)
    elseif condition=="low" then
      lowCount=lowCount+1
      w.ring:SetColorTexture(.91,.52,.10,1)
    else
      w.ring:SetColorTexture(.48,.35,.62,.8)
    end
  end
  local name=UnitName("player") or "Adventurer"
  local className=select(1,UnitClass("player")) or ""
  if mainText then mainText:SetText(name.."  |  Lv "..(UnitLevel("player") or "?").." "..className) end
  local lines={}
  if brokenCount>0 or lowCount>0 then
    lines[#lines+1]="|cffff5959BROKEN "..brokenCount.."|r   |cffffbd57LOW "..lowCount.."|r  (≤20%)"
  end
  if #snap.upgrades==0 then
    lines[#lines+1]="No clear stat-based upgrades detected."
    lines[#lines+1]="Hover items to inspect their details."
  else
    for i=1,min(3,#snap.upgrades) do
      local item=snap.upgrades[i]
      lines[#lines+1]="|cff64e59cUP|r "..item.name
    end
  end
  if upgradeText then upgradeText:SetText(table.concat(lines,"\n")) end
  if statText then
    local _,agi=UnitStat("player",2)
    local _,sta=UnitStat("player",3)
    local armorBase,armorEffective=apiValue(UnitArmor,"player")
    local armor=armorEffective or armorBase or "?"
    statText:SetText("Armor "..tostring(armor).."   Agility "..tostring(agi or "?")..
      "   Stamina "..tostring(sta or "?").."   |cff64e59c"..#snap.upgrades.." upgrades|r")
    statText:SetWidth(372)
  end
  if summaryText then summaryText:SetText("") end
end
local function matches(data,category,q)
  if not data then return true end
  if category=="Recent" and not data.recent then return false end
  if category~="All" and category~="Recent" and data.category~=category then return false end
  if q~="" then
    local lower=(data.name or ""):lower()
    if not lower:find(q,1,true) then return false end
  end
  return true
end
local function setItemVisual(button,data,selected)
  button.aetherData=data
  if data and data.item then
    local item=data.item
    local lockKey=itemLockKey(item,data.bag,data.slot)
    local locked=lockKey~=nil and AetherInventoryDB and AetherInventoryDB.lockedItems
      and AetherInventoryDB.lockedItems[lockKey]==true or false
    button.lockKey=lockKey
    if not InCombatLockdown() then button:SetAttribute("aetherLocked",locked and true or false) end
    button.lockToggle:SetShown(true)
    button.lockIcon:SetTexture(locked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up")
    button.lockIcon:SetVertexColor(locked and .48 or 1,locked and 1 or .88,locked and .62 or .50,1)
    button.lockToggle:SetAlpha(locked and 1 or .78)
    local quality=A.quality[item.quality or 1] or A.quality[1]
    button.icon:SetTexture(item.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")
    button.icon:SetAlpha(selected and 1 or .16)
    button.icon:Show();button.marker:Hide()
    button.count:SetText(item.stackCount and item.stackCount>1 and tostring(item.stackCount) or "")
    button.count:SetAlpha(selected and 1 or .30)
    button.recent:SetShown(data.recent==true);button.recentLabel:SetShown(data.recent==true)
    button.bg:SetColorTexture(.10,.08,.15,.95)
    for _,border in ipairs(button.border) do border:SetColorTexture(quality[1],quality[2],quality[3],selected and .95 or .2) end
    local condition,percent=bagItemDurability(data.bag,data.slot)
    showDurabilityBadge(button.durability,condition,percent)
    if condition=="broken" then
      for _,border in ipairs(button.border) do border:SetColorTexture(.90,.12,.16,1) end
    elseif condition=="low" then
      for _,border in ipairs(button.border) do border:SetColorTexture(1,.58,.12,1) end
    end
    setGlow(button.glow,data.upgrade~=nil and selected)
    showBadge(button.up,data.upgrade~=nil and selected)
  else
    button.lockKey=nil;button.lockToggle:Hide()
    if not InCombatLockdown() then button:SetAttribute("aetherLocked",false) end
    button.icon:Hide();button.count:SetText("");button.recent:Hide();button.recentLabel:Hide();showBadge(button.up,false);showDurabilityBadge(button.durability,nil);setGlow(button.glow,false);button.marker:Show()
    button.bg:SetColorTexture(.07,.16,.13,.70)
    for _,border in ipairs(button.border) do border:SetColorTexture(.26,.58,.42,.45) end
  end
end
local function applyFilters()
  if not currentSnapshot or InCombatLockdown() then return end
  local query=searchBox and searchBox:GetText():lower() or ""
  local filteredView=filter~="All" or query~=""
  local matchCount=0
  for _,bag in ipairs(A.bagIDs) do
    local section=bagSections[bag]
    local dat=currentSnapshot.byBag[bag]
    for slot=1,dat.size do
      local item=dat.items[slot]
      if item then item.recent=isRecentItem(item) end
      local selected=matches(item,filter,query)
      local button=section.slots[slot]
      setItemVisual(button,item,selected)
      local visible=filteredView and item~=nil and selected or (not filteredView)
      button:SetShown(visible)
      if visible and item and selected then matchCount=matchCount+1 end
    end
  end
  for cat,b in pairs(filterButtons) do
    if cat==filter then b.label:SetTextColor(.30,1,.78)
    else b.label:SetTextColor(.82,.70,.91) end
  end
  if emptyFilterText then
    if filteredView and matchCount==0 then
      local label=filter~="All" and filter or "search"
      emptyFilterText:SetText("No "..label.." items match this view.")
      emptyFilterText:Show()
    else emptyFilterText:Hide() end
  end
end
local function refreshBagSections(snap)
  local y=0
  local query=searchBox and searchBox:GetText():lower() or ""
  local filteredView=filter~="All" or query~=""
  for _,bag in ipairs(A.bagIDs) do
    local sec=bagSections[bag];local data=snap.byBag[bag];local size=data.size
    local free=data.free or 0
    local matching={}
    if filteredView then
      for slot=1,size do
        local item=data.items[slot]
        if item then item.recent=isRecentItem(item) end
        if item and matches(item,filter,query) then matching[#matching+1]=slot end
      end
    end
    local visibleCount=filteredView and #matching or size
    if filteredView and visibleCount==0 then
      sec.frame:Hide()
    else
    sec.frame:Show()
    local rows=ceil(visibleCount/columns)
    local h=max(36,37+rows*(slotW+gap)+4)
    sec.frame:SetHeight(h)
    sec.frame:ClearAllPoints();sec.frame:SetPoint("TOPLEFT",scrollContent,"TOPLEFT",0,-y)
    sec.title:SetText(A.NameForBag(bag))
    if filteredView then
      sec.counter:SetText(visibleCount.." matching"..(data.specialty and (" · "..A.BagFamilyLabel(data.family)) or ""))
    elseif size>0 then
      local familyLabel=A.BagFamilyLabel(data.family)
      sec.counter:SetText(free.." of "..size.." empty"..(data.specialty and (" · "..familyLabel) or ""))
    else sec.counter:SetText("No bag equipped") end
    for i=1,36 do
      local slot=sec.slots[i]
      local visibleIndex
      if filteredView then
        for index,physicalSlot in ipairs(matching) do if physicalSlot==i then visibleIndex=index;break end end
      elseif i<=size then visibleIndex=i end
      if visibleIndex then
        local x=12+((visibleIndex-1)%columns)*(slotW+gap)
        local yy=-35-floor((visibleIndex-1)/columns)*(slotW+gap)
        slot:ClearAllPoints();slot:SetPoint("TOPLEFT",sec.frame,"TOPLEFT",x,yy)
        slot:Show()
      else slot:Hide() end
    end
    y=y+h+9
    end
  end
  scrollContent:SetHeight(max(1,y+10))
  local lim=max(0,(scrollContent:GetHeight() or 0)-(scrollFrame:GetHeight() or 0))
  if scrollFrame:GetVerticalScroll()>lim then scrollFrame:SetVerticalScroll(lim) end
end
function A.Refresh()
  if not UIReady or not frame or not frame:IsShown() then return end
  -- Bag slots are secure drag buttons. Do not reposition/show/hide them from
  -- addon code during combat; refresh their layout as soon as combat ends.
  if InCombatLockdown() then return end
  setBagActionMode()
  currentSnapshot=A.Snapshot()
  updatePetPage(currentSnapshot)
  updateEquipped(currentSnapshot)
  renderCharacterPage()
  refreshBagSections(currentSnapshot)
  applyFilters()
  local free,total=currentSnapshot.free,currentSnapshot.total
  if footerText then
    local copper=type(GetMoney)=="function" and (GetMoney() or 0) or 0
    local gold=floor(copper/10000); local silver=floor(copper%10000/100); local cp=copper%100
    footerText:SetText("BAGS "..(total-free).."/"..total.."  •  |cff73e6a5"..currentSnapshot.freeGeneral.." general free|r  •  |cff85dfff"..currentSnapshot.freeSpecialty.." specialty free|r")
    if footerGoldText then footerGoldText:SetText(gold.."g  "..silver.."s  "..cp.."c") end
  end
  if summaryText then summaryText:SetText("") end
  if model then
    local ok=pcall(function()model:SetUnit("player")end)
    if not ok then model:Hide() end
  end
end
function A.Toggle()
  if InCombatLockdown() then
    print("Aether Inventory: use the secure B/C binding or X close button during combat.")
    return
  end
  if not UIReady then A.CreateUI() end
  -- A deliberate user toggle takes ownership away from merchant auto-open.
  merchantOpenedInventory=false
  if frame:IsShown() then frame:Hide() else frame:Show(); A.Refresh() end
end
_G.AetherInventory_Toggle=function() A.Toggle() end

function A.CreateUI()
  if UIReady then return end
  ensureToggleButton()
  frame=CreateFrame("Frame","AetherInventory_Main",UIParent)
  UISpecialFrames=UISpecialFrames or {}
  local escapeRegistered=false
  for _,name in ipairs(UISpecialFrames) do
    if name=="AetherInventory_Main" then escapeRegistered=true;break end
  end
  if not escapeRegistered then tinsert(UISpecialFrames,"AetherInventory_Main") end
  setToggleWindowReference()
  frame:SetSize(FRAME_W,FRAME_H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetMovable(true);frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
  frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing();savePosition() end)
  frame:SetScript("OnHide",function() if not InCombatLockdown() then GameTooltip:Hide() end end)
  frame:SetScript("OnShow",function() A.Refresh() end)
  panelTexture=frame:CreateTexture(nil,"BACKGROUND"); panelTexture:SetAllPoints();panelTexture:SetTexture(A.media.."panel")
  local head=textLabel(frame,"AETHER INVENTORY",25,{1,.84,.55});head:SetFont("Fonts\\MORPHEUS.TTF",28,"OUTLINE");head:SetPoint("TOPLEFT",118,-20)
  local sub=textLabel(frame,"CHARACTER  /  EQUIPMENT  /  BAGS",12,{.76,.62,.89});sub:SetPoint("TOPLEFT",118,-60)
  local version=textLabel(frame,"Version "..A.version,12,{.90,.78,.64});version:SetPoint("TOPRIGHT",-82,-35)
  local close=makeButton(frame,"X",1055,-20,35,32,nil,"SecureHandlerClickTemplate")
  close:SetFrameRef("window",frame)
  close:SetAttribute("_onclick",[[ self:GetFrameRef("window"):Hide() ]])
  close.label:SetTextColor(1,.45,.38)
  line(frame,24,-82,1060,.73,.49,.36,.82)
  line(frame,411,-100,1,.45,.29,.57,.9)
  local divider=tint(frame,"BORDER",.54,.35,.61,.70);divider:SetPoint("TOPLEFT",409,-93);divider:SetSize(2,575)
  local leftTitle=textLabel(frame,"CHARACTER & EQUIPMENT",15,GOLD);leftTitle:SetPoint("TOPLEFT",26,-105)
  mainText=textLabel(frame,"",12,LIGHT);mainText:SetPoint("TOPLEFT",26,-129)
  model=CreateFrame("PlayerModel",nil,frame)
  model:SetSize(261,335);model:SetPoint("TOPLEFT",frame,"TOPLEFT",75,-184)
  local ok=pcall(function()model:SetUnit("player"); if model.SetCamDistanceScale then model:SetCamDistanceScale(1.1) end end)
  if not ok then model:Hide() end
  prepareEquipment()
  gearElements[#gearElements+1]=model
  for _,w in ipairs(equippedWidgets) do gearElements[#gearElements+1]=w end
  local statDivider=line(frame,24,-577,368,.69,.48,.29,.60);gearElements[#gearElements+1]=statDivider
  local statLabel=textLabel(frame,"STATS / GEAR",13,GOLD);statLabel:SetPoint("TOPLEFT",25,-568)
  gearElements[#gearElements+1]=statLabel
  statText=textLabel(frame,"",12,LIGHT);statText:SetPoint("TOPLEFT",26,-591)
  gearElements[#gearElements+1]=statText
  summaryText=textLabel(frame,"",12,TEAL);summaryText:SetPoint("TOPLEFT",26,-615);summaryText:Hide()
  gearElements[#gearElements+1]=summaryText
  upgradeText=textLabel(frame,"",11,LIGHT);upgradeText:SetPoint("TOPLEFT",26,-612)
  upgradeText:SetWidth(372);upgradeText:SetJustifyH("LEFT")
  gearElements[#gearElements+1]=upgradeText

  local tx=24
  local tabWidths={Gear=37,Stats=37,Reputation=56,Skills=37,Currency=47,Titles=37,Pet=32,Settings=51}
  for _,page in ipairs(characterPages) do
    local tab=makeButton(frame,page,tx,-148,tabWidths[page],26,function()
      characterPage=page
      if characterScroll then characterScroll:SetVerticalScroll(0) end
      renderCharacterPage()
    end)
    tab.label:SetFont("Fonts\\FRIZQT__.TTF",9,"OUTLINE")
    characterTabs[page]=tab
    tx=tx+tabWidths[page]+4
  end
  characterScroll=CreateFrame("ScrollFrame",nil,frame)
  characterScroll:SetSize(378,476);characterScroll:SetPoint("TOPLEFT",frame,"TOPLEFT",25,-180)
  characterScroll:EnableMouseWheel(true)
  characterContent=CreateFrame("Frame",nil,characterScroll)
  characterContent:SetWidth(368);characterContent:SetHeight(1)
  characterScroll:SetScrollChild(characterContent)
  createSettingsPage()
  createPetPage()
  characterScroll:SetScript("OnMouseWheel",function(self,delta)
    local limit=max(0,characterContent:GetHeight()-self:GetHeight())
    self:SetVerticalScroll(max(0,min(limit,self:GetVerticalScroll()-delta*58)))
  end)
  characterScroll:Hide()
  renderCharacterPage()
  autoSortEnabled=not (AetherInventoryDB and AetherInventoryDB.autoSortEnabled==false)
  if A.autoSortButton then A.autoSortButton.label:SetText(autoSortEnabled and "Auto-sort: On" or "Auto-sort: Off") end

  local bagTitle=textLabel(frame,"BAGS BY PHYSICAL SLOT",15,GOLD);bagTitle:SetPoint("TOPLEFT",432,-105)
  local note=textLabel(frame,"Empty slots remain in their original bags",11,MUTED);note:SetPoint("TOPRIGHT",-31,-107)
  searchBox=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
  searchBox:SetPoint("TOPLEFT",frame,"TOPLEFT",446,-133)
  searchBox:SetSize(610,26)
  searchBox:SetAutoFocus(false)
  searchBox:SetTextInsets(9,9,0,0)
  searchBox:SetFontObject("ChatFontNormal")
  searchBox:SetText("")
  searchBox:SetScript("OnTextChanged",function() if UIReady and frame:IsShown() and not InCombatLockdown() then A.Refresh() end end)
  searchBox:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
  searchBox:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
  local prompt=textLabel(frame,"Search by item name",11,MUTED);prompt:SetPoint("TOPLEFT",455,-140)
  searchBox:SetScript("OnEditFocusGained",function()prompt:Hide()end)
  searchBox:SetScript("OnEditFocusLost",function()if searchBox:GetText()=="" then prompt:Show()end end)
  searchBox:HookScript("OnTextChanged",function()if searchBox:GetText()=="" and not searchBox:HasFocus() then prompt:Show() else prompt:Hide() end end)
  local x=432
  for _,cat in ipairs(categories) do
    local widths={All=53,Equipment=104,Consumables=111,Materials=93,Quest=71,Junk=62,Recent=74}
    local w=widths[cat] or 74
    local btn=makeButton(frame,cat,x,-171,w,28,function()filter=cat;if frame:IsShown() then A.Refresh() end end)
    filterButtons[cat]=btn;x=x+w+5
  end
  
  scrollFrame=CreateFrame("ScrollFrame",nil,frame)
  scrollFrame:SetSize(562,429);scrollFrame:SetPoint("TOPLEFT",frame,"TOPLEFT",433,-212)
  scrollFrame:EnableMouseWheel(true)
  scrollContent=CreateFrame("Frame",nil,scrollFrame)
  scrollContent:SetWidth(562);scrollContent:SetHeight(1000)
  emptyFilterText=textLabel(scrollContent,"",15,{.82,.75,.90})
  emptyFilterText:SetPoint("TOPLEFT",scrollContent,"TOPLEFT",18,-22);emptyFilterText:SetWidth(520);emptyFilterText:SetHeight(30)
  emptyFilterText:Hide()
  scrollFrame:SetScrollChild(scrollContent)
  scrollFrame:SetScript("OnMouseWheel",function(self,delta)
    local limit=max(0,scrollContent:GetHeight()-self:GetHeight())
    self:SetVerticalScroll(max(0,min(limit,self:GetVerticalScroll()-delta*70)))
  end)
  for _,bag in ipairs(A.bagIDs) do createBagSection(bag) end
  applySavedColors()
  local scrollBack=tint(frame,"BACKGROUND",.06,.05,.10,.27);scrollBack:SetPoint("TOPLEFT",frame,"TOPLEFT",429,-209);scrollBack:SetSize(570,434)
  local up=makeButton(frame,"UP",1007,-238,38,30,function()
    scrollFrame:SetVerticalScroll(max(0,scrollFrame:GetVerticalScroll()-170))
  end)
  local down=makeButton(frame,"DN",1007,-603,38,30,function()
    local maxScroll=max(0,scrollContent:GetHeight()-scrollFrame:GetHeight())
    scrollFrame:SetVerticalScroll(min(maxScroll,scrollFrame:GetVerticalScroll()+170))
  end)
  line(frame,25,-682,1060,.78,.51,.3,.55)
  footerText=textLabel(frame,"",9,{.98,.90,.68});footerText:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",18,18);footerText:SetWidth(275);footerText:SetHeight(18);footerText:SetWordWrap(false)
  footerGoldText=textLabel(frame,"",11,GOLD);footerGoldText:SetJustifyH("RIGHT");footerGoldText:SetPoint("BOTTOMRIGHT",frame,"BOTTOMLEFT",400,18);footerGoldText:SetWidth(90);footerGoldText:SetHeight(18)
  local readOnly=textLabel(frame,"Click the small lock to protect an item; right-click to use or sell at a vendor.",11,MUTED)
  readOnly:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-26,12)
  makeButton(frame,"Clean Up",435,-649,88,29,function()
    local sorted=sortBags()
    if sorted and autoSortEnabled then
      autoSortPending=false;autoSortSettling=false
      lastAutoSortSignature=bagLayoutSignature();autoSortSeeded=true
    end
  end)
  A.autoSortButton=makeButton(frame,autoSortEnabled and "Auto-sort: On" or "Auto-sort: Off",528,-649,116,29,function()
    setAutoSort(not autoSortEnabled)
  end)
  toggleBindButtons.B=makeButton(frame,AetherInventoryDB.toggleKeys and AetherInventoryDB.toggleKeys.B and "Unbind B" or "Bind B",720,-649,70,29,function()toggleToggleKey("B")end)
  toggleBindButtons.C=makeButton(frame,AetherInventoryDB.toggleKeys and AetherInventoryDB.toggleKeys.C and "Unbind C" or "Bind C",795,-649,70,29,function()toggleToggleKey("C")end)
  makeButton(frame,"Open normal bags",880,-649,145,29,function()
    if type(ToggleAllBags)=="function" then ToggleAllBags() end
  end)
  
  frame:SetScale(AetherInventoryDB.scale or 0.91)
  placeFrame()
  frame:Hide()
  UIReady=true
end

local ev=CreateFrame("Frame")
local targetWatchElapsed=0
local recentRefreshElapsed=0
ev:SetScript("OnUpdate",function(_,elapsed)
  targetWatchElapsed=targetWatchElapsed+elapsed
  if targetWatchElapsed>=.08 then
    targetWatchElapsed=0
    updateSecureItemTargeting()
  end
  if autoSortPending then
    autoSortDelay=autoSortDelay-elapsed
    if autoSortDelay<=0 then runQueuedAutoSort() end
  end
  recentRefreshElapsed=recentRefreshElapsed+elapsed
  if recentRefreshElapsed>=1 then
    recentRefreshElapsed=0
    if currentSnapshot and frame and frame:IsShown() and not InCombatLockdown() then applyFilters() end
  end
end)
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("BAG_UPDATE")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
for _,eventName in ipairs({"UNIT_STATS","UNIT_MAXHEALTH","UNIT_MAXPOWER","PLAYER_MONEY","UPDATE_FACTION","SKILL_LINES_CHANGED","CURRENCY_DISPLAY_UPDATE","KNOWN_TITLES_UPDATE","UPDATE_INVENTORY_DURABILITY","UPDATE_INVENTORY_ALERTS"}) do
  pcall(ev.RegisterEvent,ev,eventName)
end
for _,eventName in ipairs({"UNIT_PET","PET_BAR_UPDATE","PET_UI_UPDATE","UNIT_HAPPINESS","UNIT_LOYALTY"}) do
  pcall(ev.RegisterEvent,ev,eventName)
end
ev:SetScript("OnEvent",function(_,event)
  if event=="PLAYER_LOGIN" then
    AetherInventoryDB=AetherInventoryDB or {}
    if type(AetherInventoryDB.scale)~="number" then AetherInventoryDB.scale=.91 end
    autoSortEnabled=AetherInventoryDB.autoSortEnabled~=false
    A.CreateUI()
    scanRecentItems()
    if autoSortEnabled then lastAutoSortSignature=bagLayoutSignature();autoSortSeeded=true end
    installMerchantBagCloseHook()
    restoreToggleBindings()
  elseif event=="BAG_UPDATE_DELAYED" then
    scanRecentItems()
    queueAutoSort()
    if UIReady and frame and frame:IsShown() and not InCombatLockdown() then A.Refresh() end
  elseif event=="BAG_UPDATE" then
    queueAutoSort()
  elseif event=="PLAYER_REGEN_ENABLED" then
    queueAutoSort()
    if UIReady and frame and frame:IsShown() then A.Refresh() end
  elseif event=="MERCHANT_SHOW" then
    if not UIReady then A.CreateUI() end
    if not InCombatLockdown() and frame then
      if not frame:IsShown() then
        merchantOpenedInventory=true
        frame:Show()
      end
      frame:Raise()
      setBagActionMode()
      A.Refresh()
    end
  elseif event=="MERCHANT_CLOSED" then
    if not InCombatLockdown() and merchantOpenedInventory and frame and frame:IsShown() then
      frame:Hide()
    end
    merchantOpenedInventory=false
    if UIReady and frame and frame:IsShown() and not InCombatLockdown() then
      setBagActionMode()
      A.Refresh()
    end
  elseif UIReady and frame and frame:IsShown() and not InCombatLockdown() then
    A.Refresh()
  end
end)
SLASH_AETHERINVENTORY1="/ai"
SLASH_AETHERINVENTORY2="/aetherinventory"
SlashCmdList.AETHERINVENTORY=function(msg)
  msg=(msg or ""):lower()
  if msg=="reset" then
    AetherInventoryDB.x=0;AetherInventoryDB.y=0;placeFrame();print("Aether Inventory: window reset")
  elseif msg:match("^scale%s+[%d%.]+$") then
    local value=tonumber(msg:match("[%d%.]+"))
    value=max(.65,min(1.18,value or .91))
    AetherInventoryDB.scale=value
    if frame then frame:SetScale(value);placeFrame() end
    print("Aether Inventory: scale "..string.format("%.2f",value))
  elseif msg=="debugclick" then
    rightClickDiagnostics=not rightClickDiagnostics
    print("Aether Inventory: right-click diagnostics "..(rightClickDiagnostics and "ON; right-click one item once" or "OFF"))
  elseif msg=="help" then
    print("Aether Inventory: /ai toggle, /ai scale 0.9, /ai reset, /ai debugclick")
  else
    A.Toggle()
  end
end
