import * as Context from "effect/Context";
import * as Layer from "effect/Layer";
import { env } from "../../app/env";

export type IrohTrustBrokerConfigShape = {
  readonly lanDiscoverySecretBase64?: string;
  readonly accountSubjectSecretBase64?: string;
  readonly grantSigningPrivateKeyPem?: string;
  readonly grantSigningKid?: string;
  readonly grantVerificationKeysJson?: string;
  readonly relayMinterUrl?: string;
  readonly relayMinterHmacSecretBase64?: string;
  readonly relayMinterInsecureLoopbackOptIn: boolean;
  readonly deploymentEnvironment: string;
  readonly isVercelDeployment: boolean;
};

export class IrohTrustBrokerConfig extends Context.Tag("hmux/IrohTrustBrokerConfig")<
  IrohTrustBrokerConfig,
  IrohTrustBrokerConfigShape
>() {}

export function irohTrustBrokerConfigFromEnv(): IrohTrustBrokerConfigShape {
  return {
    lanDiscoverySecretBase64: env.HMUX_IROH_LAN_DISCOVERY_SECRET_B64,
    accountSubjectSecretBase64: env.HMUX_IROH_ACCOUNT_SUBJECT_SECRET_B64,
    grantSigningPrivateKeyPem: env.HMUX_IROH_GRANT_SIGNING_KEY_P8,
    grantSigningKid: env.HMUX_IROH_GRANT_SIGNING_KID,
    grantVerificationKeysJson: env.HMUX_IROH_GRANT_VERIFICATION_KEYS_JSON,
    relayMinterUrl: env.HMUX_IROH_MINT_URL,
    relayMinterHmacSecretBase64: env.HMUX_IROH_MINT_HMAC_SECRET_B64,
    relayMinterInsecureLoopbackOptIn:
      env.HMUX_IROH_DEV_ALLOW_INSECURE_LOOPBACK_MINTER === "1",
    deploymentEnvironment: process.env.VERCEL_ENV ?? process.env.NODE_ENV ?? "development",
    isVercelDeployment: process.env.VERCEL === "1",
  };
}

export const IrohTrustBrokerConfigLive = Layer.succeed(
  IrohTrustBrokerConfig,
  irohTrustBrokerConfigFromEnv(),
);

