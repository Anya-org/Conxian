# Getting Started with Conxius Development

This guide explains how to set up your environment to develop, test, and build the Conxius Wallet.

## Prerequisites

- **Node.js**: v18.0.0 or higher
- **Android Studio**: Arctic Fox or newer (for mobile builds)
- **Java**: JDK 17
- **Capacitor CLI**: `npm install -g @capacitor/cli`

## Initial Setup

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/conxian/conxius-wallet.git
    cd conxius-wallet
    ```

2.  **Install Dependencies**
    ```bash
    npm install
    ```

3.  **Environment Variables**
    Create a `.env` file in the root directory:
    ```env
    VITE_GEMINI_API_KEY=your_key_here
    VITE_NETWORK=mainnet
    ```

## Development Workflow

### Web Development (Mock Enclave)
To work on the UI and core logic without an Android device:
```bash
npm run dev
```
The app will run in "Mock Enclave" mode, using `sessionStorage` instead of the native hardware keystore.

### Android Development
1.  **Build the Web Assets**
    ```bash
    npm run build
    ```

2.  **Sync with Capacitor**
    ```bash
    npx cap sync android
    ```

3.  **Open in Android Studio**
    ```bash
    npx cap open android
    ```
    From Android Studio, you can run the app on a physical device or emulator. **Note**: Enclave features require a physical device with a Secure Element / TEE for full hardware security.

## Testing

### Unit Tests (Vitest)
```bash
npm test
```

### Native Tests (Android)
```bash
cd android && ./gradlew test
```

## Build for Production

1.  **Production Web Build**
    ```bash
    npm run build
    ```

2.  **Generate Signed APK/Bundle**
    Use Android Studio's "Generate Signed Bundle / APK" wizard.

---

For technical details on the enclave, see the **[Enclave Architecture](./enclave-architecture.md)** guide.
