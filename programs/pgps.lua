local function is_number(v)
  if v == nil then return false end
  if v ~= v then return false end
  return type(v) == "number"
end

local function is_valid_sample(sample)
  return sample ~= nil and is_number(sample.x) and is_number(sample.y) and is_number(sample.z)
end

-- I don't know how this works i just copied it
local function triliterate(A, B, C)
  local a2b = {x = B.x - A.x, y = B.y - A.y, z = B.z - A.z}
  local a2c = {x = C.x - A.x, y = C.y - A.y, z = C.z - A.z}
  
  a2b.l = math.sqrt(a2b.x*a2b.x + a2b.y*a2b.y + a2b.z*a2b.z)
  a2b.nx = a2b.x / a2b.l
  a2b.ny = a2b.y / a2b.l
  a2b.nz = a2b.z / a2b.l
  
  a2c.l = math.sqrt(a2c.x*a2c.x + a2c.y*a2c.y + a2c.z*a2c.z)
  a2c.nx = a2c.x / a2c.l
  a2c.ny = a2c.y / a2c.l
  a2c.nz = a2c.z / a2c.l
  
  if math.abs(a2b.nx * a2c.nx + a2b.ny * a2c.ny + a2b.nz * a2c.nz) > 0.999 then
    return nil
  end
  
  local ex = {x = a2b.nx, y = a2b.ny, z = a2b.nz}
  local i = ex.x * a2c.x + ex.y * a2c.y + ex.z * a2c.z
  local ey = {x = a2c.x - ex.x * i, y = a2c.y - ex.y * i, z = a2c.z - ex.z * i}
  ey.l = math.sqrt(ey.x*ey.x + ey.y*ey.y + ey.z*ey.z)
  ey.x = ey.x / ey.l
  ey.y = ey.y / ey.l
  ey.z = ey.z / ey.l
  local j = ey.x*a2c.x + ey.y*a2c.y + ey.z*a2c.z
  local ez = {x = ex.y*ey.z - ex.z*ey.y, y = ex.z*ey.x - ex.x*ey.z, z = ex.x*ey.y - ex.y*ey.x}
  
  ex.l = math.sqrt(ex.x*ex.x + ex.y*ex.y + ex.z*ex.z)
  ey.l = math.sqrt(ey.x*ey.x + ey.y*ey.y + ey.z*ey.z)
  ez.l = math.sqrt(ez.x*ez.x + ez.y*ez.y + ez.z*ez.z)
  if ez.l > 1.001 or ez.l < 0.999 then
    print("vectors are fucked:")
    print(("  ex %.2f %.2f %.2f l %.2f"):format(ex.x, ex.y, ex.z, ex.l))
    print(("  ey %.2f %.2f %.2f l %.2f"):format(ey.x, ey.y, ey.z, ey.l))
    print(("  ez %.2f %.2f %.2f l %.2f"):format(ez.x, ez.y, ez.z, ez.l))
  end
  
  local x = (A.d*A.d - B.d*B.d + a2b.l*a2b.l) / (2*a2b.l)
  local y = (A.d*A.d - C.d*C.d - x*x + (x-i)*(x-i) + j*j) / (2*j)
  
  local result = {x = A.x + ex.x*x + ey.x*y, y = A.y + ex.y*x + ey.y*y, z = A.z + ex.z*x + ey.z*y}
  local zsqr = A.d*A.d - x*x - y*y
  if zsqr > 0 then
    local z = math.sqrt(zsqr)
    local result1 = {x = result.x + ez.x*z, y = result.y + ez.y*z, z = result.z + ez.z*z}
    local result2 = {x = result.x - ez.x*z, y = result.y - ez.y*z, z = result.z - ez.z*z}
    
    if result1.x ~= result2.x or result1.y ~= result2.y or result1.z ~= result2.z then
      return result1, result2
    else
      return result
    end
  end
  return result
end

