/**
 * Google Play subscription refund/revoke detection.
 * - checkSubscriptionStatus: callable to verify one user's subscription via Play API.
 * - runSubscriptionCheckJob: scheduled every 6 hours to verify all premium users and revoke if needed.
 *
 * Setup:
 * 1. Enable Android Publisher API in Google Cloud.
 * 2. Create a service account, grant it access in Play Console (Settings > API access).
 * 3. Set Firebase config: firebase functions:config:set play.package_name="com.instaflow"
 * 4. Store service account JSON as a secret or in config (e.g. play.service_account_json).
 *    For secret: firebase functions:secrets:set PLAY_SERVICE_ACCOUNT_JSON
 *    (paste the JSON when prompted)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");

function getPackageName() {
  return process.env.PLAY_PACKAGE_NAME || functions.config().play?.package_name || "com.instaflow";
}
const SUBSCRIPTION_ID = "premium_monthly";

function getAndroidPublisherClient() {
  const raw = process.env.PLAY_SERVICE_ACCOUNT_JSON || functions.config().play?.service_account_json;
  if (!raw) {
    throw new Error("PLAY_SERVICE_ACCOUNT_JSON or functions.config().play.service_account_json required for subscription check");
  }
  const credentials = typeof raw === "string" ? JSON.parse(raw) : raw;
  const auth = new google.auth.GoogleAuth({ credentials });
  return google.androidpublisher({ version: "v3", auth });
}

/**
 * Check subscription status with Google Play API.
 * Returns { valid: boolean, reason?: string }.
 * If not valid (expired, cancelled, refunded), caller should revoke.
 */
async function checkSubscriptionWithPlay(purchaseToken) {
  const androidPublisher = getAndroidPublisherClient();
  const packageName = getPackageName();
  const res = await androidPublisher.purchases.subscriptions.get({
    packageName,
    subscriptionId: SUBSCRIPTION_ID,
    token: purchaseToken,
  });
  const sub = res.data;
  const nowMs = Date.now();
  const expiryMs = parseInt(sub.expiryTimeMillis || "0", 10);
  const cancelReason = parseInt(sub.cancelReason || "0", 10);
  const paymentState = parseInt(sub.paymentState || "0", 10);

  if (expiryMs > 0 && expiryMs < nowMs) {
    return { valid: false, reason: "expired" };
  }
  if (cancelReason === 1) {
    return { valid: false, reason: "cancelled_by_user" };
  }
  if (cancelReason === 2) {
    return { valid: false, reason: "cancelled_by_system" };
  }
  if (cancelReason === 3) {
    return { valid: false, reason: "replaced" };
  }
  if (paymentState !== 1 && paymentState !== 2) {
    return { valid: false, reason: "payment_not_received" };
  }
  return { valid: true };
}

/**
 * Revoke premium in Firestore and write refund_logs.
 */
async function revokePremium(uid, userSnap, reason) {
  const db = admin.firestore();
  const userData = userSnap.data() || {};
  const email = userData.email || "";
  const duration = userData.premiumDuration || "";
  const premiumExpiry = userData.premiumExpiry?.toDate?.()?.toISOString?.() || null;
  const premiumStartDate = userData.premiumStartDate?.toDate?.()?.toISOString?.() || null;

  await db.collection("users").doc(uid).update({
    isPremium: false,
    premiumPlan: "none",
    premiumDuration: "none",
    premiumExpiry: null,
    premiumStartDate: null,
    premiumStatus: "revoked",
    refundDetected: true,
    premiumRemovedAt: admin.firestore.FieldValue.serverTimestamp(),
    subscriptionPurchaseToken: admin.firestore.FieldValue.delete(),
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection("refund_logs").add({
    uid,
    email,
    duration,
    purchaseDate: premiumStartDate,
    revokedAt: admin.firestore.FieldValue.serverTimestamp(),
    reason: reason || "revoked",
    expiryWas: premiumExpiry,
  });

  functions.logger.info(`Revoked premium for ${uid} (${email}), reason: ${reason}`);
}

/**
 * Callable: checkSubscriptionStatus(uid, purchaseToken, productId).
 * Verifies subscription with Play API and revokes if invalid.
 * Only the user themselves or admin should call this (caller must be authenticated; optionally check uid === auth.uid).
 */
exports.checkSubscriptionStatus = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 60 })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }
    const { uid, purchaseToken, productId } = data || {};
    if (!uid || !purchaseToken) {
      throw new functions.https.HttpsError("invalid-argument", "uid and purchaseToken required");
    }
    if (context.auth.uid !== uid) {
      const userDoc = await admin.firestore().collection("users").doc(context.auth.uid).get();
      const isAdmin = userDoc.exists && userDoc.data()?.isAdmin === true;
      if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Can only check own subscription");
      }
    }

    try {
      const result = await checkSubscriptionWithPlay(purchaseToken);
      if (result.valid) {
        return { ok: true, valid: true };
      }
      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      if (!userSnap.exists) {
        return { ok: true, valid: false, reason: result.reason };
      }
      await revokePremium(uid, userSnap, result.reason);
      return { ok: true, valid: false, revoked: true, reason: result.reason };
    } catch (err) {
      functions.logger.error("checkSubscriptionStatus error", err);
      throw new functions.https.HttpsError("internal", err.message);
    }
  });

/**
 * Scheduled job: every 6 hours, get all premium users with subscriptionPurchaseToken and verify each.
 */
exports.runSubscriptionCheckJob = functions
  .region("us-central1")
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("0 */6 * * *")
  .timeZone("UTC")
  .onRun(async () => {
    const db = admin.firestore();
    const snapshot = await db.collection("users").where("isPremium", "==", true).get();
    let revoked = 0;
    for (const doc of snapshot.docs) {
      const token = doc.data().subscriptionPurchaseToken;
      if (!token || typeof token !== "string") continue;
      try {
        const result = await checkSubscriptionWithPlay(token);
        if (!result.valid) {
          await revokePremium(doc.id, doc, result.reason);
          revoked++;
        }
      } catch (err) {
        functions.logger.warn(`Subscription check failed for ${doc.id}:`, err.message);
      }
    }
    functions.logger.info(`runSubscriptionCheckJob: checked ${snapshot.size}, revoked ${revoked}`);
    return null;
  });
