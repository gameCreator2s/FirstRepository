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
	IDLE = 0,
	WALK = 1,
	ATTACK = 2,
	WAIT_MOVE = 3,
	WAIT_TO_NEXT_TEAM = 4,
	WAIT_LOOK_ENEMY = 5
}

Solider = class("Solider",function(camp,soliderType)
	local res = "blue_1.png";
	if camp == 2 then 
		res = "red_1.png";
	end

	local sp = cc.Sprite:create(res);
	return sp;
end)

function Solider:ctor(camp,soliderType)
	self.camp = camp;

	self.grid_x = -1;
	self.grid_y = -1;

	self.status = SOLIDER_SATUS.IDLE;

	self.solider_type = soliderType;

	if self.solider_type == 4 then
		self.attack_dist = 3;
	elseif self.solider_type == 2 then
		self.attack_dist = 2;
	else
		self.attack_dist = 1;
	end

	if self.solider_type == 3 then
		self.move_speed = 200;
	else
		self.move_speed = 100;
	end;

	self.attack_interval = 1;
	self.prev_move_dir = 0;
end

function Solider:init(gridx,gridy)
	self.grid_x = gridx;
	self.grid_y = gridy;

	self.blood = 100;
	self.update_func = self.onIdle;
end

function Solider:update(dt)
	if self.update_func ~= nil then
		self.update_func(self,dt);
	end
end

function Solider:idle()
	self.status = SOLIDER_SATUS.IDLE;
	self.update_func = self.onIdle;
end

function Solider:onIdle()
	--周围是否有攻击对象
	if self:checkRound() then
		self:attackOnIdle();
	end
end

function Solider:checkRound()
	math.randomseed(os.time())
	local hurt = 20 + math.random()*20;
	for i=1,self.attack_dist do
		for j=1,#DIR_GRID do
			local n_x = self.grid_x + i*DIR_GRID[j].x;
			local n_y = self.grid_y + i*DIR_GRID[j].y;

			if self:checkAttack(n_x,n_y) then
				return true;
			end
		end
	end

	return false;
end

function Solider:checkAttack(n_x,n_y)
	local grid_data = MapDataProxy.getMapData(n_x,n_y);
	return self:checkAttackByGridData(grid_data);
end

function Solider:checkAttackByGridData(grid_data)
	local hurt = 50;
	if grid_data ~= nil and grid_data.flag == 1 and grid_data.army.camp ~= self.camp then
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

function Solider:attackOnIdle()
	--
	local scale_action_1 = cc.ScaleTo:create(0.25,1.5);
	local scale_action_2 = cc.ScaleTo:create(0.25,1);

	self.attackAction = cc.Sequence:create(scale_action_1,scale_action_2);
	self.attackAction:retain();
    self.attackAction:startWithTarget(self);
    self.attackAction:step(0);
    self.attackTime = 0;
    self.status = SOLIDER_SATUS.ATTACK;

    self.update_func = self.onAttackOnIdle;
end

function Solider:onAttackOnIdle(dt)
	self.attackAction:step(dt);
	self.attackTime = self.attackTime + dt;
	if self.attackTime >= self.attack_interval then
		self.attackAction:release();
        self.attackAction = nil;
		self:idle();
	end
end

--根据手指经过的格子进行四方向移动,这里已经是去掉了重复和多余的格子，并且判断不是单方向的手势
function Solider:moveByTeamGrid(teamGridList)
	self.move_mode = 2;
	self.move_list = {};
	self.move_index = 1;

	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

	--还没开始进入手势格子的时候，先找出离得最近的列表中的格子
	local min_dist = 9999;
	local idx = 1;
	for i=#teamGridList,1,-1 do
		local d_x = math.abs(teamGridList[i].x - t_x);
		local d_y = math.abs(teamGridList[i].y - t_y);

		if (d_x + d_y) <=1 then --就在格子附近
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

		for i=1,d_x do --先往Y方向行走
			if st_x > t_x then
				table.insert(self.move_list,{x=t_x+i,y=last_y});
			else 
				table.insert(self.move_list,{x=t_x-i,y=last_y});
			end
		end
	end

	for i=idx,#teamGridList do
		local len = #self.move_list;
		if len == 0 or teamGridList[i].x ~= self.move_list[len].x or teamGridList[i].y ~= self.move_list[len].y then
			table.insert(self.move_list,{x=teamGridList[i].x,y=teamGridList[i].y});
		end
	end

	if self.move_list[1].x ~= t_x or self.move_list[1].y ~= t_y then
		table.insert(self.move_list,1,{x=t_x,y=t_y});
	end
	
	self:moveToNextTeamGrid();
