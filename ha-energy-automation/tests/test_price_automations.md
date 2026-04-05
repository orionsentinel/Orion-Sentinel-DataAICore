# Price Automation Tests

Manual test procedures for `02_energy_prices.yaml` price sensors and guards.

---

## Test 1: All-In Price Calculation

**Purpose:** Verify `sensor.energy_price_all_in` calculates correctly.

**Steps:**
1. Go to **Developer Tools → Template**
2. Run this template to verify the formula:

```jinja2
{% set spot = states('sensor.nord_pool_nl_current_price') | float(0) %}
{% set eb = 0.1228 %}
{% set network = states('input_number.network_tariff') | float(0.04) %}
{% set vat = 1.21 %}
{% set calculated = ((spot + eb + network) * vat) | round(4) %}
{% set sensor_value = states('sensor.energy_price_all_in') | float(0) %}

Spot: {{ spot }} €/kWh
Energiebelasting: {{ eb }} €/kWh
Netwerktarief: {{ network }} €/kWh
BTW: {{ vat }}x
Calculated all-in: {{ calculated }} €/kWh
Sensor value: {{ sensor_value }} €/kWh
Match: {{ (calculated - sensor_value) | abs < 0.0001 }}
```

**Expected:** "Match: True" — calculated value matches sensor.

---

## Test 2: Price Freshness Guard

**Purpose:** Verify `sensor.price_freshness_ok` correctly reflects data age.

**Steps:**
1. Go to **Developer Tools → Template** and run:

```jinja2
{% set last_updated = states.sensor.nord_pool_nl_current_price.last_updated %}
{% set age_seconds = (now() - last_updated).total_seconds() %}
{% set age_minutes = (age_seconds / 60) | round(1) %}

Nord Pool last updated: {{ last_updated.strftime('%Y-%m-%d %H:%M:%S') }}
Age: {{ age_minutes }} minutes
Fresh (< 90 min): {{ age_seconds < 5400 }}
price_freshness_ok sensor: {{ states('sensor.price_freshness_ok') }}
```

**Expected:** Both `Fresh` and `price_freshness_ok` should match (both `true` or both `false`).

2. Check the sensor on the dashboard — should show the same result.

---

## Test 3: Simulate Cheap Hour (Low Threshold)

**Purpose:** Verify `binary_sensor.is_cheap_hour` and dependent automations.

**Steps:**
1. Note current `input_number.battery_charge_price_threshold` value
2. Set `input_number.battery_charge_price_threshold` to `1.0` (all hours are cheap)
3. Check `binary_sensor.is_cheap_hour` — verify it shows `on` OR check the 25th percentile:

```jinja2
{% set prices = state_attr('sensor.nord_pool_nl_current_price', 'today') %}
{% set current = states('sensor.nord_pool_nl_current_price') | float(0) %}
{% if prices %}
  {% set sorted = prices | map('float', 0) | sort | list %}
  {% set p25 = sorted[(sorted | length * 0.25) | int] %}
  Current: {{ current }} €/kWh
  25th percentile: {{ p25 }} €/kWh
  Is cheap hour: {{ current <= p25 }}
{% endif %}
```

4. Wait 1 minute for `automation.battery_rule_grid_charge_cheap_price` to evaluate
5. Check `input_select.battery_desired_mode` (if battery available)

**Reset:**
1. Set `input_number.battery_charge_price_threshold` back to `0.02`
2. Call `script.reset_battery_to_self_consumption`

---

## Test 4: Simulate Negative Price

**Purpose:** Verify negative price detection and notification.

**Steps (conceptual — real negative prices are rare):**
1. Go to **Developer Tools → Template** and verify the template logic:

```jinja2
{% set spot = states('sensor.nord_pool_nl_current_price') | float(0) %}
{% set is_negative = spot < 0 %}
{% set is_fresh = states('sensor.price_freshness_ok') == 'true' %}

Spot: {{ spot }} €/kWh
Is negative: {{ is_negative }}
Is fresh: {{ is_fresh }}
binary_sensor.is_negative_price would be: {{ is_negative and is_fresh }}
```

2. To actually test the negative price notification: you can temporarily modify the
   `binary_sensor.is_negative_price` via Developer Tools → States, or wait for a real
   negative price event (common on sunny/windy days in NL, typically 10-20x/year).