local function narrow_position(pos1, pos2, fix)
  local d1x = pos1.x - fix.x
  local d1y = pos1.y - fix.y
  local d1z = pos1.z - fix.z
  local d1 = math.sqrt(d1x*d1x + d1y*d1y + d1z*d1z)
  
  local d2x = pos2.x - fix.x
  local d2y = pos2.y - fix.y
  local d2z = pos2.z - fix.z
  local d2 = math.sqrt(d2x*d2x + d2y*d2y + d2z*d2z)
  
  local e1 = math.abs(d1 - fix.d)
  local e2 = math.abs(d2 - fix.d)
  if math.abs(e1 - e2) < 0.01 then
    return nil
  elseif e1 < e2 then
    return pos1, e1
  elseif e1 > e2 then
    return pos2, e2
  else
    return nil
  end  
end

local function fix(_timeout, _debug)
  if type(_timeout) ~= "number" then
    error("timeout must be a number")
  end
  if _debug ~= nil and type(_debug) ~= "boolean" then
    error("debug must be a boolean or nil")
  end
  
  local modem_side = nil
  
  for n, side in pairs(redstone.getSides()) do
    if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
      modem_side = side
    end
  end
  
  if modem_side == nil then
    error("No wireless modem attached")
    return 0
  end
  
  local modem = peripheral.wrap(modem_side)
  
  if _debug then
    print("gathering fixes...")    
  end
  
  local close_modem_when_done = false
  if not modem.isOpen(os.getComputerID()) then
    close_modem_when_done = true
    modem.open(os.getComputerID())
  end
  
  modem.transmit(gps.CHANNEL_GPS, os.getComputerID(), "PING")
  
  local fix_count = 0
  local timeout = os.startTimer(_timeout or 2)
  
  while true do
    local e, p1, p2, p3, p4, p5 = os.pullEvent()
    
    if e == "modem_message" then
      local side, channel, reply_channel, message, distance = p1, p2, p3, p4, p5
      if side == modem_side and channel == os.getComputerID() and reply_channel == gps.CHANNEL_GPS and distance then
        fix_count = fix_count + 1
        if _debug then
          print(("Located fix %.2f %.2f %.2f"):format(message[1], message[2], message[3]))
        end
      end
    elseif e == "timer" then
      local timer = p1
      if timer == timeout then
        break
      end
    end
  end
    
  if close_modem_when_done then
    modem.close(os.getComputerID())
  end
  
  if _debug then
    print(("Located %d fixes"):format(fix_count))
  end
  
  return fix_count
end

