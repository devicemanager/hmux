ALTER TABLE "vault_cli_auth_requests"
ADD COLUMN "client" text DEFAULT 'hmux-vault' NOT NULL;
--> statement-breakpoint
ALTER TABLE "vault_cli_auth_requests"
ADD CONSTRAINT "vault_cli_auth_requests_client_check"
CHECK ("client" in ('hmux-vault', 'subrouter'));
