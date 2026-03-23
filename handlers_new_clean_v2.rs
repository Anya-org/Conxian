use axum::{extract::State, http::StatusCode, Json};
use compliance::{IdentityManager, SimulatedHsm, ZkcVerifier};
use conxian_core::{AttestationRequest, GcpTokenRequest, HardwareTrust, SharedState};
use serde_json::{json, Value};
use std::time::{SystemTime, UNIX_EPOCH};
use tracing::{error, info};

pub async fn health_check(State(state): State<SharedState>) -> Json<Value> {
    let s = state.read().unwrap();
    let mut status = "healthy";
    let mut details = Vec::new();

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    if s.bitcoin.status.contains("error") {
        status = "degraded";
        details.push(format!("Bitcoin error: {}", s.bitcoin.status));
        status = "degraded";
        details.push(format!(
            "Bitcoin sync is stale (last sync: {}s ago)",
            now.saturating_sub(s.bitcoin.last_sync_time)
        ));

    if s.stacks.status.contains("error") {
        status = "degraded";
        details.push(format!("Stacks error: {}", s.stacks.status));
        status = "degraded";
        details.push(format!(
            "Stacks sync is stale (last sync: {}s ago)",
            now.saturating_sub(s.stacks.last_sync_time)
        ));

    {
        let mut s_write = state.write().unwrap();
        s_write.metrics.total_requests += 1;
        s_write.metrics.health_requests += 1;

    Json(json!({
        "status": status,
        "service": "conxian-gateway",
        "version": conxian_core::VERSION,
        "details": if details.is_empty() { None } else { Some(details) },
        "timestamp": now,
        "industry_enhancements": "enabled"

pub async fn get_state(State(state): State<SharedState>) -> Json<Value> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;
        s.metrics.state_requests += 1;
    let s = state.read().unwrap();
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    let uptime = now.saturating_sub(s.start_time);

    Json(json!({
        "bitcoin": s.bitcoin,
        "stacks": s.stacks,
        "metrics": s.metrics,
        "start_time": s.start_time,
        "uptime_seconds": uptime,
        "current_timestamp": now,
        "tam_capture": {
            "sbtc_liquidity": s.metrics.sbtc_liquidity,
            "syi_index": s.metrics.syi_index

pub async fn get_metrics(State(state): State<SharedState>) -> String {
    let mut s_write = state.write().unwrap();
    s_write.metrics.total_requests += 1;
    s_write.metrics.metrics_requests += 1;
    drop(s_write);

    let s = state.read().unwrap();
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    let uptime = now.saturating_sub(s.start_time);

    format!(
        "# HELP gateway_total_requests The total number of API requests received.\n         # TYPE gateway_total_requests counter\n         gateway_total_requests {}\n         # HELP gateway_health_requests The number of health check requests.\n         # TYPE gateway_health_requests counter\n         gateway_health_requests {}\n         # HELP gateway_state_requests The number of state requests.\n         # TYPE gateway_state_requests counter\n         gateway_state_requests {}\n         # HELP gateway_metrics_requests The number of metrics requests.\n         # TYPE gateway_metrics_requests counter\n         gateway_metrics_requests {}\n         # HELP gateway_verification_requests The total number of attestation verifications attempted.\n         # TYPE gateway_verification_requests counter\n         gateway_verification_requests {}\n         # HELP gateway_verification_success The number of successful attestation verifications.\n         # TYPE gateway_verification_success counter\n         gateway_verification_success {}\n         # HELP gateway_verification_failure The number of failed attestation verifications.\n         # TYPE gateway_verification_failure counter\n         gateway_verification_failure {}\n         # HELP bitcoin_block_height The current block height of the Bitcoin chain.\n         # TYPE bitcoin_block_height gauge\n         bitcoin_block_height {}\n         # HELP stacks_block_height The current block height of the Stacks chain.\n         # TYPE stacks_block_height gauge\n         stacks_block_height {}\n         # HELP bitcoin_last_sync_timestamp The last successful sync timestamp for Bitcoin.\n         # TYPE bitcoin_last_sync_timestamp gauge\n         bitcoin_last_sync_timestamp {}\n         # HELP stacks_last_sync_timestamp The last successful sync timestamp for Stacks.\n         # TYPE stacks_last_sync_timestamp gauge\n         stacks_last_sync_timestamp {}\n         # HELP gateway_uptime_seconds The total uptime of the gateway in seconds.\n         # TYPE gateway_uptime_seconds counter\n         gateway_uptime_seconds {}\n         # HELP treasury_balance_stx Current STX balance in treasury.\n         # TYPE treasury_balance_stx gauge\n         treasury_balance_stx {}\n         # HELP treasury_balance_btc Current BTC balance in treasury.\n         # TYPE treasury_balance_btc gauge\n         treasury_balance_btc {}\n         # HELP sbtc_liquidity Current sBTC liquidity in $ (TAM Capture).\n         # TYPE sbtc_liquidity gauge\n         sbtc_liquidity {}\n         # HELP syi_index Current Sovereign Yield Index value.\n         # TYPE syi_index gauge\n         syi_index {}\n",
        s.metrics.total_requests,
        s.metrics.health_requests,
        s.metrics.state_requests,
        s.metrics.metrics_requests,
        s.metrics.verification_requests,
        s.metrics.verification_success,
        s.metrics.verification_failure,
        s.bitcoin.height,
        s.stacks.height,
        s.bitcoin.last_sync_time,
        s.stacks.last_sync_time,
        uptime,
        s.metrics.treasury_balance_stx,
        s.metrics.treasury_balance_btc,
        s.metrics.sbtc_liquidity,
        s.metrics.syi_index
    )

pub async fn verify_attestation(
    State(state): State<SharedState>,
    Json(request): Json<AttestationRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;
        s.metrics.verification_requests += 1;

    let verifier = ZkcVerifier::new();
    let (attestation_type, result) = match request {
        AttestationRequest::Ecdsa(a) => ("ECDSA", verifier.verify(&a)),
        AttestationRequest::Schnorr(a) => ("Schnorr", verifier.verify_schnorr(&a)),
        AttestationRequest::Zkml(a) => ("ZKML", verifier.verify_zkml(&a)),
        AttestationRequest::BitVm(a) => ("BitVM", verifier.verify_bitvm(&a)),

    info!(
        "Processing {} attestation verification request",
        attestation_type
    );

    match result {
        Ok(valid) => {
            {
                let mut s = state.write().unwrap();
                if valid {
                    s.metrics.verification_success += 1;
                    info!("{} attestation verified successfully", attestation_type);
                } else {
                    s.metrics.verification_failure += 1;
                    info!(
                        "{} attestation verification failed: invalid signature",
                        attestation_type
                    );
                }
            }
            Ok(Json(json!({ "valid": valid, "type": attestation_type })))
        Err(e) => {
            {
                let mut s = state.write().unwrap();
                s.metrics.verification_failure += 1;
            }
            info!("{} attestation verification error: {}", attestation_type, e);
            Err((
                StatusCode::BAD_REQUEST,
                Json(json!({ "error": e.to_string(), "type": attestation_type })),
            ))

pub async fn exchange_identity(
    State(state): State<SharedState>,
    Json(request): Json<GcpTokenRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;

    let manager = IdentityManager::new();
    match manager.exchange_token(&request).await {
        Ok(token) => Ok(Json(
            json!({ "access_token": token, "token_type": "Bearer", "expires_in": 3600 }),
        )),
        Err(e) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "error": e.to_string() })),
        )),

pub async fn generate_iso_payment(
    State(_state): State<SharedState>,
    Json(payload): Json<Value>,
) -> Result<String, (StatusCode, Json<Value>)> {
    let sender = payload["sender"].as_str().unwrap_or("CONXIAN-SENDER");
    let receiver = payload["receiver"]
        .as_str()
        .unwrap_or("INSTITUTIONAL-RECEIVER");
    let amount = payload["amount"].as_f64().unwrap_or(0.0);

    let verifier = ZkcVerifier::new();
    Ok(verifier.format_iso20022_pacs008(sender, receiver, amount))

pub async fn generate_mvcr(
    State(state): State<SharedState>,
    Json(request): Json<conxian_core::MvcrRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;

    let verifier = ZkcVerifier::new();
    let hsm = SimulatedHsm::new();

    match verifier.generate_mvcr(&request.nexus_id, &request.state_root) {
        Ok(report_hash) => {
            let hsm_receipt = hsm.sign_receipt(&report_hash).unwrap_or_default();
            info!("MVCR generated and HSM-signed successfully for Nexus: {}", request.nexus_id);
            Ok(Json(json!({
                "nexus_id": request.nexus_id,
                "report_hash": report_hash,
                "hsm_receipt": hsm_receipt,
                "fips_level": hsm.get_fips_level(),
                "status": "Verified",
                "timestamp": SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
            })))
        Err(e) => {
            error!("MVCR generation failed: {}", e);
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": e.to_string() })),
            ))

pub async fn export_compliance_report(
    State(state): State<SharedState>,
    Json(request): Json<conxian_core::ComplianceReportRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;

    let verifier = ZkcVerifier::new();
    match verifier.export_compliance_report(&request.entity_id, request.timeframe) {
        Ok(report) => {
            info!("Compliance report exported successfully for entity: {}", request.entity_id);
            Ok(Json(report))
        Err(e) => {
            error!("Compliance report export failed: {}", e);
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": e.to_string() })),
            ))



        let res = get_state(State(state)).await;

/// Industry Enhancement: Trigger x402 M2M Settlement.
pub async fn trigger_x402(
    State(state): State<SharedState>,
    Json(request): Json<conxian_core::X402Request>,
) -> Result<Json<conxian_core::X402Response>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;

    info!("Processing x402 settlement for agent: {}", request.agent_id);

    // Simulation: valid if amount > 0 and signature present
    if request.amount == 0 || request.signature.is_empty() {
        return Err((StatusCode::BAD_REQUEST, Json(json!({"error": "Invalid x402 request parameters"}))));

    let receipt_hash = format!("x402-receipt-{}-{}", request.agent_id, uuid::Uuid::new_v4());

    Ok(Json(conxian_core::X402Response {
        status: "Accepted".to_string(),
        txid: Some(format!("txid-{}", uuid::Uuid::new_v4())),
        receipt_hash,

/// Industry Enhancement: Request Stateless OTP.
pub async fn request_otp(
    State(state): State<SharedState>,
    Json(request): Json<conxian_core::OtpRequest>,
) -> Result<Json<conxian_core::OtpResponse>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;

    info!("Requesting stateless OTP for phone: {}", request.phone_number);

    let session_id = format!("otp-session-{}", uuid::Uuid::new_v4());
    let expires_at = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() + 300;

    Ok(Json(conxian_core::OtpResponse {
        session_id,
        expires_at,

/// Industry Enhancement: Verify Stateless OTP.
pub async fn verify_otp(
    State(state): State<SharedState>,
    Json(request): Json<conxian_core::OtpVerifyRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    {
        let mut s = state.write().unwrap();
        s.metrics.total_requests += 1;

    info!("Verifying OTP for session: {}", request.session_id);

    // Simulation: any 6-digit code is valid
    if request.code.len() == 6 && request.code.chars().all(|c| c.is_digit(10)) {
        Ok(Json(json!({ "status": "Verified", "session_id": request.session_id })))
        Err((StatusCode::UNAUTHORIZED, Json(json!({ "error": "Invalid OTP code" }))))

#[cfg(test)]
mod tests {
    use super::*;
    use conxian_core::GatewayState;
    use std::sync::{Arc, RwLock};

    #[tokio::test]
    async fn test_health_check_handler() {
        let state = Arc::new(RwLock::new(GatewayState::default()));
        let res = health_check(State(state)).await;
        assert_eq!(res.0["status"], "healthy");
        assert_eq!(res.0["version"], conxian_core::VERSION);
    }

    #[tokio::test]
    async fn test_get_state_handler() {
        let state = Arc::new(RwLock::new(GatewayState::default()));
        {
            let mut s = state.write().unwrap();
            s.bitcoin.height = 100;
        }
        let res = get_state(State(state)).await;
        assert_eq!(res.0["bitcoin"]["height"], 100);
        assert_eq!(res.0["metrics"]["state_requests"], 1);
        assert!(res.0.as_object().unwrap().contains_key("uptime_seconds"));
    }
}
