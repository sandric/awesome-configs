local setmetatable = setmetatable
local ipairs       = ipairs
local pairs        = pairs
local print        = print
local table        = table
local button       = require( "awful.button"      )
local beautiful    = require( "beautiful"         )
local tag          = require( "awful.tag"         )
local util         = require( "awful.util"        )
local common       = require( "ultiLayout.common" )
local vertex2      = require( "ultiLayout.vertex"      )

local capi = { image  = image  ,
               widget = widget }

module("ultiLayout.linear")


local function cg_to_idx(list,cg)
    for k,v in ipairs(list) do
        if v == cg then
            return k
        end
    end
    return nil
end

local function new(cg,orientation) 
   local data     = {}
   data.ratio     = {}
   local nb       = 0
   local vertex   = {}
   
   local function sum_ratio()
        local sumratio = 0
        for k,v in ipairs(cg:childs()) do
            sumratio = sumratio + (data.ratio[k] or 1)
        end
        return sumratio
   end
   
   local function get_average()
       if #cg:childs() == 0 then return 1 end
       return (sum_ratio() / #cg:childs()) or 1
   end
   
   local function ratio_to_percent(ratio)
       return ratio / sum_ratio()
   end
   
   local function get_cg_idx(child)
       for k,v in ipairs(cg:childs()) do
           if v == child then
               return k
           end
       end
       return nil
   end
   
   function data:show_splitters(show,horizontal,vertical)
--        if horizontal then
--            --ultiLayout.common.add_splitter_box()
--        end
--        if vertical then
--             
--        end
       for k,v in ipairs(cg:childs()) do
           v:show_splitters(show,horizontal,vertical)
       end
   end
   
    function data:gen_vertex(vertex_list)
        local prev = nil
        local nb2   = 0
        for k,v in ipairs(cg:childs()) do
            if prev and nb2 ~= nb then
                if not vertex[prev] or not vertex[prev][v] then
                    local aVertex = vertex2({x=cg.x,y=v.y,orientation="horizontal",length=cg.width})
                    aVertex:add_signal("distance::changed",function(_v, delta)
                        if _v.cg1.parent == cg and _v.cg2.parent == cg then
                            local cg1_ratio_k, cg2_ratio_k = get_cg_idx(_v.cg1),get_cg_idx(_v.cg2)
                            local diff = (sum_ratio()/cg[(orientation == "horizontal") and "height" or "width"])*delta
                            data.ratio[cg1_ratio_k] = data.ratio[cg1_ratio_k] + diff
                            data.ratio[cg2_ratio_k] = data.ratio[cg2_ratio_k] - diff
                            self:update()
                        end
                    end)
                    aVertex.cg1     = prev
                    aVertex.cg2     = v
                    vertex[prev]    = vertex[prev] or {}
                    vertex[prev][v] = aVertex
                    aVertex:add_signal("distance::changed",function(delta)
                        
                    end)
                end
                local aVertex = vertex[prev][v]
                aVertex.length = cg.width
                if orientation == "horizontal" then
                    aVertex.x = cg.x
                    aVertex.y = v.y
                else
                    aVertex.x = v.x
                    aVertex.y = cg.y
                end
                table.insert(vertex_list,vertex[prev][v])
            end
            v:gen_vertex(vertex_list)
            prev = v
            nb2 = nb2+1
        end
        return vertex_list
    end
   
   function data:update()
       local relX   = cg.x
       local relY   = cg.y
       for k,v in ipairs(cg:childs()) do
            if orientation == "horizontal" then
                v:geometry({width  = cg.width                ,
                            height = cg.height*ratio_to_percent(data.ratio[k]) ,
                            x      = relX                    ,
                            y      = relY                   })
            else
                v:geometry({width  = cg.width*ratio_to_percent(data.ratio[k])  ,
                            height = cg.height ,
                            x      = relX                    ,
                            y      = relY                   })
            end
            v:repaint()
            if orientation == "horizontal" then
                relY     = relY + (cg.height*ratio_to_percent(data.ratio[k]))
            else
                relX     = relX + (cg.width*ratio_to_percent(data.ratio[k]))
            end
       end
       for k,v in pairs(vertex) do
           for k2,v2 in pairs(v) do
               --v2.x = relX
               --v2.y = relY
               if orientation == "horizontal" then
                   print("here4444")
                   --v2:raw_set({x=relX,y=relY,length=k2.width}) --TODO
                    --v2.length = k2.width
               else
                   --v2:raw_set({x=relX,y=relY,length=k2.height}) --TODO
                   --v2.length = k2.height
               end
           end
       end
   end
   
       
    local function swap(_cg,other_cg,old_parent)
        if _cg.parent ~= cg then
            _cg:remove_signal("cg::swapped",swap)
            other_cg:add_signal("cg::swapped",swap)
        elseif _cg.parent == cg and other_cg.parent == cg then
            local cg_idx, other_cg_idx = cg_to_idx(cg:childs(),_cg),cg_to_idx(cg:childs(),other_cg)
            local buf = data.ratio[cg_idx]
            data.ratio[cg_idx] = data.ratio[other_cg_idx]
            data.ratio[other_cg_idx] = buf
        end
    end
    
   function data:add_child(child_cg)
        nb = nb + 1
        local percent = 1 / nb
        data.ratio[#cg:childs()+1] = child_cg.default_percent and (child_cg.default_percent*sum_ratio()) or get_average()
        child_cg:add_signal("cg::swapped",swap)
   end
   
   --function data:ajust_child_ratio_by_pixel()
   
   return data
end

common.add_new_layout("horizontal",function(cg) return new(cg,"horizontal") end)
common.add_new_layout("vertical",function(cg) return new(cg,"vertical") end)

setmetatable(_M, { __call = function(_, ...) return new(...) end })