# Tesla Integration Setup

## ⚠️ Important: Tesla SOC is Treated as Informational Only

This repository treats Tesla SOC as an **unreliable soft hint** only. All EV charging decisions are made using `sensor.alfen_wallbox_active_power_total` (the charger's own power measurement) as the primary signal for "is the car actually charging."

Tesla SOC is wrapped in availability checks everywhere it is used. If Tesla SOC is `unavailable`, automations continue working correctly using the Alfen power sensor.

---

## Integration Options

### Option A: Official Tesla Integration (Recommended)

HA has included an official Tesla integration since HA 2024.x, using the Tesla Fleet API.

**Advantages:**
- No manual token management (OAuth flow via HA)
- More stable than unofficial integrations
- Token refresh handled automatically
- Less aggressive polling available

**Setup:**
1. Go to **Settings → Integrations → + Add → Tesla**
2. Follow the OAuth authentication flow (redirects to Tesla's login page)
3. Grant the requested permissions
4. Tesla vehicles are automatically discovered

**After setup — reduce polling interval:**
1. Go to **Settings → Integrations → Tesla → [your car] → Configure**
2. Set polling interval to **300 seconds** (5 minutes) or higher
3. Tesla vehicles go to sleep when stationary — aggressive polling prevents sleep and drains the 12V battery

### Option B: alandtse/tesla_custom (HACS — Unofficial)

**Install:**
1. HACS → Integrations → + → Search "Tesla Custom Integration"
2. Install and restart HA
3. Go to **Settings → Integrations → + Add → Tesla Custom**

**Token Setup (required for alandtse):**

The alandtse integration requires a refresh token from Tesla. Tesla changed their authentication method in 2023 to OAuth + MFA, making token generation more complex.

**Method 1: Auth for Tesla app (iOS/Android)**
1. Download "Auth for Tesla" app
2. Log in with your Tesla account
3. Copy the refresh token

**Method 2: TeslaAuth Python script**
```bash
pip install teslajsonpy
python3 -c "
from teslajsonpy.teslaproxy import TeslaProxy
# Follow prompts to authenticate
"
```

**Token expiry:** Tesla refresh tokens expire every **8 weeks**. You must regenerate the token before expiry or the integration stops working. Set a calendar reminder.

### Option C: TeslaMate (Read-only, No Sleep Interruption)

[TeslaMate](https://docs.teslamate.org/) is an open-source Tesla data logger that uses a dedicated polling architecture designed to minimize sleep interruptions:
- Uses the car's native streaming API when awake
- Does not poll the car when it's asleep
- Stores all data in InfluxDB / PostgreSQL
- Provides a Grafana dashboard
- Can publish data to MQTT → HA sensor

This is the best option for read-only data (SOC history, efficiency, trips) without keeping the car awake.

TeslaMate does NOT provide charging control — use either the official HA Tesla integration or alandtse for that.

---

## Why Tesla SOC is Unreliable

1. **Cloud dependency**: Tesla's API is cloud-hosted. Network issues, Tesla server maintenance, or API changes can make it unavailable for hours.

2. **Sleep interruption**: Polling the API keeps the car's communication module awake, which slowly drains the 12V auxiliary battery. In cold weather this is worse.

3. **Token expiry**: alandtse tokens expire every 8 weeks. When expired, the integration goes unavailable until the token is renewed.

4. **Rate limiting**: Tesla has started rate-limiting API requests. Too-frequent polling can trigger temporary blocks.

5. **Data staleness**: When the car is asleep (to save energy), the API returns the last-known SOC, which may be hours old.

---

## Recommended Polling Configuration

Regardless of which integration you use, configure the polling interval conservatively:

| Scenario | Recommended interval |
|---|---|
| Car is parked, not charging | 300+ seconds (5 min) |
| Car is actively charging | 60-120 seconds |
| Car is driving | 30-60 seconds |

The official Tesla integration can adjust polling dynamically based on car state. alandtse may require manual configuration.

---

## Entity Reference

### Official Tesla Integration Entities

| Entity | Description | Reliable? |
|---|---|---|
| `sensor.tesla_battery_level` | State of Charge (%) | ⚠️ Soft hint only |
| `sensor.tesla_battery_range` | Estimated range | ⚠️ Soft hint only |
| `binary_sensor.tesla_charging` | Is charging? | ⚠️ Use Alfen power instead |
| `switch.tesla_charger` | Enable/disable charging | ⚠️ Cloud-dependent |
| `number.tesla_charging_amps` | Charge amperage | ⚠️ Cloud-dependent |
| `device_tracker.tesla` | Location | ✅ When available |

### How This Repo Uses Tesla Data

| Use | Signal used | Fallback if unavailable |
|---|---|---|
| "Is car charging?" | `sensor.alfen_wallbox_active_power_total > 200W` | N/A — always available |
| "Is car connected?" | `sensor.alfen_wallbox_status != 'A'` | N/A — always available |
| SOC in notifications | `sensor.tesla_soc_if_available` | Shows "Tesla SoC: niet beschikbaar" |
| Emergency charge | `sensor.tesla_battery_level < ev_minimum_soc` | No emergency charge (safe default) |

---

## Avoiding Excessive Car Wakeups

The 12V auxiliary battery in a Tesla powers the car's electronics and communication module. If it discharges (which can happen from excessive API polling in cold weather), the car won't start and requires a jump start or service.

**To minimise wakeups:**
1. Use polling interval ≥ 300 seconds when parked
2. Disable the Tesla integration when on extended holiday if car is garaged
3. Consider TeslaMate for historical data (uses streaming API, not polling)
4. Do not implement automations that query Tesla API every minute

---

## Troubleshooting

**Tesla SOC shows "unavailable" for hours:**
- Normal — Tesla API rate limiting or car is sleeping
- Check that the car's mobile app can also connect (rules out your network)
- All EV automations continue working using Alfen power sensor

**alandtse token expired:**
- Regenerate token using Auth for Tesla app
- Update the integration with the new token
- Set a calendar reminder for 7 weeks from now

**Official integration shows "Authentication failed":**
- Go to Settings → Integrations → Tesla → Re-authenticate
- Follow OAuth flow again
