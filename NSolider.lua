FACE_DIR = {
	UP = 1,
	RIGHT_UP = 2,
	RIGHT = 3,
	RIGHT_DOWN = 4,
	DOWN = 5,
	LEFT_DOWN = 6,
	LEFT = 7,
	LEFT_UP = 8
}

DIR_GRID = {
	{x=0,y=1},
	{x=1,y=1},
	{x=1,y=0},
	{x=1,y=-1},
	{x=0,y=-1},
	{x=-1,y=-1},
	{x=-1,y=0},
	{x=-1,y=1}
}

SOLIDER_SATUS = {
	DIED = -1,
	IDLE = 0,
	WALK = 1,
	ATTACK = 2,
	WAIT = 3
}

NSolider = class("NSolider",function(camp,soliderType,gridx,gridy)
	local res = "blue_1.png";
	if camp == 2 then 
		res = "red_1.png";
	end

	local sp = cc.Sprite:create(res);
	return sp;
end)

function NSolider:ctor(camp,soliderType,gridx,gridy)
	self.camp = camp;

	self.grid_x = gridx;
	self.grid_y = gridy;

	self.status = SOLIDER_SATUS.IDLE;

	self.solider_type = soliderType;

	if self.solider_type == 4 then
		self.attack_dist = 10;
	elseif self.solider_type == 2 then
		self.attack_dist = 2;
	else
		self.attack_dist = 1;
	end

	if self.solider_type == 3 then
		self.move_speed = 150;
	elseif self.solider_type == 4 then
		self.move_speed = 70;
	else
		self.move_speed = 100;
	end;

	self.attack_interval = 1;
	self.prev_move_dir = 0;

	self.start_cal_wait_cnt = false; --开始计算等待次数，没路走就重新找过
	self.move_wait_cnt = 0;

	self.blood = 100;
	self.ai_prev_team_grid = nil;--前一个所处的大格子
	self.update_func = self.onIdle;
end

function NSolider:update(dt)
	if self.update_func ~= nil then
		self.update_func(self,dt);
	end
end

-------------------------------------------------------------------------------------
-------------------角色状态-----------------------------------------------------------
-------------------------------------------------------------------------------------


----------------空闲状态----------------------
-----查找周围是否有可攻击对象并攻击---------------
---------------------------------------------
function NSolider:idle()
	self.status = SOLIDER_SATUS.IDLE;
	self.update_func = self.onIdle;
end

function NSolider:onIdle(dt)
	--周围是否有攻击对象
	if self:checkRound() then
		self:attack(self.idle);
	end
end

----------------攻击状态----------------------
------------攻击完成后继续其他前期操作-----------
---------------------------------------------
function NSolider:attack(endFunc)
	--
	local scale_action_1 = cc.ScaleTo:create(0.25,1.5);
	local scale_action_2 = cc.ScaleTo:create(0.25,1);

	if self.attackAction ~= nil then
		self.attackAction:release();
	end
	self.attackAction = cc.Sequence:create(scale_action_1,scale_action_2);
	self.attackAction:retain();
    self.attackAction:startWithTarget(self);
    self.attackAction:step(0);
    self.attackTime = 0;
    self.status = SOLIDER_SATUS.ATTACK;

    self.attack_end_func = endFunc;
    self.update_func = self.onAttack;
end

function NSolider:onAttack(dt)
	if self.attackAction ~= nil then
		self.attackAction:step(dt);
	end
	self.attackTime = self.attackTime + dt;
	if self.attackTime >= self.attack_interval then
		if self.attack_end_func ~= nil then 
			self.attack_end_func(self);
		else
			self:idle();
		end;
	elseif self.attackTime >= 0.5 then
		if self.attackAction ~= nil then
			self.attackAction:release();
	        self.attackAction = nil;
	    end
	end
end

----------------行走状态----------------------
------------根据移动速度前往下一个格子-----------
---------------------------------------------
function NSolider:walkTo(n_x,n_y,endFunc)
	-- body
	MapDataProxy.setMapData(self.grid_x,self.grid_y,nil,0);--先将自己之前的位置置空
	MapDataProxy.setMapData(n_x,n_y,self,1);--更新游戏世界数据
	self.grid_x = n_x;
	self.grid_y = n_y;

	if self.walkAction ~= nil then
		self.walkAction:release();
	end

	self.walkAction = cc.MoveTo:create(MapDataProxy.ARMY_GRID_WIDTH/self.move_speed,cc.p(n_x*MapDataProxy.ARMY_GRID_WIDTH+(MapDataProxy.ARMY_GRID_WIDTH/2),n_y*MapDataProxy.ARMY_GRID_WIDTH+(MapDataProxy.ARMY_GRID_WIDTH/2)));
	self.walkAction:retain();
    self.walkAction:startWithTarget(self)
    self.walkAction:step(0);
    self.walkTime = 0;
    self.status = SOLIDER_SATUS.WALK;

    self.walk_end_func = endFunc;
    self.update_func = self.onWalk;
