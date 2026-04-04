# Setup Guide

Step-by-step setup for the HA energy automation package on a Dutch household with SolarEdge SE10000H, upcoming SolarEdge Home Battery 9.7kWh, Nord Pool NL dynamic contract, EV charger, and Stedin three-phase P1 meter (HomeWizard).

---

## 1. Enable Packages in `configuration.yaml`

Add the packages directory to your HA configuration:

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Copy all files from `packages/` to your HA config directory at `config/packages/`.

---

## 2. HomeWizard P1 Meter (Local API)

**Requirements:** HomeWizard P1 with local API firmware (v5.0+)

1. Open the HomeWizard Energy app
2. Go to **Settings → Meters → [Your P1 meter] → Local API**
3. Enable the local API
4. In HA: **Settings → Integrations → + Add → HomeWizard Energy**
5. Enter the IP address shown in the app

**Expected entities:**
| Entity | Description |
|---|---|
| `sensor.p1_meter_power_import_t1` | Import tarriff 1 (kW) |
| `sensor.p1_meter_power_export_t1` | Export tarriff 1 (kW) |
| `sensor.p1_meter_energy_import_tariff_1` | Total import T1 (kWh) |
| `sensor.p1_meter_energy_export_tariff_1` | Total export T1 (kWh) |
| `sensor.p1_meter_active_power_l1_w` | Phase L1 power (W) |
| `sensor.p1_meter_active_power_l2_w` | Phase L2 power (W) |
| `sensor.p1_meter_active_power_l3_w` | Phase L3 power (W) |

---

## 3. Nord Pool Integration

**Option A: Official HA Nord Pool integration (recommended)**

1. **Settings → Integrations → + Add → Nord Pool**
2. Select area: **NL** (Netherlands)
3. Currency: **EUR**

Entity: `sensor.nord_pool_nl_current_price`

**Option B: HACS Nord Pool**

1. Install via HACS: search for "Nord Pool"
2. Configure with area `NL`

> **Note:** Entity names differ between integrations. See `docs/ENTITY_NAMES.md` for mapping.

---

## 4. Forecast.Solar Integration

1. **Settings → Integrations → + Add → Forecast.Solar**
2. Configure with your panel specs:
   - **Latitude/Longitude:** your address (auto-filled from HA)
   - **Declination (tilt):** angle of your panels from horizontal (e.g., 35)
   - **Azimuth:** direction panels face (0=N, 90=E, 180=S, 270=W; south-facing = 180)
   - **kWp:** your total installed capacity (e.g., 4.0)
3. Optionally configure a Forecast.Solar API key for more accurate data

**For Solcast (more accurate, recommended):**
1. Register free account at solcast.com
2. Install via HACS: "Solcast PV Solar"
3. Configure with your API key and site rooftop specs
4. Update entity names in `packages/solar_forecast.yaml`

---

## 5. SolarEdge Modbus TCP Setup (SE10000H)

### Enable Modbus TCP on the Inverter

**Method 1: WiFi Hotspot (no installer access needed)**

1. Long-press the inverter LCD button until "P" menu appears
2. Navigate to **Comm → RS485** and note settings
3. Navigate to **Comm → Modbus TCP** → set to **Enabled**
4. Note the IP address shown under **Comm → Eth** (connect to LAN first)

**Method 2: SetApp (recommended for full access)**

1. Download SolarEdge SetApp (requires installer account or request from SolarEdge)
2. Connect via Bluetooth
3. Navigate to **Communication → Modbus TCP → Enable**

### Ethernet Connection (Strongly Recommended)

For reliable Modbus TCP, use an Ethernet cable instead of WiFi:

1. Connect RJ45 cable from inverter to your home network switch/router
2. Assign a static DHCP lease for the inverter MAC address in your router
3. Note the static IP (e.g., `192.168.1.150`)

### Install SolarEdge Modbus Multi (HACS)

1. **HACS → Integrations → + → Search "SolarEdge Modbus Multi"**
2. Install and restart HA
3. **Settings → Integrations → + Add → SolarEdge Modbus Multi**
4. Configure:
   - **Host:** inverter IP address (e.g., `192.168.1.150`)
   - **Port:** `502`
   - **Device ID:** `1`
   - **Read battery data:** `Yes` (after battery install)
   - **Read meter data:** `Yes`

---

## 6. HACS Integrations to Install

| Integration | Purpose | HACS Search |
|---|---|---|
| **SolarEdge Modbus Multi** | Inverter/battery control via Modbus | `SolarEdge Modbus Multi` |
| **AIO Energy Management** | Cheapest/most expensive hour scheduling | `AIO Energy Management` |
| **EV Smart Charging** | Smart EV charging integration | `EV Smart Charging` |
| **Solcast** *(optional)* | Better solar forecast | `Solcast PV Solar` |
| **Frank Energie** *(optional)* | Frank Energie dynamic pricing | `Frank Energie` |

