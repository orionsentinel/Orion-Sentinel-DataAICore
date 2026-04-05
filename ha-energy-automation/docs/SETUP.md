# Complete Setup Guide

## Before You Start: Priority Actions

**⚠️ Step 1 is the most important step. Do it first.**

---

## Step 1: Run an Ethernet Cable to the Inverter

**DO THIS BEFORE ANYTHING ELSE.**

SolarEdge is deprecating WiFi Modbus TCP in firmware updates. Your SE10000H is currently WiFi-only. Without Ethernet, the Modbus connection **will break** on the next firmware push, disabling all battery and solar monitoring automations.

- The RJ45 port is on the **bottom of the SE10000H** behind the communication cover
- Run a CAT6 cable from the inverter to your home network (router or switch)
- Assign a **static DHCP reservation** in your router for the inverter's MAC address
- Update `secrets.yaml` with the static IP: `solaredge_modbus_host: "192.168.1.XXX"`

**Can't run Ethernet immediately?** See `docs/MODBUS_PROXY.md` for the temporary ha-modbusproxy workaround. But plan for Ethernet — it's the only permanent solution.

---

## Step 2: Enable Packages in `configuration.yaml`

Add to your HA configuration file (`/config/configuration.yaml`):

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Create the directory `/config/packages/` and copy all YAML files from the `packages/` directory of this repo into it.

**Verify the packages directory:**
```
/config/
├── configuration.yaml
├── packages/
│   ├── 00_secrets_template.yaml
│   ├── 01_system_watchdogs.yaml
│   ├── 02_energy_prices.yaml
│   ├── 03_solaredge.yaml
│   ├── 04_battery_state_machine.yaml
│   ├── 05_battery_automations.yaml
│   ├── 06_alfen_ev_charging.yaml
│   ├── 07_appliances.yaml
│   └── 08_solar_forecast.yaml
└── secrets.yaml  ← you create this from template
```

---

## Step 3: Create `secrets.yaml`

Copy `packages/00_secrets_template.yaml` to `/config/secrets.yaml` (note: NOT in the packages folder) and fill in your actual values:

```bash
cp packages/00_secrets_template.yaml /config/secrets.yaml
```

Then edit `/config/secrets.yaml`:
- `notify_target`: Find your notify service in **Developer Tools → Services → search "notify."**
- `solaredge_modbus_host`: Your inverter's static IP (from Step 1)
- Other secrets: see comments in the template for instructions

**NEVER commit `secrets.yaml` — it is gitignored.**

---

## Step 4: HomeWizard P1 Meter (Local API)

**Requirements:** HomeWizard P1 HWE-P1 with firmware v5.0+

1. Open the **HomeWizard Energy app** on your phone
2. Go to **Settings → Meters → [Your P1 meter] → Local API**
3. Enable the local API toggle
4. Note the IP address shown in the app
5. In HA: **Settings → Integrations → + Add → HomeWizard Energy**
6. HA should auto-discover the meter, or enter the IP manually

**Assign a static DHCP reservation** for the P1 meter's MAC address in your router.

Expected entity names (device name may differ):
- `sensor.p1_meter_active_power_import_l1_w` (phase L1)
- `sensor.p1_meter_active_power_import_l2_w` (phase L2)
- `sensor.p1_meter_active_power_import_l3_w` (phase L3)
- `sensor.p1_meter_total_power_import_kwh`
- `sensor.p1_meter_total_power_export_kwh`

> The SE10000H is a single-phase inverter (L1). For whole-house consumption, sum all three phases from the P1 meter.

---

## Step 5: Nord Pool Integration (NL, EUR)

1. **Settings → Integrations → + Add → Nord Pool**
2. Configure:
   - **Area:** `NL` (Netherlands)
   - **Currency:** `EUR`
3. Click **Submit**

Expected entity: `sensor.nord_pool_nl_current_price`

The sensor's attributes contain `today` and `tomorrow` price arrays (24 values each).

> **If using Frank Energie instead of Nord Pool directly:**
> Install HACS integration "Frank Energie" and replace `sensor.nord_pool_nl_current_price` with `sensor.frank_energie_current_price` in `02_energy_prices.yaml`. Frank prices are already all-in — remove the tax calculation from the `energy_price_all_in` template.

