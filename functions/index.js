const {onRequest} = require("firebase-functions/v" + "2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const paymobApiKey = defineSecret("PAYMOB_API_KEY");
const sendgridApiKey = defineSecret("SENDGRID_API_KEY");
const twilioAccountSid = defineSecret("TWILIO_ACCOUNT_SID");
const twilioAuthToken = defineSecret("TWILIO_AUTH_TOKEN");
const twilioFromNumber = defineSecret("TWILIO_FROM_NUMBER");
const PAYMOB_BASE_URL = "https://accept.paymob.com/api";
const HTTP_TIMEOUT_MS = 15000;

function sendJson(res, statusCode, payload) {
  res.status(statusCode).json(payload);
}

function extractBearerToken(req) {
  const header = req.get("authorization") || "";
  if (!header.toLowerCase().startsWith("bearer ")) {
    return null;
  }
  return header.substring(7).trim();
}

function normalizePhone(rawPhone) {
  const trimmed = String(rawPhone || "").trim();
  if (!trimmed) return "";
  if (trimmed.startsWith("+")) return trimmed;
  const digits = trimmed.replace(/[^\d]/g, "");
  if (!digits) return "";
  return "+" + digits;
}

async function readJsonResponse(url, options) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), HTTP_TIMEOUT_MS);
  try {
    const response = await fetch(url, {...options, signal: controller.signal});
    const rawBody = await response.text();
    let body = {};
    if (rawBody) {
      try {
        body = JSON.parse(rawBody);
      } catch (_) {
        body = {};
      }
    }
    return {response, body};
  } finally {
    clearTimeout(timer);
  }
}

async function fetchPaymobPaymentState(paymobOrderId, apiKey) {
  if (!apiKey) {
    throw new Error("PAYMOB_API_KEY_MISSING");
  }

  const auth = await readJsonResponse(PAYMOB_BASE_URL + "/auth/tokens", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({api_key: apiKey}),
  });

  if (!auth.response.ok || typeof auth.body.token !== "string") {
    throw new Error("PAYMOB_AUTH_FAILED_" + auth.response.status);
  }

  const order = await readJsonResponse(
      PAYMOB_BASE_URL + "/ecommerce/orders/" + paymobOrderId,
      {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer " + auth.body.token,
        },
      },
  );

  if (!order.response.ok) {
    throw new Error("PAYMOB_ORDER_LOOKUP_FAILED_" + order.response.status);
  }

  const statusRaw = String(
      order.body.payment_status ||
      order.body?.data?.payment_status ||
      order.body?.order?.payment_status ||
      "",
  ).toUpperCase();

  const serverTransactionId = order.body?.last_transaction?.id != null ?
    String(order.body.last_transaction.id) :
    String(order.body?.id || paymobOrderId);

  return {
    statusRaw,
    isPaid: statusRaw === "PAID",
    isUnpaid: statusRaw === "UNPAID",
    isVoided: statusRaw === "VOIDED",
    transactionId: serverTransactionId,
  };
}

async function canConfirmPayment(uid, appointmentData) {
  if (appointmentData.patientId === uid) {
    return true;
  }

  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) return false;

  const role = String(userSnap.data()?.role || "").trim().toLowerCase();
  return role === "admin" || role === "receptionist";
}

async function sendAccountUpdateEmail({apiKey, toEmail, subject, body}) {
  const payload = {
    personalizations: [{to: [{email: toEmail}]}],
    from: {email: "no-reply@mediqueue.app", name: "MediQueue"},
    subject,
    content: [{type: "text/plain", value: body}],
  };

  const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: {
      "Authorization": "Bearer " + apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error("SENDGRID_REQUEST_FAILED_" + response.status);
  }
}

