-- command a Copter to takeoff to 30m and fly to Oyama groud
--
-- CAUTION: This script only works for Copter
-- this script waits for the vehicle to be armed and RC6 input > 1800 and then:
--    a) switches to Guided mode
--    b) takeoff to 30m
--    c) flies to thr oyama pitcher mound
--    d) switches to RTL mode

local takeoff_alt_above_home = 30
local copter_guided_mode_num = 4
local copter_rtl_mode_num = 6
local stage = 0
local target_loc = Location()
local w_stage = -1

-- the main update function that uses the takeoff and velocity controllers to fly a rough square pattern
function update()

  if w_stage ~= stage then
    gcs:send_text(0, string.format("copter-fly-oyama stage:%f", stage))
    w_stage = stage
  end
  
  if not arming:is_armed() then -- reset state when disarmed
    stage = 0
  else
    pwm6 = rc:get_pwm(6)
    --gcs:send_text(0, string.format("pwm6:%f", pwm6))
    if pwm6 and pwm6 > 1800 then    -- check if RC6 input has moved high
      if (stage == 0) then          -- change to guided mode
        if (vehicle:set_mode(copter_guided_mode_num)) then  -- change to Guided mode
          stage = stage + 1
        end
      elseif (stage == 1) then      -- Stage1: takeoff
        if (vehicle:start_takeoff(takeoff_alt_above_home)) then
          stage = stage + 1
        end
      elseif (stage == 2) then      -- Stage2: check if vehicle has reached target altitude
        local home = ahrs:get_home()
        local curr_loc = ahrs:get_location()
        if home and curr_loc then
          local vec_from_home = home:get_distance_NED(curr_loc)
          --gcs:send_text(0, "alt above home: " .. tostring(math.floor(-vec_from_home:z())))
          if (math.abs(takeoff_alt_above_home + vec_from_home:z()) < 1) then
            stage = stage + 1
          end
        end
      elseif (stage == 3 ) then   -- Stage3: fly to ground pitcher mound

        -- set target(小山球場)
        target_loc.lat(target_loc, 363145900)
        target_loc.lng(target_loc, 1398523800)
        target_loc.alt(target_loc, 6710) -- 海抜37.1m + 高度30m
        vehicle:set_target_location(target_loc)
        gcs:send_text(0, string.format("set target location!"))
        stage = stage + 1

        -- for stage 4
      elseif (stage == 4) then  -- Stage4: wait for goal

        local current_pos = ahrs:get_position()
        local distance = current_pos.get_distance(current_pos, target_loc)
        gcs:send_text(0, string.format("distance:%f", distance))
        if(distance < 3) then
          gcs:send_text(0, string.format("arrive at target location!"))
          stage = stage + 1
        end

      elseif (stage == 5) then  -- Stage5: change to RTL mode
        vehicle:set_mode(copter_rtl_mode_num)
        stage = stage + 1
        gcs:send_text(0, "finished, switching to RTL")
      end
    end
  end

  return update, 100
end

return update()