> **Tibber users:** Use `sensor.tibber_price_current` and similar approach.

---

## Step 6: Forecast.Solar Integration

1. **Settings → Integrations → + Add → Forecast.Solar**
2. Configure with your panel specs:
   - **Latitude/Longitude:** auto-filled from HA location
   - **Declination (tilt):** angle from horizontal (e.g., 35° for typical roof pitch)
   - **Azimuth:** compass direction panels face (0=N, 90=E, 180=S, 270=W). South-facing = 180.
   - **Power (kWp):** your installed peak power (e.g., 4.0)
3. Optionally get a free API key at `forecast.solar` for more accurate data

**Expected entities:**
- `sensor.forecast_solar_energy_production_today`
- `sensor.forecast_solar_energy_production_tomorrow`
- `sensor.forecast_solar_energy_current_hour`

**Alternative: Solcast (more accurate)**
Register at `toolkit.solcast.com.au` (free tier: 10 calls/day).
Install via HACS: "Solcast PV Solar".
Then update entity names in `08_solar_forecast.yaml` (see comments in that file).

---

## Step 7: Enable Modbus TCP on SE10000H

**After running Ethernet cable from Step 1:**

### Via LCD Panel (no installer needed)

1. Long-press the LCD button until the `P` menu appears
2. Navigate to **Comm → Modbus TCP**
3. Set to **Enabled** (if not already)
4. Note the IP under **Comm → LAN** (Ethernet connection)

### Via SetApp (requires installer access — ask 50five/your installer)

1. Download **SolarEdge SetApp**
2. Connect via Bluetooth
3. **Communication → Modbus TCP → Enable**
4. Set **Keep Alive** to `300` seconds

### Verify Modbus Works

After Ethernet connection is established:
1. Check router DHCP table for inverter's IP
2. Try: `nc -z [inverter_IP] 502` from the HA terminal — should connect
3. Or use the HA Modbus integration to ping the IP

---

## Step 8: SolarEdge Modbus Multi (HACS)

1. **HACS → Integrations → + → Search "SolarEdge Modbus Multi"**
2. Install and **restart HA**
3. **Settings → Integrations → + Add → SolarEdge Modbus Multi**
4. Configure:
   - **Host:** your inverter's static IP (from secrets.yaml)
   - **Port:** `502`
   - **Modbus Device Address:** `1`
   - **Scan interval:** `30` seconds
   - **Read battery data:** `No` (for now — enable after battery install)
   - **Enable storage control:** `No` (enable after battery install)

After configuration, verify:
- `sensor.solaredge_i1_ac_power` appears (solar AC power in W)
- `sensor.solaredge_m1_ac_power` appears (grid meter power in W)
- `binary_sensor.modbus_available` shows `on`

---

## Step 9: Alfen Eve Wallbox (HACS)

**⚠️ Read `docs/ALFEN_WARNING.md` before configuring.**

1. Assign a **static IP** for the Alfen Eve in your router (DHCP reservation)
   - Find MAC address: check router's DHCP table, or sticker on the charger
2. **HACS → Integrations → + → Search "Alfen EV Wallbox" (leeyuentuen fork)**
3. Install and restart HA
4. **Settings → Integrations → + Add → Alfen EV Wallbox**
5. Configure:
   - **Host:** Alfen's static IP
   - **Password:** installer password from 50five documentation (see `secrets.yaml`)
   - **Username:** `admin` (default)

**Verify session status:**
- `binary_sensor.alfen_wallbox_https_api_login_status` should be `on`
- `sensor.alfen_wallbox_status` should show a value (A=no car, B=car connected, C=charging)
- `sensor.alfen_wallbox_active_power_total` should show charging power in W

**⚠️ Do NOT open Eve Connect or 50five app while HA is connected — see docs/ALFEN_WARNING.md**

---

## Step 10: Tesla Integration

**See `docs/TESLA_SETUP.md` for detailed instructions.**

**Recommended:** Official Tesla integration (HA 2024.x+):
1. **Settings → Integrations → + Add → Tesla**
2. Follow OAuth flow
3. Set polling interval to 300+ seconds (prevents car from staying awake)