async function sendAccountUpdateSms({
  accountSid,
  authToken,
  fromNumber,
  toPhone,
  message,
}) {
  const authHeader = Buffer.from(accountSid + ":" + authToken).toString(
      "base64",
  );
  const payload = new URLSearchParams({
    To: toPhone,
    From: fromNumber,
    Body: message,
  });

  const response = await fetch(
      "https://api.twilio.com/2010-04-01/Accounts/" +
      accountSid +
      "/Messages.json",
      {
        method: "POST",
        headers: {
          "Authorization": "Basic " + authHeader,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: payload.toString(),
      },
  );

  if (!response.ok) {
    throw new Error("TWILIO_REQUEST_FAILED_" + response.status);
  }
}

exports.notifyDoctorAccountDecision = onDocumentCreated(
    {
      document: "users/{uid}/notifications/{notificationId}",
      region: "us-central1",
      timeoutSeconds: 60,
      secrets: [
        sendgridApiKey,
        twilioAccountSid,
        twilioAuthToken,
        twilioFromNumber,
      ],
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const notificationData = snapshot.data() || {};
      const notificationType = String(notificationData.type || "").trim();
      if (notificationType !== "account_update") return;

      const uid = String(event.params.uid || "").trim();
      if (!uid) return;

      const userSnapshot = await db.collection("users").doc(uid).get();
      if (!userSnapshot.exists) {
        logger.warn("notifyDoctorAccountDecision: user not found", {uid});
        return;
      }

      const userData = userSnapshot.data() || {};
      const doctorEmail = String(userData.email || "").trim().toLowerCase();
      const doctorPhone = normalizePhone(userData.phone);

      const title = String(notificationData.title || "MediQueue Account Update")
          .trim();
      const message = String(
          notificationData.message || "There is an update on your account.",
      ).trim();
      const metadata = notificationData.metadata || {};
      const status = String(metadata.status || "").trim().toLowerCase();
      const reason = String(metadata.reason || "").trim();

      const subject = title;
      const body =
          "Hello,\n\n" +
          message +
          (reason ? ("\n\nReason: " + reason) : "") +
          "\n\nIf you have questions, contact hospital administration.\n\n" +
          "MediQueue";
      const smsBody =
          "MediQueue: " +
          (status === "approved" ? "Your account is approved." :
            status === "rejected" ? "Your account request is rejected." :
            "Account update available.") +
          (reason ? (" Reason: " + reason) : "");

      let emailSent = false;
      let smsSent = false;

      const sgKey = sendgridApiKey.value();
      if (doctorEmail && sgKey) {
        try {
          await sendAccountUpdateEmail({
            apiKey: sgKey,
            toEmail: doctorEmail,
            subject,
            body,
          });
          emailSent = true;
        } catch (error) {
          logger.error("notifyDoctorAccountDecision: email failed", {
            uid,
            error: String(error),
          });
        }
      }

      const twSid = twilioAccountSid.value();
      const twToken = twilioAuthToken.value();
      const twFrom = twilioFromNumber.value();
      if (doctorPhone && twSid && twToken && twFrom) {
        try {
          await sendAccountUpdateSms({
            accountSid: twSid,
            authToken: twToken,
            fromNumber: twFrom,
            toPhone: doctorPhone,
            message: smsBody,
          });
          smsSent = true;
        } catch (error) {
          logger.error("notifyDoctorAccountDecision: sms failed", {
            uid,
            error: String(error),
          });
        }
      }

      await snapshot.ref.set({
        delivery: {
          emailSent,
          smsSent,
          attemptedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }, {merge: true});
    },
);

exports.confirmPaymobPayment = onRequest(
    {
      region: "us-central1",
      timeoutSeconds: 60,
      secrets: [paymobApiKey],
    },
    async (req, res) => {
      if (req.method !== "POST") {
        return sendJson(res, 405, {success: false, error: "Method not allowed"});
      }

      try {
        const bearerToken = extractBearerToken(req);
        if (!bearerToken) {
          return sendJson(res, 401, {
            success: false,
            error: "Missing Authorization bearer token",
          });
        }

        const decoded = await admin.auth().verifyIdToken(bearerToken);
        const appointmentId = String(req.body?.appointmentId || "").trim();
        const clientTransactionId = String(req.body?.transactionId || "").trim();

        if (!appointmentId) {
          return sendJson(res, 400, {
            success: false,
            error: "appointmentId is required",
          });
        }

        const appointmentRef = db.collection("appointments").doc(appointmentId);
        const appointmentSnap = await appointmentRef.get();
        if (!appointmentSnap.exists) {
          return sendJson(res, 404, {
            success: false,
            error: "Appointment not found",
          });
        }

        const appointmentData = appointmentSnap.data() || {};
        const allowed = await canConfirmPayment(decoded.uid, appointmentData);
        if (!allowed) {
          return sendJson(res, 403, {
            success: false,
            error: "Not allowed to confirm this appointment payment",
          });
        }

        const currentPaymentStatus = String(
            appointmentData.paymentStatus || "",
        ).trim().toLowerCase();
        const currentAppointmentStatus = String(
            appointmentData.status || "",
        ).trim().toLowerCase();

        if (currentPaymentStatus === "paid") {
          return sendJson(res, 200, {
            success: true,
            alreadyVerified: true,
            transactionId: String(appointmentData.transactionId || ""),
          });
        }

        if (currentAppointmentStatus === "cancelled") {
          return sendJson(res, 409, {
            success: false,
            error: "Appointment is cancelled",
          });
        }

        if (currentPaymentStatus === "expired") {
          return sendJson(res, 409, {
            success: false,
            error: "Payment has expired",
          });
        }

        const paymobOrderId = String(appointmentData.paymobOrderId || "").trim();
        if (!paymobOrderId) {
          return sendJson(res, 400, {
            success: false,
            error: "No Paymob order is attached to this appointment",
          });
        }

        const verification = await fetchPaymobPaymentState(
            paymobOrderId,
            paymobApiKey.value(),
        );

        if (verification.isPaid) {
          const transactionId = clientTransactionId ||
            verification.transactionId ||
            paymobOrderId;

          await appointmentRef.set({
            paymentStatus: "paid",
            paymentMethod: "online_card",
            transactionId,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            paymentVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});

          return sendJson(res, 200, {
            success: true,
            paymentStatus: "paid",
            transactionId,
          });
        }

        if (verification.isVoided) {
          return sendJson(res, 409, {
            success: false,
            error: "Payment is voided",
            paymentStatus: "expired",
          });
        }

        if (verification.isUnpaid) {
          return sendJson(res, 409, {
            success: false,
            error: "Payment is not confirmed yet",
            paymentStatus: "pending",
          });
        }

        return sendJson(res, 502, {
          success: false,
          error: "Unknown Paymob payment status: " + (verification.statusRaw || "UNKNOWN"),
        });
      } catch (error) {
        logger.error("confirmPaymobPayment failed", error);
        return sendJson(res, 500, {
          success: false,
          error: "Server failed to verify payment",
        });
      }
    },
);
