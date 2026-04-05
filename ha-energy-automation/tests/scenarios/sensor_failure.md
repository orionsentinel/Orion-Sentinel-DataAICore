# Test Scenario: Sensor Failure and Recovery

## Scenario Description

Tests system behavior when one or more critical sensors become unavailable. The system must: fail safely (no Modbus writes when data is missing), notify the user, and recover cleanly when sensors come back.

## Failure Cases to Test

1. SolarEdge Modbus becomes unavailable
2. Nord Pool price data goes stale
3. Alfen API session is lost
4. HA restart (rate limiters reset correctly)
5. Kill switch turned off and on

---

## Test 1: SolarEdge Modbus Unavailable

**Setup:** Disconnect inverter from network (or stop SolarEdge Modbus Multi integration)

**Expected immediately:**
- `sensor.solaredge_i1_ac_power = unavailable`
- `binary_sensor.modbus_available = off`
- `binary_sensor.battery_hardware_available = off`
- `binary_sensor.missing_data_flag = on`
- `sensor.system_health_status = FOUT_MODBUS`

**Expected after 10 minutes:**
- `watchdog_modbus_unavailable` fires (10-min delay)
- `input_select.battery_desired_mode` → SELF_CONSUME (safe fallback)
- Mobile notification: "SolarEdge Modbus verbinding verloren"
- `input_datetime.last_modbus_alert` updates

**Expected: mode executor when Modbus unavailable:**
- If a rule automation writes a new mode → executor triggers
- Executor checks `binary_sensor.modbus_available = off`
- Executor logs warning: "Modbus niet beschikbaar — schrijven overgeslagen"
- No Modbus writes are made

**Verify:**
```
System Log → "Battery mode executor: skipped Modbus write — modbus_available=off"
input_text.battery_last_action → "⚠️ Modbus niet beschikbaar — schrijven overgeslagen"
Mobile: notification received
```

**Recovery (reconnect inverter):**
- `sensor.solaredge_i1_ac_power` becomes available
- `binary_sensor.modbus_available = on`
- `watchdog_modbus_recovered` fires
- Mobile notification: "SolarEdge Modbus hersteld"
- `battery_mode_init_on_startup` does NOT re-run (only on actual HA restart)
- Next hourly reset at :05 resets mode to SELF_CONSUME if needed

---

## Test 2: Nord Pool Price Data Stale

**Setup:** Stop Nord Pool integration or wait for price sensor to age >90 minutes

**Expected immediately:**
- `sensor.price_freshness_ok = false`
- `binary_sensor.is_cheap_hour = false` (guard)
- `binary_sensor.is_expensive_hour = false` (guard)
- `binary_sensor.is_negative_price = false` (guard)
- `sensor.system_health_status = FOUT_PRIJZEN`

**Expected: no price-triggered mode changes while stale:**
- `battery_grid_charge_cheap_price` condition `price_freshness_ok = true` → fails → no action
- `battery_peak_discharge` condition → fails → no action
- Battery stays in current mode

**Expected after next :15 (if still stale > 90 min):**
- `watchdog_nordpool_stale_prices` fires
- Mobile notification: "Nord Pool prijzen zijn verouderd"
- Cooldown: no repeat for 2 hours

**Verify:**
```
sensor.price_freshness_ok = false
Automation Traces → battery_grid_charge_cheap_price → Condition not met
Mobile: notification received once, then quiet for 2h
```

---

## Test 3: Alfen API Session Lost

**Setup:** Open Eve Connect / 50five app (steals API session) or stop Alfen integration

**Expected:**
- `binary_sensor.alfen_wallbox_https_api_login_status = off`
- `binary_sensor.alfen_available = off`

**Expected after 1 minute:**
- `watchdog_alfen_session_lost` fires
- Mobile notification: "Alfen sessie verloren — Actie vereist"
- Notification includes deep link to integrations page
- `input_datetime.last_alfen_alert` updates

**Expected: EV automations blocked while session lost:**
- `binary_sensor.alfen_available = off` visible on dashboard
- EV charging automations that check `alfen_available` skip action

**Recovery (press Login in Alfen integration):**
- `binary_sensor.alfen_wallbox_https_api_login_status = on`
- `watchdog_alfen_session_recovered` fires (if `last_alfen_alert` was recent)
- Mobile notification: "Alfen sessie hersteld"

**Verify:**
```
Mobile: "Alfen sessie verloren" notification with deep link
watchdog_alfen_session_recovered fires after login
```

---

## Test 4: HA Restart — Rate Limiters Reset

**Setup:** Restart Home Assistant

**Expected during startup:**
- `startup_reset_rate_limiters` fires after 30-second delay
- `input_datetime.battery_last_mode_change` → `1970-01-01 00:00:00`
- `input_datetime.alfen_last_change` → `1970-01-01 00:00:00`
- `input_boolean.negative_price_notified` → off
- `binary_sensor.battery_change_allowed = on` immediately (1970 is >5 min ago)
- `binary_sensor.alfen_change_allowed = on` immediately

**Expected: battery initializes to SELF_CONSUME after 1 minute:**
- `battery_mode_init_on_startup` fires (60-second delay)
- If Modbus available: writes SELF_CONSUME to Modbus

**Verify:**
```
input_datetime.battery_last_mode_change = 1970-01-01 00:00:00
binary_sensor.battery_change_allowed = on
binary_sensor.alfen_change_allowed = on
Automation Traces → battery_mode_init_on_startup → Success (if Modbus available)
```

---

## Test 5: Kill Switch Off → Safe State → Kill Switch On

**Setup:** Turn off `input_boolean.energy_automation_enabled`

**Expected immediately:**
- `watchdog_kill_switch_disabled` fires
- `input_select.battery_desired_mode` → SELF_CONSUME
- `switch.alfen_wallbox_availability_manager` → off
- `input_text.system_last_alert` updates
- Mobile notification: "Energie automaties uitgeschakeld"
- `sensor.system_health_status = GESTOPT`

**Expected while kill switch off:**
- All package 05-09 automations that check kill switch → do NOT act
- Manual scripts still work (not gated on kill switch)

**Recovery (turn kill switch back on):**
- No automatic mode changes
- Automations resume checking conditions normally
- Next triggered event (price change, hourly reset) applies correct mode

**Verify:**
```
watchdog_kill_switch_disabled → Success
input_select.battery_desired_mode = SELF_CONSUME
switch.alfen_wallbox_availability_manager = off
sensor.system_health_status = GESTOPT
Mobile: notification received
```

---

## Pass/Fail Criteria

| Test | Pass condition |
|---|---|
| Modbus unavailable | No Modbus writes, watchdog notification after 10 min |
| Modbus recovery | Recovery notification, mode can change again |
| Stale prices | No price-triggered mode changes, watchdog at :15 |
| Alfen session lost | Notification with deep link within 1 min |
| HA restart | Rate limiters reset to 1970, first write not blocked |
| Kill switch off | Battery → SELF_CONSUME, Alfen → off, all automations pause |
| Kill switch on | Automations resume on next trigger |