end

function NSolider:onWalk(dt)
	self.walkAction:step(dt);
	self.walkTime = self.walkTime + dt;
	if self.walkTime >= (MapDataProxy.ARMY_GRID_WIDTH/self.move_speed) then
		self.walkAction:release();
        self.walkAction = nil;
        self.update_func = nil;
        if self.walk_end_func ~= nil then 
        	self.walk_end_func(self)
        else
        	self:idle()
        end
	end
end

----------------等待状态----------------------
------------等待下一帧继续处理------------------
---------------------------------------------
function NSolider:wait(waitTime,waitEndFunc)
	self.status = SOLIDER_SATUS.WAIT;
	self.update_func = self.onWait;
	self.wait_time = 0;
	self.wait_max_time = waitTime;
	self.wait_end_func = waitEndFunc;
end

function NSolider:onWait(dt)
	self.wait_time = self.wait_time + dt;
	if self.wait_time >= self.wait_max_time then
		if self.wait_end_func ~= nil then
			self.wait_end_func(self);
		else
			self:idle();
		end
	end
end

----------------胜利状态----------------------
------------播放胜利动作-----------------------
---------------------------------------------
function NSolider:playWin()
	--
end

----------------死亡状态----------------------
------------播放死亡特效-----------------------
---------------------------------------------
function NSolider:setDied()
	if self.blood <= 0 then
		MapDataProxy.setMapData(self.grid_x,self.grid_y,nil,0);
		self.update_func = nil;
		self.status = SOLIDER_SATUS.DIED;
	end
end

-------------------------------------------------------------------------------------
-------------------角色AI-----------------------------------------------------------
-------------------------------------------------------------------------------------


----------------------------------------------------
---传入移动的大格子列表执行行走，大格子行走只进行4方向行走---
---这里传入移动的大格子已经是去掉了重复和多余的格子---------
----------------------------------------------------
function NSolider:moveByTeamGrid(teamGridList,endFunc)
	--生成的移动格子列表
	self.move_list = {};
	--转换自身位置到对应的大格子
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

	--找到离格子列表里最近的格子
	local min_dist = 9999;
	local idx = 1;
	for i=#teamGridList,1,-1 do
		local d_x = math.abs(teamGridList[i].x - t_x);
		local d_y = math.abs(teamGridList[i].y - t_y);

		if (d_x + d_y) <=1 then --就在格子附近，邻接
			min_dist = 1;
			idx = i;
			break;
		else
			if min_dist > d_x  + d_y then
				min_dist = d_x + d_y;
				idx = i;
			end
		end
	end

	--如果不是附近格子，则加入新路径
	--st:下一个大格子的坐标
	local st_x = teamGridList[idx].x;
	local st_y = teamGridList[idx].y;
	local d_x = math.abs(st_x-t_x);
	local d_y = math.abs(st_y-t_y);
	if (d_x + d_y) > 1 then
		local last_y = t_y;
		for i=1,d_y do --先往Y方向行走
			if st_y > t_y then
				last_y = t_y + i;
				table.insert(self.move_list,{x=t_x,y=last_y});
			else
				last_y = t_y - i; 
				table.insert(self.move_list,{x=t_x,y=last_y});
			end
		end

		for i=1,d_x do --再往X方向行走
			if st_x > t_x then
				table.insert(self.move_list,{x=t_x+i,y=last_y});
			else 
				table.insert(self.move_list,{x=t_x-i,y=last_y});
			end
		end
	end

	--补上后续格子，idx为目的地的大格子索引
	for i=idx,#teamGridList do
		local len = #self.move_list;
		if len == 0 or teamGridList[i].x ~= self.move_list[len].x or teamGridList[i].y ~= self.move_list[len].y then
			table.insert(self.move_list,{x=teamGridList[i].x,y=teamGridList[i].y});
		end
	end

	if self.move_list[1].x ~= t_x or self.move_list[1].y ~= t_y then
		table.insert(self.move_list,1,{x=t_x,y=t_y});
	end

	self.move_index = 1;
	if endFunc == nil then
		self.move_to_next_team_end_func = self.lookEnemyAttack;
	else
		self.move_to_next_team_end_func = endFunc;
	end

	self.start_cal_wait_cnt = false; --开始计算等待次数，没路走就重新找过
	self.move_wait_cnt = 0;
	--开始循环格子的行走
	self:moveToNextTeamGrid();