### Frontend Cards (HACS → Frontend)

| Card | HACS Search |
|---|---|
| **Mushroom Cards** | `Mushroom` |
| **ApexCharts Card** | `ApexCharts Card` |
| **Mini Graph Card** | `Mini Graph Card` |

---

## 7. Discover Your Entity Names

Run this template in **Developer Tools → Template** to find your SolarEdge entities:

```jinja2
{% set keywords = ['solaredge', 'modbus', 'inverter', 'storage', 'battery', 'meter'] %}
{% for state in states %}
  {% for kw in keywords %}
    {% if kw in state.entity_id %}
      {{ state.entity_id }}: {{ state.state }}
    {% endif %}
  {% endfor %}
{% endfor %}
```

See `docs/ENTITY_NAMES.md` for the full entity mapping table.

---

## 8. Customization Parameters

Update these values in the package files to match your setup:

| Parameter | File | Default | Description |
|---|---|---|---|
| `battery_min_soc` | `energy_prices.yaml` | `10%` | Minimum battery SoC before "battery low" alert |
| `battery_charge_threshold` | `energy_prices.yaml` | `0.05 €/kWh` | Spot price below which grid charging is triggered |
| `ev_cheap_price_limit` | `energy_prices.yaml` | `0.08 €/kWh` | Spot price limit for cheap EV charging hours |
| `network_tariff` | `energy_prices.yaml` | `0.0450 €/kWh` | Your network/transport tariff |
| `solar_sunny_day_threshold` | `solar_forecast.yaml` | `15 kWh` | Forecast kWh above which tomorrow is "sunny" |
| `solar_cloud_day_threshold` | `solar_forecast.yaml` | `5 kWh` | Forecast kWh below which tomorrow is "cloudy" |
| `ev_target_soc` | `ev_charging.yaml` | `80%` | Default EV charge target |
| `ev_minimum_soc` | `ev_charging.yaml` | `20%` | EV emergency charge threshold |

---

## 9. Replace Appliance and EV Entity Placeholders

### Appliances (`packages/appliances.yaml`)

Replace these placeholder entities:

```yaml
switch.washing_machine_smart_plug  # ← your washing machine smart plug
switch.dishwasher_smart_plug       # ← your dishwasher smart plug
switch.dryer_smart_plug            # ← your dryer smart plug
```

Popular smart plugs: IKEA TRADFRI, TP-Link Kasa, Shelly 1PM, Sonoff S26

### EV Charger (`packages/ev_charging.yaml` and `packages/battery_control.yaml`)

Replace:

```yaml
switch.ev_charger           # ← your EV charger switch entity
sensor.ev_state_of_charge   # ← your EV SoC sensor
binary_sensor.ev_plugged_in # ← your EV plugged-in sensor
```

See `docs/ENTITY_NAMES.md` for Easee, go-E, Zaptec, and Alfen entity mappings.

---

## 10. Notification Service

Replace all instances of `notify.mobile_app` with your notification service:

```yaml
notify.mobile_app_[your_phone_name]  # e.g. notify.mobile_app_pixel_8
notify.pushbullet
notify.telegram
```

Find your notify services: **Developer Tools → Services → Search "notify."**

---

## 11. Add Dashboard

1. **Settings → Dashboards → + Add Dashboard**
2. Name: `Energie`, Icon: `mdi:solar-power`, URL: `energy`
3. Click the new dashboard → **⋮ → Edit Dashboard → Raw configuration editor**
4. Paste the contents of `dashboards/energy_dashboard.yaml`
5. Save

> **Note:** Requires HACS frontend cards installed first (Mushroom, ApexCharts, Mini Graph Card).

---

## 12. After Battery Install — Checklist

Once the SolarEdge Home Battery 9.7 is installed and commissioned:

- [ ] Confirm `sensor.solaredge_b1_state_of_energy` is available
- [ ] Confirm `sensor.solaredge_b1_dc_power` is available
- [ ] Confirm `sensor.solaredge_b1_status` is available
- [ ] Confirm `select.solaredge_i1_storage_control_mode` is available
- [ ] Confirm `select.solaredge_i1_storage_default_mode` is available
- [ ] Enable "Storage controls" in SolarEdge Modbus Multi integration settings
- [ ] Enable "Home Hub" / "Battery" in the SE App
- [ ] Test `script.reset_battery_to_self_consumption` from Developer Tools → Services
- [ ] Verify `automation.battery_enable_remote_control_startup` runs on restart
- [ ] Check `sensor.battery_soc_pct` shows correct percentage
- [ ] Monitor `select.solaredge_i1_storage_default_mode` changes in logbook

See `docs/NOW_VS_LATER.md` for full commissioning checklist.
