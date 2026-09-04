# Grafana OSS as the private application target.
#
# Mirrored into the project ECR repository because the target subnet has no
# internet path and pulls only through the ECR endpoints. Pinned rather than
# tracking latest, so a test window is reproducible.
#
# Only Grafana runs here. The Caddy and SCIM-bridge layers of the source lab
# are deliberately absent: Caddy exists to obtain a public certificate, which a
# private destination cannot do, and the OIDC and SCIM layers are the scope
# ADR-016 removed. Entra Private Access is the access control; Grafana is the
# resource behind it. See ADR-020.
FROM grafana/grafana-oss:13.0.2

# Anonymous viewer access with the login form disabled. The target holds no
# credentials of its own, so nothing secret enters the image, the task
# definition, or Terraform state, and reaching the page is itself the proof
# that Private Access allowed the session.
ENV GF_AUTH_ANONYMOUS_ENABLED=true \
    GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer \
    GF_AUTH_DISABLE_LOGIN_FORM=true \
    GF_AUTH_BASIC_ENABLED=false \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false

EXPOSE 3000
