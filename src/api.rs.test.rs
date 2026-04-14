use crate::api::{DissolveConfirmRequest, DissolveData, DissolveRequest, RefreshData};

#[test]
fn dissolve_request_and_confirm_types_are_structural() {
    let request = DissolveRequest {
        tenant: Some("acme".to_string()),
        username: Some("alice".to_string()),
        password: Some("secret".to_string()),
    };
    let confirm = DissolveConfirmRequest {
        confirmation_token: "token".to_string(),
    };

    assert_eq!(request.tenant.as_deref(), Some("acme"));
    assert_eq!(request.username.as_deref(), Some("alice"));
    assert_eq!(request.password.as_deref(), Some("secret"));
    assert_eq!(confirm.confirmation_token, "token");
}

#[test]
fn dissolve_and_refresh_payloads_have_expected_fields() {
    let dissolve = DissolveData {
        confirmation_token: "token".to_string(),
        expires_in: 300,
    };
    let refresh = RefreshData {
        token: "jwt".to_string(),
        expires_in: 604800,
    };

    assert_eq!(dissolve.expires_in, 300);
    assert_eq!(refresh.expires_in, 604800);
}
