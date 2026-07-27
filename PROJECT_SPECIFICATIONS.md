# PataGilid: Philippine Mountain Hiking & Summit Tracker
## Architecture & Project Specifications

This document outlines the core domain models, feature specifications, media strategy, and cloud infrastructure budgeting for the **PataGilid** native iOS application.

---

### 1. Application Overview
**PataGilid** is a specialized outdoor adventure application designed for mountaineers and hikers to log their journeys across Philippine mountains. Hikers can track their successful summit accomplishments, aborted attempts (turn backs), hike timestamps, and highlight photo memories.

* **Google Account Requirement:** A valid **Google Account** (authenticated via Google Sign-In and Firebase Authentication) is strictly required for hikers to save their mountaineering progress, log summit attempts, and synchronize climbing records across devices.

---

### 2. Core Domain Data Models (Cloud Firestore)

#### A. `Mountain` Entity (Master Reference Data)
Represents a peak in the Philippines with geographical and technical mountaineering classifications.
* **Identifiers & Naming:**
  * `id`: Unique document identifier (e.g., `mt_pulag`, `mt_apo`).
  * `name`: Display name of the mountain (e.g., *"Mt. Pulag"*, *"Mt. Guiting-Guiting"*).
* **Geographically Categorized Locations:**
  * `coordinates`: Latitude and longitude pairs used for drawing pins and maps via Google Maps iOS SDK.
  * `elevationMASL`: Meters Above Sea Level (elevation rating).
  * `region`: Administrative or provincial region (e.g., *CAR*, *CALABARZON*, *Central Visayas*, *SOCCSKSARGEN*).
  * `islandGroup`: Major island classification (*Luzon*, *Visayas*, or *Mindanao*).
* **Technical Trail Specs:**
  * `difficultyLevel`: Philippine mountaineering difficulty scale (e.g., *3/9*, *6/9*, *9/9*, and *Major/Minor* classification).
  * `trailClass`: Technical terrain grading (e.g., *Class 1–2 (Walking)*, *Class 3 (Scrambling)*, *Class 4 (Ropes required)*).

#### B. `HikeLog / UserProgress` Entity (User Activity Record)
Stores an individual hiker's personal history and statistics for a targeted mountain.
* **References & Ownership:**
  * `userId`: Reference to the authenticated Firebase Auth / Google Sign-In user account.
  * `mountainId`: Foreign key reference to the targeted `Mountain`.
* **Activity & Counters:**
  * `dateTime`: Date and time when the hike occurred or was logged.
  * `timesSummited`: Integer counter tracking successful summit completions.
  * `timesTurnedBack`: Integer counter tracking aborted ascents or turn backs due to weather/health/time constraints.
* **Media Memories:**
  * `photoUrls`: Array of string URLs pointing to compressed JPEG images stored in Firebase Cloud Storage.

---

### 3. Sorting, Filtering, & Grouping Specifications
To give hikers seamless ways to browse peaks and review their climbing resumes, the UI and database queries must support:
* **Sorting (Order By):**
  * **MASL (Elevation):** Order mountains from highest elevation to lowest (or vice versa).
  * **Date:** Order activity logs chronologically by recent climbing activity.
  * **Name (Alphabetical):** A-to-Z ordering by peak title.
* **Grouping (Sectioned UI Lists / Category Pickers):**
  * **By Region:** Grouped into regional folders (e.g., Cordillera Administrative Region, CALABARZON).
  * **By Island Group:** Filtered or separated by *Luzon*, *Visayas*, and *Mindanao*.
  * **By Difficulty:** Grouped by technical difficulty (e.g., Minor Climbs [1/9 to 3/9] vs. Major Climbs [4/9 to 9/9]).

---

### 4. Media & Storage Architecture

#### A. Media Policies & Quota Constraints
To preserve clean app performance, rapid loading over variable cellular signals, and zero cloud hosting costs:
1. **Media Type Restriction:** **Images Only.** Video uploads are explicitly disallowed.
2. **Per Log Entry Cap:** **Maximum 3 photos per climb entry.** Encourages hikers to pick their top three storytelling highlights (e.g., jump-off trailhead, scenic trail view, summit marker photo).
3. **Per User Account Cap:** **Maximum 100 photos per user account.** Serves as a generous safety cap allowing more than 33 fully documented multi-photo mountain climbs per user while preventing server storage abuse.

#### B. Client-Side Compression Optimization
Before transmitting any selected photograph to Firebase Cloud Storage, the iOS client app must process and compress raw camera roll images:
* **Resolution & Quality Target:** Max dimension ~1080px width/height encoded with Swift's `jpegData(compressionQuality: 0.6)`.
* **Average File Size:** **~120 KB per photo** (down from 3.5MB–5.0MB raw iPhone camera captures).

#### C. Firebase Free Tier (Spark Plan) Math & Budgeting
Under Firebase Cloud Storage's **5 GB free storage** tier:
* **Storage per Hike Log (3 photos max):** 3 × 120 KB = **~360 KB total per climb entry**.
* **Free Tier Capacity:** Holds approximately **13,888 fully documented multi-photo climb logs** completely free of charge.
* **User Support Ceiling:** Supports over **1,388 hyper-active mountaineers** who hit their full 100-photo account maximum without exceeding the $0.00 pricing tier.
* **Pay-as-you-go Scaling:** If exceeded, additional storage costs just ~$0.026 per GB/month (~$0.13 cents per month for every additional 40,000 compressed photos).

---

### 5. Technical Stack & SDK Security Setup
* **Authentication & Identity:** **Google Sign-In (`GoogleSignIn-iOS`)** configured with **Firebase Authentication**. A Google Account is mandatory for users to persist summit histories, upload highlight photos, and write records to Cloud Firestore.
* **Entry Point:** Initialized in `PataGilidApp.swift` via an `@UIApplicationDelegateAdaptor`.
* **Zero Hardcoded Secrets:** Sensitive Firebase, Google Sign-In, and Google Maps API keys reside exclusively in `GoogleService-Info.plist`, which is excluded from source control via `.gitignore`.
* **Runtime Initialization:** `AppDelegate.application(_:didFinishLaunchingWithOptions:)` dynamically extracts credentials from `FirebaseApp.app()?.options` at launch to supply keys to `GMSServices` (Google Maps SDK) and `GIDSignIn` (Google Sign-In) cleanly and securely.
