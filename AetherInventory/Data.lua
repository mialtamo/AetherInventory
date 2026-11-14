local addonName, addon = ...
addon.version = "0.5.12"
addon.media = "Interface\\AddOns\\AetherInventory\\Media\\"

local C = C_Container
local I = C_Item

-- WoW: Forever also has a dedicated reagent bag in container 5.
addon.bagIDs = {0, 1, 2, 3, 4, 5}
addon.bagFamilies = {
  {1,"Arrows"},{2,"Bullets"},{4,"Soul Shards"},{8,"Leatherworking"},{16,"Inscription"},
  {32,"Herbs"},{64,"Enchanting"},{128,"Engineering"},{256,"Keys"},{512,"Gems"},
  {1024,"Mining"},{2048,"Equipment"},{4096,"Pets"},{8192,"Currency"},
  {16384,"Quest Items"},{32768,"Reagents"},
}
addon.colors = {
  panel = {0.075, 0.060, 0.125}, gold = {0.91, 0.72, 0.39},
  lavender = {0.78, 0.65, 1.00}, empty = {0.22, 0.54, 0.39},
}
addon.quality = {
  [0] = {0.52,0.53,0.56}, [1] = {0.78,0.80,0.83}, [2] = {0.22,0.93,0.32},
  [3] = {0.20,0.56,1.00}, [4] = {0.68,0.30,0.96}, [5] = {1.00,0.50,0.09},
}
addon.equipment = {
  {1,"Head"},{2,"Neck"},{3,"Shoulder"},{15,"Back"},{5,"Chest"},{9,"Wrist"},{10,"Hands"},
  {6,"Waist"},{7,"Legs"},{8,"Feet"},{11,"Ring 1"},{12,"Ring 2"},{13,"Trinket 1"},{14,"Trinket 2"},
  {16,"Main hand"},{17,"Off hand"},{18,"Ranged"},{4,"Shirt"},{19,"Tabard"},
}
local classWeights = {
  HUNTER={agi=6,str=0.5,int=0.35,sta=1.6,spi=0.3,weapon=6,ranged=12},
  WARRIOR={agi=2.2,str=5,int=0,sta=2.8,spi=0,weapon=8,ranged=1},
  ROGUE={agi=6,str=1.0,int=0,sta=1.5,spi=0,weapon=9,ranged=2},
  PALADIN={agi=1,str=3.5,int=2.5,sta=2.5,spi=0.3,weapon=6,ranged=0},
  SHAMAN={agi=2,str=2.8,int=3,sta=2,spi=0.3,weapon=5,ranged=0},
  DRUID={agi=3,str=1,int=3.5,sta=1.8,spi=0.5,weapon=2,ranged=0},
  MAGE={agi=0,str=0,int=6,sta=1.3,spi=2,weapon=1,ranged=0},
  PRIEST={agi=0,str=0,int=5.5,sta=1.5,spi=2,weapon=1,ranged=0},
  WARLOCK={agi=0,str=0,int=5.5,sta=1.7,spi=1.5,weapon=1,ranged=0},
}
local slotByType = {
  INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_CLOAK={15},
  INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WRIST={9}, INVTYPE_HAND={10},
  INVTYPE_WAIST={6}, INVTYPE_LEGS={7}, INVTYPE_FEET={8}, INVTYPE_FINGER={11,12},
  INVTYPE_TRINKET={13,14}, INVTYPE_WEAPON={16}, INVTYPE_2HWEAPON={16},
  INVTYPE_WEAPONMAINHAND={16}, INVTYPE_WEAPONOFFHAND={17}, INVTYPE_SHIELD={17},
  INVTYPE_HOLDABLE={17}, INVTYPE_RANGED={18}, INVTYPE_RANGEDRIGHT={18},
  INVTYPE_THROWN={18}, INVTYPE_RELIC={18}, INVTYPE_BAG={}, INVTYPE_BODY={4}, INVTYPE_TABARD={19},
}
local function safeCall(f,...)
  if type(f) ~= "function" then return nil end
  local ok,a,b,c,d,e,f2,g,h,i,j,k,l,m = pcall(f,...)
  if ok then return a,b,c,d,e,f2,g,h,i,j,k,l,m end
  return nil
end
addon.safeCall = safeCall

