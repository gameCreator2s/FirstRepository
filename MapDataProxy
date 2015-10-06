MapDataProxy = {};

MapDataProxy.mapdata = {};
MapDataProxy.all_army = {};

MapDataProxy.ARMY_GRID_WIDTH = 20;--实际坐标的间隔，防止重叠，可以看做是实际的一个小格子的边长
MapDataProxy.TEAM_GRID_WIDTH = 180;

MapDataProxy.TEAM_MAX_X = 5;--X方向上大格子的数码
MapDataProxy.TEAM_MAX_Y = 7;--Y方向上大格子的数码

--大格子各个阵营人数，用于AI判断攻击哪个区域
MapDataProxy.TEAM_ARMY_CNT_LIST = {};
--大格子各个阵营列表，用于每帧数据重复利用，临时用，每帧清零
MapDataProxy.TEAM_TEMP_DATA = {};

function MapDataProxy.initMapData()
	for i=0,47 do
		for j=0,65 do
			local idx = j * 100 + i;
			MapDataProxy.mapdata[idx] = {flag=0,army=nil};
		end
	end

	for i=1,MapDataProxy.TEAM_MAX_X do
		MapDataProxy.TEAM_ARMY_CNT_LIST[i] = {};
		MapDataProxy.TEAM_TEMP_DATA[i] = {}
		for j=1,MapDataProxy.TEAM_MAX_Y do
			MapDataProxy.TEAM_ARMY_CNT_LIST[i][j] = {0,0};--阵营1和阵营2的人数
			MapDataProxy.TEAM_TEMP_DATA[i][j] = {{},{}};--阵营1和阵营2的列表
		end
	end
end

function MapDataProxy.getMapData(x,y)
	local idx = y * 100 + x;
	return MapDataProxy.mapdata[idx];
end

function MapDataProxy.setMapData(x,y,army,flag)--flag:1：有物体 0:无物体
	local idx = y * 100 + x;
	local grid_data = MapDataProxy.mapdata[idx];
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(x,y);
	if grid_data ~= nil and grid_data.flag == 1 then
		local cnt = MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][grid_data.army.camp];
		if cnt > 0 then
			MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][grid_data.army.camp] = cnt - 1;
		end
	end

	MapDataProxy.mapdata[idx] = {flag=flag,army=army};

	if army ~= nil and flag > 0 then
		local cnt = MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][army.camp];
		MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][army.camp] = cnt + 1;
	end
end

function MapDataProxy.changSoliderToTeamGrid(n_x,n_y)
	local s_x = n_x * MapDataProxy.ARMY_GRID_WIDTH + MapDataProxy.ARMY_GRID_WIDTH/2;
	local s_y = n_y * MapDataProxy.ARMY_GRID_WIDTH + MapDataProxy.ARMY_GRID_WIDTH/2;

	local t_x = math.floor(s_x / MapDataProxy.TEAM_GRID_WIDTH);
	local t_y = math.floor(s_y / MapDataProxy.TEAM_GRID_WIDTH);

	return t_x,t_y;
end

function MapDataProxy.getTeamSoliderCnt(x,y,camp)
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(x,y);
	if camp == 1 then
		return MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][2];
	else
		return MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][1];
	end
end

function MapDataProxy.getTeamSoliderCntByIdx(team_x,team_y,camp)
	if camp == 1 then
		return MapDataProxy.TEAM_ARMY_CNT_LIST[team_x+1][team_y+1][2];
	else
		return MapDataProxy.TEAM_ARMY_CNT_LIST[team_x+1][team_y+1][1];
	end
end

--取到所处的大格子里所有小格子数据
function MapDataProxy.getTeamGridRang(x,y)
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(x,y);

	local s_x = t_x * MapDataProxy.TEAM_GRID_WIDTH + MapDataProxy.ARMY_GRID_WIDTH/2;
	local s_y = t_y * MapDataProxy.TEAM_GRID_WIDTH + MapDataProxy.ARMY_GRID_WIDTH/2;

	local s_gx = math.floor(s_x / MapDataProxy.ARMY_GRID_WIDTH);
	local s_gy = math.floor(s_y / MapDataProxy.ARMY_GRID_WIDTH);

	local e_x = s_x + MapDataProxy.TEAM_GRID_WIDTH - MapDataProxy.ARMY_GRID_WIDTH/2;
	local e_y = s_y + MapDataProxy.TEAM_GRID_WIDTH - MapDataProxy.ARMY_GRID_WIDTH/2;

	local e_gx = math.floor(e_x / MapDataProxy.ARMY_GRID_WIDTH);
	local e_gy = math.floor(e_y / MapDataProxy.ARMY_GRID_WIDTH);

	return {x=s_gx,y=s_gy},{x=e_gx,y=e_gy};
end

function MapDataProxy.clearTeamTempData()
	for i=1,MapDataProxy.TEAM_MAX_X do
		for j=1,MapDataProxy.TEAM_MAX_Y do
			MapDataProxy.TEAM_TEMP_DATA[i][j] = {{},{}};
		end
	end
end

--获取大格子内对象列表，每帧清空，用于当前格子相同士兵读取，防止重复循环
function MapDataProxy.getTeamTempData(x,y,camp)
	local t_x,t_y = MapDataProxy.changSoliderToTeamGrid(x,y);
	local t_camp = 0;
	if camp == 1 then 
		t_camp = 2;
	else
		t_camp = 1;
	end;

	local list = MapDataProxy.TEAM_TEMP_DATA[t_x+1][t_y+1][t_camp];
	if #list == 0 and MapDataProxy.TEAM_ARMY_CNT_LIST[t_x+1][t_y+1][t_camp] ~= 0 then
		local t_list = {};
		local s_g,e_g = MapDataProxy.getTeamGridRang(x,y);
		for i=s_g.x,e_g.x do
			for j=s_g.y,e_g.y do
				local idx = j * 100 + i;
				local grid_data = MapDataProxy.mapdata[idx];	
				if grid_data ~= nil and grid_data.flag == 1 and grid_data.army.camp == t_camp then
					table.insert(t_list,grid_data.army);
				end
			end
		end
		MapDataProxy.TEAM_TEMP_DATA[t_x+1][t_y+1][t_camp] = t_list;
		return t_list;
	else
		return list;
	end
end
