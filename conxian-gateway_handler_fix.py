import os

path = 'conxian-gateway/internal/api/src/handlers.rs'
if os.path.exists(path):
    with open(path, 'r') as f:
        content = f.read()

    # Update execute_alex_swap to parse request and call alex client
    search_str = """pub async fn execute_alex_swap(
    State(_state): State<AppState>,
    _body: Body,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    warn!("ALEX swap requested but signer integration is unavailable");
    Err((
        StatusCode::NOT_IMPLEMENTED,
        Json(json!({
            "error": "Swap execution not available: signer integration required",
            "code": "alex_swap_signer_unavailable"
        })),
    ))
}"""

    replace_str = """pub async fn execute_alex_swap(
    State(state): State<AppState>,
    Json(request): Json<conxian_core::AlexSwapRequest>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    info!("Processing ALEX swap request...");
    match state.alex.execute_swap(request, "SYSTEM_ENCLAVE_KEY").await {
        Ok(txid) => Ok(Json(json!({ "status": "handshake_initiated", "txid": txid }))),
        Err(e) => Err((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "error": e.to_string() })),
        )),
    }
}"""

    if search_str in content:
        content = content.replace(search_str, replace_str)
        with open(path, 'w') as f:
            f.write(content)
        print(f"Fixed {path}")
    else:
        print("Search string not found in handlers.rs")
else:
    print(f"File not found: {path}")
