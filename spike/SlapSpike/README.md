# SlapSpike — Weekend 1 IOKit probe (v2)

Throwaway. The only goal: **confirm we can read the Apple Silicon accelerometer
from an unsigned, user-mode Swift binary, with enough resolution to detect a slap.**

If yes, real SlapShift app proceeds. If no, the plan reshapes.

## What v2 does differently than v1

v1 used `IOHIDManager` + matched on the standard Sensor usage page (0x20) and
called the wrong callback (`InputValueCallback`). All three were wrong:

1. `IOHIDManager` requires a signed binary. `swift run` produces an unsigned
   binary, so device open failed with `kIOReturnUnsupported`.
2. The Apple Silicon accelerometer lives on the vendor-specific HID page
   `0xFF00`, not the standard sensor page `0x20`.
3. The sensor delivers raw HID reports (use `InputReportCallback`), not
   discrete HID elements (`InputValueCallback`).

v2 uses the `IOServiceMatching("AppleSPUHIDDevice")` path which works for
unsigned binaries, filters by `PrimaryUsagePage=0xFF00, PrimaryUsage=3`, wakes
the sensor via three `IOHIDDeviceSetProperty` calls, and parses the 22-byte
Bosch BMI286 report format (int32 Q16 XYZ at offsets 6/10/14, scale 65536).

Technique credit (see `main.swift` header for full attribution):
- [olvvier/apple-silicon-accelerometer](https://github.com/olvvier/apple-silicon-accelerometer)
- [AbdullahFID/MacSlapApp](https://github.com/AbdullahFID/MacSlapApp)
- [taigrr/spank](https://github.com/taigrr/spank)

## Run

```bash
cd spike/SlapSpike
swift run SlapSpike
```

Requires Xcode command-line tools (`xcode-select --install` if missing). The
first run may prompt for Input Monitoring permission for your Terminal app
(System Settings → Privacy & Security → Input Monitoring). Grant, re-run.

No sudo required — `spank`'s `geteuid != 0` check is over-cautious; the SPU
device opens fine from a user-mode process with Input Monitoring granted.

## Expected output (pass case)

```
== SlapSpike v2 — AppleSPUHIDDevice path ==

Phase 1: searching for AppleSPUHIDDevice services...
  found SPU dev #1: page=0xFF00 usage=0x03  [ACCEL]
  found SPU dev #2: page=0xFF00 usage=0x09  [gyro]
Phase 1 done: scanned 2 SPU device(s).

Phase 2: opening accelerometer device...
  device opened.
  sensor woken (ReportInterval=1000us, Reporting=on, Power=on).

Phase 3: listening for 10s.

  → Slap your MacBook (firmly, on the palm rest, a few times!)
  → Watch for ⚡ markers when magnitude exceeds 1.4g.

  t= 0.25s  x=+0.012g  y=-0.008g  z=+0.998g  mag=0.998g
  t= 0.50s  x=+0.011g  y=-0.009g  z=+1.001g  mag=1.001g
  ⚡ SLAP-LIKE EVENT  t=2.34s  mag=3.82g
  t= 2.50s  x=-0.421g  y=+0.103g  z=+0.911g  mag=1.011g
  ⚡ SLAP-LIKE EVENT  t=4.87s  mag=4.61g
  ...

== Done ==
Reports received:   1247
Max magnitude:      4.612g (at t=4.87s)
Slap-like events:   3  (threshold 1.4g)

✓  SUCCESS. Sensor works. Slap detection is feasible.
   Use the max-magnitude value to set the threshold in SlapClassifier.swift.
```

## What to record after a successful run

Save these numbers for `Motion/SlapClassifier.swift` calibration in the real app:

- **Idle magnitude:** roughly 1.0g (gravity) at rest. Note any drift.
- **Slap peak magnitude:** several samples. Threshold should sit 30-50% below the median peak.
- **Reports per second:** roughly 125Hz expected. Confirm.
- **Inter-slap timing:** if you double-slap, note the millisecond gap between peaks. Sets the debounce window.

## Failure modes to log

If the spike fails, the failure tells us where the foundation cracks:

- **Phase 1 scans 0 SPU devices** → SPU is gone on this hardware. Stop. Microphone pivot.
- **Phase 1 finds devices but none match 0xFF00/3** → format changed. Re-enumerate all SPU device properties.
- **Phase 2 IOHIDDeviceOpen returns non-success** → permission or signing issue. Check Input Monitoring.
- **Phase 3 zero reports despite open success** → sensor wasn't woken. Try different property keys (`ReportInterval` value, etc).
- **Phase 3 reports but garbage magnitudes** → BMI286 parse is wrong on this hardware. Check raw byte dumps that v2 prints for the first 5 failed parses.

Document outcome under `PLAN.md` → Part 4 → Weekend 1 → exit criteria.
