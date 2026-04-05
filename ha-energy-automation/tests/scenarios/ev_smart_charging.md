# Test Scenario: EV Smart Charging

## Scenario Description

Tests the EV charging flows: jonasbkarlsson/ev_smart_charging integration as primary scheduler, solar excess charging, emergency charge, rate limiting, Tesla SOC sync, and the Alfen flash-wear safety guard.

## Prerequisites

- Alfen Eve wallbox powered and connected to network
- Alfen HACS integration installed, session active
- `binary_sensor.alfen_wallbox_https_api_login_status = on`
- Kill switch on
- Car connected (for tests involving charging)

---

## Test 1: jonasbkarlsson Primary Scheduler

**Setup:** Install and configure jonasbkarlsson/ev_smart_charging via HACS and UI

**Configuration:**
- Price entity: `sensor.nord_pool_nl_current_price`
- SOC sensor: `input_number.ev_soc_manual`
- Ready time: `input_datetime.ev_departure_time`
- Target SOC: `input_number.ev_target_soc`

**Expected:**
- jonasbkarlsson schedules charging during cheapest hours before departure time
- jonasbkarlsson enables `switch.alfen_wallbox_availability_manager` directly
- This package's automations do NOT conflict (they use conditions to avoid double-switching)

**Verify:**
```
jonasbkarlsson dashboard card shows scheduled charge windows
Alfen is enabled during scheduled window
No "rate limited" conflicts between jonasbkarlsson and this package
```

---

## Test 2: Tesla SOC Syncs to Manual Input

**Setup:** Tesla integration connected, `sensor.tesla_battery_level` available

**Expected:**
- `ev_sync_tesla_soc` fires when Tesla SOC changes by >2%
- `input_number.ev_soc_manual` updates to match Tesla SOC
- `sensor.ev_soc_display` shows Tesla value with `source = tesla_cloud`

**Verify:**
```
Change Tesla SOC by >2% (charge or discharge car manually)
input_number.ev_soc_manual matches sensor.tesla_battery_level (within 1%)
sensor.ev_soc_display = Tesla SOC
state attribute source = tesla_cloud
```

**Fallback (Tesla unavailable):**
- `sensor.tesla_battery_level = unavailable`
- `sensor.ev_soc_display` shows `input_number.ev_soc_manual` (manually set)
- `state attribute source = manual_input`
- Set `input_number.ev_soc_manual` manually on dashboard

---

## Test 3: Solar Excess Charging

**Setup:**
- Export > 1000W for 5 minutes (disconnect loads or wait for sunny afternoon)
- Car connected
- SOC < target SOC
- Alfen not already charging
- Kill switch on, `ev_smart_charging_enabled = on`

**Expected (after 5-minute delay):**
- `ev_solar_excess_charge` fires
- `binary_sensor.alfen_change_allowed = on` check passes
- `input_datetime.alfen_last_change` updates
- `switch.alfen_wallbox_availability_manager = on`
- Car begins charging
- `input_text.ev_last_action` logs solar excess start

**Verify:**
```
sensor.homewizard_p1_active_power_w < -1000 for 5 min
Automation Traces → ev_solar_excess_charge → Success
switch.alfen_wallbox_availability_manager = on
input_text.ev_last_action → "Zonne-energie laden gestart"
```

**Stop (export drops):**
- Export rises above -200W for 5 minutes
- Not during cheap price window, not manual override
- `ev_solar_excess_stop` fires
- Rate limit check passes (>10 min since last change)
- Alfen disabled

**Verify:**
```
Automation Traces → ev_solar_excess_stop → Success
switch.alfen_wallbox_availability_manager = off
```

---

## Test 4: Rate Limiting Prevents Flash Wear

**Setup:** Trigger two enable/disable operations within 10 minutes

**Expected:**
- First operation: `alfen_change_allowed = on` → executes, updates `alfen_last_change`
- Second operation (< 10 min later): `alfen_change_allowed = off` → automation condition fails → no action
- After 10 minutes: `alfen_change_allowed = on` again

**Verify:**
```
input_datetime.alfen_last_change updates on first operation
binary_sensor.alfen_change_allowed = off immediately after
binary_sensor.alfen_change_allowed = on after ~10 min
Second operation: Automation Traces → Condition not met (alfen_change_allowed = off)
```

**Critical: NO current limit writes**
```
grep -r "alfen_wallbox_max_station_current" packages/ scripts/
```
Must return 0 results. Any `number.set_value` targeting Alfen current limit would cause flash wear.

---

## Test 5: Emergency Charge Below Minimum SOC

**Setup:**
- Car connected
- `sensor.ev_soc_display < input_number.ev_minimum_soc` (e.g. SOC = 15%, minimum = 20%)
- `binary_sensor.ev_needs_emergency_charge = on` for >2 minutes

**Expected:**
- `ev_emergency_charge` fires
- `alfen_change_allowed = on` check passes
- Alfen enabled immediately regardless of price
- Mobile notification: "EV noodladen gestart" with current price

**Verify:**
```
binary_sensor.ev_needs_emergency_charge = on
Automation Traces → ev_emergency_charge → Success (after 2-min delay)
switch.alfen_wallbox_availability_manager = on
Mobile: notification with price and SOC
```

---

## Test 6: Manual Override

**Setup:** Turn on `input_boolean.ev_charge_override` from dashboard

**Expected:**
- `ev_manual_override_start` fires
- Alfen enabled immediately
- `input_text.ev_last_action` logs "Handmatig laden gestart"

**Midnight reset:**
- At 00:00:10, `ev_manual_override_stop` fires
- `ev_charge_override` → off
- Log: "Handmatig laden reset om middernacht"

**Verify:**
```
Automation Traces → ev_manual_override_start → Success
input_text.ev_last_action → "Handmatig laden gestart"
After midnight: input_boolean.ev_charge_override = off
```

---

## Test 7: Evening Reminder

**Setup:** 20:00, car NOT connected (`binary_sensor.alfen_car_connected = off`)

**Expected:**
- `ev_evening_reminder` fires
- Mobile notification: "EV niet aangesloten" with cheapest hour prices
- Includes deep link to dashboard

**Not triggered if car connected:**
- `alfen_car_connected = on` → condition fails → no notification

**Verify:**
```
Automation Traces → ev_evening_reminder → Success (car not connected)
Automation Traces → ev_evening_reminder → Condition not met (car connected)
```

---

## Pass/Fail Criteria

| Test | Pass condition |
|---|---|
| jonasbkarlsson integration | Schedules charge, no conflicts |
| Tesla SOC sync | `ev_soc_manual` matches Tesla SOC |
| Solar excess charge | Starts after 5 min export > 1kW |
| Solar excess stop | Stops after 5 min export < 200W |
| Rate limiting | Second operation within 10 min is blocked |
| No current limit writes | `grep alfen_wallbox_max_station_current` returns 0 results |
| Emergency charge | Activates at SOC < minimum regardless of price |
| Manual override | Starts immediately, resets at midnight |
| Evening reminder | Fires at 20:00 when car not connected |