end

function Solider:getGridDir(p_x,p_y,n_x,n_y)
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

function Solider:moveToNextTeamGrid()
	--如果已经是最后一个格子，则执行攻击
	if self.move_index == #self.move_list then
		if self.move_index == 1 then 
			local curr_grid = self.move_list[self.move_index];
			self.move_dir = 0;--已经在格子则随机行走
			self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y}};
			self.end_grid = {x=curr_grid.x,y=curr_grid.y};
		else
			--前进攻击
			local curr_grid = self.move_list[self.move_index];
			local prev_grid = self.move_list[self.move_index-1];
			local dir = self:getGridDir(prev_grid.x,prev_grid.y,curr_grid.x,curr_grid.y);
			if dir ~= 0 then
				self.move_dir = dir;
			end;
			self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y}};
			self.end_grid = {x=curr_grid.x,y=curr_grid.y};
		end
		self:attackRandom();--主动寻找这个格子内的敌人攻击
	else
		local curr_grid = self.move_list[self.move_index];
		local next_grid = self.move_list[self.move_index+1];
		if curr_grid.x == next_grid.x and curr_grid.y == next_grid.y then--如果格子重复
			self.move_index = self.move_index + 1;
			self:waitToNextTeamGrid();
		else
			if self.move_index == 1 then --初始就下一格子的方向决定行走方向
				self.move_dir = self:getGridDir(curr_grid.x,curr_grid.y,next_grid.x,next_grid.y);
				self.end_grid = {x=next_grid.x,y=next_grid.y}
				self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y},{x=next_grid.x,y=next_grid.y}};
			else --根据下一格和前一格的方向决定行走方向
				local prev_grid = self.move_list[self.move_index-1];

				self.move_dir = self:getGridDir(prev_grid.x,prev_grid.y,next_grid.x,next_grid.y);
				self.end_grid = {x=next_grid.x,y=next_grid.y}
				self.can_move_grid = {{x=curr_grid.x,y=curr_grid.y},{x=next_grid.x,y=next_grid.y}};
			end
			self.move_index = self.move_index + 1;
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		end
	end
end

