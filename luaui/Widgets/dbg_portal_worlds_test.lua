-- SPDX-License-Identifier: GPL-2.0-or-later
function widget:GetInfo()
	return {name="Portal worlds UI tests", desc="Opt-in BAR view and minimap checks", author="Codex", license="GPL v2 or later", layer=10002, enabled=true, handler=true}
end
local test=Spring.GetModOptions().portal_worlds_test
if test~="four" and test~="baseline" then return false end
local checked, stage, pending, drawAfter = {},0,nil,nil
local checks,failures=0,0
local function Check(key,value,detail)
	checks=checks+1
	if not value then failures=failures+1 end
	Spring.Echo("[BAR_PORTAL_UI] ASSERT "..key.." pass="..tostring(not not value).." "..tostring(detail or ""))
end
function widget:Update()
	local f=Spring.GetGameFrame()
	if test=="baseline" then
		if f>=120 and not checked.baseline then
			checked.baseline=true
			Check("ordinary_view_absent",not WG.PortalWorldView and not WG.PortalWorlds)
		end
		return
	end
	local api=WG.PortalWorlds
	if not api or not WG.PortalWorldView then return end
	if f>=100 and not checked.closed then
		checked.closed=true
		local active,menu=api.GetState()
		Check("selector_hidden_before_loss",active==1 and not menu)
		for i=2,4 do Check("closed_view_refused_"..i,api.View(i)==false) end
	end
	if f>=330 and not checked.open then
		checked.open=true
		local _,menu=api.GetState()
		Check("selector_open_after_loss",menu)
		Check("only_open_neighbor",api.Accessible(2) and not api.Accessible(3) and not api.Accessible(4))
		Check("still_closed_view_refused",api.View(3)==false)
	end
	if f>=400 and not checked.input then
		checked.input=true
		local gate=Spring.GetGameRulesParam("portal_test_gate")
		local id=Spring.GetGameRulesParam("portal_test_ui")
		local x,y,z=Spring.GetUnitPosition(gate)
		api.View(1,{name="ta",mode=1,px=x,py=y,pz=z,height=1000,angle=0.2,flipped=0})
		Spring.SelectUnitArray({id})
		checked.clickAfter=Spring.GetDrawFrame()+4
	end
	if checked.clickAfter and Spring.GetDrawFrame()>=checked.clickAfter then
		checked.clickAfter=nil
		local gate=Spring.GetGameRulesParam("portal_test_gate")
		local x,y,z=Spring.GetUnitPosition(gate)
		local sx,sy=Spring.WorldToScreenCoords(x,y+10,z)
		local ui=widgetHandler:FindWidget("Portal view bounds")
		Check("real_portal_right_click",ui:MousePress(sx,sy,3)==true)
	end
	if f>=700 and stage<4 and not pending then
		stage=stage+1
		Check("open_view_"..stage,api.View(stage))
		pending=stage
		drawAfter=Spring.GetDrawFrame()+4
	end
end
function widget:DrawScreenPost()
	if not pending or Spring.GetDrawFrame()<drawAfter then return end
	local region=pending
	pending=nil
	local view=WG.PortalWorldView
	Check("active_region_"..region,view.region==region)
	Check("material_region_"..region,WG.PortalMapMaterial and WG.PortalMapMaterial.region==region)
	local camera=Spring.GetCameraState()
	Check("camera_region_"..region,camera.px and camera.pz and camera.px>=view.rect.x0 and camera.px<view.rect.x1 and camera.pz>=view.rect.z0 and camera.pz<view.rect.z1)
	local x,y,w,h=Spring.GetMiniMapGeometry()
	local _,hit=Spring.TraceScreenRay(x+w/2,y+h/2,true,true)
	Check("minimap_region_"..region,type(hit)=="table" and hit[1]>=view.rect.x0 and hit[1]<view.rect.x1 and hit[3]>=view.rect.z0 and hit[3]<view.rect.z1)
	Spring.SendCommands("screenshot")
	if region==4 then Spring.Echo("[BAR_PORTAL_UI] DONE checks="..checks.." failures="..failures) end
end