function addon.BagSize(bag)
  return math.max(0, math.min(36, tonumber(safeCall(C and C.GetContainerNumSlots,bag)) or 0))
end
function addon.BagFamily(bag)
  local _,family=safeCall(C and C.GetContainerNumFreeSlots,bag)
  if type(family)=="number" then return family end
  if bag==0 then return 0 end
  local inv=safeCall(C and C.ContainerIDToInventoryID,bag)
  if not inv and type(ContainerIDToInventoryID)=="function" then inv=safeCall(ContainerIDToInventoryID,bag) end
  local link=inv and safeCall(GetInventoryItemLink,"player",inv)
  local getFamily=(I and I.GetItemFamily) or GetItemFamily
  local itemFamily=link and safeCall(getFamily,link)
  return type(itemFamily)=="number" and itemFamily or 0
end
function addon.BagFamilyLabel(family)
  if type(family)~="number" or family==0 then return "General" end
  local labels={}
  for _,entry in ipairs(addon.bagFamilies) do
    local mask,label=entry[1],entry[2]
    if math.floor(family/mask)%2==1 then labels[#labels+1]=label end
  end
  return #labels>0 and table.concat(labels," / ") or "Specialty"
end
function addon.BagInfo(bag,slot)
  return safeCall(C and C.GetContainerItemInfo,bag,slot)
end
function addon.BagLink(bag,slot)
  local it = addon.BagInfo(bag,slot)
  return it and it.hyperlink or safeCall(C and C.GetContainerItemLink,bag,slot)
end
function addon.NameForBag(bag)
  if bag==0 then return "Backpack" end
  local bagName = safeCall(C and C.GetBagName, bag)
  if type(bagName)=="string" and bagName~="" then return bagName end
  local inv=safeCall(C and C.ContainerIDToInventoryID,bag)
  if not inv and type(ContainerIDToInventoryID)=="function" then inv=ContainerIDToInventoryID(bag) end
  local link=inv and GetInventoryItemLink("player",inv)
  local name=link and I and safeCall(I.GetItemInfo,link)
  if name then return name end
  return "Bag "..bag
end
function addon.Category(link,item)
  if not item then return "Empty" end
  if item.quality == 0 then return "Junk" end
  local _,typ,sub,equipLoc,_,classID = safeCall(I and I.GetItemInfoInstant, link or item.itemID)
  if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG" then return "Equipment" end
  if classID==0 then return "Consumables" end
  if classID==7 or classID==5 or classID==6 or classID==9 then return "Materials" end
  if classID==12 then return "Quest" end
  return "Other"
end
function addon.ItemDisplayName(link,item)
  if item and item.itemName then return item.itemName end
  local name=link and I and safeCall(I.GetItemInfo,link)
  if name then return name end
  if link then return (link:match("%[(.-)%]") or "Item") end
  return "Unknown item"
end

local function numeric(stats,key)
  local v=stats and stats[key]
  return type(v)=="number" and v or 0
end
local utilityToolIDs = {[7005]=true,[2901]=true}
local function IsInventoryTool(link,itemID)
  if utilityToolIDs[itemID] then return true end
  local name=safeCall(I and I.GetItemInfo,link)
  if type(name)=="string" then
    local lower=name:lower()
    if lower:find("skinning knife",1,true) or lower:find("mining pick",1,true) then return true end
  end
  return false
end
function addon.Score(link, equipLoc)
  if not link or not I then return nil end
  local stats=safeCall(I.GetItemStats,link)
  if type(stats)~="table" then return nil end
  local _,class=UnitClass("player")
  local w=classWeights[class] or classWeights.HUNTER
  local agi=numeric(stats,"ITEM_MOD_AGILITY_SHORT")
  local str=numeric(stats,"ITEM_MOD_STRENGTH_SHORT")
  local sta=numeric(stats,"ITEM_MOD_STAMINA_SHORT")
  local int=numeric(stats,"ITEM_MOD_INTELLECT_SHORT")
  local spi=numeric(stats,"ITEM_MOD_SPIRIT_SHORT")
  local crit=numeric(stats,"ITEM_MOD_CRIT_RATING_SHORT")
  local hit=numeric(stats,"ITEM_MOD_HIT_RATING_SHORT")
  local ap=numeric(stats,"ITEM_MOD_ATTACK_POWER_SHORT")
  local rap=numeric(stats,"ITEM_MOD_RANGED_ATTACK_POWER_SHORT")
  local spell=numeric(stats,"ITEM_MOD_SPELL_POWER_SHORT")
  local armor=numeric(stats,"RESISTANCE0_NAME")
  local dps=numeric(stats,"ITEM_MOD_DAMAGE_PER_SECOND_SHORT")
  local physical=(class=="HUNTER" or class=="ROGUE" or class=="WARRIOR")
  local score=agi*w.agi + str*w.str + sta*w.sta + int*w.int + spi*w.spi
  score=score+crit*1.4+hit*1.8 + (physical and ap*0.7 or 0) + (physical and rap*0.7 or 0)
  score=score+(not physical and spell*2.1 or 0) + armor*0.025
  if dps>0 then
    if equipLoc=="INVTYPE_RANGED" or equipLoc=="INVTYPE_RANGEDRIGHT" then
      score=score+dps*w.ranged
    else
      score=score+dps*w.weapon
    end
  end
  local hasData=(agi+str+sta+int+spi+crit+hit+ap+rap+spell+dps+armor)>0
  return hasData and score or nil
end
function addon.BestCompareSlot(equipLoc)
  local slots=slotByType[equipLoc]
  if not slots or #slots==0 then return nil end
  local chosen=nil
  local minScore=nil
  for _,slot in ipairs(slots) do
    local link=GetInventoryItemLink("player",slot)
    -- An empty slot is not evidence that a bag item is an upgrade. In
    -- particular, generic one-hand tools must not light up an empty off-hand.
    if link then
      local cur=addon.Score(link,equipLoc)
      if not cur then return nil end -- incomplete equipped data; do not claim upgrade
      if not minScore or cur<minScore then chosen=slot;minScore=cur end
    end
  end
  return chosen, minScore
end
function addon.UpgradeFor(link)
  if not link or not I then return nil end
  if type(I.IsEquippableItem)=="function" and not safeCall(I.IsEquippableItem,link) then return nil end
  local itemID,_,_,equipLoc= safeCall(I.GetItemInfoInstant,link)
  if IsInventoryTool(link,itemID) then return nil end
  if not equipLoc or equipLoc=="" then return nil end
  local chosen, oldScore=addon.BestCompareSlot(equipLoc)
  if not chosen or not oldScore then return nil end
  local newScore=addon.Score(link,equipLoc)
  if not newScore then return nil end
  local _,_,_,_,reqLevel = safeCall(I.GetItemInfo,link)
  if type(reqLevel)=="number" and reqLevel>UnitLevel("player") then return nil end
  -- Basic equipment eligibility check; final recommendation remains advisory.
  if newScore <= oldScore*1.18 + 1 then return nil end
  return {slot=chosen,delta=newScore-oldScore,score=newScore,old=oldScore}
end
function addon.Snapshot()
  local all={}; local total,free,freeGeneral,freeSpecialty=0,0,0,0; local good={}; local byBag={}
  for _,bag in ipairs(addon.bagIDs) do
    local size=addon.BagSize(bag); local list={}; local family=addon.BagFamily(bag); local bagFree=0
    for slot=1,size do
      total=total+1
      local item=addon.BagInfo(bag,slot)
      if not item then
        free=free+1;bagFree=bagFree+1
        if family==0 then freeGeneral=freeGeneral+1 else freeSpecialty=freeSpecialty+1 end
      else
        local link=item.hyperlink or addon.BagLink(bag,slot)
        local category=addon.Category(link,item)
        local up=addon.UpgradeFor(link)
        local data={bag=bag,slot=slot,item=item,link=link,category=category,upgrade=up,
          name=addon.ItemDisplayName(link,item)}
        all[#all+1]=data; list[slot]=data
        if up then good[#good+1]=data end
      end
    end
    byBag[bag]={size=size,items=list,family=family,free=bagFree,specialty=family~=0}
  end
  table.sort(good,function(a,b) return a.upgrade.delta>b.upgrade.delta end)
  return {total=total,free=free,freeGeneral=freeGeneral,freeSpecialty=freeSpecialty,items=all,upgrades=good,byBag=byBag}
end

