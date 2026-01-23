package com.conxius.wallet;

import android.util.Base64;
import org.json.JSONArray;
import org.json.JSONObject;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

public class NativeCrypto {
    private static final int GCM_TAG_BITS = 128;

    public static byte[] decryptVault(String vaultJson, String pin) throws Exception {
        JSONObject envelope = new JSONObject(vaultJson);
        int v = envelope.getInt("v");
        if (v != 1) throw new IllegalArgumentException("Unknown vault version");

        JSONArray saltJson = envelope.getJSONArray("salt");
        JSONArray ivJson = envelope.getJSONArray("iv");
        JSONArray dataJson = envelope.getJSONArray("data");

        byte[] salt = new byte[saltJson.length()];
        for(int i=0; i<saltJson.length(); i++) salt[i] = (byte)saltJson.getInt(i);

        byte[] iv = new byte[ivJson.length()];
        for(int i=0; i<ivJson.length(); i++) iv[i] = (byte)ivJson.getInt(i);

        byte[] data = new byte[dataJson.length()];
        for(int i=0; i<dataJson.length(); i++) data[i] = (byte)dataJson.getInt(i);

        // Derive Key: PBKDF2WithHmacSHA256, 200000 iterations
        SecretKeyFactory factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
        PBEKeySpec spec = new PBEKeySpec(pin.toCharArray(), salt, 200000, 256);
        SecretKey tmp = factory.generateSecret(spec);
        SecretKeySpec secret = new SecretKeySpec(tmp.getEncoded(), "AES");

        // Decrypt: AES/GCM/NoPadding
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, secret, new GCMParameterSpec(GCM_TAG_BITS, iv));
        
        return cipher.doFinal(data);
    }
}