end

---------------------------------------------
---开始走往下一个大格子-------------------------
---这里是对行走列表进行更新，当走完一个格子后，-----
---配置好下个格子，以及允许在行走时可以穿过的格子---
---------------------------------------------
function NSolider:moveToNextTeamGrid()
	--如果已经是最后一个格子，则执行攻击
	if self.move_index == #self.move_list then
		local curr_grid = self.move_list[self.move_index];
		if self.move_index == 1 then
			--如果一开始已经是在终点格子则行走方向随机
			self.move_dir = 0;			
		else
			--前进攻击
			local prev_grid = self.move_list[self.move_index-1];
			local dir = self:getGridDir(prev_grid.x,prev_grid.y,curr_grid.x,curr_grid.y);
			if dir ~= 0 then
				self.move_dir = dir;
			end;
		end
		--已经是最后一个格子，则只能在当前格子行动
		self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y}};
		self.end_grid = {x=curr_grid.x,y=curr_grid.y};
		--主动寻找这个格子内的敌人攻击
		if self.move_to_next_team_end_func == nil then
			self:lookEnemyAttack();
		else
			self.move_to_next_team_end_func(self);
		end
	else
		local curr_grid = self.move_list[self.move_index];
		local next_grid = self.move_list[self.move_index+1];
		if self.move_index == 1 then --初始就由下一格子的方向决定行走方向
			if self.ai_prev_team_grid == nil then
				self.move_dir = self:getGridDir(curr_grid.x,curr_grid.y,next_grid.x,next_grid.y);
			else
				self.move_dir = self:getGridDir(self.ai_prev_team_grid.x,self.ai_prev_team_grid.y,next_grid.x,next_grid.y);
				if self.move_dir == 0 then
					self.move_dir = self:getGridDir(curr_grid.x,curr_grid.y,next_grid.x,next_grid.y);
				end
			end
			self.end_grid = {x=next_grid.x,y=next_grid.y}
			self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y},{x=next_grid.x,y=next_grid.y}};
		else --其他的根据下一格和前一格的方向决定行走方向
			local prev_grid = self.move_list[self.move_index-1];

			self.move_dir = self:getGridDir(prev_grid.x,prev_grid.y,next_grid.x,next_grid.y);
			self.end_grid = {x=next_grid.x,y=next_grid.y}
			self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y},{x=next_grid.x,y=next_grid.y}};
		end
		self.ai_prev_team_grid = {x=curr_grid.x,y=curr_grid.y};
		self.move_index = self.move_index + 1;
		self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
		self.start_move_end_func = self.moveToNextTeamGrid;

		if self.move_index == #self.move_list then
			self.start_cal_wait_cnt = true; --开始计算等待次数，没路走就重新找过
			self.move_wait_cnt = 0;
		end
		self:startMove();
	end
end

---------------------------------------------
---开始行走处理--------------------------------
---------------------------------------------
function NSolider:startMove()
	self.status = SOLIDER_SATUS.WALK;
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

	if t_x == self.end_grid.x and t_y == self.end_grid.y then--检查是否在终点格子
		if self.start_move_end_func ~= nil then
			self.start_move_end_func(self);
		else
			self:lookEnemyAttack();
		end
	else
		--先看前进方向能不能走
		local n_x = self.grid_x + DIR_GRID[self.move_dir].x;
		local n_y = self.grid_y + DIR_GRID[self.move_dir].y;
		local grid_data = MapDataProxy.getMapData(n_x,n_y);
		if self:calAttack(grid_data) then --先看前进方向有没攻击对象
			self:attack(self.startMove);
		else
			--前进方向的格子是否可以走
			if grid_data ~= nil and grid_data.flag == 0 and self:checkTeamGridCanWalk(n_x,n_y) then
				self:walkTo(n_x,n_y,self.startMove);
			elseif self:checkRound() then --周围有攻击就攻击
				self:attack(self.startMove);
			else
				--根据最近的对方周围空的格子来决定行走方向，格子不能超出所处大格子的范围
				local n_x,n_y = self:getNextGrid(self.grid_x,self.grid_y,self.move_dir);
				if n_x ~= nil and n_y ~= nil then
					self:walkTo(n_x,n_y,self.startMove);
				else
					if self.start_cal_wait_cnt then
						self.move_wait_cnt = self.move_wait_cnt + 1;
					end
					if self.move_wait_cnt > 10 then
						if self.start_move_end_func ~= nil then
							self.start_move_end_func(self);
						else
							self:lookEnemyAttack();
						end
					else
						self:wait(0.2,self.startMove);
					end
				end
			end
		end
	end
