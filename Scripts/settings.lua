local M={}
function M.new(root,C,H,log)
 local state={rows={},stopped=false}
 local path=root..'Runtime/player-volume.txt'
 local f=io.open(path,'r');if f then local n=tonumber(f:read('*a'));f:close();if n and n>=0 and n<=1 then C.volume=n end end
 local function valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
 local function text(s)return StaticFindObject('/Script/Engine.Default__KismetTextLibrary'):Conv_StringToText(s)end
 local function addAfter(parent,reference,row)
  local index=parent:GetChildIndex(reference);local tail={}
  for i=index+1,parent:GetChildrenCount()-1 do
   local child=parent:GetChildAt(i);local slot=child.Slot;local pad=slot.Padding;local sz=slot.Size
   tail[#tail+1]={child=child,padding={Left=pad.Left,Top=pad.Top,Right=pad.Right,Bottom=pad.Bottom},size={Value=sz.Value,SizeRule=sz.SizeRule},h=slot.HorizontalAlignment,v=slot.VerticalAlignment}
  end
  for _,x in ipairs(tail)do parent:RemoveChild(x.child)end
  local slot=parent:AddChild(row);slot:SetPadding({Left=0,Top=0,Right=0,Bottom=5})
  for _,x in ipairs(tail)do local s=parent:AddChild(x.child);s:SetPadding(x.padding);s:SetSize(x.size);s:SetHorizontalAlignment(x.h);s:SetVerticalAlignment(x.v)end
 end
 function state:attach(panel)
  if not valid(panel.AIBarkVolume)then return end
  local key=panel:GetFullName();local entry=self.rows[key]
  if entry and valid(entry.row)then return end
  local template=panel.AIBarkVolume
  local row=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(panel,template:GetClass(),H.GetPlayerController())
  assert(valid(row),'Could not create Player Voice Volume slider')
  row.BarType=2;row.MinSliderRange=0;row.MaxSliderRange=100;row.FractionalDigits=0
  addAfter(template:GetParent(),template,row)
  -- Configure after attachment: the native Construct selects its default type.
  row.TypeSwitcher:SetActiveWidgetIndex(2)
  row.LabelText:SetText(text('Player Voice Volume'))
  row.SliderWidget:SetMinValue(0);row.SliderWidget:SetMaxValue(1);row.SliderWidget:SetStepSize(0.01)
  row.SliderWidget:SetValue(C.volume)
  local color=template.SliderProgress.FillColorAndOpacity
  row.SliderProgress:SetFillColorAndOpacity({R=color.R,G=color.G,B=color.B,A=color.A})
  row.SliderProgress:SetPercent(C.volume)
  row.ValueTxt:SetText(text(tostring(math.floor(C.volume*100+0.5))))
  self.rows[key]={row=row,last=C.volume}
  log('Added Player Voice Volume to Audio settings')
 end
 function state:tick()
  if self.stopped then return end
  for _,panel in ipairs(FindAllOf('WB_AudioSettingsPanel_C')or{})do
   if valid(panel)and not panel:GetFullName():find('Default__',1,true)then self:attach(panel)end
  end
  for key,e in pairs(self.rows)do
   if not valid(e.row)then self.rows[key]=nil else
    local value=math.floor(math.max(0,math.min(1,e.row.SliderWidget.Value))*100+0.5)/100
    if math.abs(value-e.last)>0.001 then
     e.last=value;C.volume=value
     e.row.SliderProgress:SetPercent(value);e.row.ValueTxt:SetText(text(tostring(math.floor(value*100+0.5))))
     local out=assert(io.open(path,'w'));out:write(string.format('%.2f',value));out:close()
     log('Player Voice Volume '..math.floor(value*100+0.5)..'%')
    end
   end
  end
 end
 function state:shutdown()self.stopped=true;for _,e in pairs(self.rows)do if valid(e.row)then e.row:RemoveFromParent()end end end
 return state
end
return M
