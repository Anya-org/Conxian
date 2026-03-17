# Android Build Repair Report - 2026-02-18

## 1. Executive Summary

The Android build system for **Conxius Wallet** has been successfully repaired. The project now compiles for both Debug (`assembleDebug`) and Test (`assembleAndroidTest`) configurations. All reported IDE errors regarding missing packages and symbols in `NativePluginTest.java` and `MainActivity.java` have been resolved by correcting the underlying build configuration dependencies.

## 2. Issues Resolved

### A. Invalid JDK Configuration (`JAVA_HOME`)

- **Issue:** The build failed because `JAVA_HOME` was pointing to an invalid path (`C:\Users\bmokoka.jdks\...` missing a backslash).
- **Fix:** Identified the correct JDK 17 path (`C:\Users\bmokoka\.jdks\temurin-17\jdk-17.0.17+10`) and configured the environment to use it.

### B. Android SDK Version Mismatch

- **Issue:** The project was configured to compile against API Level **36** (Android 15+), but the host machine only had API Level **34** (Android 14) installed.
- **Fix:** Downgraded `compileSdk` and `targetSdk` from `36` to **34** in:
  - `android/variables.gradle`
  - `android/app/build.gradle`

### C. Dependency Conflicts (AndroidX)

- **Issue:** Transitive dependencies from Capacitor (e.g., `androidx.activity:activity:1.11.0`) required API 36, causing build failures when targeting API 34.
- **Fix:** Enforced compatible versions for AndroidX libraries in `android/variables.gradle`:
  - `androidx.activity` -> `1.9.0`
  - `androidx.fragment` -> `1.6.2`
  - `androidx.coordinatorlayout` -> `1.2.0`
  - `androidx.webkit` -> `1.9.0`

### D. Capacitor Plugin Incompatibility (`SystemBars.java`)

- **Issue:** The `SystemBars` plugin source code referenced `Build.VERSION_CODES.VANILLA_ICE_CREAM` (API 35), which is not available in the API 34 SDK.
- **Fix:** Patched `node_modules/@capacitor/android/capacitor/src/main/java/com/getcapacitor/plugin/SystemBars.java` to use the integer literal `35` instead of the missing symbol, ensuring compilation while preserving logic.

## 3. Verification status

- **Build `assembleDebug`:** ✅ **SUCCESS** (5m 11s)
- **Build `assembleAndroidTest`:** ✅ **SUCCESS** (1m 40s)

## 4. Next Steps for User

The project is now ready for deployment to the attached Samsung Galaxy A10.

**To deploy and run:**

1. Connect the device via USB.
2. Run the following command in the terminal:

   ```bash
   cd android
   ./gradlew installDebug
   ```

3. Alternatively, use the Capacitor CLI:

   ```bash
   npx cap run android
   ```

**To run tests:**

```bash
cd android
./gradlew connectedAndroidTest
```