3. When `binary_sensor.is_negative_price` goes to `on`:
   - Verify notification fires: "💚 Negatieve energieprijs!"
   - Verify `automation.battery_rule_grid_charge_cheap_price` fires
   - Verify the notification is NOT repeated every minute (debounced — single fire)

---

## Test 5: Cheapest Hour Percentile Calculation

**Purpose:** Verify `binary_sensor.is_cheap_hour` and `is_expensive_hour` use correct percentiles.

**Steps:**
1. Go to **Developer Tools → Template** and run:

```jinja2
{% set prices = state_attr('sensor.nord_pool_nl_current_price', 'today') %}
{% set current = states('sensor.nord_pool_nl_current_price') | float(999) %}
{% if prices and prices | length > 0 %}
  {% set sorted = prices | map('float', 0) | sort | list %}
  {% set p25_idx = (sorted | length * 0.25) | int %}
  {% set p75_idx = (sorted | length * 0.75) | int %}
  Today's prices: {{ sorted | join(', ') }}
  25th percentile (cheap threshold): {{ sorted[p25_idx] }} €/kWh
  75th percentile (expensive threshold): {{ sorted[p75_idx] }} €/kWh
  Current price: {{ current }} €/kWh
  Is cheap: {{ current <= sorted[p25_idx] }}
  Is expensive: {{ current >= sorted[p75_idx] }}
  is_cheap_hour sensor: {{ states('binary_sensor.is_cheap_hour') }}
  is_expensive_hour sensor: {{ states('binary_sensor.is_expensive_hour') }}
{% else %}
  No price data available
{% endif %}
```

**Expected:** Template calculations match the binary sensor states.

---

## Test 6: Price Staleness Watchdog

**Purpose:** Verify watchdog fires when price is stale and cooldown works.

**Steps:**
1. Check current `input_datetime.last_stale_price_notification` value
2. Manually trigger `automation.watchdog_nordpool_stale_prices` via Developer Tools → Automations
   (this bypasses the time and staleness conditions — fires immediately)
3. Verify `input_datetime.last_stale_price_notification` gets updated to current time
4. Verify notification received

**Verify cooldown:**
1. Try triggering the watchdog again immediately
2. Expected: notification NOT sent (cooldown 2 hours)

**Reset cooldown:**
1. Set `input_datetime.last_stale_price_notification` to a date far in the past
2. Now the watchdog can fire again

---

## Test 7: AIO Energy Management Schedules

**Purpose:** Verify AIO creates the expected binary sensor entities.

**Steps:**
1. Go to **Developer Tools → States**
2. Verify these entities exist:
   - `binary_sensor.cheapest_4h_overnight`
   - `binary_sensor.cheapest_6h_any`
   - `binary_sensor.most_expensive_4h`
3. Run this template to see schedule details:

```jinja2
{# Check AIO schedules #}
Cheapest 4h overnight: {{ states('binary_sensor.cheapest_4h_overnight') }}
  {% if state_attr('binary_sensor.cheapest_4h_overnight', 'schedule') %}
  Hours: {{ state_attr('binary_sensor.cheapest_4h_overnight', 'schedule') }}
  {% endif %}

Most expensive 4h: {{ states('binary_sensor.most_expensive_4h') }}

Cheapest 6h: {{ states('binary_sensor.cheapest_6h_any') }}
```

**Expected:** All three binary sensors exist and show either `on` or `off`.

---

## Test 8: Nord Pool Tomorrow Prices

**Purpose:** Verify tomorrow's prices are available after 13:00.

**Steps (run after 14:00 CET):**
1. Go to **Developer Tools → Template** and run:

```jinja2
{% set tomorrow = state_attr('sensor.nord_pool_nl_current_price', 'tomorrow') %}
{% if tomorrow and tomorrow | length > 0 %}
  Tomorrow's {{ tomorrow | length }} prices available.
  Min: {{ tomorrow | map('float', 0) | min | round(4) }} €/kWh
  Max: {{ tomorrow | map('float', 0) | max | round(4) }} €/kWh
  Prices: {{ tomorrow | map('float', 0) | map('round', 4) | list | join(', ') }}
{% else %}
  Tomorrow's prices not yet available (before ~14:00 CET).
{% endif %}
```

**Expected (after 14:00):** 24 prices available.
**Expected (before 14:00):** "not yet available" — normal, Nord Pool publishes at ~13:00-14:00.