--四方向行走，如果滑屏只是滑一个方向，则执行一个方向的行走
function Solider:moveByDir(dir)
	--
	self.move_mode = 1;
	self.move_dir = dir;

	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
	if dir == FACE_DIR.UP then
		local e_x = t_x;
		local e_y = t_y + 1;
		if e_y < MapDataProxy.TEAM_MAX_Y then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.DOWN then
		local e_x = t_x;
		local e_y = t_y - 1;
		if e_y >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.LEFT then
		local e_x = t_x - 1;
		local e_y = t_y;
		if e_x >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.RIGHT then
		local e_x = t_x + 1;
		local e_y = t_y;
		if e_x < MapDataProxy.TEAM_MAX_X then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			--能够行走的格子
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.RIGHT_UP then
		local e_x = t_x + 1;
		local e_y = t_y + 1;
		if e_x < MapDataProxy.TEAM_MAX_X and e_y < MapDataProxy.TEAM_MAX_Y then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x+1,y=t_y},{x=t_x,y=t_y+1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.RIGHT_DOWN then
		local e_x = t_x + 1;
		local e_y = t_y - 1;
		if e_x < MapDataProxy.TEAM_MAX_X and e_y >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x+1,y=t_y},{x=t_x,y=t_y-1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.LEFT_UP then
		local e_x = t_x - 1;
		local e_y = t_y + 1;
		if e_x >= 0 and e_y < MapDataProxy.TEAM_MAX_Y then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x-1,y=t_y},{x=t_x,y=t_y+1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	elseif dir == FACE_DIR.LEFT_DOWN then
		local e_x = t_x - 1;
		local e_y = t_y - 1;
		if e_x >= 0 and e_y >= 0 then
			--终点格子
			self.end_grid = {x=e_x,y=e_y};
			self.can_move_grid = {{x=t_x,y=t_y},{x=e_x,y=e_y},{x=t_x-1,y=t_y},{x=t_x,y=t_y-1}};
			self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
			self:startMove();
		else --以到达最后格子
			self:attackRandom();--主动寻找这个格子内的敌人攻击
		end
	end
end

function Solider:startMove()
	self.status = SOLIDER_SATUS.WALK;
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);

	if t_x == self.end_grid.x and t_y == self.end_grid.y then--检查是否在终点格子
		if self.move_mode == 1 then --如果在终点格子则更新移动方向的下个格子
			self:moveByDir(self.move_dir);
		elseif self.move_mode == 2 then
			self:moveToNextTeamGrid();
		end
	else
		--先看前进方向能不能走
		local n_x = self.grid_x + DIR_GRID[self.move_dir].x;
		local n_y = self.grid_y + DIR_GRID[self.move_dir].y;
		if self:checkAttack(n_x,n_y) then --先看前进方向有没攻击对象
			self:attackOnMove();
			return;
		else
			--前进方向的格子
			if self:checkTeamGridCanWalk(n_x,n_y) then
				local grid_data = MapDataProxy.getMapData(n_x,n_y);
				--是否可以走
				if grid_data ~= nil and grid_data.flag == 0 then
					self:walkTo(n_x,n_y);
					return;
				end
			end
			
			if self:checkRound() then --周围有攻击就攻击
				self:attackOnMove();
				return;
			else
				--根据最近的对方周围空的格子来决定行走方向，格子不能超出所处大格子的范围
				local n_x,n_y = self:getNextGrid(self.grid_x,self.grid_y,self.move_dir);
				if n_x ~= nil and n_y ~= nil then
					self:walkTo(n_x,n_y);
					return;
				end	
			end

			self:waitMove();
		end
	end
end

function Solider:waitToNextTeamGrid()
	self.status = SOLIDER_SATUS.WAIT_TO_NEXT_TEAM;
	self.update_func = self.onWaitNextTeamGrid;
end

function Solider:onWaitNextTeamGrid()
	self.update_func = nil;
	self:moveToNextTeamGrid();
end

function Solider:waitMove()
	self.status = SOLIDER_SATUS.WAIT_MOVE;
	self.update_func = self.onWaitMove;
end

function Solider:onWaitMove()
	self.update_func = nil;
	self.prev_move_dir = 0;--上一次移动的格子方向，下次保持这个方向，以防止假死
	if self.move_mode == 1 or self.move_mode == 2 then
		self:startMove();
	elseif self.move_mode == 3 then
		self:attackRandom();
	elseif self.move_mode == 4 then
		self:lookEnemyAttack();
	end
end

function Solider:checkTeamGridCanWalk(n_x,n_y)
	local nt_x,nt_y = MapDataProxy.changSoliderToTeamGrid(n_x,n_y);
	for i=1,#self.can_move_grid do
		if nt_x == self.can_move_grid[i].x and nt_y == self.can_move_grid[i].y then
			return true;
		end
	end
	return false;
end

function Solider:getNextGrid(p_x,p_y,dir)
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

function Solider:checkNextGrid(p_x,p_y,dir,n_dir)
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