local function locate(_fix_count, _timeout, _debug)
  if _fix_count ~= nil and type(_fix_count) ~= "number" then
    error("fix_count must be a number")
  elseif _fix_count < 4 then
    error("need at least 4 fixes")
  end
  if _timeout ~= nil and type(_timeout) ~= "number" then
    error("timeout must be a number or nil")
  end
  if _debug ~= nil and type(_debug) ~= "boolean" then
    error("debug must be a boolean or nil")
  end
  
  local modem_side = nil
  
  for n, side in pairs(redstone.getSides()) do
    if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
      modem_side = side
    end
  end
  
  if modem_side == nil then
    error("No wireless modem attached")
    return
  end
  
  local modem = peripheral.wrap(modem_side)
  
  local close_modem_when_done = false
  
  if not modem.isOpen(os.getComputerID()) then
    close_modem_when_done = true
    modem.open(os.getComputerID())
  end
  
  if _debug then
    print("finding position...")
  end
  
  local fixes = {}
  local timeout = os.startTimer(_timeout or 2)

  modem.transmit(gps.CHANNEL_GPS, os.getComputerID(), "PING")
    
  while #fixes < _fix_count do
    local e, p1, p2, p3, p4, p5 = os.pullEvent()
    if e == "modem_message" then
      local side, channel, reply_channel, message, distance = p1, p2, p3, p4, p5
      if side == modem_side and channel == os.getComputerID() and reply_channel == gps.CHANNEL_GPS and distance then
        if type(message) == "table" and tonumber(message[1]) and tonumber(message[2]) and tonumber(message[3]) then
          local fix = {x = tonumber(message[1]), y = tonumber(message[2]), z = tonumber(message[3]), d = distance}
          if _debug then
            print(("Fix: %f meters from %f %f %f"):format(fix.d, fix.x, fix.y, fix.z))
          end
          table.insert(fixes, fix)
        end
      end
    elseif e == "timer" then
      if p1 == timeout then
        break
      end
    end
  end
  
  if _debug then
    print(("locked %d fixes"):format(#fixes))
  end  
  
  --iterate over every pair of 4 fixes and sample the location
  local samples = {}
  
  for i1 = 1, #fixes-3, 1 do
    local fix1 = fixes[i1]
    for i2 = i1+1, #fixes-2, 1 do
      local fix2 = fixes[i2]
      for i3 = i2+1, #fixes-1, 1 do
        local fix3 = fixes[i3]
        for i4 = i3+1, #fixes, 1 do
          local fix4 = fixes[i4]
          local err = 0.0
          local sample, pos2 = triliterate(fix1, fix2, fix3)
          if pos2 then
            sample, err = narrow_position(sample, pos2, fix4)
          end
          if is_valid_sample(sample) and err < 0.01 then
            table.insert(samples, sample)
            if _debug then
              print(("Sample: %.2f %.2f %.2f error %.2f"):format(sample.x, sample.y, sample.z, err))
            end
          end
        end
      end
    end
  end
  
  --
  local mean = {x=0,y=0,z=0}
  for i, sample in pairs(samples) do
    mean.x = mean.x + sample.x
    mean.y = mean.y + sample.y
    mean.z = mean.z + sample.z
  end
  mean.x = mean.x / #samples
  mean.y = mean.y / #samples
  mean.z = mean.z / #samples
  
  if _debug then
    print(("Found %d samples"):format(#samples))
    print(("Mean sample at %.2f %.2f %.2f"):format(mean.x, mean.y, mean.z))
  end
  
  --square of standard deviation
  local devsqr = 0
  for i, sample in pairs(samples) do
    local dx = sample.x - mean.x
    local dy = sample.y - mean.y
    local dz = sample.z - mean.z
    devsqr = devsqr + dx*dx + dy* dy + dz*dz
  end
  devsqr = devsqr / #samples
  devsqr = math.max(devsqr, 0.01)
  
  if _debug then
    print(("square of standard deviation: %.2f"):format(devsqr))
  end
  
  local pos = {x = 0, y = 0, z = 0}
  local c = 0
  for i, sample in pairs(samples) do
    local dx = sample.x - mean.x
    local dy = sample.y - mean.y
    local dz = sample.z - mean.z
    local dlsqr = dx*dx+dy*dy+dz*dz
    
    if dlsqr < devsqr*9 then
      pos.x = pos.x + sample.x
      pos.y = pos.y + sample.y
      pos.z = pos.z + sample.z
      c = c + 1
    end
  end
  
  pos.x = pos.x / c
  pos.y = pos.y / c
  pos.z = pos.z / c
  
  local fdev = 0.0
  for i, sample in pairs(samples) do
    local dx = sample.x - pos.x
    local dy = sample.y - pos.y
    local dz = sample.z - pos.z
    fdev = fdev + dx*dx + dy*dy + dz*dz
  end
  fdev = math.sqrt(fdev)
  
  if close_modem_when_done then
    modem.close(os.getComputerID())
  end
  
  return pos.x, pos.y, pos.z, fdev
end

local mode = nil

if type(arg) == "table" then
  mode = arg[1]
end

if mode == "locate" then
  local fc = tonumber(arg[2])
  if fc == nil then
    fc = fix(0.05, true)
  end
  local x, y, z, dev = locate(fc, 0.05, true)
  print(("Located at %.2f %.2f %.2f"):format(x, y, z))
  print(("Deviation %.2f"):format(dev))
elseif mode == "fix" then
  fix(0.05, true)
else
  return{
    fix = fix,
    locate = locate
  }
end
