const admin = require("firebase-admin");

/**
 * Send FCM notification to a specific device token
 * @param {string} deviceToken - FCM device token from the client app
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Optional data payload
 * @returns {Promise<string>} Message ID if successful
 */
async function sendNotification(deviceToken, title, body, data = {}) {
  try {
    const message = {
      token: deviceToken,
      notification: {
        title: title,
        body: body,
      },
      data: data,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log(`Notification sent successfully: ${response}`);
    return response;
  } catch (error) {
    console.error("Error sending notification:", error);
    throw error;
  }
}

/**
 * Send multicast notification to multiple device tokens
 * @param {string[]} deviceTokens - Array of FCM device tokens
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {object} data - Optional data payload
 * @returns {Promise<object>} Results for each token
 */
async function sendMulticastNotification(deviceTokens, title, body, data = {}) {
  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    const response = await admin
      .messaging()
      .sendMulticast({ ...message, tokens: deviceTokens });

    console.log(
      `Multicast notification sent. Success: ${response.successCount}, Failed: ${response.failureCount}`,
    );
    return response;
  } catch (error) {
    console.error("Error sending multicast notification:", error);
    throw error;
  }
}

module.exports = {
  sendNotification,
  sendMulticastNotification,
};