function Solider:walkTo(n_x,n_y)
	-- body
	MapDataProxy.setMapData(self.grid_x,self.grid_y,nil,0);
	MapDataProxy.setMapData(n_x,n_y,self,1);
	self.grid_x = n_x;
	self.grid_y = n_y;

	self.walkAction = cc.MoveTo:create(20/self.move_speed,cc.p(n_x*20+10,n_y*20+10));
	self.walkAction:retain();
    self.walkAction:startWithTarget(self)
    self.walkAction:step(0);
    self.walkTime = 0;
    self.status = SOLIDER_SATUS.WALK;

    self.update_func = self.onWalk;
end

function Solider:onWalk(dt)
	self.walkAction:step(dt);
	self.walkTime = self.walkTime + dt;
	if self.walkTime >= (20/self.move_speed) then
		self.walkAction:release();
        self.walkAction = nil;
        self.update_func = nil;
        if self.move_mode == 1 or self.move_mode == 2 then
			self:startMove();
		elseif self.move_mode == 3 then
			self:attackRandom();
		elseif self.move_mode == 4 then
			self:lookEnemyAttack();
		end
	end
end

function Solider:attackOnMove()
	--
	local scale_action_1 = cc.ScaleTo:create(0.25,1.5);
	local scale_action_2 = cc.ScaleTo:create(0.25,1);

	self.attackAction = cc.Sequence:create(scale_action_1,scale_action_2);
	self.attackAction:retain();
    self.attackAction:startWithTarget(self);
    self.attackAction:step(0);
    self.attackTime = 0;
    self.status = SOLIDER_SATUS.ATTACK;

    self.update_func = self.onAttackOnMove;
end

function Solider:onAttackOnMove(dt)
	self.attackAction:step(dt);
	self.attackTime = self.attackTime + dt;
	if self.attackTime >= self.attack_interval then
		self.attackAction:release();
        self.attackAction = nil;
        self.update_func = nil;
		if self.move_mode == 1 or self.move_mode == 2 then
			self:startMove();
		elseif self.move_mode == 3 then
			self:attackRandom();
		elseif self.move_mode == 4 then
			self:lookEnemyAttack();
		end
	end
end

--攻击自己所在格子的敌人
function Solider:attackRandom()
	self.move_mode = 3;
	if self.move_dir == 0 then --随机攻击
		self:lookEnemyAttack();--寻找格子内的敌人攻击
	else
		--移动方向后面是否有自己人，有则前进，给后面让位
		local prev_x = self.grid_x - DIR_GRID[self.move_dir].x;
		local prev_y = self.grid_y - DIR_GRID[self.move_dir].y;
		--如果后面是敌人则先消灭敌人给后面前进提供协助
		if self:checkAttack(prev_x,prev_y) then
			self:attackOnMove();
		else --否则前进
			--在自己格子内行走攻击
			local n_x = self.grid_x + DIR_GRID[self.move_dir].x;
			local n_y = self.grid_y + DIR_GRID[self.move_dir].y;
			if self:checkAttack(n_x,n_y) then --先看前进方向有没攻击对象
				self:attackOnMove();
			else
				--如果行走方向的前方没有敌人了，则执行寻找攻击
				local list = MapDataProxy.getTeamTempData(self.grid_x,self.grid_y,self.camp);
				if #list > 0 then
					if self.move_dir == FACE_DIR.UP then
						local exist = false;
						for i=1,#list do
							if list[i].grid_y >= self.grid_y then
								exist = true;
								break;
							end
						end
						if not exist then
							self:lookEnemyAttack();
							return;
						end
					elseif self.move_dir == FACE_DIR.DOWN then
						local exist = false;
						for i=1,#list do
							if list[i].grid_y <= self.grid_y then
								exist = true;
								break;
							end
						end
						if not exist then
							self:lookEnemyAttack();
							return;
						end
					elseif self.move_dir == FACE_DIR.RIGHT then
						local exist = false;
						for i=1,#list do
							if list[i].grid_x >= self.grid_x then
								exist = true;
								break;
							end
						end
						if not exist then
							self:lookEnemyAttack();
							return;
						end
					elseif self.move_dir == FACE_DIR.LEFT then
						local exist = false;
						for i=1,#list do
							if list[i].grid_x <= self.grid_x then
								exist = true;
								break;
							end
						end
						if not exist then
							self:lookEnemyAttack();
							return;
						end
					end
				else 
					self:lookEnemyAttack();
					return ;
				end

				local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(n_x,n_y);
				if t_x == self.end_grid.x and t_y == self.end_grid.y then --下个格子还在自身大格子内则继续行走
					local grid_data = MapDataProxy.getMapData(n_x,n_y);
					--是否可以走
					if grid_data ~= nil and grid_data.flag == 0 then
						self:walkTo(n_x,n_y);
						return;
					end
					--方向不可走则找周围方向
					local n_x,n_y = self:getNextGrid(self.grid_x,self.grid_y,self.move_dir);
					if n_x ~= nil and n_y ~= nil then
						self:walkTo(n_x,n_y);
					else --不可行走则攻击周围
						if self:checkRound() then --周围有攻击就攻击
							self:attackOnMove();
						else
							self:waitMove();
						end
					end
				else
					self:lookEnemyAttack();--寻找格子内的敌人攻击
				end
			end
		end
	end
