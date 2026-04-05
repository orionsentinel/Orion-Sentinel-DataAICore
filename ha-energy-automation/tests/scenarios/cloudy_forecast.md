# Test Scenario: Cloudy Forecast Day

## Scenario Description

Tomorrow's solar forecast is very low (< 8 kWh — "cloudy" category). Tests: forecast gate enables grid charging, dynamic target SOC set to 80% (cloudy + arbitrage), battery fills via grid, and `battery_will_fill_naturally = off` keeps grid charging permitted.

## Prerequisites

- All integrations available
- Kill switch on
- Forecast.Solar integration working
- Battery SOC at 20%
- Price spread > `input_number.arbitrage_min_spread`

## Test Steps

### Step 1: Forecast gate enables grid charging at 13:30

**Setup:** Ensure `sensor.solar_forecast_tomorrow_kwh < 20` (cloudy day)

**Expected (at 13:30):**
- `battery_forecast_gate` automation runs
- `binary_sensor.battery_will_fill_naturally = off` (forecast < 20 kWh)
- `input_boolean.allow_grid_battery_charge → on`
- Log: "grid charge enabled — solar forecast X kWh insufficient"

**Verify:**
```
Automation Traces → battery_forecast_gate → "grid charge enabled" branch
input_boolean.allow_grid_battery_charge = on
sensor.solar_forecast_category = cloudy (if forecast < 8 kWh)
```

---

### Step 2: Dynamic target SOC set to 80% (cloudy + arbitrage)

**Setup:** `sensor.solar_forecast_category = cloudy`, `binary_sensor.arbitrage_opportunity = on`

**Expected:**
- `sensor.battery_target_soc = 80`
- Attribute `reason` = "Bewolkt + hoge spreiding — extra laden voor arbitrage"

**Verify:**
```
Developer Tools → States → sensor.battery_target_soc = 80
State attributes → reason = "Bewolkt + hoge spreiding..."
```

---

### Step 3: GRID_CHARGE activates during cheap overnight hour

**Setup:** `binary_sensor.is_cheap_hour = on`, battery SOC at 20% < 80% target

**Expected:**
- `battery_grid_charge_cheap_price` triggers
- All conditions pass (arbitrage on, SOC < target, grid charge allowed)
- Mode → GRID_CHARGE
- Battery begins charging to 80% target

**Verify:**
```
input_select.battery_desired_mode = GRID_CHARGE
Logbook → "Charge from Grid" written to SolarEdge
```

---

### Step 4: Charging stops at 80% (not 95%)

**Setup:** Battery SOC reaches 80%

**Expected:**
- `battery_grid_charge_target_reached` triggers
- Mode → HOLD
- Charging stops at 80% (dynamic target — not hardcoded 95%)

**Verify:**
```
Automation Traces → battery_grid_charge_target_reached → Success
input_select.battery_desired_mode = HOLD
sensor.solaredge_b1_soc ≈ 80%
```

---

### Step 5: Solar does not over-ride planned charge overnight

**Setup:** No solar at night (expected, but test that `solar_producing = off` doesn't break things)

**Expected:**
- `battery_solar_override` does NOT trigger (no solar, binary_sensor.solar_producing = off)
- Mode stays GRID_CHARGE until target reached

**Verify:**
```
Automation Traces → battery_solar_override → NOT triggered overnight
```

---

### Step 6: Next day — limited solar, battery discharges normally

**Setup:** Morning of cloudy day, `solar_forecast_category = cloudy`, mode in SELF_CONSUME

**Expected:**
- Solar produces < 1 kW (cloudy)
- Battery discharges to cover household load in SELF_CONSUME
- No PEAK_DISCHARGE unless is_expensive_hour + arbitrage_opportunity

**Verify:**
```
sensor.solaredge_b1_dc_power negative (discharging)
input_select.battery_desired_mode = SELF_CONSUME
```

---

### Step 7: Forecast.Solar API failure gives low forecast warning

**Setup:** In April–September, if forecast shows 0 kWh at 14:00

**Expected:**
- `solar_forecast_fault_check` fires at 14:00
- Notification: "Zonneprognose onverwacht laag"
- Prompts user to verify Forecast.Solar integration

**Verify:**
```
Mobile: notification "Zonneprognose onverwacht laag" received
Automation Traces → solar_forecast_fault_check → Success
```

---

## Pass/Fail Criteria

| Check | Pass condition |
|---|---|
| Forecast gate at 13:30 | `allow_grid_battery_charge = on` when forecast < 20 kWh |
| Target SOC = 80% | `battery_target_soc = 80` when cloudy + arbitrage |
| GRID_CHARGE to target | Charging stops at 80%, not 95% |
| Transition to HOLD | Mode → HOLD when target reached |
| Forecast fault warning | Notification when forecast < 0.5 kWh in summer |
