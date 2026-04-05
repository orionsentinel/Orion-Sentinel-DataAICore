# SolarEdge WiFi Modbus — Deprecation Warning & Solutions

## ⚠️ Critical Warning — Read This First

SolarEdge is **actively removing WiFi Modbus TCP support** in inverter firmware updates. This is not a rumour — it is documented SolarEdge policy as of 2024. Inverters running recent firmware may already have WiFi Modbus disabled. **Your SE10000H is currently WiFi-only. The Modbus connection WILL break on the next SolarEdge firmware push if you do not run an Ethernet cable first.**

All battery automations in this repository depend on Modbus. Without it:
- Battery control is unavailable
- Solar production data is unavailable
- Price-responsive automations cannot run

---

## Priority Action: Run an Ethernet Cable (Permanent Solution)

This is the **only permanent fix**. Everything else is a temporary workaround.

### Where is the Ethernet port on the SE10000H?

The RJ45 port is located on the **bottom of the inverter, behind the communication cover** (the small panel at the bottom held by a screw). It is labelled `ETH` or similar. You need to:

1. Remove the communication cover (small Phillips screw)
2. Route a CAT6 cable from the inverter to your home network (router or switch)
3. Connect and verify the inverter gets a DHCP address
4. Assign a **static DHCP lease** in your router for the inverter MAC address (important for Modbus TCP reliability)

### Typical NL Installation

In most Dutch homes, the SolarEdge SE10000H is installed in the **meterkast** (meter cupboard) or **garage**, often near the main distribution board. A router or network switch is often nearby or in the same room. Running a short Ethernet cable (1–5m) is almost always feasible.

**What to tell your electrician:**
> "Ik heb een UTP kabel nodig van de omvormer naar de router/switch, CAT6 of beter. De kabel hoeft niet door de muur maar mag langs de kabelgoot lopen."

### After Connecting Ethernet

1. The inverter will get a new IP address via DHCP (check your router's DHCP table)
2. Assign a static DHCP reservation for the inverter's MAC address (typically found in the router's DHCP clients list)
3. Update `secrets.yaml`: `solaredge_modbus_host: "192.168.1.XXX"` (new static IP)
4. Reconfigure SolarEdge Modbus Multi integration with the new IP
5. Verify connectivity: the integration should show entities as available within a few minutes

---

## Interim Solution: ha-modbusproxy Add-on

If running Ethernet immediately is not possible, use the **ha-modbusproxy** add-on as a temporary bridge. This proxies Modbus TCP requests from HA through the Raspberry Pi to the inverter over WiFi.

**Important limitation:** This still uses the inverter's WiFi interface. If SolarEdge disables WiFi Modbus in a firmware update, this proxy will also stop working. **Only Ethernet is permanent.**

### Install ha-modbusproxy

1. In HA: **Settings → Add-ons → Add-on Store** (button in bottom-right)
2. Click the three-dot menu → **Repositories**
3. Add: `https://github.com/adamoutler/ha-modbusproxy` (verify this URL in HACS add-on store — it may change)
4. Find **Modbus Proxy** in the store and click **Install**

### Configure ha-modbusproxy

In the add-on configuration (Settings → Add-ons → Modbus Proxy → Configuration):

```yaml
upstream_host: "192.168.1.XXX"   # ← your inverter's WiFi IP address
upstream_port: 1502               # SolarEdge WiFi Modbus port (NOT 502)
listen_port: 502                  # Port HA will connect to (on localhost)
```

> **Note:** SolarEdge WiFi Modbus uses port **1502**, not the standard 502.
> The proxy listens on 502 locally, so HA connects to the Pi's IP on port 502.

### Configure SolarEdge Modbus Multi to Use the Proxy

In the SolarEdge Modbus Multi integration settings:
- **Host:** `localhost` or `127.0.0.1` (the Raspberry Pi itself)
- **Port:** `502` (the proxy's listen port)
- **Device ID:** `1`

### Verify the Proxy is Working

1. Start the add-on
2. Check the add-on logs for connection messages
3. In HA, check if `sensor.solaredge_i1_ac_power` is available
4. Check `binary_sensor.modbus_available` — should be `on`

---

## What Happens When WiFi Modbus Breaks

When a SolarEdge firmware update disables WiFi Modbus:

1. `sensor.solaredge_i1_ac_power` → `unavailable`
2. `binary_sensor.modbus_available` → `off`
3. Watchdog automation `watchdog_modbus_unavailable` fires after 10 minutes
4. Battery mode forced to `SELF_CONSUME` (safe fallback)
5. You receive a notification with instructions

**Recovery (without Ethernet):** You cannot recover without either:
- Running an Ethernet cable (permanent fix)
- Downgrading inverter firmware (not supported by SolarEdge)
- Using the SolarEdge Cloud API instead of Modbus (very limited — no battery control)

---

## Verifying Modbus is Enabled on the SE10000H

### Method: LCD Panel (no installer account needed)

1. Long-press the LCD button until the P menu appears
2. Navigate to **Comm** (use short presses)
3. Look for **Modbus TCP** → should show **Enabled**
4. Note the IP address under **Comm → LAN** (Ethernet) or **Comm → WiFi** (current connection)

### Method: SetApp (requires installer access)

1. Download SolarEdge SetApp (may require installer credentials — ask your installer)
2. Connect via Bluetooth
3. Navigate to **Communication → Modbus TCP → Enable**
4. Set **Keep Alive:** 300 seconds (prevents connection drops)

---

## Enabling Modbus TCP (if disabled after firmware update)

If Modbus gets disabled by a firmware update (WiFi path):

1. Access SetApp or use the LCD method above
2. Re-enable Modbus TCP
3. Note: SolarEdge may require you to use Ethernet for Modbus in newer firmware — plan accordingly

---

## Recommended: Static IP Assignment

Whether using WiFi or Ethernet, always assign a **static DHCP reservation** for the inverter:

1. Find the inverter MAC address: check your router's DHCP client list after it connects
2. In your router, add a DHCP reservation: MAC → fixed IP (e.g., `192.168.1.150`)
3. Update `secrets.yaml` and the Modbus Multi integration with this IP
4. This prevents the IP from changing and breaking the Modbus connection

---

## Summary: Decision Tree

```
Is Ethernet cable connected to inverter?
├── YES → Update Modbus Multi with Ethernet IP. You're safe from deprecation.
└── NO  ┬── Can I run a cable soon?
        ├── YES → Run the cable ASAP. Meanwhile:
        │         Install ha-modbusproxy as interim. 
        └── NO  → Install ha-modbusproxy as interim.
                  Accept that WiFi Modbus may break on next firmware update.
                  Plan for Ethernet installation.
```
