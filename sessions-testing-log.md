# Sessions Feature Testing Log

**Device:** Dallas Caley's iPhone
**App Version:** 1.8.2 (build 5)
**Date Started:** 2026-06-14

---

## Test 1 — Band Practice Recording (Voice)

**Feature:** Band Practice tab → Record button
**Input:** Voice (phone microphone)
**Action:** Record a short voice clip, save it

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| Tap Record button | Timer starts, mic active | Works | PASS |
| Speak into phone mic | Recording captures audio | Works | PASS |
| Tap Stop button | Recording stops, save sheet appears | Works | PASS |
| Enter name and save | Session appears in list | Works | PASS |
| Tap play on saved session | Audio plays back clearly | Works | PASS |
| Playback on web interface | Audio plays correctly | Works | PASS |

**Notes:**
- UI Issue: Stop button text truncated — button not wide enough for "Stop" label. See Issue #1.

---

## Test 2 — Individual Recording (Voice)

**Feature:** Individual tab → My Recordings → Record button
**Input:** Voice (phone microphone)

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| Tap Record button | Timer starts, mic active | Works | PASS |
| Speak into phone mic | Recording captures audio | Works | PASS |
| Tap Stop button | Save sheet appears | Works | PASS |
| Select instrument (optional) | Instrument picker works | Works | PASS |
| Save recording | Session appears in My Recordings | Works | PASS |
| Playback | Audio plays back clearly | Works | PASS |

**Notes:**

---

## Test 3 — Mashup: Select Backing Track

**Feature:** Individual tab → Mashups → Create Mashup
**Prerequisite:** At least one individual session exists

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| Tap "Create Mashup" | Backing track list appears | Works | PASS |
| Sessions listed | Own individual + band member sessions shown | Works | PASS |
| Tap a session | "Downloading backing track..." appears | Works | PASS |
| Download completes | Record screen appears with session name | Works | PASS |

**Notes:**

---

## Test 4 — Mashup: Record Over Backing Track

**Feature:** Mashup recording screen
**Input:** Voice over backing track
**Setup:** USB headphones connected via 3.5mm to USB-C adapter

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| Tap record button | Backing track plays through headphones, timer starts | Backing NOT audible in headphones | FAIL |
| Speak/sing while backing plays | Both audible during recording | Recording worked, backing silent | FAIL |
| Tap stop button | "Processing recording..." appears | Works | PASS |
| Processing completes | Volume adjustment screen appears | Works | PASS |
| Playback of mixed result | Both tracks audible | Works | PASS |

**Notes:**
- Issue: Backing track not audible through headphones during recording
- Root cause: `.defaultToSpeaker` audio session option interfering with headphone output
- See Issue #2

---

## Test 5 — Mashup: Adjust Volumes

**Feature:** Mashup volume adjustment screen

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| Backing Track slider | Adjusts from 0-100% | | |
| Your Recording slider | Adjusts from 0-100% | | |
| Tap "Preview Mix" | "Generating preview..." then preview screen | | |

**Notes:**

---

## Test 6 — Mashup: Preview and Save

**Feature:** Mashup preview screen

| Step | Expected | Actual | Status |
|------|----------|--------|--------|
| Tap play button | Mixed audio plays | | |
| Both tracks audible | Backing + recording mixed at set volumes | | |
| Tap stop button | Playback stops | | |
| Tap "Save Mashup" | Save sheet appears | | |
| Enter name and save | "Saving mashup..." then returns to Sessions | | |
| Find saved mashup | Appears in Individual sessions list | | |
| Play saved mashup | Mixed audio plays correctly | | |

**Notes:**

---

## Test 7 — Mashup: Edge Cases

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Cancel mid-download | Returns to backing selection | | |
| Cancel mid-recording | Returns to ready-to-record state | | |
| Re-record after initial | Clears previous, starts fresh | | |
| Backing 0%, Recording 100% | Only recording audible | | |
| Backing 100%, Recording 0% | Only backing audible | | |
| Long recording (2+ min) | Handles without issues | | |

**Notes:**

---

## Test 8 — Session Playback

**Feature:** Playing sessions from the list

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Tap play on any session | Now Playing bar appears, audio plays | | |
| Tap stop/X on Now Playing | Playback stops, bar disappears | | |
| Tap different session while playing | Switches to new session | | |
| Play band member session | Streams and plays correctly | | |

**Notes:**

---

## Test 9 — Session Management

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Edit session name | Name updates in list | | |
| Change session band | Band assignment updates | | |
| Change instrument | Instrument updates | | |
| Delete session | Removed from list | | |
| Rate session (1-10) | Rating chip updates | | |
| Clear rating | Returns to "Rate" | | |

**Notes:**

---

## Issues Found

| # | Description | Severity | Status |
|---|-------------|----------|--------|
| 1 | Stop button too narrow for "Stop" text when recording | Low | Fixed |
| 2 | Backing track not audible through headphones during mashup recording | High | Fixed |

---

## Summary

**Tests Passed:**
**Tests Failed:**
**Blocked:**

**Overall Status:**
