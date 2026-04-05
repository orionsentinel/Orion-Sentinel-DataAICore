# EV Charging Tests

Manual test procedures for `06_alfen_ev_charging.yaml`.

**Prerequisites:**
- `binary_sensor.alfen_wallbox_https_api_login_status` = `on`
- `sensor.alfen_wallbox_status` not `unavailable`
- `input_boolean.ev_smart_charging_enabled` = `on`

---

## Test 1: Start Charging on Cheap Window (Price-Based)

**Purpose:** Verify EV charging starts when price drops below threshold.

**Steps:**
1. Connect the car to the Alfen (verify `binary_sensor.alfen_car_connected` = `on`)
2. Note current `input_number.ev_charge_price_threshold` value
3. Set `input_number.ev_charge_price_threshold` to `1.0` (forces all hours to be "cheap")
4. Wait for `binary_sensor.ev_cheap_charging_now` to update to `on` (may take up to 1 minute)

**Expected results:**
- `binary_sensor.ev_cheap_charging_now` = `on`
- `automation.ev_start_charging_cheap_window` fires
- `switch.alfen_wallbox_availability_manager` = `on`
- `sensor.alfen_wallbox_active_power_total` > 0 (car starts drawing power)
- Notification received on phone

**Reset:**
1. Set `input_number.ev_charge_price_threshold` back to `0.08`
2. `binary_sensor.ev_cheap_charging_now` → `off`
3. Wait for `automation.ev_stop_charging_expensive_hour` (may need to trigger manually)
4. Verify `switch.alfen_wallbox_availability_manager` = `off`

---

## Test 2: Stop Charging When Price Rises (Respect Override)

**Purpose:** Verify charger stops when cheap window closes, but NOT when override is on.

**Steps (part A — stop works normally):**
1. Start charging (from Test 1 or manually)
2. Ensure `input_boolean.ev_charge_override` = `off`
3. Ensure `binary_sensor.ev_needs_emergency_charge` = `off`
4. Set `input_number.ev_charge_price_threshold` back to `0.08` (so current price > threshold)
5. Trigger `automation.ev_stop_charging_expensive_hour` manually

**Expected:** `switch.alfen_wallbox_availability_manager` = `off`

**Steps (part B — override prevents stop):**
1. Turn on `input_boolean.ev_charge_override`
2. Start charging manually
3. Attempt to trigger `automation.ev_stop_charging_expensive_hour`

**Expected:** Charger stays ON (override condition blocks the stop)

**Reset:** Turn off `input_boolean.ev_charge_override`.

---

## Test 3: Price Staleness Guard (NO-OP on stale data)

**Purpose:** Verify automations do NOT stop/start charging when price data is stale.

**Simulating stale prices:**
1. Go to **Developer Tools → States**
2. Find `sensor.price_freshness_ok` — note it is currently `true`
3. The only way to force staleness in a test environment is to disconnect network briefly,
   wait 90 minutes, or use the HA `homeassistant.set_state` service (developer use)

**Alternative test (checking the condition logic):**
1. Go to **Developer Tools → Template**
2. Run: `{{ states('sensor.price_freshness_ok') }}`
3. Should return `true` when prices are fresh

**Verify stale guard exists:**
```jinja2
{# Check that freshness is evaluated correctly #}
{% set age = (now() - states.sensor.nord_pool_nl_current_price.last_updated).total_seconds() %}
Last updated {{ (age / 60) | round(1) }} minutes ago.
Fresh: {{ age < 5400 }}
```

**Expected:** When `price_freshness_ok` = `false`, the EV stop automation condition fails and
the charger keeps running (safe default — don't stop charging on bad data).

---

## Test 4: Override Mode — Force Start

**Purpose:** Verify override bypasses price check and starts charging.

**Steps:**
1. Set `input_number.ev_charge_price_threshold` to a very low value (e.g., `-0.20`) so no hour is cheap
2. Verify `binary_sensor.ev_cheap_charging_now` = `off`
3. Connect car (verify `binary_sensor.alfen_car_connected` = `on`)
4. Turn on `input_boolean.ev_charge_override`

**Expected:**
- `automation.ev_start_charging_override` fires
- `switch.alfen_wallbox_availability_manager` = `on`
- Car starts charging regardless of price

**Reset:**
1. Turn off `input_boolean.ev_charge_override`
2. Turn off `switch.alfen_wallbox_availability_manager` manually
3. Reset `input_number.ev_charge_price_threshold` to `0.08`

---

## Test 5: Solar Excess Absorption

**Purpose:** Verify EV charging starts when solar export exceeds 1500W.

**Prerequisites:** Daytime, solar producing, battery either full or unavailable.

**Steps:**
1. Ensure car is connected (`binary_sensor.alfen_car_connected` = `on`)
2. Ensure `switch.alfen_wallbox_availability_manager` = `off` (car not charging)
3. Wait for `sensor.grid_export_w` > 1500W for 10 consecutive minutes
   (this happens naturally on sunny days when battery is full)

**Expected:**
- `automation.ev_start_solar_excess_absorption` fires
- `switch.alfen_wallbox_availability_manager` = `on`
- Notification received: "EV laden met zonne-overschot"
- `sensor.alfen_wallbox_active_power_total` > 0

**Simulate if no solar available:**
1. Go to **Developer Tools → Automations**
2. Find `ev_start_solar_excess_absorption` → click Run (this bypasses the `for: "00:10:00"` condition)
3. Note: manually triggered automations skip conditions — verify entities manually

**Stop test:**
- Solar export will naturally drop when cloud passes or EV reduces grid export
- Or manually trigger `ev_stop_solar_excess_absorption`

---

## Test 6: Evening Reminder (Not Connected at 22:00)

**Purpose:** Verify notification fires at 22:00 if car is not connected.

**Steps:**
1. Ensure `binary_sensor.alfen_car_connected` = `off` (car not at charger)
2. Ensure `input_boolean.ev_smart_charging_enabled` = `on`
3. Wait until 22:00 OR manually trigger `automation.ev_evening_reminder_not_connected`

**Expected:**
- Notification received: "Auto niet ingestopt"
- Notification includes Tesla SOC if available, or "niet beschikbaar" if Tesla is offline

**Reset:** No action needed.

---

## Test 7: Alfen Flash Wear Verification

**Purpose:** Verify no automation is writing to the current-limit register.

**Steps:**
1. Go to **Developer Tools → Logbook**
2. Filter by entity: `number.alfen_wallbox_max_station_current`
3. Look at the last 24 hours

**Expected:** NO entries in the logbook for this entity from HA automations.
The only writes should be from manual dashboard interactions (if you ever change it).

**If you see frequent writes:** There is a bug — find the automation writing to this entity and fix it.
See `docs/ALFEN_WARNING.md` for the danger and safe alternatives.

---

## Test 8: Alfen Session Loss Simulation

**Purpose:** Verify watchdog detects and notifies on session loss.

**Steps (requires Eve Connect app or 50five app on phone):**
1. Open Eve Connect app on your phone while HA has the session
2. Wait 1-2 minutes
3. Check `binary_sensor.alfen_wallbox_https_api_login_status`

**Expected:**
- `binary_sensor.alfen_wallbox_https_api_login_status` → `off`
- Within 1 minute: watchdog fires
- Notification received: "Alfen sessie verloren"

**Recovery:**
1. Close the Eve Connect app
2. Go to **Settings → Integrations → Alfen EV Wallbox → [device] → Login** button
3. Verify `binary_sensor.alfen_wallbox_https_api_login_status` → `on`
4. Notification received: "Alfen sessie hersteld"