**Important:** Tesla SOC is treated as informational only in this repo.
All EV charging decisions use the Alfen charger's power sensor.

---

## Step 11: HACS Integrations and Frontend Cards

### Integrations (HACS → Integrations)

| Integration | Purpose | Required? |
|---|---|---|
| **SolarEdge Modbus Multi** | Inverter + battery control | ✅ Required |
| **AIO Energy Management** | Cheapest/most expensive hour scheduling | ✅ Required |
| **alfen_wallbox** (leeyuentuen) | Alfen Eve control | ✅ Required |
| **tesla_custom** (alandtse) | Tesla data (if not using official) | Optional |
| **Solcast PV Solar** | Better solar forecast | Optional |
| **Frank Energie** | Frank Energie pricing (if Frank customer) | Optional |

### Frontend Cards (HACS → Frontend)

| Card | Purpose | Required for dashboard? |
|---|---|---|
| **Mushroom Cards** | Status chips and template cards | ✅ Yes |
| **ApexCharts Card** | Price bar chart | ✅ Yes |
| **Mini Graph Card** | Power history graphs | ✅ Yes |

---

## Step 12: Dashboard Setup

1. Go to **Settings → Dashboards → + Add Dashboard**
2. Name: `Energie`, Icon: `mdi:solar-power`, URL path: `energy`
3. Open the new dashboard
4. Click **⋮ (three dots) → Edit Dashboard → Raw configuration editor**
5. Replace the entire content with `dashboards/energy_dashboard.yaml`
6. Click **Save**

> **Note:** Requires all HACS frontend cards (Step 11) installed first.
> Battery-related cards will show "unavailable" until battery is installed.

---

## Step 13: Entity Name Verification

After all integrations are configured, verify entity names match what's in the package files.

Run this template in **Developer Tools → Template** to discover entities:

```jinja2
{# Find all energy-related entities #}
{% set keywords = ['solaredge', 'p1_meter', 'nord_pool', 'alfen', 'tesla', 'forecast_solar'] %}
{% for state in states | sort(attribute='entity_id') %}
  {% for kw in keywords %}
    {% if kw in state.entity_id %}
      {{ state.entity_id }}: {{ state.state }} {{ state.attributes.unit_of_measurement | default('') }}
    {% endif %}
  {% endfor %}
{% endfor %}
```

Compare the output with entity names used in the package files. If they differ, update the package files. See `docs/ENTITY_NAMES.md` for the full reference.

Also replace these placeholders in package files:
```bash
grep -r "← replace" packages/ scripts/
```

---

## Step 14: First Test Checklist

- [ ] HA Config check passes: **Settings → System → Check Configuration**
- [ ] `sensor.price_freshness_ok` = `true`
- [ ] `sensor.energy_price_all_in` shows a reasonable value (€0.10–€0.40)
- [ ] `sensor.solar_production_w` = 0 (night) or a positive value (daytime)
- [ ] `binary_sensor.modbus_available` = `on`
- [ ] `sensor.alfen_wallbox_status` not `unavailable`
- [ ] `binary_sensor.alfen_wallbox_https_api_login_status` = `on`
- [ ] `binary_sensor.cheapest_4h_overnight` exists (from AIO Energy Management)
- [ ] No errors in **Settings → System → Logs** related to the packages
- [ ] Notifications work: trigger the negative price test (set threshold high temporarily)

---

## DST (Daylight Saving Time) Notes

The Netherlands observes CET (UTC+1 winter) and CEST (UTC+2 summer).
DST transitions occur on the **last Sunday of March** (spring forward) and **last Sunday of October** (fall back).

**Potential issues on DST transition days:**
- AIO Energy Management overnight windows may shift by 1 hour
- Fixed time triggers (09:00, 13:30, 20:30, 22:00) fire at the "wrong" solar time
- Nord Pool typically publishes D+1 prices relative to CEST/CET — AIO handles this

**Recommended:** On DST transition days, manually verify that overnight appliance scheduling runs as expected and check `binary_sensor.cheapest_4h_overnight` timing.
