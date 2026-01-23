package com.conxius.wallet;

import android.util.Log;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;

// Breez SDK Imports
import breez_sdk.BlockingBreezServices;
import breez_sdk.BreezEvent;
import breez_sdk.Breez_sdkKt;
import breez_sdk.Config;
import breez_sdk.ConnectRequest;
import breez_sdk.EnvironmentType;
import breez_sdk.EventListener;
import breez_sdk.GreenlightNodeConfig;
import breez_sdk.NodeConfig;
import breez_sdk.NodeState;
import breez_sdk.Payment;
import breez_sdk.ReceivePaymentRequest;
import breez_sdk.SendPaymentRequest;
import breez_sdk.SendPaymentResponse;
import breez_sdk.OpeningFeeParams;
import kotlin.UByte;
import kotlin.UInt;
import kotlin.ULong;

@CapacitorPlugin(name = "Breez")
public class BreezPlugin extends Plugin {
    private static final String TAG = "BreezPlugin";
    private BlockingBreezServices breezServices;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private static Long reflectLongNoArgByPrefix(Object target, String methodPrefix) {
        try {
            for (Method m : target.getClass().getMethods()) {
                if (m.getParameterCount() == 0 && m.getName().startsWith(methodPrefix)) {
                    Object v = m.invoke(target);
                    if (v instanceof Long) return (Long) v;
                    if (v instanceof Number) return ((Number) v).longValue();
                    return null;
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private static Integer reflectIntNoArgByPrefix(Object target, String methodPrefix) {
        try {
            for (Method m : target.getClass().getMethods()) {
                if (m.getParameterCount() == 0 && m.getName().startsWith(methodPrefix)) {
                    Object v = m.invoke(target);
                    if (v instanceof Integer) return (Integer) v;
                    if (v instanceof Number) return ((Number) v).intValue();
                    return null;
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private static <T> T newPrivateInstance(Class<T> cls, Class<?>[] paramTypes, Object[] args) throws Exception {
        Constructor<T> c = cls.getDeclaredConstructor(paramTypes);
        c.setAccessible(true);
        return c.newInstance(args);
    }

    private static UByte createUByte(byte b) {
        try {
             // Kotlin inline class boxing
             Method m = UByte.class.getMethod("box-impl", byte.class);
             return (UByte) m.invoke(null, b);
        } catch (Exception e) {
            return null;
        }
    }

    @PluginMethod
    public void start(PluginCall call) {
        String mnemonic = call.getString("mnemonic");
        String apiKey = call.getString("apiKey");
        String inviteCode = call.getString("inviteCode"); // Greenlight invite
        String vault = call.getString("vault");
        String pin = call.getString("pin");

        if (apiKey == null) {
            call.reject("Missing apiKey");
            return;
        }

        if (mnemonic == null && (vault == null || pin == null)) {
            call.reject("Missing mnemonic OR vault/pin");
            return;
        }

        executor.submit(() -> {
            try {
                String mnemoToUse = mnemonic;
                
                // Native Decryption if Vault provided
                if (mnemoToUse == null) {
                    try {
                        byte[] seedBytes = NativeCrypto.decryptVault(vault, pin);
                        mnemoToUse = null; // Ensure we don't use mnemonic path
                        // Convert to List<UByte>
                        java.util.List<UByte> seedList = new java.util.ArrayList<>();
                        for (byte b : seedBytes) {
                            UByte ub = createUByte(b);
                            if (ub != null) seedList.add(ub);
                        }
                        // Wipe seedBytes
                        java.util.Arrays.fill(seedBytes, (byte)0);
                        
                        String safeInviteCode = inviteCode == null ? "" : inviteCode;
                        NodeConfig nodeConfig = new NodeConfig.Greenlight(new GreenlightNodeConfig(null, safeInviteCode));
                        Config config = Breez_sdkKt.defaultConfig(EnvironmentType.PRODUCTION, apiKey, nodeConfig);
                        
                        ConnectRequest connectRequest = new ConnectRequest(config, seedList, false);
                        this.breezServices = Breez_sdkKt.connect(connectRequest, new EventListener() {
                             @Override
                             public void onEvent(BreezEvent e) {
                                 Log.d(TAG, "Breez Event: " + e.toString());
                             }
                        });
                    } catch (Exception e) {
                        call.reject("Vault connect failed: " + e.getMessage());
                        return;
                    }
                } else {
                    // Mnemonic Path
                    String safeInviteCode = inviteCode == null ? "" : inviteCode;
                    NodeConfig nodeConfig = new NodeConfig.Greenlight(new GreenlightNodeConfig(null, safeInviteCode));
                    Config config = Breez_sdkKt.defaultConfig(EnvironmentType.PRODUCTION, apiKey, nodeConfig);
                    ConnectRequest connectRequest = new ConnectRequest(config, Breez_sdkKt.mnemonicToSeed(mnemoToUse), false);
                    this.breezServices = Breez_sdkKt.connect(connectRequest, new EventListener() {
                         @Override
                         public void onEvent(BreezEvent e) {
                             Log.d(TAG, "Breez Event: " + e.toString());
                         }
                    });
                }

                NodeState state = this.breezServices.nodeInfo();
                JSObject ret = new JSObject();
                ret.put("id", state.getId());
                Long maxPayableMsat = reflectLongNoArgByPrefix(state, "getMaxPayableMsat");
                ret.put("balanceMsat", maxPayableMsat != null ? maxPayableMsat : 0);
                call.resolve(ret);

            } catch (Exception e) {
                Log.e(TAG, "Failed to start Breez", e);
                call.reject("Start failed: " + e.getMessage());
            }
        });
    }

    @PluginMethod
    public void nodeInfo(PluginCall call) {
        if (breezServices == null) {
            call.reject("Not started");
            return;
        }
        try {
            NodeState state = breezServices.nodeInfo();
            JSObject ret = new JSObject();
            ret.put("id", state.getId());
            Integer blockHeight = reflectIntNoArgByPrefix(state, "getBlockHeight");
            Long maxPayableMsat = reflectLongNoArgByPrefix(state, "getMaxPayableMsat");
            Long maxReceivableMsat = reflectLongNoArgByPrefix(state, "getMaxReceivableMsat");
            ret.put("blockHeight", blockHeight != null ? blockHeight : 0);
            ret.put("maxPayableMsat", maxPayableMsat != null ? maxPayableMsat : 0);
            ret.put("maxReceivableMsat", maxReceivableMsat != null ? maxReceivableMsat : 0);
            call.resolve(ret);
        } catch (Exception e) {
            call.reject(e.getMessage());
        }
    }

    @PluginMethod
    public void invoice(PluginCall call) {
        if (breezServices == null) {
            call.reject("Not started");
            return;
        }
        Long amountMsat = call.getLong("amountMsat"); // can be null for any amount
        String description = call.getString("description", "");
        
        executor.submit(() -> {
            try {
                long safeAmountMsat = amountMsat == null ? 0L : amountMsat;
                java.util.List<UByte> preimage = new java.util.ArrayList<>();
                ReceivePaymentRequest req = newPrivateInstance(
                    ReceivePaymentRequest.class,
                    new Class<?>[] { long.class, String.class, java.util.List.class, OpeningFeeParams.class, Boolean.class, UInt.class, UInt.class },
                    new Object[] { safeAmountMsat, description, preimage, null, null, null, null }
                );
                breez_sdk.ReceivePaymentResponse response = breezServices.receivePayment(req);
                
                JSObject ret = new JSObject();
                ret.put("bolt11", response.getLnInvoice().getBolt11());
                ret.put("paymentHash", response.getLnInvoice().getPaymentHash());
                call.resolve(ret);
            } catch (Exception e) {
                 call.reject("Invoice failed: " + e.getMessage());
            }
        });
    }

    @PluginMethod
    public void pay(PluginCall call) {
        if (breezServices == null) {
            call.reject("Not started");
            return;
        }
        String bolt11 = call.getString("bolt11");
        if (bolt11 == null) {
            call.reject("Missing bolt11");
            return;
        }

        executor.submit(() -> {
            try {
                SendPaymentRequest req = newPrivateInstance(
                    SendPaymentRequest.class,
                    new Class<?>[] { String.class, boolean.class, ULong.class, String.class },
                    new Object[] { bolt11, false, null, null }
                );
                SendPaymentResponse resp = breezServices.sendPayment(req);
                breez_sdk.Payment result = resp.getPayment();
                JSObject ret = new JSObject();
                ret.put("paymentHash", result.getId());
                ret.put("status", result.getStatus().name());
                Long amountMsat = reflectLongNoArgByPrefix(result, "getAmountMsat");
                ret.put("amountMsat", amountMsat != null ? amountMsat : 0);
                call.resolve(ret);
            } catch (Exception e) {
                 call.reject("Pay failed: " + e.getMessage());
            }
        });
    }
    
    @PluginMethod
    public void lnurlAuth(PluginCall call) {
        if (breezServices == null) {
            call.reject("Not started");
            return;
        }
        String lnurl = call.getString("lnurl");
        if (lnurl == null) {
            call.reject("Missing lnurl");
            return;
        }

        executor.submit(() -> {
            try {
                breez_sdk.InputType input = Breez_sdkKt.parseInput(lnurl);
                if (input instanceof breez_sdk.InputType.LnUrlAuth) {
                    breez_sdk.LnUrlAuthRequestData data = ((breez_sdk.InputType.LnUrlAuth) input).getData();
                    breez_sdk.LnUrlCallbackStatus result = breezServices.lnurlAuth(data);
                    
                    if (result instanceof breez_sdk.LnUrlCallbackStatus.Ok) {
                         call.resolve();
                    } else {
                         // Extract error details if available in the variant
                         call.reject("LNURL Auth failed with status: " + result.toString());
                    }
                } else {
                    call.reject("Provided string is not a valid LNURL-Auth URL");
                }
            } catch (Exception e) {
                call.reject("LNURL Auth Error: " + e.getMessage());
            }
        });
    }

    @PluginMethod
    public void stop(PluginCall call) {
        if (breezServices != null) {
             try {
                breezServices.disconnect();
             } catch (Exception e) {} // ignore
             breezServices = null;
        }
        call.resolve();
    }
}