end

---------------------------------------------
---执行方向行走--------------------------------
---isKeepMove: false 一次只行走一个格子---------
---			   true  一直往某个方向行走---------
---------------------------------------------
function NSolider:moveByDir(dir,isKeepMove)
	self.move_dir = dir;
	if isKeepMove then
		self.start_move_end_func = self.execMoveDir;
	else
		self.start_move_end_func = nil;
	end;
	self.is_keep_move = isKeepMove;
	self.exec_move_dir_end_func = self.lookEnemyAttack;
	self:execMoveDir();
end

function NSolider:execMoveDir()
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
	if self.move_dir == FACE_DIR.UP then
		local e_x = t_x;
		local e_y = t_y + 1;
		if e_y < MapDataProxy.TEAM_MAX_Y then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.DOWN then
		local e_x = t_x;
		local e_y = t_y - 1;
		if e_y >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.LEFT then
		local e_x = t_x - 1;
		local e_y = t_y;
		if e_x >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.RIGHT then
		local e_x = t_x + 1;
		local e_y = t_y;
		if e_x < MapDataProxy.TEAM_MAX_X then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.RIGHT_UP then
		local e_x = t_x + 1;
		local e_y = t_y + 1;
		if e_x < MapDataProxy.TEAM_MAX_X and e_y < MapDataProxy.TEAM_MAX_Y then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x+1,y=t_y},{x=t_x,y=t_y+1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.RIGHT_DOWN then
		local e_x = t_x + 1;
		local e_y = t_y - 1;
		if e_x < MapDataProxy.TEAM_MAX_X and e_y >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x+1,y=t_y},{x=t_x,y=t_y-1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.LEFT_UP then
		local e_x = t_x - 1;
		local e_y = t_y + 1;
		if e_x >= 0 and e_y < MapDataProxy.TEAM_MAX_Y then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x-1,y=t_y},{x=t_x,y=t_y+1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	elseif self.move_dir == FACE_DIR.LEFT_DOWN then
		local e_x = t_x - 1;
		local e_y = t_y - 1;
		if e_x >= 0 and e_y >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x-1,y=t_y},{x=t_x,y=t_y-1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self.ai_prev_team_grid = {x=t_x,y=t_y};
			self:startMove();
		else --以到达最后格子
			if self.exec_move_dir_end_func == nil then
				self:lookEnemyAttack();--主动寻找这个格子内的敌人攻击
			else
				self.exec_move_dir_end_func(self);
			end
		end
	end
end

---------------------------------------------
---在最后的格子内保持前进------------------------
---------------------------------------------
function NSolider:lookEnemyAttack()
	if self.move_dir == 0 then --随机攻击
		self:attackRandom();--随机寻找格子内的敌人攻击
	else
		--移动方向后面是否有自己人，有则前进，给后面让位
		local prev_x = self.grid_x - DIR_GRID[self.move_dir].x;
		local prev_y = self.grid_y - DIR_GRID[self.move_dir].y;
		local grid_data = MapDataProxy.getMapData(prev_x,prev_y);
		--如果后面是敌人则先消灭敌人给后面前进提供协助
		if self:calAttack(grid_data) then
			self:attack(self.lookEnemyAttack);
		else --否则前进
			--在自己格子内行走攻击
			local n_x = self.grid_x + DIR_GRID[self.move_dir].x;
			local n_y = self.grid_y + DIR_GRID[self.move_dir].y;
			grid_data = MapDataProxy.getMapData(n_x,n_y);
			if self:calAttack(grid_data) then --先看前进方向有没攻击对象
				self:attack(self.lookEnemyAttack);
			else
				self:attackRandom();--随机寻找格子内的敌人攻击
			end
		end
	end
end


---------------------------------------------
---攻击自己所在格子的敌人-----------------------
---------------------------------------------
function NSolider:attackRandom()
	if self:checkRound() then --周围有攻击就攻击
		self:attack(self.attackRandom);
	else
		--取到当前格子敌人数量
		local cnt = MapDataProxy.getTeamSoliderCnt(self.grid_x,self.grid_y,self.camp);

		if cnt == 0 then--找附近最多敌人的格子
			self:gotoEnemyMaxTeamGrid();
		else--随机搜寻敌人去攻击
			self.attack_in_team_end_func = self.attackRandom;
			self:attackInTeamGrid();
		end
	end
end

---------------------------------------------
---攻击自己格子内敌人---------------------------
---------------------------------------------
function NSolider:attackInTeamGrid()
	if self:checkRound() then --周围有攻击就攻击
		self:attack(self.attack_in_team_end_func);
	else
		local list = MapDataProxy.getTeamTempData(self.grid_x,self.grid_y,self.camp);
		local dist = 99999;
		local dir = 0;
		local e_x = -1;
		local e_y = -1;
		for i=1,#list do
			local a_x = math.abs(list[i].grid_x - self.grid_x);
			local a_y = math.abs(list[i].grid_y - self.grid_y);
			local temp_dist = 0;
			if a_x == a_y then 
				temp_dist = a_x * 1.414;
			elseif a_x > a_y then
				temp_dist = a_y * 1.414 + (a_x-a_y);
			else
				temp_dist = a_x * 1.414 + (a_y-a_x);
			end

			if temp_dist < dist then
				local t_ dir = self:getGridDir(self.grid_x,self.grid_y,list[i].grid_x,list[i].grid_y);
				local n_x = self.grid_x + DIR_GRID[dir].x;
				local n_y = self.grid_y + DIR_GRID[dir].y;
				local grid_data = MapDataProxy.getMapData(n_x,n_y);
				if grid_data ~= nil and grid_data.flag == 0 then
					dist = temp_dist;
					dir = t_dir;
					e_x = n_x;
					e_y = n_y;
				end
			end
		end

		if dir ~= 0 and e_x >= 0 and e_y >= 0 then
			self:walkTo(e_x,e_y,self.attack_in_team_end_func);
		else
			--没有靠近敌人的机会则随机走一格
			local is_walk = false;
			local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
			for i=1,8 do
				local n_x = self.grid_x + DIR_GRID[i].x;
				local n_y = self.grid_y + DIR_GRID[i].y;
				local n_tx,n_ty = MapDataProxy.changSoliderToTeamGrid(n_x,n_y);
				if n_tx == t_x and n_ty == t_y then --如果在同一个格子内
					local grid_data = MapDataProxy.getMapData(n_x,n_y);
					if grid_data ~= nil and grid_data.flag == 0 then
						self:walkTo(n_x,n_y,self.attack_in_team_end_func);
						return;
					end
				end
			end
			self:wait(0.2,self.attack_in_team_end_func);
		end
	end
end

---------------------------------------------
---行走至周围敌人数量最多的大格子-----------------
---------------------------------------------
function NSolider:gotoEnemyMaxTeamGrid()
	local teamGridList = self:getRoundEnemyMaxTeamGrid();
	if teamGridList ~= nil then
		self:moveByTeamGrid(teamGridList);
	else
		--没有攻击敌人了
		self:idle();
	end
end

-------------------------------------------------------------------------------------
-------------------NPC AI函数--------------------------------------------------------
-------------------------------------------------------------------------------------

function NSolider:moveToTeamGrid(nt_x,nt_y,endFunc)
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

	if self.ai_prev_team_grid == nil then
		self.move_dir = self:getGridDir(t_x,t_y,nt_x,nt_y);
	else
		self.move_dir = self:getGridDir(self.ai_prev_team_grid.x,self.ai_prev_team_grid.y,nt_x,nt_y);
	end

	self.ai_prev_team_grid = {x=t_x,y=t_y};
	self.end_grid = {x=nt_x,y=nt_y}
	self.can_move_grid = {{x=t_x,y=t_y},{x=nt_x,y=nt_y}};
	self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
	self.start_move_end_func = endFunc;

	self.start_cal_wait_cnt = true; --开始计算等待次数，没路走就重新找过
	self.move_wait_cnt = 0;
	self:startMove();
end

---------------------------------------------
---执行AI-------------------------------------
---------------------------------------------
AI_TYPE = {
	FORWARD_AND_DIR_ATTACK = 1,--往一个方向推进，走到一个大格子就清理这个格子内的敌人，清理完毕继续往下一个大格子前进 	
	FORWARD_AND_ROUND_ATTACK = 2,--往一个方向推进，走到一个大格子就清理这个格子内的敌人，清理完毕继续找周围格子敌人最多的格子清理，没有就保持前进(适合攻坚部队)
	FORWARD_AND_HELP_ATTACK = 3,--往一个方向推进，走到一个大格子就清理这个格子内的敌人，清理完毕继续找周围格子敌人最少的格子清理，没有就保持前进(适合护卫部队)
	ROUND_ATTACK_AND_FORWARD = 4,--清理
}

function NSolider:aiToForwardAndDirAttack(dir)
	self.move_dir = dir;
	self.start_move_end_func = self.execAIByForwardAndDirAttack;
	self.is_keep_move = false;
	self.exec_move_dir_end_func = self.lookEnemyAttack;
	self:execAIByForwardAndDirAttack();
end

function NSolider:execAIByForwardAndDirAttack()
	--取到当前格子敌人数量
	local cnt = MapDataProxy.getTeamSoliderCnt(self.grid_x,self.grid_y,self.camp);
	if cnt == 0 then --当前格子没有敌人则继续前进
		self:execMoveDir();
	else
		self.attack_in_team_end_func = self.execAIByForwardAndDirAttack;
		self:attackInTeamGrid();
	end
end

function NSolider:aiToForwardAndRoundAttack(dir)
	self.move_dir = dir;
	self.start_move_end_func = self.execAIByForwardAndRoundAttack;
	self.is_keep_move = false;
	self.exec_move_dir_end_func = self.lookEnemyAttack;
	self:execAIByForwardAndRoundAttack();
end

function NSolider:execAIByForwardAndRoundAttack()
	--取到当前格子敌人数量
	local cnt = MapDataProxy.getTeamSoliderCnt(self.grid_x,self.grid_y,self.camp);
	if cnt == 0 then --当前格子没有敌人则继续前进
		local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

		local teamGridList = self:getRoundOneEnemyMaxTeamGrid();
		if teamGridList ~= nil then
			self:moveToTeamGrid(teamGridList.x,teamGridList.y,self.execAIByForwardAndRoundAttack);
		else
			--没有攻击敌人了
			self:lookEnemyAttack();
		end
	else
		self.attack_in_team_end_func = self.execAIByForwardAndRoundAttack;
		self:attackInTeamGrid();
	end
end

function NSolider:aiToForwardAndHelpAttack(dir)
	self.move_dir = dir;
	self.start_move_end_func = self.execAIByForwardAndHelpAttack;
	self.is_keep_move = false;
	self.exec_move_dir_end_func = self.lookEnemyAttack;
	self:execAIByForwardAndHelpAttack();
end

function NSolider:execAIByForwardAndHelpAttack()
	--取到当前格子敌人数量
	local cnt = MapDataProxy.getTeamSoliderCnt(self.grid_x,self.grid_y,self.camp);
	if cnt == 0 then --当前格子没有敌人则继续前进
		local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

		local teamGridList = self:getRoundOneEnemyMinTeamGrid();
		if teamGridList ~= nil then
			self:moveToTeamGrid(teamGridList.x,teamGridList.y,self.execAIByForwardAndHelpAttack);
		else
			--没有攻击敌人了
			self:lookEnemyAttack();
		end
	else
		self.attack_in_team_end_func = self.execAIByForwardAndHelpAttack;
		self:attackInTeamGrid();
	end
end

-------------------------------------------------------------------------------------
-------------------辅助函数-----------------------------------------------------------
-------------------------------------------------------------------------------------

---------------------------------------------
---计算格子的方向------------------------------
---------------------------------------------
function NSolider:getGridDir(p_x,p_y,n_x,n_y)
	local d_x = n_x - p_x;
	local d_y = n_y - p_y;

	if d_x < 0 then 
		d_x = -1;
	elseif d_x > 0 then
		d_x = 1
	end

	if d_y < 0 then 
		d_y = -1;
	elseif d_y > 0 then
		d_y = 1
	end

	for i=1,#DIR_GRID do
		if DIR_GRID[i].x == d_x and DIR_GRID[i].y == d_y then
			return i;
		end
	end

	return 0;
end

---------------------------------------------
---检查周围8方向是否有攻击对象--------------------
---------------------------------------------
function NSolider:checkRound()
	for i=1,self.attack_dist do
		for j=1,#DIR_GRID do
			local n_x = self.grid_x + i*DIR_GRID[j].x;
			local n_y = self.grid_y + i*DIR_GRID[j].y;

			local grid_data = MapDataProxy.getMapData(n_x,n_y);
			if self:calAttack(grid_data) then
				return true;
			end
		end
	end

	return false;
end

---------------------------------------------
---计算攻击伤害，成功返回true，失败返回false------
---------------------------------------------
function NSolider:calAttack(grid_data)
	local hurt = 50;
	if grid_data ~= nil and grid_data.flag == 1 and grid_data.army.camp ~= self.camp then
		--兵种克制
		if (self.army_type == 1 and grid_data.army.army_type == 2) or
		   (self.army_type == 2 and grid_data.army.army_type == 3) or
		   (self.army_type == 3 and grid_data.army.army_type == 1) then
			hurt = hurt * 2;
		end
		grid_data.army.blood = grid_data.army.blood - hurt;

		if grid_data.army.blood <= 0 then
			grid_data.army:setDied();
		end
		return true;
	end
	return false;
end


---------------------------------------------
---检测大格子是否可以走-------------------------
---每次AI会设置好允许走的大格子列表---------------
---------------------------------------------
function NSolider:checkTeamGridCanWalk(n_x,n_y)
	local nt_x,nt_y = MapDataProxy.changSoliderToTeamGrid(n_x,n_y);
	for i=1,#self.can_move_grid do
		if nt_x == self.can_move_grid[i].x and nt_y == self.can_move_grid[i].y then
			return true;
		end
	end
	return false;
end

---------------------------------------------
---获取行走方向的下一个格子----------------------
---如果前进方向不行则取前进方向的附近方向行走-------
---------------------------------------------
function NSolider:getNextGrid(p_x,p_y,dir)
	--先走之前方向的格子
	if self.prev_move_dir ~= 0 then
		local n_x,n_y = self:checkNextGrid(p_x,p_y,dir,self.prev_move_dir);
		if n_x ~= nil and n_y ~= nil then
			return n_x,n_y;
		end;
	end

	--逆时针一格
	local n_dir = dir - 1;
	if n_dir <= 0 then
		n_dir = 8 + n_dir;
	end

	if n_dir ~= self.prev_move_dir then
		n_x,n_y = self:checkNextGrid(p_x,p_y,dir,n_dir);
		if n_x ~= nil and n_y ~= nil then
			self.prev_move_dir = n_dir;
			return n_x,n_y;
		end;
	end

	--顺时针一格
	n_dir = dir + 1;
	if n_dir > 8 then
		n_dir = n_dir - 8;
	end
	if n_dir ~= self.prev_move_dir then
		n_x,n_y = self:checkNextGrid(p_x,p_y,dir,n_dir);
		if n_x ~= nil and n_y ~= nil then
			self.prev_move_dir = n_dir;
			return n_x,n_y;
		end;
	end

	--逆时针两格
	n_dir = dir - 2;
	if n_dir <= 0 then
		n_dir = 8 + n_dir;
	end
	if n_dir ~= self.prev_move_dir then
		n_x,n_y = self:checkNextGrid(p_x,p_y,dir,n_dir);
		if n_x ~= nil and n_y ~= nil then
			self.prev_move_dir = n_dir;
			return n_x,n_y;
		end;
	end

	--顺时针两格
	n_dir = dir + 2;
	if n_dir > 8 then
		n_dir = n_dir - 8;
	end
	if n_dir ~= self.prev_move_dir then
		n_x,n_y = self:checkNextGrid(p_x,p_y,dir,n_dir);
		if n_x ~= nil and n_y ~= nil then
			self.prev_move_dir = n_dir;
			return n_x,n_y;
		end;
	end

	return nil,nil;
end

---------------------------------------------
---检测下一个格子是否可以行走----------------------
---如果其他方向后面有自己人则不占用----------------
---------------------------------------------
function NSolider:checkNextGrid(p_x,p_y,dir,n_dir)
	local n_x = p_x + DIR_GRID[n_dir].x;
	local n_y = p_y + DIR_GRID[n_dir].y;

	if self:checkTeamGridCanWalk(n_x,n_y) then 
		local grid_data = MapDataProxy.getMapData(n_x,n_y);
		--是否可以走
		if grid_data ~= nil and grid_data.flag == 0 then
			--同时后续没有自己人，有的话优先对方走，即优先保证方向上可以行走的
			local prev_x = n_x - DIR_GRID[dir].x;
			local prev_y = n_y - DIR_GRID[dir].y;
			local prev_data = MapDataProxy.getMapData(prev_x,prev_y);
			if prev_data ~= nil and (prev_data.flag == 0 or (prev_data.flag == 1 and prev_data.army.camp ~= self.camp)) then
				return n_x,n_y;
			end
		end
	end;

	return nil,nil;
end

---------------------------------------------
---获取周围敌人最多的格子------------------------
---以自身为中心寻找整个格子的敌人，优先周围格子-----
---------------------------------------------
function NSolider:getRoundEnemyMaxTeamGrid()
	local m_grid = math.max(MapDataProxy.TEAM_MAX_X,MapDataProxy.TEAM_MAX_Y) - 1;
	for i=1,m_grid do
		local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
		local tmpCnt = 0;
		local pt_x = 0;
		local pt_y = 0;

		local four_list = {{x=0,y=-1},{x=-1,y=0},{x=1,y=0},{x=0,y=1}};
		for j=1,4 do
			local nt_y = t_y + i*four_list[j].y;
			local nt_x = t_x + i*four_list[j].x;
			if nt_y >= 0 and nt_y < MapDataProxy.TEAM_MAX_Y and nt_x >= 0 and nt_x < MapDataProxy.TEAM_MAX_X then
				local sum = MapDataProxy.getTeamSoliderCntByIdx(nt_x,nt_y,self.camp)
				if sum > tmpCnt then
					tmpCnt = sum; 
					pt_x = nt_x;
					pt_y = nt_y;
				end
			end
		end
		if tmpCnt ~= 0 then
			return {{x=pt_x,y=pt_y}};
		end

		four_list = {{x=1,y=-1},{x=-1,y=-1},{x=-1,y=1},{x=1,y=1}};
		for j=1,4 do
			local nt_y = t_y + i*four_list[j].y;
			local nt_x = t_x + i*four_list[j].x;
			if nt_y >= 0 and nt_y < MapDataProxy.TEAM_MAX_Y and nt_x >= 0 and nt_x < MapDataProxy.TEAM_MAX_X then
				local sum = MapDataProxy.getTeamSoliderCntByIdx(nt_x,nt_y,self.camp)
				if sum > tmpCnt then
					tmpCnt = sum; 
					pt_x = nt_x;
					pt_y = nt_y;
				end
			end
		end
		if tmpCnt ~= 0 then
			return {{x=pt_x,y=pt_y}};
		end
	end

	return nil;
end

---------------------------------------------
---获取周围敌人最多的格子------------------------
---只搜寻周围一圈四方向的格子---------------------
---------------------------------------------
function NSolider:getRoundOneEnemyMaxTeamGrid()
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
	local tmpCnt = 0;
	local pt_x = 0;
	local pt_y = 0;

	local four_list = {{x=0,y=-1},{x=-1,y=0},{x=1,y=0},{x=0,y=1}};
	for j=1,4 do
		local nt_y = t_y + four_list[j].y;
		local nt_x = t_x + four_list[j].x;
		if nt_y >= 0 and nt_y < MapDataProxy.TEAM_MAX_Y and nt_x >= 0 and nt_x < MapDataProxy.TEAM_MAX_X then
			local sum = MapDataProxy.getTeamSoliderCntByIdx(nt_x,nt_y,self.camp)
			if sum > tmpCnt then
				tmpCnt = sum; 
				pt_x = nt_x;
				pt_y = nt_y;
			end
		end
	end
	if tmpCnt ~= 0 then
		return {x=pt_x,y=pt_y};
	else
		return nil;
	end
end

---------------------------------------------
---获取周围敌人最少的格子------------------------
---只搜寻周围一圈四方向的格子---------------------
---------------------------------------------
function NSolider:getRoundOneEnemyMinTeamGrid()
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
	local tmpCnt = 99999;
	local pt_x = 0;
	local pt_y = 0;

	local four_list = {{x=0,y=-1},{x=-1,y=0},{x=1,y=0},{x=0,y=1}};
	for j=1,4 do
		local nt_y = t_y + four_list[j].y;
		local nt_x = t_x + four_list[j].x;
		if nt_y >= 0 and nt_y < MapDataProxy.TEAM_MAX_Y and nt_x >= 0 and nt_x < MapDataProxy.TEAM_MAX_X then
			local sum = MapDataProxy.getTeamSoliderCntByIdx(nt_x,nt_y,self.camp)
			if sum > 0 and sum < tmpCnt then
				tmpCnt = sum;
				pt_x = nt_x;
				pt_y = nt_y;
			end
		end
	end
	if tmpCnt > 0 and tmpCnt < 99999 then
		return {x=pt_x,y=pt_y};
	else
		return nil;
	end
end
