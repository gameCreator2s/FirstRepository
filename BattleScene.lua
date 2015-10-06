require "Army"
require "MapDataProxy"

local BattelScene = class("BattelScene",function()
    return cc.Scene:create()
end)

function BattelScene.create()
    local scene = BattelScene.new()
    scene:addChild(scene:createMapLayer())
    scene:addChild(scene:createArmyLayer())

    return scene
end


function BattelScene:ctor()
    self.visibleSize = cc.Director:getInstance():getVisibleSize()
    self.origin = cc.Director:getInstance():getVisibleOrigin()
    self.schedulerID = nil
end

function BattelScene:createMapLayer()
	local map_layer = cc.Layer:create();
	local bg = cc.Sprite:create("map.jpg");
	bg:setAnchorPoint(0,0);
	bg:setPosition(0,0);
	map_layer:addChild(bg);


	return map_layer
end

function BattelScene:createArmyLayer()
	MapDataProxy.initMapData();
	local layer = cc.Layer:create();

	local army_1 = Army.new(1);
	army_1:createSolider(0,0);
	layer:addChild(army_1);
	self.army_1 = army_1;
	army_1:move({{x=1,y=1}});
	-- army_1:moveDir(1);

	local army_2 = Army.new(1);
	army_2:createSolider(18,0);
	layer:addChild(army_2);
	self.army_2 = army_2;
	army_2:move({{x=1,y=1}});

	local army_3 = Army.new(1);
	army_3:createSolider(27,0);
	layer:addChild(army_3);
	self.army_3 = army_3;
	army_3:move({{x=2,y=1}});

	local army_4 = Army.new(1);
	army_4:createSolider(36,0);
	layer:addChild(army_4);
	self.army_4 = army_4;
	army_4:move({{x=2,y=2}});

	local enemy_1 = Army.new(2);
	enemy_1:createSolider(9,30);
	layer:addChild(enemy_1);
	self.enemy_1 = enemy_1;
	enemy_1:exexAI(1,5)

	local enemy_2 = Army.new(2);
	enemy_2:createSolider(18,30);
	layer:addChild(enemy_2);
	self.enemy_2 = enemy_2;
	enemy_2:exexAI(2,5)

	local function s_update(dt)
    	self:update(dt);
    end
    --layer:scheduleUpdateWithPriorityLua(s_update, 0);

	return layer;
end

function BattelScene:createEnemy()
	local list = {0,0,0,  0,0,0,  0,0,0, 0,0,0,  0,0,0,  0,0,0,
				  0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,
				  0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,
				  0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,

				  0,0,0,  0,0,0,  0,0,0, 0,1,1,  1,0,1,  1,1,0,
				  0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,
				  0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,
				  0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0

				  -- 0,0,0,  0,0,0,  0,0,0, 0,1,1,  1,0,1,  1,1,0,
				  -- 0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,
				  -- 0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0,
				  -- 0,1,1,  1,0,1,  1,1,0, 0,1,1,  1,0,1,  1,1,0
				 }

	for i=#list,1,-1 do
		if list[i] == 1 then
			local idx = (i-1) % 9 + 16;
			local idy = math.floor((i-1) / 9) + 2;

			local sp = Solider.new(2,2);
			sp:init(idx,idy);
			sp:setPosition(idx*20+10,idy*20+10);

			MapDataProxy.setMapData(idx,idy,sp,1);
			self:addChild(sp);
		end
	end
end

function BattelScene:update(dt)
	MapDataProxy.clearTeamTempData();
	self.army_1:update(dt);
	self.army_2:update(dt);
	self.army_3:update(dt);
	self.army_4:update(dt);
	self.enemy_1:update(dt);
	self.enemy_2:update(dt);
end

return BattelScene
