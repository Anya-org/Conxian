#[derive(Serialize)]
pub struct StatusResponse {
    pub state_root: String,
    pub processed_height: u64,
    pub bitcoin_height: u64,
    pub safety_mode: bool,
    pub drift: u64,
}

async fn get_status(State(state): State<AppState>) -> Result<Json<StatusResponse>, StatusCode> {
    let state_root = state.nexus_state.get_state_root();

    let stx_row = sqlx::query("SELECT MAX(height) as max_height FROM stacks_blocks")
        .fetch_one(&state.storage.pg_pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let btc_row = sqlx::query("SELECT last_processed_height FROM bitcoin_sync_state WHERE id = 1")
        .fetch_one(&state.storage.pg_pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let processed_height: Option<i64> = stx_row.get("max_height");
    let bitcoin_height: i64 = btc_row.get("last_processed_height");

    let mut conn = state.storage.redis_client.get_multiplexed_async_connection().await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let safety_mode: bool = redis::cmd("GET").arg("nexus:safety_mode").query_async(&mut conn).await.unwrap_or(false);
    let drift: u64 = redis::cmd("GET").arg("nexus:drift").query_async(&mut conn).await.unwrap_or(0);

    Ok(Json(StatusResponse {
        state_root,
        processed_height: processed_height.unwrap_or(0) as u64,
        bitcoin_height: bitcoin_height as u64,
        safety_mode,
        drift,
    }))
}