end

function Solider:lookEnemyAttack()
	if self:checkRound() then --周围有攻击就攻击
		self:attackOnLookEnemy();
	else
		--取到当前格子敌人数量
		local cnt = MapDataProxy.getTeamSoliderCnt(self.grid_x,self.grid_y,self.camp);

		if cnt == 0 then--找附近最多敌人的格子
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
					self:moveByTeamGrid({{x=pt_x,y=pt_y}});
					return;
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
					self:moveByTeamGrid({{x=pt_x,y=pt_y}});
					return;
				end
			end
			self:waitToLookEnemy();
		else--随机搜寻敌人去攻击
			local list = MapDataProxy.getTeamTempData(self.grid_x,self.grid_y,self.camp);
			local dist = 99999;
			local dir = 0;
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
					dist = temp_dist;
					dir = self:getGridDir(self.grid_x,self.grid_y,list[i].grid_x,list[i].grid_y);
				end
			end

			if dir ~= 0 then
				self.prev_move_dir = 0;
				local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(self.grid_x,self.grid_y);
				self.can_move_grid = {{x=t_x,y=t_y}};
				local n_x,n_y = self:getNextGrid(self.grid_x,self.grid_y,dir);
				if n_x ~= nil and n_y ~= nil then
					self.move_mode = 4;
					self:walkTo(n_x,n_y);
					return;
				end
			end

			self:waitToLookEnemy();
		end
	end
end

function Solider:waitToLookEnemy()
	self.status = SOLIDER_SATUS.WAIT_LOOK_ENEMY;
	self.update_func = self.onWaitLookEnemy;
end

function Solider:onWaitLookEnemy()
	self.update_func = nil;
	self:lookEnemyAttack();
end

function Solider:attackOnLookEnemy()
	--
	local scale_action_1 = cc.ScaleTo:create(0.25,1.5);
	local scale_action_2 = cc.ScaleTo:create(0.25,1);

	self.attackAction = cc.Sequence:create(scale_action_1,scale_action_2);
	self.attackAction:retain();
    self.attackAction:startWithTarget(self);
    self.attackAction:step(0);
    self.attackTime = 0;
    self.status = SOLIDER_SATUS.ATTACK;

    self.update_func = self.onAttackOnLookEnemy;
end

function Solider:onAttackOnLookEnemy(dt)
	self.attackAction:step(dt);
	self.attackTime = self.attackTime + dt;
	if self.attackTime >= self.attack_interval then
		self.attackAction:release();
        self.attackAction = nil;
        self.update_func = nil;
		self:lookEnemyAttack();
	end
end

function Solider:setDied()
	if self.blood <= 0 then
		MapDataProxy.setMapData(self.grid_x,self.grid_y,nil,0);
		self.update_func = nil;
		self.status = -1;
	end
end
